package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/vhea
// vhea — Vertical Header Table
/*
The vertical header table contains global information for laying out fonts that use
vertical metrics. It is similar to the horizontal header table (hhea) but for vertical layout.
The vertical header table contains information such as vertical typographic ascender and descender,
line gap, and the maximum advance height.
*/

Vhea_Table :: struct {
	data:     ^OpenType_Vhea_Table, // Pointer to the raw table data
	raw_data: []byte, // Reference to raw data
	version:  Vhea_Version, // Table version
}

// Vertical Header Table version
Vhea_Version :: enum u32be {
	Version_1_0 = 0x00010000, // Version 1.0
	Version_1_1 = 0x00011000, // Version 1.1
}

// Vertical Header table structure
OpenType_Vhea_Table :: struct #packed {
	version:                 Version16Dot16, // Version number (0x00010000 for 1.0, 0x00011000 for 1.1)
	vert_typo_ascender:      FWORD, // Typographic top (typically positive)
	vert_typo_descender:     FWORD, // Typographic bottom (typically negative)
	vert_typo_line_gap:      FWORD, // Typographic line gap
	advance_height_max:      UFWORD, // Maximum advance height value
	min_top_side_bearing:    FWORD, // Minimum top side bearing
	min_bottom_side_bearing: FWORD, // Minimum bottom side bearing
	y_max_extent:            FWORD, // Maximum Y extent (y_max for a glyph - top side bearing)
	caret_slope_rise:        SHORT, // Caret slope (rise/run), 0/1 for vertical caret
	caret_slope_run:         SHORT, // Caret slope (rise/run), 1/0 for horizontal caret
	caret_offset:            SHORT, // Amount to offset the caret for punctuation (0 for vertical)
	reserved1:               SHORT, // Set to 0
	reserved2:               SHORT, // Set to 0
	reserved3:               SHORT, // Set to 0
	reserved4:               SHORT, // Set to 0
	metric_data_format:      SHORT, // Set to 0
	number_of_v_metrics:     USHORT, // Number of advance heights in the vmtx table
}


load_vhea_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	vhea_data, ok := get_table_data(font, "vhea")
	if !ok {
		return {}, .Table_Not_Found
	}

	// Check minimum size for the vhea table
	if len(vhea_data) < size_of(OpenType_Vhea_Table) {
		return {}, .Invalid_Table_Format
	}

	// Create a new Vhea_Table structure
	vhea := new(Vhea_Table)
	vhea.raw_data = vhea_data
	vhea.data = cast(^OpenType_Vhea_Table)&vhea_data[0]

	// Extract the version
	version := u32(vhea.data.version)
	if version == 0x00010000 {
		vhea.version = .Version_1_0
	} else if version == 0x00011000 {
		vhea.version = .Version_1_1
	} else {
		// Unknown version
		free(vhea)
		return {}, .Invalid_Table_Format
	}

	return Table_Entry{data = vhea, destroy = destroy_vhea_table}, .None
}

destroy_vhea_table :: proc(data: rawptr) {
	if data == nil {return}
	vhea := cast(^Vhea_Table)data
	free(vhea)
}

//////////////////////////////////////////////////////////////////////////////////////////
// API Functions

// Get the typographic ascender for vertical layout
get_vert_ascender :: proc(vhea: ^Vhea_Table) -> i16 {
	if vhea == nil || vhea.data == nil {return 0}
	return i16(vhea.data.vert_typo_ascender)
}

// Get the typographic descender for vertical layout
get_vert_descender :: proc(vhea: ^Vhea_Table) -> i16 {
	if vhea == nil || vhea.data == nil {return 0}
	return i16(vhea.data.vert_typo_descender)
}

// Get the line gap for vertical layout
get_vert_line_gap :: proc(vhea: ^Vhea_Table) -> i16 {
	if vhea == nil || vhea.data == nil {return 0}
	return i16(vhea.data.vert_typo_line_gap)
}

// Get the maximum advance height
get_advance_height_max :: proc(vhea: ^Vhea_Table) -> u16 {
	if vhea == nil || vhea.data == nil {return 0}
	return u16(vhea.data.advance_height_max)
}

// Get the minimum top side bearing
get_min_top_side_bearing :: proc(vhea: ^Vhea_Table) -> i16 {
	if vhea == nil || vhea.data == nil {return 0}
	return i16(vhea.data.min_top_side_bearing)
}

// Get the minimum bottom side bearing
get_min_bottom_side_bearing :: proc(vhea: ^Vhea_Table) -> i16 {
	if vhea == nil || vhea.data == nil {return 0}
	return i16(vhea.data.min_bottom_side_bearing)
}

// Get the maximum Y extent
get_y_max_extent :: proc(vhea: ^Vhea_Table) -> i16 {
	if vhea == nil || vhea.data == nil {return 0}
	return i16(vhea.data.y_max_extent)
}

// Get the caret slope for vertical layout
get_vert_caret_slope :: proc(vhea: ^Vhea_Table) -> (rise: i16, run: i16) {
	if vhea == nil || vhea.data == nil {return 0, 0}
	return i16(vhea.data.caret_slope_rise), i16(vhea.data.caret_slope_run)
}

// Get the caret offset for vertical layout
get_vert_caret_offset :: proc(vhea: ^Vhea_Table) -> i16 {
	if vhea == nil || vhea.data == nil {return 0}
	return i16(vhea.data.caret_offset)
}

// Get the number of vertical metrics entries
get_number_of_v_metrics :: proc(vhea: ^Vhea_Table) -> u16 {
	if vhea == nil || vhea.data == nil {return 0}
	return u16(vhea.data.number_of_v_metrics)
}

// Check if font has vertical metrics
has_vertical_metrics :: proc(font: ^Font) -> bool {
	// A font has vertical metrics if it has both vhea and vmtx tables
	_, has_vhea := get_table_data(font, "vhea")
	_, has_vmtx := get_table_data(font, "vmtx")
	return has_vhea && has_vmtx
}

// Calculate default vertical line metrics
calculate_vertical_line_metrics :: proc(vhea: ^Vhea_Table) -> (height: i32, gap: i32) {
	if vhea == nil || vhea.data == nil {return 0, 0}

	// Vertical height is typically calculated as ascender - descender
	// Note: descender is typically negative in vertical fonts
	height = i32(vhea.data.vert_typo_ascender) - i32(vhea.data.vert_typo_descender)

	// Gap is the line gap value
	gap = i32(vhea.data.vert_typo_line_gap)

	return height, gap
}

// Helper function to determine if a font is designed for vertical writing
is_vertical_writing_font :: proc(font: ^Font) -> bool {
	// A font is designed for vertical writing if:
	// 1. It has vertical metrics tables (vhea, vmtx)
	if !has_vertical_metrics(font) {return false}

	// 2. Check for GPOS with vertical writing features (optional)
	// This would require checking GPOS features, which is more complex
	// and might be implemented elsewhere in the font engine
	// TODO:
	return false
}
