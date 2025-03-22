package ttf

// // HarfBuzz-style implementation for glyf table handling

// // Main table structure - minimal, with just references to raw data
// Glyf_Table :: struct {
// 	data: []byte, // Raw glyf table data
// 	font: ^Font, // Reference to parent font (needed for loca)
// }

// // Glyph representation - minimal, just holds necessary references
// Glyph :: struct {
// 	bytes:   []byte, // Slice of data for this specific glyph
// 	index:   Glyph, // Glyph ID
// 	phantom: bool, // Virtual glyph with no data (e.g., space)
// }

// // Glyph extents - returned by get_extents, not stored
// Glyph_Extents :: struct {
// 	x_bearing: i16, // Left side bearing
// 	y_bearing: i16, // Top side bearing
// 	width:     i16, // Width
// 	height:    i16, // Height
// }

// // Path callbacks for font rendering
// Path_Callbacks :: struct {
// 	move_to:    proc(to_x, to_y: f32, user_data: rawptr),
// 	line_to:    proc(to_x, to_y: f32, user_data: rawptr),
// 	quad_to:    proc(control_x, control_y, to_x, to_y: f32, user_data: rawptr),
// 	close_path: proc(user_data: rawptr),
// 	user_data:  rawptr,
// }

// // Load the glyf table - minimal initial setup
// load_glyf_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
// 	glyf_data, ok := get_table_data(font, "glyf")
// 	if !ok {
// 		return {}, .Table_Not_Found
// 	}

// 	// Create the glyf table structure - minimal state
// 	glyf := new(Glyf_Table)
// 	glyf.data = glyf_data
// 	glyf.font = font

// 	return Table_Entry{data = glyf, destroy = destroy_glyf_table}, .None
// }

// destroy_glyf_table :: proc(data: rawptr) {
// 	if data == nil {return}
// 	glyf := cast(^Glyf_Table)data
// 	free(glyf)
// }

// // Get a glyph from the table - lazy loading approach
// get_glyph :: proc(glyf: ^Glyf_Table, glyph_id: Glyph) -> (glyph: Glyph, ok: bool) {
// 	if glyf == nil {
// 		return {}, false
// 	}

// 	// Get loca table for glyph offsets
// 	loca, has_loca := get_table(glyf.font, "loca", load_loca_table, Loca_Table)
// 	if !has_loca {
// 		return {}, false
// 	}

// 	// Get the offsets for this glyph
// 	offset, length, found := get_glyph_location(loca, glyph_id)
// 	if !found {
// 		return {}, false
// 	}

// 	// Create glyph representation - minimal, just holds a reference to the data
// 	glyph = Glyph {
// 		index   = glyph_id,
// 		phantom = length == 0,
// 	}

// 	// Only set the bytes if this isn't a phantom glyph
// 	if !glyph.phantom {
// 		if offset + length > uint(len(glyf.data)) {
// 			return {}, false
// 		}
// 		glyph.bytes = glyf.data[offset:offset + length]
// 	}

// 	return glyph, true
// }

// // Get the extents of a glyph - parsed on demand
// get_glyph_extents :: proc(glyf: ^Glyf_Table, glyph: Glyph) -> (extents: Glyph_Extents, ok: bool) {
// 	if glyph.phantom || len(glyph.bytes) == 0 {
// 		// Empty glyph (e.g., space) - zero extents
// 		return {}, true
// 	}

// 	// Need at least a header
// 	if len(glyph.bytes) < size_of(OpenType_Glyph_Header) {
// 		return {}, false
// 	}

// 	// Parse the header to get the bounding box
// 	header := cast(^OpenType_Glyph_Header)&glyph.bytes[0]

// 	extents = Glyph_Extents {
// 		x_bearing = i16(header.x_min),
// 		y_bearing = i16(header.y_max),
// 		width     = i16(header.x_max - header.x_min),
// 		height    = i16(header.y_max - header.y_min),
// 	}

// 	return extents, true
// }

// // Check if a glyph is a composite glyph - quick check without full parsing
// is_composite_glyph :: proc(glyph: Glyph) -> bool {
// 	if glyph.phantom || len(glyph.bytes) < size_of(OpenType_Glyph_Header) {
// 		return false
// 	}

// 	header := cast(^OpenType_Glyph_Header)&glyph.bytes[0]
// 	return i16(header.number_of_contours) < 0
// }

