package ttf

import "base:runtime"

// https://docs.microsoft.com/en-us/typography/opentype/spec/cmap

CMAP_Version :: enum u16 {
	Version_0 = 0, // Standard version
}

Platform_ID :: enum u16 {
	Unicode   = 0,
	Macintosh = 1,
	ISO       = 2, // Deprecated
	Windows   = 3,
	Custom    = 4,
}

// Unicode Platform Encoding IDs
Unicode_Encoding_ID :: enum u16 {
	Unicode_1_0                 = 0,
	Unicode_1_1                 = 1,
	ISO_10646                   = 2,
	Unicode_2_0_BMP             = 3,
	Unicode_2_0_Full            = 4,
	Unicode_Variation_Sequences = 5,
	Unicode_Full                = 6,
}

// Windows Platform Encoding IDs
Windows_Encoding_ID :: enum u16 {
	Symbol                  = 0,
	Unicode_BMP             = 1,
	ShiftJIS                = 2,
	PRC                     = 3, // Simplified Chinese
	Big5                    = 4, // Traditional Chinese
	Wansung                 = 5, // Korean
	Johab                   = 6, // Korean
	Reserved1               = 7,
	Reserved2               = 8,
	Reserved3               = 9,
	Unicode_Full_Repertoire = 10,
}

// Macintosh Platform Encoding IDs
Macintosh_Encoding_ID :: enum u16 {
	Roman               = 0,
	Japanese            = 1,
	Chinese_Traditional = 2,
	Korean              = 3,
	Arabic              = 4,
	Hebrew              = 5,
	Greek               = 6,
	Russian             = 7,
	// TODO: And many more...
}

// CMAP Format types
CMAP_Format :: enum u16 {
	Byte_Encoding         = 0, // Format 0
	High_Byte_Mapping     = 2, // Format 2
	Segment_Mapping       = 4, // Format 4 (most common)
	Trimmed_Table         = 6, // Format 6
	Mixed_Coverage        = 8, // Format 8
	Trimmed_Array         = 10, // Format 10
	Segmented_Coverage    = 12, // Format 12
	Many_To_One_Mapping   = 13, // Format 13
	Unicode_Variation_Seq = 14, // Format 14
}

// CMAP table structures (redesigned to minimize allocations)
CMAP_Table :: struct {
	version:          CMAP_Version,
	encoding_records: []CMAP_Encoding_Record, // Allocated
	subtables:        []CMAP_Subtable, // Allocated
	raw_data:         []byte, // Reference
}

CMAP_Encoding_Record :: struct {
	platform_id: Platform_ID,
	encoding_id: u16, // Unicode_Encoding_ID | Windows_Encoding_ID | Macintosh_Encoding_ID
	subtable:    ^CMAP_Subtable,
}

CMAP_Subtable :: struct {
	format:   CMAP_Format,
	length:   u32,
	language: u32,
	offset:   uint, // From beginning of cmap 
	data:     CMAP_Subtable_Data,
}

CMAP_Subtable_Data :: union {
	^Format0, // Allocated (new)
	^Format2, // Allocated (new)
	^Format4, // Allocated (new)
	^Format6, // Allocated (new)
	^Format8, // Allocated (new)
	^Format10, // Allocated (new)
	^Format12, // Allocated (new)
	^Format13, // Allocated (new)
	^Format14, // Allocated (new)
}

// Format 0: Byte encoding table (simple 1-to-1 mapping for ASCII)
Format0 :: struct {
	glyph_ids_offset: uint, // Offset to the 256-byte glyph ID array in raw_data
}

// Format 2: High-byte mapping through table (for CJK fonts)
Format2 :: struct {
	sub_header_keys_offset: uint, // Offset to 256 subHeaderKeys (512 bytes)
	sub_headers_offset:     uint, // Offset to subHeaders array
	sub_headers_count:      uint, // Number of subHeaders
	glyph_id_array_offset:  uint, // Offset to glyphIdArray
	glyph_id_array_length:  uint, // Length of glyphIdArray in u16 units
}

