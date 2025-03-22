package ttf

import "core:fmt"
import "core:math"

Glyph_Outline :: struct {
	contours: [dynamic]Contour,
	bounds:   Bounding_Box,
	glyph_id: Glyph,
	is_empty: bool, // For whitespace characters
}

// A single closed contour
Contour :: struct {
	segments:     [dynamic]Path_Segment,
	is_clockwise: bool, // Direction of the contour
}

// Segment types (already defined in your codebase)
Path_Segment :: union {
	Line_Segment,
	Quad_Bezier_Segment,
}

Line_Segment :: struct {
	a, b: [2]f32,
}

Quad_Bezier_Segment :: struct {
	a, control, b: [2]f32,
}

ON_CURVE_POINT := Simple_Glyph_Flag {
	ON_CURVE_POINT = true,
}
X_SHORT_VECTOR := Simple_Glyph_Flag {
	X_SHORT_VECTOR = true,
}
X_IS_SAME := Simple_Glyph_Flag {
	X_IS_SAME = true,
}
Y_SHORT_VECTOR := Simple_Glyph_Flag {
	Y_SHORT_VECTOR = true,
}
Y_IS_SAME := Simple_Glyph_Flag {
	Y_IS_SAME = true,
}
REPEAT_FLAG := Simple_Glyph_Flag {
	REPEAT_FLAG = true,
}

// Determine if the contour is clockwise or counter-clockwise
compute_contour_direction :: proc(contour: ^Contour) -> (clockwise: bool) {
	// Use the "shoelace formula" to determine the area
	// Positive area = counter-clockwise, negative area = clockwise
	// In TrueType, clockwise is positive area (opposite of normal)
	if len(contour.segments) < 3 {return true} 	// Default to clockwise for simple contours

	area: f32 = 0
	for segment in contour.segments {
		switch s in segment {
		case Line_Segment:
			area += (s.b[0] - s.a[0]) * (s.b[1] + s.a[1])
		case Quad_Bezier_Segment:
			// Approximate by treating the control point as a vertex
			area += (s.control[0] - s.a[0]) * (s.control[1] + s.a[1])
			area += (s.b[0] - s.control[0]) * (s.b[1] + s.control[1])
		}
	}

	return area > 0
}

// Parse a glyph outline from the font, with optional transform
parse_glyph_outline :: proc(
	glyf: ^Glyf_Table,
	glyph_id: Glyph,
	transform: ^[6]f32 = nil,
	allocator := context.allocator,
) -> (
	outline: Glyph_Outline,
	ok: bool,
) {
	if glyf == nil {return outline, false}

	// Initialize outline
	outline.glyph_id = glyph_id
	outline.contours = make([dynamic]Contour, 0, 8, allocator) // Most glyphs have < 8 contours

	glyph_entry, got_entry := get_glyf_entry(glyf, glyph_id)
	if !got_entry {return outline, false}

	// Handle empty glyphs (spaces, etc.)
	if glyph_entry.is_empty {
		outline.is_empty = true
		return outline, true
	}

	// Get bounds
	outline.bounds, _ = get_bbox(glyph_entry)

	// Create identity transform if none provided
	identity := [6]f32{1.0, 0.0, 0.0, 1.0, 0.0, 0.0}
	active_transform := transform != nil ? transform^ : identity

	// Process glyph based on type
	if is_composite_glyph(glyph_entry) {
		ok = parse_composite_glyph(glyf, &glyph_entry, &outline, &active_transform, allocator)
	} else {
		ok = parse_simple_glyph(glyf, &glyph_entry, &outline, &active_transform, allocator)
	}

	if !ok {
		destroy_glyph_outline(&outline)
		return {}, false
	}

	return outline, true
}

