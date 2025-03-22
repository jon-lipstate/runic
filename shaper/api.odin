package rune
/*
load_font :: proc(filepath: string) -> (font: Font, err: Font_Error)
destroy_font :: proc(font: ^Font)
has_feature :: proc(font: ^Font, feature: Font_Feature) -> bool
has_table :: proc(font: ^Font, tag: string) -> bool

// Get metrics for a specific glyph
get_glyph_metrics :: proc(
	font: ^Font,
	glyph_id: Glyph,
) -> (
	advance: i16,
	lsb: i16,
	bbox: Bounding_Box,
	ok: bool,
)

// Get kerning between two glyphs
get_kerning :: proc(font: ^Font, first_glyph, second_glyph: u16) -> i16

// Get glyph ID for a Unicode code point
get_glyph_id :: proc(font: ^Font, codepoint: rune) -> (glyph_id: u16, ok: bool)

// Extract glyph outline
get_glyph_outline :: proc(font: ^Font, glyph_id: u16) -> (outline: Glyph_Outline, ok: bool)

// Get font metadata from name table
get_font_name :: proc(font: ^Font, name_id: Name_ID, preferred_language: string = "") -> string

// For variable fonts
get_variation_axes :: proc(font: ^Font) -> (axes: []Variation_Axis, ok: bool)

// Set variation coordinates (for variable fonts)
set_variation_coordinates :: proc(font: ^Font, coordinates: []Variation_Coordinate) -> bool


//////////////////////////////////////////////////////////////////////////////////////////////////////
// Core font interface
get_font_name :: proc(font: ^Font, name_id: Name_ID) -> string
get_font_family :: proc(font: ^Font) -> string // Convenience wrapper for NAME_FAMILY
get_font_style :: proc(font: ^Font) -> string // Convenience wrapper for NAME_SUBFAMILY
get_postscript_name :: proc(font: ^Font) -> string // Convenience wrapper for NAME_POSTSCRIPT

// Font metrics
get_ascender :: proc(font: ^Font) -> i16
get_descender :: proc(font: ^Font) -> i16
get_line_gap :: proc(font: ^Font) -> i16
get_units_per_em :: proc(font: ^Font) -> u16 // Already in your Font struct

// Typographic metrics (from OS/2 table)
get_typographic_ascender :: proc(font: ^Font) -> i16
get_typographic_descender :: proc(font: ^Font) -> i16
get_typographic_line_gap :: proc(font: ^Font) -> i16

// Font bounding box
get_bounding_box :: proc(font: ^Font) -> Bounding_Box

// Glyph lookup and metrics
get_glyph_id :: proc(font: ^Font, codepoint: rune) -> (Glyph, bool)
get_glyph_horizontal_advance :: proc(font: ^Font, glyph: Glyph) -> i16
get_glyph_bounding_box :: proc(font: ^Font, glyph: Glyph) -> (Bounding_Box, bool)
get_kerning :: proc(font: ^Font, left: Glyph, right: Glyph) -> i16

// Glyph outline data (lazy loaded)
get_glyph_outline :: proc(font: ^Font, glyph: Glyph) -> (Glyph_Outline, bool)

// Feature detection (supplementing your bit_set approach)
has_feature :: proc(font: ^Font, feature: Font_Feature) -> bool
supports_script :: proc(font: ^Font, script: Script_Tag) -> bool
supports_language :: proc(font: ^Font, script: Script_Tag, language: Language_Tag) -> bool

// OpenType feature support
has_opentype_feature :: proc(font: ^Font, 
                             script: Script_Tag, 
                             language: Language_Tag, 
                             feature: Feature_Tag) -> bool

// GSUB/GPOS functionality
shape_text :: proc(font: ^Font, 
                   text: string, 
                   features: []Feature_Tag, 
                   script: Script_Tag, 
                   language: Language_Tag) -> []Shaped_Glyph

// Variation support for variable fonts
set_variation :: proc(font: ^Font, axis: Variation_Axis_Tag, value: f32) -> bool
get_variation_axes :: proc(font: ^Font) -> []Variation_Axis



*/
