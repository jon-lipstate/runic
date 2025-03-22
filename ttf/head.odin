package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/head
// head — Font Header Table
/*
The font header table contains global information about the font. This includes:
- Font version
- Creation/modification dates
- Font bounding box
- Style and rendering characteristics
- Other global font properties
*/

OpenType_Head_Table :: struct #packed {
	// Required info
	version:             Head_Table_Version, // Table version number (0x00010000 for 1.0)
	font_revision:       Fixed, // Font revision set by font designer
	checksum_adjustment: u32be, // Used for font checksumming
	magic_number:        u32be, // Set to 0x5F0F3CF5
	flags:               Head_Flags, // Font flags
	units_per_em:        u16be, // Valid range is 16 to 16384
	created:             i64be, // Date created (seconds since 1904-01-01)
	modified:            i64be, // Date modified (seconds since 1904-01-01)

	// Bounding box
	x_min:               i16be, // Min x for all glyphs
	y_min:               i16be, // Min y for all glyphs
	x_max:               i16be, // Max x for all glyphs
	y_max:               i16be, // Max y for all glyphs

	// Style and rendering properties
	mac_style:           Mac_Style, // Style bits
	lowest_rec_ppem:     u16be, // Smallest readable size in pixels

	// Direction and encoding info
	font_direction_hint: i16be, // Deprecated, set to 2
	index_to_loc_format: i16be, // 0 for short offsets, 1 for long
	glyph_data_format:   i16be, // 0 for current format
}

// Head flags
Head_Flags :: bit_field u16be {
	Baseline_At_Y0:                    bool | 1, // Baseline at y=0
	Left_Sidebearing_At_X0:            bool | 1, // LSB at x=0
	Instructions_Depend_On_Point_Size: bool | 1, // Hinting varies with point size
	Force_PPem_To_Integer:             bool | 1, // Round PPEM to integer
	Instructions_Alter_Advance_Width:  bool | 1, // Advance width changes with hinting
	reserved1:                         u8   | 6, // Bits 5-10 are reserved
	Lossless_Font_Data:                bool | 1, // Font is uncompressed
	Font_Converted:                    bool | 1, // Font has been converted
	Font_Optimized_For_ClearType:      bool | 1, // Optimized for ClearType rendering
	deprecated:                        bool | 1, // Bit 14 is deprecated
	Last_Resort_Font:                  bool | 1, // Used if no other font available
}

// Mac style flags
Mac_Style :: bit_field u16be {
	Bold:      bool  | 1,
	Italic:    bool  | 1,
	Underline: bool  | 1,
	Outline:   bool  | 1,
	Shadow:    bool  | 1,
	Condensed: bool  | 1,
	Extended:  bool  | 1,
	reserved:  u16be | 9, // Bits 7-15 are reserved
}

// Load the head table
load_head_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	head_data, ok := get_table_data(font, "head")
	if !ok {return {}, .Table_Not_Found}

	// Check minimum size for header
	if len(head_data) < size_of(OpenType_Head_Table) {
		return {}, .Invalid_Table_Format
	}

	// Create new head table structure
	head := new(OpenType_Head_Table)
	head^ = (cast(^OpenType_Head_Table)&head_data[0])^

	// Validate magic number
	// magic_number must be 0x5F0F3CF5
	magic := u32(head.magic_number)
	if magic != 0x5F0F3CF5 {
		free(head)
		return {}, .Invalid_Table_Format
	}

	// Validate version
	version := transmute(u32be)head.version
	if u32(version) != 0x00010000 {
		free(head)
		return {}, .Invalid_Table_Format
	}

	return Table_Entry{data = head, destroy = destroy_head_table}, .None
}

destroy_head_table :: proc(data: rawptr) {
	if data == nil {return}
	head := cast(^OpenType_Head_Table)data
	free(head)
}

// Head table version
Head_Table_Version :: enum u32be {
	Version_1_0 = 0x00010000, // Version 1.0 - the only valid version
}

////////////////////////////////////////////////////////////////////////////////////////
get_font_revision :: proc(head: ^OpenType_Head_Table) -> i32 {
	if head == nil {return 0}
	return i32(head.font_revision)
}

// Font creation/modification dates (returns seconds since January 1, 1904)
get_creation_date :: proc(head: ^OpenType_Head_Table) -> i64 {
	if head == nil {return 0}
	return i64(head.created) // TODO: turn into time.Time
}

get_modification_date :: proc(head: ^OpenType_Head_Table) -> i64 {
	if head == nil {return 0}
	return i64(head.modified) // TODO: turn into time.Time
}

// Font metrics
get_units_per_em :: proc(head: ^OpenType_Head_Table) -> u16 {
	if head == nil {return 0}
	return u16(head.units_per_em)
}

get_font_bounding_box :: proc(head: ^OpenType_Head_Table) -> Bounding_Box {
	if head == nil {return {}}

	return Bounding_Box {
		min = {i16(head.x_min), i16(head.y_min)},
		max = {i16(head.x_max), i16(head.y_max)},
	}
}

get_lowest_recommended_ppem :: proc(head: ^OpenType_Head_Table) -> u16 {
	if head == nil {return 0}
	return u16(head.lowest_rec_ppem)
}

// Style and rendering flags
get_head_flags :: proc(head: ^OpenType_Head_Table) -> Head_Flags {
	if head == nil {return {}}
	return head.flags
}

get_mac_style :: proc(head: ^OpenType_Head_Table) -> Mac_Style {
	if head == nil {return {}}
	return head.mac_style
}

// Format information
get_index_to_loc_format :: proc(head: ^OpenType_Head_Table) -> i16 {
	if head == nil {return 0}
	return i16(head.index_to_loc_format)
}

// Helper functions for checking specific style bits
is_bold_head :: proc(head: ^OpenType_Head_Table) -> bool {
	if head == nil {return false}
	style := get_mac_style(head)
	return style.Bold
}

is_italic_head :: proc(head: ^OpenType_Head_Table) -> bool {
	if head == nil {return false}
	style := get_mac_style(head)
	return style.Italic
}

// Helper functions for checking specific flag bits
has_vertical_metrics_head :: proc(head: ^OpenType_Head_Table) -> bool {
	if head == nil {return false}
	flags := get_head_flags(head)
	return flags.Baseline_At_Y0
}

has_horizontal_metrics :: proc(head: ^OpenType_Head_Table) -> bool {
	if head == nil {return false}
	flags := get_head_flags(head)
	return flags.Left_Sidebearing_At_X0
}

is_optimized_for_cleartype :: proc(head: ^OpenType_Head_Table) -> bool {
	if head == nil {return false}
	flags := get_head_flags(head)
	return flags.Font_Optimized_For_ClearType
}