// Calculate transform matrix for a component
calculate_component_transform :: proc(component: Composite_Component) -> [6]f32 {
	// Start with identity matrix
	transform := [6]f32{1.0, 0.0, 0.0, 1.0, 0.0, 0.0} // [xx, xy, yx, yy, dx, dy]

	// Apply translation
	if component.flags.ARGS_ARE_XY_VALUES {
		transform[4] = f32(component.x_offset) // dx
		transform[5] = f32(component.y_offset) // dy
	}

	// Apply scaling/transformation based on flags
	if component.flags.WE_HAVE_A_SCALE {
		transform[0] = component.scale_x // xx
		transform[3] = component.scale_x // yy
	} else if component.flags.WE_HAVE_AN_X_AND_Y_SCALE {
		transform[0] = component.scale_x // xx
		transform[3] = component.scale_y // yy
	} else if component.flags.WE_HAVE_A_TWO_BY_TWO {
		transform[0] = component.matrx[0] // xx
		transform[1] = component.matrx[1] // xy
		transform[2] = component.matrx[2] // yx
		transform[3] = component.matrx[3] // yy
	}

	return transform
}

// Helper function to combine two transformation matrices
composite_transform :: proc(a, b: [6]f32) -> [6]f32 {
	return [6]f32 {
		a[0] * b[0] + a[1] * b[2], // xx
		a[0] * b[1] + a[1] * b[3], // xy
		a[2] * b[0] + a[3] * b[2], // yx
		a[2] * b[1] + a[3] * b[3], // yy
		a[0] * b[4] + a[1] * b[5] + a[4], // dx
		a[2] * b[4] + a[3] * b[5] + a[5], // dy
	}
}

// Apply a transform to a point
transform_point :: proc(p: [2]f32, t: [6]f32) -> [2]f32 {
	return {
		t[0] * p[0] + t[1] * p[1] + t[4], // x' = xx*x + xy*y + dx
		t[2] * p[0] + t[3] * p[1] + t[5], // y' = yx*x + yy*y + dy
	}
}

// Parse a composite glyph (made of multiple components)
parse_composite_glyph :: proc(
	glyf: ^Glyf_Table,
	glyph: ^Glyf_Entry,
	outline: ^Glyph_Outline,
	parent_transform: ^[6]f32,
	allocator := context.allocator,
) -> bool {
	// Initialize component parser
	parser, parser_ok := init_component_parser(glyph^)
	if !parser_ok {return false}

	// Process each component
	for {
		component, got_comp := next_component(&parser)
		if !got_comp {break} 	// No more components

		// Get the component glyph
		component_glyph, got_glyph := get_glyf_entry(glyf, component.glyph_index)
		if !got_glyph {continue} 	// Skip invalid components

		// For empty component glyphs, just update the bounds
		if component_glyph.is_empty {
			// For spaces and other empty glyphs, apply the offset only
			if component.flags.ARGS_ARE_XY_VALUES {
				// Update bounds if needed based on component position
				// This is important for proper positioning of composite glyphs
				// TODO:
			}
			continue
		}

		// Create a transform matrix for this component
		component_transform := calculate_component_transform(component)

		// Combine with parent transform
		combined_transform: [6]f32
		if parent_transform != nil {
			combined_transform = composite_transform(parent_transform^, component_transform)
		} else {
			combined_transform = component_transform
		}

		// Parse the component glyph's outline with the combined transform
		component_outline, comp_outline_ok := parse_glyph_outline(
			glyf,
			component.glyph_index,
			&combined_transform,
			allocator,
		)

		if !comp_outline_ok {continue} 	// Skip components we can't parse

		// Transfer ownership of contours to parent outline
		for &comp_contour in component_outline.contours {
			append(&outline.contours, comp_contour)
		}

		// Free component outline resources (but we've already copied the segments)
		delete(component_outline.contours)
	}

	return len(outline.contours) > 0
}

// Clean up resources
destroy_glyph_outline :: proc(outline: ^Glyph_Outline) {
	for &contour in outline.contours {delete(contour.segments)}
	delete(outline.contours)
}


// TrueType Point structure to represent parsed point data
TT_Point :: struct {
	x, y:       f32, // Coordinates (transformed)
	is_implied: bool, // True if this is an implied point (not in original data)
	flags:      Simple_Glyph_Flag, // Original TrueType flags
}

