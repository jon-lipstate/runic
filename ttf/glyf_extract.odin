package ttf

import "core:fmt"
import "core:mem"

IDENTITY_MATRIX :: matrix[2, 3]f32{
	1.0, 0.0, 0.0, 
	0.0, 1.0, 0.0, 
}

Extracted_Glyph :: union {
	Extracted_Simple_Glyph,
	Extracted_Compound_Glyph,
}

Extracted_Simple_Glyph :: struct {
	// Points from the font file
	points:            [][2]i16, // Allocated
	on_curve:          []bool, // Allocated
	contour_endpoints: []u16, // Allocated - Specifies the slices of `points` that form distinct contours

	// Hinting data
	instructions:      []byte,
	bounds:            Bounding_Box,
}

Extracted_Compound_Glyph :: struct {
	components:   []Glyph_Component, // Allocated
	instructions: []byte,
}

Glyph_Component :: struct {
	glyph_id:      u16, // Reference to another glyph
	transform:     matrix[2, 3]f32,
	round_to_grid: bool,
}

extract_glyph :: proc(
	glyf: ^Glyf_Table,
	glyph_id: Glyph,
	allocator := context.allocator,
) -> (
	result: Extracted_Glyph,
	ok: bool,
) {
	if glyf == nil {return {}, false}

	glyph_entry, got_entry := get_glyf_entry(glyf, glyph_id)
	if !got_entry {return {}, false}

	bbox, _ := get_bbox(glyph_entry)

	// Handle empty glyphs (spaces, etc.)
	if glyph_entry.is_empty {
		// Return an empty simple glyph
		simple := Extracted_Simple_Glyph {
			bounds = bbox,
		}
		return simple, true
	}

	if is_composite_glyph(glyph_entry) {
		return extract_compound_glyph(&glyph_entry, bbox, allocator)
	} else {
		return extract_simple_glyph(&glyph_entry, bbox, allocator)
	}
}

extract_simple_glyph :: proc(
	glyph: ^Glyf_Entry,
	bbox: Bounding_Box,
	allocator := context.allocator,
) -> (
	result: Extracted_Glyph,
	ok: bool,
) {
	// Get number of contours
	num_contours := glyph.header.number_of_contours
	if num_contours <= 0 {return}

	// Get contour endpoints
	end_points_be := get_end_points(glyph^) or_return

	point_count := int(end_points_be[len(end_points_be) - 1]) + 1

	endpoints := make([]u16, len(end_points_be), allocator)
	defer if !ok {delete(endpoints)}

	for i := 0; i < len(endpoints); i += 1 {
		endpoints[i] = u16(end_points_be[i])
	}

	// Get instructions
	instructions := get_instructions(glyph^) or_return

	// Now extract the points and flags
	points := make([][2]i16, point_count, allocator)
	defer if !ok {delete(points)}
	on_curve := make([]bool, point_count, allocator)
	defer if !ok {delete(on_curve)}
	// FIXME: flags should be on scratch
	flags := make([]Simple_Glyph_Flags, point_count, allocator)
	defer delete(flags)


	// Calculate offsets for parsing
	end_points_offset := uint(size_of(OpenType_Glyf_Entry_Header))
	instruction_len_offset := end_points_offset + uint(glyph.header.number_of_contours) * 2
	instruction_length := uint(len(instructions))
	flags_offset := instruction_len_offset + 2 + instruction_length

	// Start parsing points
	current_offset := flags_offset
	point_idx := 0

	// Flag parsing pass
	for point_idx < point_count {
		if bounds_check(current_offset >= uint(len(glyph.slice))) {return}

		flags[point_idx] = read_simple_glyph_flags(glyph.slice[current_offset])
		current_offset += 1
		on_curve[point_idx] = .ON_CURVE_POINT in flags[point_idx]
		// Handle repeat flag
		if .REPEAT_FLAG in flags[point_idx] {
			if bounds_check(current_offset >= uint(len(glyph.slice))) {return}

			// Get repeat count
			repeat_count := int(glyph.slice[current_offset])
			current_offset += 1

			// Check if we have enough space for all repeats
			if point_idx + repeat_count >= point_count {
				repeat_count = point_count - point_idx - 1
			}

			// Set the repeated flags
			repeating_flag := flags[point_idx]
			repeating_flag ~= {.REPEAT_FLAG} // Clear repeat flag for copies

			for j := 0; j < repeat_count; j += 1 {
				point_idx += 1
				flags[point_idx] = repeating_flag
				on_curve[point_idx] = .ON_CURVE_POINT in repeating_flag
			}
		}

		point_idx += 1
	}

	// X coordinates
	current_offset = flags_offset
	// Skip past all flags
	for i := 0; i < point_count; i += 1 {
		flag := flags[i]
		if .REPEAT_FLAG in flag {
			current_offset += 1 // Skip repeat count
		}
		current_offset += 1 // Flag byte
	}

	// Now parse X coordinates
	x_coord := i16(0)
	for i := 0; i < point_count; i += 1 {
		flag := flags[i]

		if .X_SHORT_VECTOR in flag {
			// 1-byte X coordinate
			if bounds_check(current_offset >= uint(len(glyph.slice))) {return}

			delta := i16(glyph.slice[current_offset])
			current_offset += 1

			// If X_IS_SAME is clear, the value is negative
			if .X_IS_SAME not_in flag {
				delta = -delta
			}

			x_coord += delta
		} else if .X_IS_SAME in flag {
			// X coordinate is same as previous (delta = 0)
		} else {
			// 2-byte X coordinate delta
			if bounds_check(current_offset + 1 >= uint(len(glyph.slice))) {return}

			delta := i16(read_i16(glyph.slice, current_offset))
			current_offset += 2
			x_coord += delta
		}

		points[i][0] = x_coord
	}

	// Y coordinates
	y_coord := i16(0)
	for i := 0; i < point_count; i += 1 {
		flag := flags[i]

		if .Y_SHORT_VECTOR in flag {
			// 1-byte Y coordinate
			if bounds_check(current_offset >= uint(len(glyph.slice))) {return}

			delta := i16(glyph.slice[current_offset])
			current_offset += 1

			// If Y_IS_SAME is clear, the value is negative
			if .Y_IS_SAME not_in flag {
				delta = -delta
			}

			y_coord += delta
		} else if .Y_IS_SAME in flag {
			// Y coordinate is same as previous (delta = 0)
		} else {
			// 2-byte Y coordinate delta
			if bounds_check(current_offset + 1 >= uint(len(glyph.slice))) {return}

			delta := i16(read_i16(glyph.slice, current_offset))
			current_offset += 2
			y_coord += delta
		}

		points[i][1] = y_coord
	}

	simple := Extracted_Simple_Glyph {
		points            = points,
		on_curve          = on_curve,
		contour_endpoints = endpoints,
		instructions      = instructions, // slice into the font file
		bounds            = bbox,
	}
	ok = true
	return simple, ok
}

