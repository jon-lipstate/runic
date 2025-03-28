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


// Main function to convert from Extracted_Glyph to Glyph_Outline
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
	outline.contours = make([dynamic]Contour, allocator)
	defer if !ok {delete(outline.contours)}
	// Handle based on glyph type
	switch &ext in extracted {
	case Extracted_Simple_Glyph:
		outline.glyph_id = 0 // This needs to be passed in as we don't store it in Extracted_Glyph
		outline.bounds = ext.bounds

		if ext.points == nil || len(ext.points) == 0 {
			// Empty glyph (space, etc.)
			outline.is_empty = true
			return outline, true
		}

	// ok = create_outline_from_simple_glyph(&ext, &outline, transform, allocator)

	case Extracted_Compound_Glyph:
		outline.glyph_id = 0 // This needs to be passed in

		// Default identity transform if none provided
		identity := IDENTITY_MATRIX
		active_transform := transform != nil ? transform^ : identity

	// ok = create_outline_from_compound_glyph(glyf, &ext, &outline, &active_transform, allocator)
	}
	if !ok {return}

	return outline, true
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