// Collect glyph points directly during parsing
parse_raw_glyph_points :: proc(
	glyph: ^Glyf_Entry,
	transform: ^[6]f32 = nil,
	allocator := context.allocator,
) -> (
	points: [dynamic]TT_Point,
	ok: bool,
) {
	if glyph.is_empty {return {}, true}

	// Get total point count
	point_count, got_point_count := get_point_count(glyph^)
	if !got_point_count {return {}, false}

	// Get instruction data (for offset calculation)
	instructions, got_instructions := get_instructions(glyph^)
	if !got_instructions {return {}, false}

	// Calculate offsets for parsing
	end_points_offset := uint(size_of(OpenType_Glyf_Entry_Header))
	instruction_len_offset := end_points_offset + uint(glyph.header.number_of_contours) * 2
	instruction_length := uint(len(instructions))
	flags_offset := instruction_len_offset + 2 + instruction_length

	// Initialize points array
	points = make([dynamic]TT_Point, 0, point_count, allocator)

	// Parse flags and populate initial point data
	current_offset := flags_offset
	for point_idx := 0; point_idx < int(point_count); point_idx += 1 {
		if bounds_check(current_offset >= uint(len(glyph.slice))) {
			delete(points)
			return {}, false
		}

		// Read the flag byte
		flag_byte := glyph.slice[current_offset]
		current_offset += 1

		// Create a TT_Point with just the flag data
		flag := transmute(Simple_Glyph_Flag)flag_byte
		point := TT_Point {
			flags = flag,
		}

		append(&points, point)

		// Handle repeat flag
		if flag.REPEAT_FLAG {
			if bounds_check(current_offset >= uint(len(glyph.slice))) {
				delete(points)
				return {}, false
			}

			repeat_count := int(glyph.slice[current_offset])
			current_offset += 1

			for j := 0; j < repeat_count && point_idx + j + 1 < int(point_count); j += 1 {
				// Add repeated points with the same flag
				repeat_flag := flag
				repeat_flag.REPEAT_FLAG = false

				repeat_point := TT_Point {
					flags      = repeat_flag,
					is_implied = false,
				}

				append(&points, repeat_point)
				point_idx += 1
			}
		}
	}

	// Parse X coordinates
	coord := i16(0)

	for i := 0; i < len(points); i += 1 {
		point := &points[i]
		flag := point.flags

		if flag.X_SHORT_VECTOR {
			// 1-byte value
			if bounds_check(current_offset >= uint(len(glyph.slice))) {
				delete(points)
				return {}, false
			}

			delta := i16(glyph.slice[current_offset])
			current_offset += 1

			if !flag.X_IS_SAME {delta = -delta}
			coord += delta

		} else if flag.X_IS_SAME {
			// Same as previous (no change)
		} else {
			// 2-byte value
			if bounds_check(current_offset + 1 >= uint(len(glyph.slice))) {
				delete(points)
				return {}, false
			}

			delta := i16(
				u16(glyph.slice[current_offset]) << 8 | u16(glyph.slice[current_offset + 1]),
			)
			current_offset += 2
			coord += delta
		}

		point.x = f32(coord)
	}

	// Parse Y coordinates
	coord = 0

	for i := 0; i < len(points); i += 1 {
		point := &points[i]
		flag := point.flags

		if flag.Y_SHORT_VECTOR {
			// 1-byte value
			if current_offset >= uint(len(glyph.slice)) {
				delete(points)
				return {}, false
			}

			delta := i16(glyph.slice[current_offset])
			current_offset += 1

			if !flag.Y_IS_SAME {delta = -delta}

			coord += delta
		} else if flag.Y_IS_SAME {
			// Same as previous (no change)
		} else {
			// 2-byte value
			if current_offset + 1 >= uint(len(glyph.slice)) {
				delete(points)
				return {}, false
			}

			delta := i16(
				u16(glyph.slice[current_offset]) << 8 | u16(glyph.slice[current_offset + 1]),
			)
			current_offset += 2
			coord += delta
		}

		point.y = f32(coord)
	}

	// Apply transforms if provided
	if transform != nil {
		for i := 0; i < len(points); i += 1 {
			point := &points[i]
			fx, fy := point.x, point.y
			tx := transform[0] * fx + transform[1] * fy + transform[4]
			ty := transform[2] * fx + transform[3] * fy + transform[5]
			point.x, point.y = tx, ty
		}
	}

	return points, true
}