// Format 4: Segment mapping to delta values (most common for BMP)
Format4 :: struct {
	segment_count:          uint, // Number of segments
	end_code_offset:        uint, // Offset to endCode array
	start_code_offset:      uint, // Offset to startCode array
	id_delta_offset:        uint, // Offset to idDelta array
	id_range_offset_offset: uint, // Offset to idRangeOffset array
	glyph_id_array_offset:  uint, // Offset to glyphIdArray
	glyph_id_array_length:  uint, // Length of glyphIdArray in u16 units
}

// Format 6: Trimmed table mapping
Format6 :: struct {
	first_code:       u16, // First character code covered
	entry_count:      u16, // Number of character codes covered
	glyph_ids_offset: uint, // Offset to glyphIds array
}

// Format 8: Mixed 16-bit and 32-bit coverage
Format8 :: struct {
	is_32_offset:  uint, // Offset to is32 bit array (8192 bytes)
	num_groups:    u32, // Number of groupings
	groups_offset: uint, // Offset to groups array
}

// Format 10: Trimmed array (for 32-bit character codes)
Format10 :: struct {
	start_char_code: u32, // First character code covered
	num_chars:       u32, // Number of character codes covered
	glyphs_offset:   uint, // Offset to glyphs array
}

// Format 12: Segmented coverage (for non-BMP, 32-bit)
Format12 :: struct {
	num_groups:    u32, // Number of groups
	groups_offset: uint, // Offset to character groups
}

// Format 13: Many-to-one range mappings (for non-BMP, 32-bit)
Format13 :: struct {
	num_groups:    u32, // Number of groups
	groups_offset: uint, // Offset to character groups
}

// For reading Format 12/13 groups directly from byte data
Character_Group :: struct {
	start_char_code: u32,
	end_char_code:   u32,
	start_glyph_id:  u32,
}

Character_Group_Single_Glyph :: struct {
	start_char_code: u32,
	end_char_code:   u32,
	glyph_id:        u32,
}

// Format 14: Unicode Variation Sequences
Format14 :: struct {
	num_var_selectors:    u32, // Number of variation selectors
	var_selectors_offset: uint, // Offset to variation selectors array
	offset:               uint, // Base offset of this subtable within cmap table
}

Variation_Selector :: struct {
	selector:                   u32, // 24-bit Unicode variation selector
	default_uvs_offset:         u32, // Offset to default UVS table
	nondefault_uvs_offset:      u32, // Offset to non-default UVS table
	default_uvs_range_count:    u32, // Number of default UVS ranges
	nondefault_uvs_range_count: u32, // Number of non-default UVS mappings
}

Default_UVS_Range :: struct {
	start_unicode: u32, // 24-bit starting Unicode value
	count:         u8, // Additional code points in range
}