// // Decompose a glyph to a path - lazily processes the glyph data
// decompose_glyph :: proc(glyf: ^Glyf_Table, glyph: Glyph, callbacks: Path_Callbacks) -> bool {
// 	if glyph.phantom || len(glyph.bytes) == 0 {
// 		return true // Nothing to do for empty glyphs
// 	}

// 	if len(glyph.bytes) < size_of(OpenType_Glyph_Header) {
// 		return false
// 	}

// 	header := cast(^OpenType_Glyph_Header)&glyph.bytes[0]

// 	if i16(header.number_of_contours) < 0 {
// 		// Composite glyph - recursively decompose components
// 		return decompose_composite_glyph(glyf, glyph, callbacks)
// 	} else {
// 		// Simple glyph - decompose directly
// 		return decompose_simple_glyph(glyph, callbacks)
// 	}
// }

// // Decompose a simple glyph - parses the glyph data on demand
// decompose_simple_glyph :: proc(glyph: Glyph, callbacks: Path_Callbacks) -> bool {
// 	if glyph.phantom || len(glyph.bytes) < size_of(OpenType_Glyph_Header) {
// 		return false
// 	}

// 	header := cast(^OpenType_Glyph_Header)&glyph.bytes[0]
// 	num_contours := i16(header.number_of_contours)

// 	if num_contours <= 0 {
// 		return false // Not a simple glyph
// 	}

// 	// Process contour endpoints
// 	endpoints_offset := size_of(OpenType_Glyph_Header)
// 	if endpoints_offset + uint(num_contours) * 2 > uint(len(glyph.bytes)) {
// 		return false
// 	}

// 	// Read the last endpoint to determine total points
// 	last_endpoint_offset := endpoints_offset + uint(num_contours - 1) * 2
// 	last_endpoint := read_u16(glyph.bytes, last_endpoint_offset)
// 	point_count := uint(last_endpoint) + 1

// 	// Parse endpoints for each contour
// 	endpoints := make([]u16, num_contours)
// 	for i := 0; i < int(num_contours); i += 1 {
// 		endpoints[i] = read_u16(glyph.bytes, endpoints_offset + uint(i) * 2)
// 	}

// 	// Skip to instruction bytes
// 	instruction_length_offset := endpoints_offset + uint(num_contours) * 2
// 	if instruction_length_offset + 2 > uint(len(glyph.bytes)) {
// 		delete(endpoints)
// 		return false
// 	}

// 	instruction_length := read_u16(glyph.bytes, instruction_length_offset)
// 	flags_offset := instruction_length_offset + 2 + uint(instruction_length)

// 	if flags_offset >= uint(len(glyph.bytes)) {
// 		delete(endpoints)
// 		return false
// 	}

// 	// Parse flags
// 	flags := make([]u8, point_count)
// 	flag_idx := uint(0)
// 	current_offset := flags_offset

// 	for flag_idx < point_count && current_offset < uint(len(glyph.bytes)) {
// 		flag := glyph.bytes[current_offset]
// 		flags[flag_idx] = flag
// 		flag_idx += 1
// 		current_offset += 1

// 		// Handle repeat flag
// 		if (flag & u8(Simple_Glyph_Flag.REPEAT_FLAG)) != 0 {
// 			if current_offset >= uint(len(glyph.bytes)) {
// 				delete(endpoints)
// 				delete(flags)
// 				return false
// 			}

// 			repeat_count := glyph.bytes[current_offset]
// 			current_offset += 1

// 			for j := u8(0); j < repeat_count && flag_idx < point_count; j += 1 {
// 				flags[flag_idx] = flag
// 				flag_idx += 1
// 			}
// 		}
// 	}

// 	// Parse x coordinates
// 	x_coords_offset := current_offset
// 	x_coords := make([]i16, point_count)
// 	x := i16(0)
// 	current_offset = x_coords_offset

// 	for i := uint(0); i < point_count && current_offset < uint(len(glyph.bytes)); i += 1 {
// 		flag := flags[i]
// 		is_short := (flag & u8(Simple_Glyph_Flag.X_SHORT_VECTOR)) != 0
// 		is_same_or_positive := (flag & u8(Simple_Glyph_Flag.X_IS_SAME)) != 0

// 		if is_short {
// 			// 1-byte value
// 			if current_offset >= uint(len(glyph.bytes)) {
// 				delete(endpoints)
// 				delete(flags)
// 				delete(x_coords)
// 				return false
// 			}

// 			delta := i16(glyph.bytes[current_offset])
// 			current_offset += 1

// 			if !is_same_or_positive {
// 				delta = -delta
// 			}

