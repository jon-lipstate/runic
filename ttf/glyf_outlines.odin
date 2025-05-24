package ttf

import "core:fmt"
import "core:math"

// Glyph_Outline_Cache :: struct {
// 	font:             ^Font,
// 	extracted_glyphs: map[u16]Extracted_Glyph,
// 	// processed_curves: map[u16]Glyph_Curves
// 	// hinted_glyphs:    map[Hinting_Key]Hinted_Glyph,
// }
// Hinting_Key :: struct {
// 	glyph_id:     u16,
// 	size_px:      u16,
// 	dpi:          u16,
// 	hinting_mode: u8,
// }

// Hinted_Glyph :: struct {
// 	points:   [][2]f32, // Hinted points in pixel space
// 	flags:    []u8, // Flags for these points
// 	contours: []u16, // Contour endpoints
// 	curves:   Glyph_Curves, // Processed curves for rendering
// }

///////////////////////////////////////////////////////////////////////////////////////
Glyph_Outline :: struct {
	contours: [dynamic]Contour,
	bounds:   Bounding_Box,
	glyph_id: Glyph,
	is_empty: bool, // For whitespace characters
}

// A single closed contour
Contour :: struct {
	segments:     [dynamic]Path_Segment,
	is_clockwise: bool,
}

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


// Main entry point to create an outline from an extracted glyph
create_outline_from_extracted :: proc(
	glyf: ^Glyf_Table,
	extracted: ^Extracted_Glyph,
	transform: ^matrix[2, 3]f32 = nil,
	allocator := context.allocator,
) -> (
	outline: Glyph_Outline,
	ok: bool,
) {
	// Initialize outline
	outline.contours = make([dynamic]Contour, 0, 8, allocator)

	// Apply identity transform if none provided
	identity := IDENTITY_MATRIX
	active_transform := transform != nil ? transform^ : identity

	// Process based on glyph type
	switch &e in extracted {
	case Extracted_Simple_Glyph:
		outline.glyph_id = e.glyph_id
		outline.bounds = e.bounds

		// Handle empty glyphs
		if len(e.points) == 0 {
			outline.is_empty = true
			return outline, true
		}

		ok = create_outline_from_simple_extracted(&e, &outline, &active_transform, allocator)

	case Extracted_Compound_Glyph:
		outline.glyph_id = e.glyph_id
		ok = create_outline_from_compound_extracted(
			glyf,
			&e,
			&outline,
			&active_transform,
			allocator,
		)
	}

	if !ok {
		destroy_glyph_outline(&outline)
		return {}, false
	}

	return outline, true
}

destroy_glyph_outline :: proc(g: ^Glyph_Outline) {
	for s in g.contours {delete(s.segments)}
	delete(g.contours)
}

// Process a simple extracted glyph to create an outline
create_outline_from_simple_extracted :: proc(
	simple: ^Extracted_Simple_Glyph,
	outline: ^Glyph_Outline,
	transform: ^matrix[2, 3]f32,
	allocator := context.allocator,
) -> bool {
	if simple.points == nil || len(simple.points) == 0 {return true} 	// Empty glyph is valid

	// Process contours based on endpoints
	start_idx := 0
	for endpoint_idx := 0; endpoint_idx < len(simple.contour_endpoints); endpoint_idx += 1 {
		endpoint := int(simple.contour_endpoints[endpoint_idx])

		// Ensure we have enough points
		if bounds_check(endpoint >= len(simple.points)) {return false}

		// Create a new contour
		contour: Contour
		contour.segments = make([dynamic]Path_Segment, 0, endpoint - start_idx + 1, allocator)

		// Process points for this contour
		// points_in_contour := endpoint - start_idx + 1

		// Add segments by processing points
		ok := create_segments_for_contour(
			&contour,
			simple.points[start_idx:endpoint + 1],
			simple.on_curve[start_idx:endpoint + 1],
			transform,
			allocator,
		)

		if !ok {
			delete(contour.segments)
			return false
		}

		// Determine contour direction
		contour.is_clockwise = compute_contour_direction(&contour)

		// fmt.printf(
		// 	"Contour %d: %s, %d segments\n",
		// 	endpoint_idx,
		// 	contour.is_clockwise ? "clockwise (filled)" : "counterclockwise (hole)",
		// 	len(contour.segments),
		// )

		// Add contour to outline
		append(&outline.contours, contour)

		// Update start index for next contour
		start_idx = endpoint + 1
	}

	return true
}