Nondefault_UVS_Mapping :: struct {
	unicode:  u32, // 24-bit Unicode value
	glyph_id: Glyph,
}
load_cmap_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	cmap_data, ok := get_table_data(font, .cmap)
	if !ok || len(cmap_data) < 4 {
		return {}, .Missing_Required_Table
	}

	// Parse header
	version := cast(CMAP_Version)read_u16(cmap_data, 0)
	num_tables := read_u16(cmap_data, 2)

	// Create table
	cmap := new(CMAP_Table, font.allocator)
	cmap.version = version
	cmap.raw_data = cmap_data // Store reference to raw data

	// Check if data is valid
	if num_tables <= 0 || bounds_check(len(cmap_data) < 4 + int(num_tables) * 8) {
		return {}, .Invalid_Table_Format
	}

	// Parse encoding records
	cmap.encoding_records = make([]CMAP_Encoding_Record, num_tables, font.allocator)
	cmap.subtables = make([]CMAP_Subtable, num_tables, font.allocator)

	offset: uint = 4 // Skip header

	// First pass: Build encoding records and basic subtable info
	for i: uint = 0; i < uint(num_tables); i += 1 {
		cmap.encoding_records[i] = CMAP_Encoding_Record {
			platform_id = cast(Platform_ID)read_u16(cmap_data, offset),
			encoding_id = read_u16(cmap_data, offset + 2),
			subtable    = &cmap.subtables[i], // Link directly to its subtable
		}

		subtable_offset := uint(read_u32(cmap_data, offset + 4))
		if bounds_check(subtable_offset + 2 > uint(len(cmap_data))) {
			continue // Skip invalid subtable
		}

		// Read format and create appropriate subtable
		format := cast(CMAP_Format)read_u16(cmap_data, subtable_offset)
		cmap.subtables[i].format = format
		cmap.subtables[i].offset = subtable_offset

		// Read basic header info - varies by format
		parse_cmap_subtable_header(cmap_data, subtable_offset, &cmap.subtables[i])

		offset += 8
	}

	// Second pass: Parse detailed subtable data 
	for i: uint = 0; i < uint(num_tables); i += 1 {
		subtable_offset := uint(read_u32(cmap_data, 4 + i * 8 + 4))
		if bounds_check(subtable_offset + 2 > uint(len(cmap_data))) {
			continue
		}

		switch cmap.subtables[i].format {
		case .Byte_Encoding:
			parse_cmap_format0(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .High_Byte_Mapping:
			parse_cmap_format2(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .Segment_Mapping:
			parse_cmap_format4(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .Trimmed_Table:
			parse_cmap_format6(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .Mixed_Coverage:
			parse_cmap_format8(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .Trimmed_Array:
			parse_cmap_format10(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .Segmented_Coverage:
			parse_cmap_format12(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .Many_To_One_Mapping:
			parse_cmap_format13(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)

		case .Unicode_Variation_Seq:
			parse_cmap_format14(cmap_data, subtable_offset, &cmap.subtables[i], font.allocator)
		}
	}

	return Table_Entry{data = cmap}, .None
}

// Helper to parse the basic subtable header
@(private)
parse_cmap_subtable_header :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable) {
	format := subtable.format

	// Different formats have different header structures
	if format == .Segment_Mapping ||
	   format == .Byte_Encoding ||
	   format == .High_Byte_Mapping ||
	   format == .Trimmed_Table {
		// 16-bit length and language
		if bounds_check(offset + 4 > uint(len(data))) {return}
		subtable.length = u32(read_u16(data, offset + 2))
		subtable.language = u32(read_u16(data, offset + 4))
	} else if format == .Segmented_Coverage ||
	   format == .Many_To_One_Mapping ||
	   format == .Mixed_Coverage ||
	   format == .Trimmed_Array {
		// 32-bit length and language
		if bounds_check(offset + 12 > uint(len(data))) {return}
		subtable.length = read_u32(data, offset + 4)
		subtable.language = read_u32(data, offset + 8)
	} else if format == .Unicode_Variation_Seq {
		// Format 14 has its own structure
		if bounds_check(offset + 4 > uint(len(data))) {return}
		subtable.length = read_u32(data, offset + 2)
		subtable.language = 0 // Format 14 doesn't have a language field
	}
}

// Format 0: Byte encoding table
@(private)
parse_cmap_format0 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 6 + 256 > uint(len(data))) {return}

	format0 := new(Format0, allocator) // Allocated (small struct)
	format0.glyph_ids_offset = offset + 6

	subtable.data = format0
}

// Format 2: High-byte mapping through table
@(private)
parse_cmap_format2 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 6 + 512 > uint(len(data))) {return}

	format2 := new(Format2, allocator) // Allocated (small struct)
	format2.sub_header_keys_offset = offset + 6

	// Find maximum subHeader index to determine count
	max_key := u16(0)
	for i: uint = 0; i < 256; i += 1 {
		key := read_u16(data, format2.sub_header_keys_offset + i * 2) / 8
		if key > max_key {
			max_key = key
		}
	}

	format2.sub_headers_count = uint(max_key) + 1
	format2.sub_headers_offset = offset + 6 + 512

	// Calculate glyphIdArray location and size
	glyph_id_array_offset := format2.sub_headers_offset + format2.sub_headers_count * 8
	format2.glyph_id_array_offset = glyph_id_array_offset
	format2.glyph_id_array_length = (uint(subtable.length) - (glyph_id_array_offset - offset)) / 2

	subtable.data = format2
}

// Format 4: Segment mapping to delta values
@(private)
parse_cmap_format4 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 14 > uint(len(data))) {return}

	seg_count_x2 := read_u16(data, offset + 6)
	seg_count := uint(seg_count_x2) / 2

	if seg_count <= 0 || bounds_check(offset + 14 + (seg_count * 8) + 2 > uint(len(data))) {return}

	format4 := new(Format4, allocator) // Allocated (small struct)
	format4.segment_count = seg_count

	// Calculate offsets to various arrays
	format4.end_code_offset = offset + 14
	format4.start_code_offset = format4.end_code_offset + seg_count * 2 + 2 // Skip reservedPad
	format4.id_delta_offset = format4.start_code_offset + seg_count * 2
	format4.id_range_offset_offset = format4.id_delta_offset + seg_count * 2
	format4.glyph_id_array_offset = format4.id_range_offset_offset + seg_count * 2

	// Calculate length of glyphIdArray (remainder of the subtable)
	glyph_id_array_bytes := uint(subtable.length) - (format4.glyph_id_array_offset - offset)
	format4.glyph_id_array_length = glyph_id_array_bytes / 2

	subtable.data = format4
}