// 			x += delta
// 		} else if is_same_or_positive {
// 			// Same as previous (no change)
// 		} else {
// 			// 2-byte value
// 			if current_offset + 2 > uint(len(glyph.bytes)) {
// 				delete(endpoints)
// 				delete(flags)
// 				delete(x_coords)
// 				return false
// 			}

// 			delta := read_i16(glyph.bytes, current_offset)
// 			current_offset += 2
// 			x += delta
// 		}

// 		x_coords[i] = x
// 	}

// 	// Parse y coordinates
// 	y_coords_offset := current_offset
// 	y_coords := make([]i16, point_count)
// 	y := i16(0)
// 	current_offset = y_coords_offset

// 	for i := uint(0); i < point_count && current_offset < uint(len(glyph.bytes)); i += 1 {
// 		flag := flags[i]
// 		is_short := (flag & u8(Simple_Glyph_Flag.Y_SHORT_VECTOR)) != 0
// 		is_same_or_positive := (flag & u8(Simple_Glyph_Flag.Y_IS_SAME)) != 0

// 		if is_short {
// 			// 1-byte value
// 			if current_offset >= uint(len(glyph.bytes)) {
// 				delete(endpoints)
// 				delete(flags)
// 				delete(x_coords)
// 				delete(y_coords)
// 				return false
// 			}

// 			delta := i16(glyph.bytes[current_offset])
// 			current_offset += 1

// 			if !is_same_or_positive {
// 				delta = -delta
// 			}

// 			y += delta
// 		} else if is_same_or_positive {
// 			// Same as previous (no change)
// 		} else {
// 			// 2-byte value
// 			if current_offset + 2 > uint(len(glyph.bytes)) {
// 				delete(endpoints)
// 				delete(flags)
// 				delete(x_coords)
// 				delete(y_coords)
// 				return false
// 			}

// 			delta := read_i16(glyph.bytes, current_offset)
// 			current_offset += 2
// 			y += delta
// 		}

// 		y_coords[i] = y
// 	}

// 	// Generate the path commands
// 	contour_start := uint(0)
// 	for i := 0; i < int(num_contours); i += 1 {
// 		contour_end := uint(endpoints[i])

// 		if contour_end >= point_count || contour_start > contour_end {
// 			delete(endpoints)
// 			delete(flags)
// 			delete(x_coords)
// 			delete(y_coords)
// 			return false
// 		}

// 		// Find the first on-curve point to start with
// 		start_point := contour_start
// 		for j := contour_start; j <= contour_end; j += 1 {
// 			if (flags[j] & u8(Simple_Glyph_Flag.ON_CURVE_POINT)) != 0 {
// 				start_point = j
// 				break
// 			}
// 		}

// 		// If no on-curve points found, use the first point
// 		// (uncommon but allowed)

// 		// Initialize path with move_to
// 		if callbacks.move_to != nil {
// 			callbacks.move_to(
// 				f32(x_coords[start_point]),
// 				f32(y_coords[start_point]),
// 				callbacks.user_data,
// 			)
// 		}

// 		// Generate the contour path
// 		point := start_point
// 		for {
// 			next_point := point + 1
// 			if next_point > contour_end {
// 				next_point = contour_start
// 			}

// 			if next_point == start_point {
// 				break // Completed the contour
// 			}

// 			if (flags[point] & u8(Simple_Glyph_Flag.ON_CURVE_POINT)) != 0 {
// 				if (flags[next_point] & u8(Simple_Glyph_Flag.ON_CURVE_POINT)) != 0 {
// 					// Both points are on-curve, simple line
// 					if callbacks.line_to != nil {
// 						callbacks.line_to(
// 							f32(x_coords[next_point]),
// 							f32(y_coords[next_point]),
// 							callbacks.user_data,
// 						)
// 					}
// 				} else {
// 					// Current on-curve, next off-curve
// 					next_next_point := next_point + 1
// 					if next_next_point > contour_end {
// 						next_next_point = contour_start
// 					}

// 					if (flags[next_next_point] & u8(Simple_Glyph_Flag.ON_CURVE_POINT)) != 0 {
// 						// Off-curve followed by on-curve, make a quadratic bezier
// 						if callbacks.quad_to != nil {
// 							callbacks.quad_to(
// 								f32(x_coords[next_point]),
// 								f32(y_coords[next_point]),
// 								f32(x_coords[next_next_point]),
// 								f32(y_coords[next_next_point]),
// 								callbacks.user_data,
// 							)
// 						}
// 						point = next_next_point
// 						continue
// 					} else {
// 						// Two consecutive off-curve points, implied point between them
// 						implied_x := (x_coords[next_point] + x_coords[next_next_point]) / 2
// 						implied_y := (y_coords[next_point] + y_coords[next_next_point]) / 2

