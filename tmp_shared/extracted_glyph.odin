package runic_tmp_shared

IDENTITY_MATRIX :: matrix[2, 3]f32{
	1.0, 0.0, 0.0, 
	0.0, 1.0, 0.0, 
}

Glyph :: distinct u16

Bounding_Box :: struct {
	min: [2]i16,
	max: [2]i16,
}

Extracted_Glyph :: union {
	Extracted_Simple_Glyph,
	Extracted_Compound_Glyph,
}

Extracted_Simple_Glyph :: struct {
	// Points from the font file
	glyph_id:          Glyph,
	points:            [][2]i16, // Allocated
	on_curve:          []bool, // Allocated
	contour_endpoints: []u16, // Allocated - Specifies the slices of `points` that form distinct contours

	// Hinting data
	instructions:      []byte,
	bounds:            Bounding_Box,
}

Extracted_Compound_Glyph :: struct {
	glyph_id:     Glyph,
	components:   []Glyph_Component, // Allocated
	instructions: []byte,
}

Glyph_Component :: struct {
	glyph_id:      Glyph,
	transform:     matrix[2, 3]f32,
	round_to_grid: bool,
}