// Collect processed points for each contour, with implied points added
collect_glyph_points :: proc(
	glyph: ^Glyf_Entry,
	transform: ^[6]f32 = nil,
	allocator := context.allocator,
) -> (
	points_by_contour: [][dynamic]TT_Point,
	ok: bool,
) {
	if glyph.is_empty {return nil, true}

	// Get end points of contours
	end_points, got_end_points := get_end_points(glyph^)
	if !got_end_points || len(end_points) == 0 {return nil, false}

	// Parse all raw points in one go
	all_points, parse_ok := parse_raw_glyph_points(glyph, transform, allocator)
	if !parse_ok {return nil, false}
	defer delete(all_points) // TODO: if i was more clever; id figure out how to do the implied inserts and just use this as backing for the [][]TT_Point

	// Allocate contour arrays only after parsing succeeds
	contour_count := len(end_points)
	points_by_contour = make([][dynamic]TT_Point, contour_count, allocator)

	// Distribute points to their respective contours
	point_idx := 0
	for i := 0; i < contour_count; i += 1 {
		end_point := int(end_points[i])
		start_point := 0
		if i > 0 {
			start_point = int(end_points[i - 1]) + 1
		}

		// Calculate points in this contour
		contour_point_count := end_point - start_point + 1

		// Initialize contour array
		points_by_contour[i] = make([dynamic]TT_Point, 0, contour_point_count, allocator)

		// Copy points for this contour
		for point_idx <= end_point {
			append(&points_by_contour[i], all_points[point_idx])
			point_idx += 1
		}

		add_implied_points(&points_by_contour[i])
	}

	return points_by_contour, true
}

// Add implied points for a contour
add_implied_points :: proc(contour_points: ^[dynamic]TT_Point) {
	point_count := len(contour_points)
	if point_count < 2 {return}

	// First, check if all points are off-curve
	all_off_curve := true
	for i := 0; i < point_count; i += 1 {
		if contour_points[i].flags.ON_CURVE_POINT {
			all_off_curve = false
			break
		}
	}

	if all_off_curve {
		// Add implied points between each pair of off-curve points
		original_count := point_count
		for i := 0; i < original_count; i += 1 {
			p1 := contour_points[i]
			p2 := contour_points[(i + 1) % original_count]

			// Create an implied on-curve point at the midpoint
			implied := TT_Point {
				x = (p1.x + p2.x) / 2,
				y = (p1.y + p2.y) / 2,
				flags = {ON_CURVE_POINT = true},
				is_implied = true,
			}

			// Insert after the current point
			insert_at(contour_points, i * 2 + 1, implied)
		}
	} else {
		// Add implied points between consecutive off-curve points
		i := 0
		for i < len(contour_points) {
			if !contour_points[i].flags.ON_CURVE_POINT {
				next_idx := (i + 1) % len(contour_points)
				if !contour_points[next_idx].flags.ON_CURVE_POINT {
					// Two consecutive off-curve points - add implied point
					implied := TT_Point {
						x = (contour_points[i].x + contour_points[next_idx].x) / 2,
						y = (contour_points[i].y + contour_points[next_idx].y) / 2,
						flags = {ON_CURVE_POINT = true},
						is_implied = true,
					}

					// Insert after the current point
					insert_at(contour_points, i + 1, implied)

					// Skip ahead past the implied point
					i += 2
					continue
				}
			}
			i += 1
		}
	}
}