// 						if callbacks.quad_to != nil {
// 							callbacks.quad_to(
// 								f32(x_coords[next_point]),
// 								f32(y_coords[next_point]),
// 								f32(implied_x),
// 								f32(implied_y),
// 								callbacks.user_data,
// 							)
// 						}
// 						point = next_next_point
// 						continue
// 					}
// 				}
// 			} else {
// 				// Current point is off-curve
// 				if (flags[next_point] & u8(Simple_Glyph_Flag.ON_CURVE_POINT)) != 0 {
// 					// Off-curve to on-curve, quadratic bezier
// 					if callbacks.quad_to != nil {
// 						callbacks.quad_to(
// 							f32(x_coords[point]),
// 							f32(y_coords[point]),
// 							f32(x_coords[next_point]),
// 							f32(y_coords[next_point]),
// 							callbacks.user_data,
// 						)
// 					}
// 				} else {
// 					// Two off-curve points, implied point between them
// 					implied_x := (x_coords[point] + x_coords[next_point]) / 2
// 					implied_y := (y_coords[point] + y_coords[next_point]) / 2

// 					if callbacks.quad_to != nil {
// 						callbacks.quad_to(
// 							f32(x_coords[point]),
// 							f32(y_coords[point]),
// 							f32(implied_x),
// 							f32(implied_y),
// 							callbacks.user_data,
// 						)
// 					}
// 				}
// 			}

// 			point = next_point
// 		}

// 		// Close the path
// 		if callbacks.close_path != nil {
// 			callbacks.close_path(callbacks.user_data)
// 		}

// 		contour_start = contour_end + 1
// 	}

// 	// Clean up
// 	delete(endpoints)
// 	delete(flags)
// 	delete(x_coords)
// 	delete(y_coords)

// 	return true
// }

// // Decompose a composite glyph - recursively processes component glyphs
// decompose_composite_glyph :: proc(
// 	glyf: ^Glyf_Table,
// 	glyph: Glyph,
// 	callbacks: Path_Callbacks,
// ) -> bool {
// 	if glyph.phantom || len(glyph.bytes) < size_of(OpenType_Glyph_Header) {
// 		return false
// 	}

// 	header := cast(^OpenType_Glyph_Header)&glyph.bytes[0]

// 	if i16(header.number_of_contours) >= 0 {
// 		return false // Not a composite glyph
// 	}

// 	current_offset := size_of(OpenType_Glyph_Header)
// 	more_components := true

// 	// Process each component
// 	for more_components && current_offset + 4 <= uint(len(glyph.bytes)) {
// 		flags := transmute(Composite_Glyph_Flag)read_u16(glyph.bytes, current_offset)
// 		component_glyph_id := Glyph(read_u16(glyph.bytes, current_offset + 2))
// 		current_offset += 4

// 		// Get component offset based on flags
// 		arg1, arg2: i16 = 0, 0

// 		if flags.ARG_1_AND_2_ARE_WORDS != 0 {
// 			// Arguments are 16-bit values
// 			if current_offset + 4 > uint(len(glyph.bytes)) {
// 				return false
// 			}

// 			arg1 = read_i16(glyph.bytes, current_offset)
// 			arg2 = read_i16(glyph.bytes, current_offset + 2)
// 			current_offset += 4
// 		} else {
// 			// Arguments are 8-bit values
// 			if current_offset + 2 > uint(len(glyph.bytes)) {
// 				return false
// 			}

// 			arg1 = i16(cast(i8)glyph.bytes[current_offset])
// 			arg2 = i16(cast(i8)glyph.bytes[current_offset + 1])
// 			current_offset += 2
// 		}

// 		// Get component transformation
// 		transform: [6]f32 // [xx, xy, yx, yy, dx, dy] - 2x3 matrix
// 		transform[0] = 1.0 // xx
// 		transform[3] = 1.0 // yy

// 		if flags.ARGS_ARE_XY_VALUES != 0 {
// 			transform[4] = f32(arg1) // dx
// 			transform[5] = f32(arg2) // dy
// 		} else {
// 			// Anchor points (handled later)
// 		}

// 		if flags.WE_HAVE_A_SCALE != 0 {
// 			// Single scale value for both x and y
// 			if current_offset + 2 > uint(len(glyph.bytes)) {
// 				return false
// 			}