// Extract data for a compound glyph
extract_compound_glyph :: proc(
	glyph: ^Glyf_Entry,
	bbox: Bounding_Box,
	allocator := context.allocator,
) -> (
	result: Extracted_Glyph,
	ok: bool,
) {
	if glyph.header.number_of_contours >= 0 {return}

	parser, parser_ok := init_component_parser(glyph^)
	if !parser_ok {return}

	components := make([dynamic]Glyph_Component, allocator)
	defer if !ok {delete(components)}

	// Process all components
	component_data_end_offset := uint(size_of(OpenType_Glyf_Entry_Header))
	instructions_offset := uint(0)
	has_instructions := false

	for component in next_component(&parser) {
		// Save the last component's end offset
		component_data_end_offset = parser.current_offset

		// Check if we have instructions
		if .WE_HAVE_INSTRUCTIONS in component.flags {
			has_instructions = true
		}

		// Update matrix values based on the component flags
		mat := IDENTITY_MATRIX

		// Set translation
		mat[0, 2] = f32(component.x_offset)
		mat[1, 2] = f32(component.y_offset)

		// Apply scaling/transformation based on flags
		if .WE_HAVE_A_SCALE in component.flags {
			mat[0, 0] = component.scale_x
			mat[1, 1] = component.scale_x
		} else if .WE_HAVE_AN_X_AND_Y_SCALE in component.flags {
			mat[0, 0] = component.scale_x
			mat[1, 1] = component.scale_y
		} else if .WE_HAVE_A_TWO_BY_TWO in component.flags {
			mat[0, 0] = component.matrx[0]
			mat[0, 1] = component.matrx[1]
			mat[1, 0] = component.matrx[2]
			mat[1, 1] = component.matrx[3]
		}

		// Add the component
		glyph_component := Glyph_Component {
			glyph_id      = u16(component.glyph_index),
			transform     = mat,
			round_to_grid = .ROUND_XY_TO_GRID in component.flags,
		}

		append(&components, glyph_component)

		// If we're done with components, remember the offset for instructions
		if .MORE_COMPONENTS not_in component.flags {
			instructions_offset = parser.current_offset
			break
		}
	}

	// Extract instructions if present
	instructions: []byte
	if has_instructions {
		if bounds_check(instructions_offset + 2 <= uint(len(glyph.slice))) {
			instruction_count := uint(read_u16(glyph.slice, instructions_offset))
			instructions_offset += 2

			if bounds_check(instructions_offset + instruction_count <= uint(len(glyph.slice))) {
				instructions =
				glyph.slice[instructions_offset:instructions_offset + instruction_count]
			}
		}
	}

	compound := Extracted_Compound_Glyph {
		components   = components[:],
		instructions = instructions,
	}
	ok = true
	return compound, ok
}

