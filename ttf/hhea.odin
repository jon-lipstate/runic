package ttf

import "base:runtime"

// The hhea table is needed to parse hmtx properly
OpenType_Hhea_Table :: struct {
	version:                Fixed, // 0x00010000 (1.0)
	ascender:               FWORD, // Typographic ascent (may differ from OS/2 value)
	descender:              FWORD, // Typographic descent (may differ from OS/2 value)
	line_gap:               FWORD, // Typographic line gap
	advance_width_max:      UFWORD, // Maximum advance width
	min_left_side_bearing:  FWORD, // Minimum left side bearing
	min_right_side_bearing: FWORD, // Minimum right side bearing
	x_max_extent:           FWORD, // Max horizontal extent (lsb + (xMax-xMin))
	caret_slope_rise:       SHORT, // Used to calculate slanted carets
	caret_slope_run:        SHORT, // Used to calculate slanted carets
	caret_offset:           SHORT, // Used for non-slanted carets
	reserved1:              SHORT, // Set to 0
	reserved2:              SHORT, // Set to 0
	reserved3:              SHORT, // Set to 0
	reserved4:              SHORT, // Set to 0
	metric_data_format:     SHORT, // 0 for current format
	number_of_h_metrics:    USHORT, // Number of hMetric entries in hmtx table
}

load_hhea_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	hhea_data, ok := get_table_data(font, .hhea)
	if !ok {return {}, .Table_Not_Found}

	// Check minimum size for header
	if len(hhea_data) < size_of(OpenType_Hhea_Table) {
		return {}, .Invalid_Table_Format
	}

	// The table is a fixed size, so we can just cast the pointer
	hhea := (cast(^OpenType_Hhea_Table)&hhea_data[0])

	return Table_Entry{data = hhea}, .None
}

destroy_hhea_table :: proc(data: rawptr) {
	if data == nil {return}
	hhea := cast(^OpenType_Hhea_Table)data
}
//////////////////////////////////////////////////////////////////////////////////////////
get_ascender :: proc(hhea: ^OpenType_Hhea_Table) -> i16 {
	if hhea == nil {return 0}
	return i16(hhea.ascender)
}

get_descender :: proc(hhea: ^OpenType_Hhea_Table) -> i16 {
	if hhea == nil {return 0}
	return i16(hhea.descender)
}

get_line_gap :: proc(hhea: ^OpenType_Hhea_Table) -> i16 {
	if hhea == nil {return 0}
	return i16(hhea.line_gap)
}

get_advance_width_max :: proc(hhea: ^OpenType_Hhea_Table) -> u16 {
	if hhea == nil {return 0}
	return u16(hhea.advance_width_max)
}

get_min_left_side_bearing :: proc(hhea: ^OpenType_Hhea_Table) -> i16 {
	if hhea == nil {return 0}
	return i16(hhea.min_left_side_bearing)
}

get_min_right_side_bearing :: proc(hhea: ^OpenType_Hhea_Table) -> i16 {
	if hhea == nil {return 0}
	return i16(hhea.min_right_side_bearing)
}

get_x_max_extent :: proc(hhea: ^OpenType_Hhea_Table) -> i16 {
	if hhea == nil {return 0}
	return i16(hhea.x_max_extent)
}

get_caret_slope :: proc(hhea: ^OpenType_Hhea_Table) -> (rise: i16, run: i16) {
	if hhea == nil {return 0, 0}
	return i16(hhea.caret_slope_rise), i16(hhea.caret_slope_run)
}

get_caret_offset :: proc(hhea: ^OpenType_Hhea_Table) -> i16 {
	if hhea == nil {return 0}
	return i16(hhea.caret_offset)
}

get_number_of_h_metrics :: proc(hhea: ^OpenType_Hhea_Table) -> u16 {
	if hhea == nil {return 0}
	return u16(hhea.number_of_h_metrics)
}