// 			scale := F2DOT14_to_Float(read_i16be(glyph.bytes, current_offset))
// 			transform[0] = scale // xx
// 			transform[3] = scale // yy
// 			current_offset += 2
// 		} else if flags.WE_HAVE_AN_X_AND_Y_SCALE != 0 {
// 			// Separate scale values for x and y
// 			if current_offset + 4 > uint(len(glyph.bytes)) {
// 				return false
// 			}

// 			transform[0] = F2DOT14_to_Float(read_i16be(glyph.bytes, current_offset)) // xx
// 			transform[3] = F2DOT14_to_Float(read_i16be(glyph.bytes, current_offset + 2)) // yy
// 			current_offset += 4
// 		} else if flags.WE_HAVE_A_TWO_BY_TWO != 0 {
// 			// 2x2 transformation matrix
// 			if current_offset + 8 > uint(len(glyph.bytes)) {
// 				return false
// 			}

// 			transform[0] = F2DOT14_to_Float(read_i16be(glyph.bytes, current_offset)) // xx
// 			transform[1] = F2DOT14_to_Float(read_i16be(glyph.bytes, current_offset + 2)) // xy
// 			transform[2] = F2DOT14_to_Float(read_i16be(glyph.bytes, current_offset + 4)) // yx
// 			transform[3] = F2DOT14_to_Float(read_i16be(glyph.bytes, current_offset + 6)) // yy
// 			current_offset += 8
// 		}

// 		// Skip instructions if present
// 		if flags.WE_HAVE_INSTRUCTIONS != 0 {
// 			// Skip past any instructions at the end (after all components)
// 			// This flag means the glyph has instructions, but they come after
// 			// all components are defined
// 		}

// 		// Recursive decomposition of component glyph with transformation
// 		component_glyph, component_ok := get_glyph(glyf, component_glyph_id)
// 		if component_ok && !component_glyph.phantom {
// 			// Create transformed callbacks to apply the transformation
// 			transformed_callbacks := Path_Callbacks {
// 				move_to = proc(to_x, to_y: f32, user_data: rawptr) {
// 					transform := cast(^[6]f32)user_data
// 					x := transform[0] * to_x + transform[1] * to_y + transform[4]
// 					y := transform[2] * to_x + transform[3] * to_y + transform[5]

// 					original_callbacks := cast(^Path_Callbacks)transform[6]
// 					if original_callbacks.move_to != nil {
// 						original_callbacks.move_to(x, y, original_callbacks.user_data)
// 					}
// 				},
// 				line_to = proc(to_x, to_y: f32, user_data: rawptr) {
// 					transform := cast(^[6]f32)user_data
// 					x := transform[0] * to_x + transform[1] * to_y + transform[4]
// 					y := transform[2] * to_x + transform[3] * to_y + transform[5]

// 					original_callbacks := cast(^Path_Callbacks)transform[6]
// 					if original_callbacks.line_to != nil {
// 						original_callbacks.line_to(x, y, original_callbacks.user_data)
// 					}
// 				},
// 				quad_to = proc(control_x, control_y, to_x, to_y: f32, user_data: rawptr) {
// 					transform := cast(^[6]f32)user_data
// 					cx := transform[0] * control_x + transform[1] * control_y + transform[4]
// 					cy := transform[2] * control_x + transform[3] * control_y + transform[5]
// 					x := transform[0] * to_x + transform[1] * to_y + transform[4]
// 					y := transform[2] * to_x + transform[3] * to_y + transform[5]

// 					original_callbacks := cast(^Path_Callbacks)transform[6]
// 					if original_callbacks.quad_to != nil {
// 						original_callbacks.quad_to(cx, cy, x, y, original_callbacks.user_data)
// 					}
// 				},
// 				close_path = proc(user_data: rawptr) {
// 					transform := cast(^[6]f32)user_data
// 					original_callbacks := cast(^Path_Callbacks)transform[6]
// 					if original_callbacks.close_path != nil {
// 						original_callbacks.close_path(original_callbacks.user_data)
// 					}
// 				},
// 			}

// 			// Store the original callbacks in the transform array for the nested callbacks
// 			// This is a hack, but it works for this example
// 			transform_with_callbacks := transform
// 			transform_with_callbacks[6] = transmute(f32)&callbacks

// 			transformed_callbacks.user_data = &transform_with_callbacks

// 			// Recursively decompose the component
// 			decompose_glyph(glyf, component_glyph, transformed_callbacks)
// 		}

// 		more_components = flags.MORE_COMPONENTS != 0
// 	}

// 	return true
// }