destroy_extracted_glyph :: proc(glyph: ^Extracted_Glyph) {
	switch g in glyph {
	case Extracted_Simple_Glyph:
		delete(g.points)
		delete(g.on_curve)
		delete(g.contour_endpoints)
	case Extracted_Compound_Glyph:
		delete(g.components)
	}
}

/*
// Flatten a compound glyph into a single simple glyph
// This recursively processes all components and combines them
flatten_compound_glyph :: proc(
	glyf: ^Glyf_Table,
	compound: ^Extracted_Compound_Glyph,
	allocator := context.allocator,
) -> (
	simple: Extracted_Simple_Glyph,
	ok: bool,
) {
	result_points := make([dynamic][2]i16, allocator)
	result_flags := make([dynamic]Simple_Glyph_Flags, allocator)
	result_endpoints := make([dynamic]u16, allocator)

	point_count := 0

	// Process all components recursively
	for component in compound.components {
		// Extract the component glyph
		component_glyph, got_glyph := extract_glyph(glyf, Glyph(component.glyph_id), allocator) // FIXME: use cache
		if !got_glyph {continue}
		defer destroy_extracted_glyph(&component_glyph)

		// Transform and add the component's data
		switch &g in component_glyph {
		case Extracted_Simple_Glyph:
			// Calculate point offset for contour endpoints
			endpoint_offset := u16(point_count)

			// Add transformed points and flags
			for i := 0; i < len(g.points); i += 1 {
				// Apply transform
				px := f32(g.points[i][0])
				py := f32(g.points[i][1])

				// Matrix multiplication
				new_x :=
					component.transform[0, 0] * px +
					component.transform[0, 1] * py +
					component.transform[0, 2]
				new_y :=
					component.transform[1, 0] * px +
					component.transform[1, 1] * py +
					component.transform[1, 2]

				// Round if needed
				if component.round_to_grid {
					new_x = f32(i16(new_x + 0.5))
					new_y = f32(i16(new_y + 0.5))
				}

				// Add to result
				append(&result_points, [2]i16{i16(new_x), i16(new_y)})
				append(&result_flags, g.flags[i])
			}

			// Update and add contour endpoints
			for endpoint in g.contour_endpoints {
				append(&result_endpoints, endpoint + endpoint_offset)
			}

			// Update point count
			point_count += len(g.points)

		case Extracted_Compound_Glyph:
			// Recursively flatten the nested compound glyph
			flattened, flatten_ok := flatten_compound_glyph(glyf, &g, allocator)
			if !flatten_ok {continue}
			flat_glyph: Extracted_Glyph = flattened // FIXME: maybe dont need ptr..
			defer destroy_extracted_glyph(&flat_glyph)

			// Calculate point offset for contour endpoints
			endpoint_offset := u16(point_count)

			// Add transformed points and flags
			for i := 0; i < len(flattened.points); i += 1 {
				// Apply transform
				px := f32(flattened.points[i][0])
				py := f32(flattened.points[i][1])

				// Matrix multiplication
				new_x :=
					component.transform[0, 0] * px +
					component.transform[0, 1] * py +
					component.transform[0, 2]
				new_y :=
					component.transform[1, 0] * px +
					component.transform[1, 1] * py +
					component.transform[1, 2]

				// Round if needed
				if component.round_to_grid {
					new_x = f32(i16(new_x + 0.5))
					new_y = f32(i16(new_y + 0.5))
				}

				// Add to result
				append(&result_points, [2]i16{i16(new_x), i16(new_y)})
				append(&result_flags, flattened.flags[i])
			}

			// Update and add contour endpoints
			for endpoint in flattened.contour_endpoints {
				append(&result_endpoints, endpoint + endpoint_offset)
			}

			// Update point count
			point_count += len(flattened.points)
		}
	}

	// Create the resulting simple glyph
	simple = Extracted_Simple_Glyph {
		points            = result_points[:],
		flags             = result_flags[:],
		contour_endpoints = result_endpoints[:],
		instructions      = clone(compound.instructions, allocator), // FIXME: this seems wrong
		bounds            = compound.bounds,
	}

	return simple, true
}
*/