reverse_contour_segments :: proc(segments: ^[dynamic]Path_Segment) {
	if len(segments) == 0 {return}

	// Reverse the order of segments
	for i := 0; i < len(segments) / 2; i += 1 {
		j := len(segments) - 1 - i
		segments[i], segments[j] = segments[j], segments[i]
	}

	// Reverse the direction of each segment
	for &segment in segments {
		switch &s in segment {
		case Line_Segment:
			s.a, s.b = s.b, s.a
		case Quad_Bezier_Segment:
			s.a, s.b = s.b, s.a
		// Control point stays the same
		}
	}
}

test_simple_contour :: proc() {
	// Test with a simple square (4 on-curve points)
	test_points := [][2]i16{{0, 0}, {100, 0}, {100, 100}, {0, 100}}
	test_on_curve := []bool{true, true, true, true}

	contour := Contour{}
	contour.segments = make([dynamic]Path_Segment, 0, 4)

	success := create_segments_for_contour(&contour, test_points, test_on_curve, nil)

	fmt.printf(
		"Simple square test: %s, %d segments created\n",
		success ? "SUCCESS" : "FAILED",
		len(contour.segments),
	)

	// Check if it's closed
	if len(contour.segments) == 4 {
		// Should be 4 line segments forming a closed square
		fmt.println("Square contour created successfully")
	}
}

test_explicit_square :: proc() {
	test_points := [][2]f32{{0, 0}, {100, 0}, {100, 100}, {0, 100}}

	contour := Contour{}
	contour.segments = make([dynamic]Path_Segment, 0, 4)

	// Explicitly create the 4 segments:
	append(&contour.segments, Line_Segment{a = test_points[0], b = test_points[1]}) // bottom
	append(&contour.segments, Line_Segment{a = test_points[1], b = test_points[2]}) // right
	append(&contour.segments, Line_Segment{a = test_points[2], b = test_points[3]}) // top
	append(&contour.segments, Line_Segment{a = test_points[3], b = test_points[0]}) // left (closing)

	// Check closure
	first_point := test_points[0]
	last_point := test_points[0] // Should be same!
	distance := math.sqrt(
		math.pow(first_point[0] - last_point[0], 2) + math.pow(first_point[1] - last_point[1], 2),
	)
	fmt.printf("Explicit square closure distance: %f\n", distance) // Should be 0!
}

create_segments_for_contour :: proc(
	contour: ^Contour,
	points: [][2]i16,
	on_curve: []bool,
	transform: ^matrix[2, 3]f32,
	allocator := context.allocator,
) -> bool {
	point_count := len(points)
	if point_count < 2 {
		return false
	}

	// OPTIMIZATION 1: Pre-calculate final array size
	// Count how many implied points we'll need to add
	implied_point_count := 0
	for i := 0; i < point_count; i += 1 {
		if !on_curve[i] {
			next_idx := (i + 1) % point_count
			if !on_curve[next_idx] {
				implied_point_count += 1
			}
		}
	}

	final_point_count := point_count + implied_point_count

	// Pre-allocate arrays with exact size
	processed_points := make([dynamic][2]f32, 0, final_point_count, allocator)
	processed_on_curve := make([dynamic]bool, 0, final_point_count, allocator)
	defer delete(processed_points)
	defer delete(processed_on_curve)

	// OPTIMIZATION 2: Single-pass array building (O(n) instead of O(n²))
	for i := 0; i < point_count; i += 1 {
		// Transform and add current point
		x, y := f32(points[i][0]), f32(points[i][1])

		if transform != nil {
			tx := transform[0, 0] * x + transform[0, 1] * y + transform[0, 2]
			ty := transform[1, 0] * x + transform[1, 1] * y + transform[1, 2]
			x, y = tx, ty
		}

		append(&processed_points, [2]f32{x, y})
		append(&processed_on_curve, on_curve[i])

		// Check if we need to add implied point AFTER this one
		if !on_curve[i] {
			next_idx := (i + 1) % point_count
			if !on_curve[next_idx] {
				// Add implied on-curve point between consecutive off-curve points
				next_x, next_y := f32(points[next_idx][0]), f32(points[next_idx][1])

				if transform != nil {
					tx := transform[0, 0] * next_x + transform[0, 1] * next_y + transform[0, 2]
					ty := transform[1, 0] * next_x + transform[1, 1] * next_y + transform[1, 2]
					next_x, next_y = tx, ty
				}

				midpoint := [2]f32{(x + next_x) / 2, (y + next_y) / 2}
				append(&processed_points, midpoint)
				append(&processed_on_curve, true)
			}
		}
	}

	// Find first on-curve point
	start_idx := -1
	for i := 0; i < len(processed_on_curve); i += 1 {
		if processed_on_curve[i] {
			start_idx = i
			break
		}
	}

	if start_idx == -1 {
		fmt.println("ERROR: No on-curve points found in contour")
		return false
	}

	// Generate segments
	current := start_idx
	total_points := len(processed_points)

	for {
		next := (current + 1) % total_points

		if processed_on_curve[current] && processed_on_curve[next] {
			segment := Line_Segment {
				a = processed_points[current],
				b = processed_points[next],
			}
			append(&contour.segments, segment)
			current = next

		} else if processed_on_curve[current] && !processed_on_curve[next] {
			control_idx := next
			end_idx := (control_idx + 1) % total_points

			if !processed_on_curve[end_idx] {
				fmt.printf(
					"ERROR: Expected on-curve point at %d after control point %d\n",
					end_idx,
					control_idx,
				)
				return false
			}

			segment := Quad_Bezier_Segment {
				a       = processed_points[current],
				control = processed_points[control_idx],
				b       = processed_points[end_idx],
			}
			append(&contour.segments, segment)
			current = end_idx

		} else {
			fmt.printf(
				"ERROR: Unexpected point configuration - current=%d (on_curve=%v), next=%d (on_curve=%v)\n",
				current,
				processed_on_curve[current],
				next,
				processed_on_curve[next],
			)
			return false
		}

		if current == start_idx {break}

		if len(contour.segments) > total_points + 2 {
			fmt.printf(
				"ERROR: Too many segments created (%d), possible infinite loop\n",
				len(contour.segments),
			)
			return false
		}
	}

	// Validation
	if len(contour.segments) > 0 {
		first_seg := contour.segments[0]
		last_seg := contour.segments[len(contour.segments) - 1]

		first_point, last_point: [2]f32

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

		when ODIN_DEBUG {
			distance := math.sqrt(
				math.pow(first_point[0] - last_point[0], 2) +
				math.pow(first_point[1] - last_point[1], 2),
			)

			if distance > 0.1 {
				fmt.printf("WARNING: Contour not properly closed, distance=%f\n", distance)
				close_segment := Line_Segment {
					a = last_point,
					b = first_point,
				}
				append(&contour.segments, close_segment)
			}
		}
	}

	return true
}

