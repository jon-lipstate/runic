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
		points_in_contour := endpoint - start_idx + 1

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

		// Add contour to outline
		append(&outline.contours, contour)

		// Update start index for next contour
		start_idx = endpoint + 1
	}

	return true
}

// Create segments directly from point data
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

	// First, we need to process points to handle implied points between consecutive off-curve points
	// We'll create temporary work arrays
	processed_points := make([dynamic][2]f32, 0, point_count * 2, allocator)
	processed_on_curve := make([dynamic]bool, 0, point_count * 2, allocator)
	defer delete(processed_points)
	defer delete(processed_on_curve)

	// First, transform points
	for i := 0; i < point_count; i += 1 {
		x, y := f32(points[i][0]), f32(points[i][1])

		// Apply transform if provided
		if transform != nil {
			tx := transform[0, 0] * x + transform[0, 1] * y + transform[0, 2]
			ty := transform[1, 0] * x + transform[1, 1] * y + transform[1, 2]
			x, y = tx, ty
		}

		append(&processed_points, [2]f32{x, y})
		append(&processed_on_curve, on_curve[i])
	}

	// Check if all points are off-curve
	all_off_curve := true
	for i := 0; i < len(processed_on_curve); i += 1 {
		if processed_on_curve[i] {
			all_off_curve = false
			break
		}
	}

	// Add implied points
	if all_off_curve {
		// If all points are off-curve, add implied on-curve points between each pair
		original_count := len(processed_points)
		for i := 0; i < original_count; i += 1 {
			p1 := processed_points[i]
			p2 := processed_points[(i + 1) % original_count]

			// Create implied on-curve point at midpoint
			midpoint := [2]f32{(p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2}

			// Insert after current point
			idx := i * 2 + 1
			insert_at_elem(&processed_points, idx, midpoint)
			insert_at_elem(&processed_on_curve, idx, true) // implied point is on-curve
		}
	} else {
		// Add implied points between consecutive off-curve points
		i := 0
		for i < len(processed_on_curve) {
			if !processed_on_curve[i] {
				next_idx := (i + 1) % len(processed_on_curve)
				if !processed_on_curve[next_idx] {
					// Two consecutive off-curve points - add implied on-curve point
					p1 := processed_points[i]
					p2 := processed_points[next_idx]
					midpoint := [2]f32{(p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2}

					// Insert after current point
					insert_at_elem(&processed_points, i + 1, midpoint)
					insert_at_elem(&processed_on_curve, i + 1, true)

					// Skip past newly inserted point
					i += 2
					continue
				}
			}
			i += 1
		}
	}

	// Find first on-curve point
	start_idx := 0
	for i := 0; i < len(processed_on_curve); i += 1 {
		if processed_on_curve[i] {
			start_idx = i
			break
		}
	}

	// Create segments from processed points
	current := start_idx
	for i := 0; i < len(processed_points); i += 1 {
		next := (current + 1) % len(processed_points)

		// If we've wrapped around, we're done
		if i > 0 && next == start_idx {
			break
		}

		if processed_on_curve[current] && processed_on_curve[next] {
			// Line segment between two on-curve points
			segment := Line_Segment {
				a = processed_points[current],
				b = processed_points[next],
			}
			append(&contour.segments, segment)
			current = next
		} else if processed_on_curve[current] && !processed_on_curve[next] {
			// Find next on-curve point after off-curve control point
			after_next := (next + 1) % len(processed_points)

			// With our preprocessing, this must be on-curve
			if !processed_on_curve[after_next] {
				return false
			}

			// Quadratic bezier
			segment := Quad_Bezier_Segment {
				a       = processed_points[current],
				control = processed_points[next],
				b       = processed_points[after_next],
			}
			append(&contour.segments, segment)

			// Skip ahead
			current = after_next
		} else {
			return false // Unexpected configuration
		}
	}

	// Ensure the contour is closed
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