// Create segments from a contour's points
create_segments_from_points :: proc(
	contour: ^Contour,
	points: []TT_Point,
	allocator := context.allocator,
) -> bool {
	point_count := len(points)
	if point_count < 2 {return false}

	// Initialize segments array
	contour.segments = make([dynamic]Path_Segment, 0, point_count / 2, allocator)

	// Find first on-curve point
	start_idx := 0
	for i := 0; i < point_count; i += 1 {
		if points[i].flags.ON_CURVE_POINT {
			start_idx = i
			break
		}
	}

	// We must have at least one on-curve point
	if start_idx == point_count {
		fmt.println("ERROR: No on-curve points found after preprocessing")
		return false
	}

	// Process points to create segments
	current := start_idx
	for i := 0; i < point_count; i += 1 {
		next := (current + 1) % point_count

		// If we've wrapped around, we're done
		if i > 0 && next == start_idx {
			break
		}

		if points[current].flags.ON_CURVE_POINT && points[next].flags.ON_CURVE_POINT {
			// Line segment between two on-curve points
			segment := Line_Segment {
				a = [2]f32{points[current].x, points[current].y},
				b = [2]f32{points[next].x, points[next].y},
			}
			append(&contour.segments, segment)

			// fmt.printf(
			// 	"Line: (%.1f, %.1f) to (%.1f, %.1f)\n",
			// 	segment.a[0],
			// 	segment.a[1],
			// 	segment.b[0],
			// 	segment.b[1],
			// )

			current = next
		} else if points[current].flags.ON_CURVE_POINT && !points[next].flags.ON_CURVE_POINT {
			// Find the next on-curve point after the off-curve point
			after_next := (next + 1) % point_count

			// With our preprocessing, this must be on-curve
			if !points[after_next].flags.ON_CURVE_POINT {
				fmt.println("ERROR: Expected on-curve point after off-curve point")
				return false
			}

			// Quadratic bezier
			segment := Quad_Bezier_Segment {
				a       = [2]f32{points[current].x, points[current].y},
				control = [2]f32{points[next].x, points[next].y},
				b       = [2]f32{points[after_next].x, points[after_next].y},
			}
			append(&contour.segments, segment)

			// fmt.printf(
			// 	"Bezier: (%.1f, %.1f) control (%.1f, %.1f) to (%.1f, %.1f)\n",
			// 	segment.a[0],
			// 	segment.a[1],
			// 	segment.control[0],
			// 	segment.control[1],
			// 	segment.b[0],
			// 	segment.b[1],
			// )

			// Skip ahead
			current = after_next
		} else {
			fmt.println("ERROR: Unexpected point configuration after preprocessing")
			return false
		}
	}

	// Ensure contour is closed
	if len(contour.segments) > 0 {
		first_seg := contour.segments[0]
		last_seg := contour.segments[len(contour.segments) - 1]

		// Get first and last points
		first_point: [2]f32
		last_point: [2]f32

		switch s in first_seg {
		case Line_Segment:
			first_point = s.a
		case Quad_Bezier_Segment:
			first_point = s.a
		}

		switch s in last_seg {
		case Line_Segment:
			last_point = s.b
		case Quad_Bezier_Segment:
			last_point = s.b
		}

		// If they don't match, add a closing segment
		if first_point[0] != last_point[0] || first_point[1] != last_point[1] {
			close_segment := Line_Segment {
				a = last_point,
				b = first_point,
			}
			append(&contour.segments, close_segment)

			// fmt.printf(
			// 	"Closing Line: (%.1f, %.1f) to (%.1f, %.1f)\n",
			// 	close_segment.a[0],
			// 	close_segment.a[1],
			// 	close_segment.b[0],
			// 	close_segment.b[1],
			// )
		}
	}

	return true
}

// Streamlined parse_simple_glyph using direct point collection
parse_simple_glyph :: proc(
	glyf: ^Glyf_Table,
	glyph: ^Glyf_Entry,
	outline: ^Glyph_Outline,
	transform: ^[6]f32,
	allocator := context.allocator,
) -> bool {
	// Collect all points for all contours directly
	contour_points, points_ok := collect_glyph_points(glyph, transform, allocator)
	if !points_ok {return false}
	defer {
		for i in 0 ..< len(contour_points) {delete(contour_points[i])}
		delete(contour_points)
	}

	// Process each contour
	for i := 0; i < len(contour_points); i += 1 {
		// Create a new contour
		contour: Contour

		// Build segments from points
		ok := create_segments_from_points(&contour, contour_points[i][:], allocator)
		if !ok {
			// Clean up on failure
			delete(contour.segments)
			return false
		}

		// Determine contour direction
		contour.is_clockwise = compute_contour_direction(&contour)

		// Add to outline
		append(&outline.contours, contour)
	}

	return true
}

// Helper to insert a point at a specific index in a dynamic array
insert_at :: proc(array: ^[dynamic]TT_Point, index: int, value: TT_Point) {
	if index > len(array) {
		fmt.println("INSERT_AT OOB")
		return
	}
	resize(array, len(array) + 1)
	// Shift elements right
	for i := len(array) - 2; i >= index; i -= 1 {
		array[i + 1] = array[i]
	}
	array[index] = value
}