// Process a compound extracted glyph to create an outline
create_outline_from_compound_extracted :: proc(
	glyf: ^Glyf_Table,
	compound: ^Extracted_Compound_Glyph,
	outline: ^Glyph_Outline,
	parent_transform: ^matrix[2, 3]f32,
	allocator := context.allocator,
) -> bool {
	// Process each component
	for component in compound.components {
		// Extract the component glyph
		component_extracted, got_glyph := extract_glyph(glyf, component.glyph_id, allocator)
		if !got_glyph {
			continue // Skip invalid components
		}
		defer destroy_extracted_glyph(&component_extracted)

		// Combine transforms
		combined_transform: matrix[2, 3]f32
		combined_transform = composite_transform(parent_transform^, component.transform)

		// Recursively create the component's outline
		component_outline, comp_outline_ok := create_outline_from_extracted(
			glyf,
			&component_extracted,
			&combined_transform,
			allocator,
		)

		if !comp_outline_ok {
			continue // Skip components we can't process
		}

		// Transfer contours to the parent outline
		for &comp_contour in component_outline.contours {
			append(&outline.contours, comp_contour)
			// Clear from source so destroy_glyph_outline doesn't double-free
			clear(&comp_contour.segments)
		}

		// Clean up component outline - the segments have been moved to the parent
		delete(component_outline.contours)
	}

	return len(outline.contours) > 0
}
// Helper function to combine two transformation matrices
composite_transform :: proc(a, b: matrix[2, 3]f32) -> matrix[2, 3]f32 {
	result: matrix[2, 3]f32

	// First row
	result[0, 0] = a[0, 0] * b[0, 0] + a[0, 1] * b[1, 0] // xx
	result[0, 1] = a[0, 0] * b[0, 1] + a[0, 1] * b[1, 1] // xy
	result[0, 2] = a[0, 0] * b[0, 2] + a[0, 1] * b[1, 2] + a[0, 2] // dx
	// Second row
	result[1, 0] = a[1, 0] * b[0, 0] + a[1, 1] * b[1, 0] // yx
	result[1, 1] = a[1, 0] * b[0, 1] + a[1, 1] * b[1, 1] // yy
	result[1, 2] = a[1, 0] * b[0, 2] + a[1, 1] * b[1, 2] + a[1, 2] // dy

	return result
}


insert_at :: proc(array: ^[dynamic]$T, index: int, value: T) {
	if index > len(array) {return}
	resize(array, len(array) + 1)
	// Shift elements right
	for i := len(array) - 2; i >= index; i -= 1 {
		array[i + 1] = array[i]
	}
	array[index] = value
}