// Format 6: Trimmed table mapping
@(private)
parse_cmap_format6 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 10 > uint(len(data))) {return}

	format6 := new(Format6, allocator) // Allocated (small struct)
	format6.first_code = read_u16(data, offset + 6)
	format6.entry_count = read_u16(data, offset + 8)
	format6.glyph_ids_offset = offset + 10

	subtable.data = format6
}

// Format 8: Mixed 16-bit and 32-bit coverage
@(private)
parse_cmap_format8 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 16 + 8192 > uint(len(data))) {return}

	format8 := new(Format8, allocator) // Allocated (small struct)
	format8.is_32_offset = offset + 16

	// Parse num_groups
	num_groups_offset := offset + 16 + 8192
	if bounds_check(num_groups_offset + 4 > uint(len(data))) {
		return
	}

	format8.num_groups = read_u32(data, num_groups_offset)
	format8.groups_offset = num_groups_offset + 4

	// Verify we have enough data for the groups
	if bounds_check(format8.groups_offset + uint(format8.num_groups) * 12 > uint(len(data))) {
		return
	}

	subtable.data = format8
}

// Format 10: Trimmed array
@(private)
parse_cmap_format10 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 20 > uint(len(data))) {
		return
	}

	format10 := new(Format10, allocator) // Allocated (small struct)
	format10.start_char_code = read_u32(data, offset + 12)
	format10.num_chars = read_u32(data, offset + 16)
	format10.glyphs_offset = offset + 20

	// Verify we have enough data for all the glyph IDs
	if bounds_check(format10.glyphs_offset + uint(format10.num_chars) * 2 > uint(len(data))) {
		return
	}

	subtable.data = format10
}

// Format 12: Segmented coverage
@(private)
parse_cmap_format12 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 16 > uint(len(data))) {return}

	format12 := new(Format12, allocator) // Allocated (small struct)
	format12.num_groups = read_u32(data, offset + 12)
	format12.groups_offset = offset + 16

	// Verify we have enough data for all the groups
	if bounds_check(format12.groups_offset + uint(format12.num_groups) * 12 > uint(len(data))) {
		return
	}

	subtable.data = format12
}

// Format 13: Many-to-one mapping
@(private)
parse_cmap_format13 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 16 > uint(len(data))) {return}

	format13 := new(Format13, allocator) // Allocated (small struct)
	format13.num_groups = read_u32(data, offset + 12)
	format13.groups_offset = offset + 16

	// Verify we have enough data for all the groups
	if bounds_check(format13.groups_offset + uint(format13.num_groups) * 12 > uint(len(data))) {
		return
	}

	subtable.data = format13
}

// Format 14: Unicode Variation Sequences
@(private)
parse_cmap_format14 :: proc(data: []byte, offset: uint, subtable: ^CMAP_Subtable, allocator: runtime.Allocator) {
	if bounds_check(offset + 10 > uint(len(data))) {
		return
	}

	format14 := new(Format14, allocator) // Allocated (small struct)
	format14.num_var_selectors = read_u32(data, offset + 6)
	format14.var_selectors_offset = offset + 10
	format14.offset = offset // Store the base offset for calculating absolute positions

	// Verify we have enough data for all the variation selectors
	if format14.var_selectors_offset + uint(format14.num_var_selectors) * 11 > uint(len(data)) {
		return
	}

	subtable.data = format14
}

