package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/loca
// loca — Index to Location Table
/*
The loca table stores offsets to the locations of the glyphs in the glyf table.
It comes in two formats: 
- Short format: 16-bit offsets divided by 2
- Long format: 32-bit offsets

The format is specified by indexToLocFormat field in the head table.

The number of entries in the loca table is numGlyphs + 1, where the last entry
points to the end of the glyf table. This allows calculating the length of each
glyph by subtracting consecutive offsets.
*/

Loca_Table :: struct {
	format:     Loca_Format, // Format specified by indexToLocFormat in the head table
	num_glyphs: u16, // Number of glyphs (numGlyphs+1 entries in table)
	raw_data:   []byte, // Raw loca table data
	font:       ^Font, // Reference to parent font
}

// Format of the loca table as specified in the head table
Loca_Format :: enum u16 {
	Short = 0, // 16-bit offsets divided by 2
	Long  = 1, // 32-bit offsets
}

// Load the loca table
load_loca_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	loca_data, ok := get_table_data(font, "loca")
	if !ok {
		return {}, .Table_Not_Found
	}

	// We need the head table to determine the format
	head, ok_head := get_table(font, "head", load_head_table, OpenType_Head_Table)
	if !ok_head {
		return {}, .Missing_Required_Table
	}

	// We need maxp to get numGlyphs
	maxp, ok_maxp := get_table(font, "maxp", load_maxp_table, Maxp_Table)
	if !ok_maxp {
		return {}, .Missing_Required_Table
	}

	// Create the loca table structure
	loca := new(Loca_Table)
	loca.raw_data = loca_data
	loca.font = font
	loca.num_glyphs = get_num_glyphs(maxp)
	loca.format = Loca_Format(get_index_to_loc_format(head))

	// Verify the table size is correct for the format
	expected_entries := uint(loca.num_glyphs) + 1
	expected_size: uint

	if loca.format == .Short {
		expected_size = expected_entries * 2 // 2 bytes per entry
	} else {
		expected_size = expected_entries * 4 // 4 bytes per entry
	}

	if uint(len(loca_data)) < expected_size {
		free(loca)
		return {}, .Invalid_Table_Format
	}

	// Verify that offsets are in ascending order
	when ODIN_DEBUG {
		prev_offset := uint(0)
		for i := uint(0); i < expected_entries; i += 1 {
			current_offset := get_offset_at(loca, Glyph(i))

			if current_offset < prev_offset {
				free(loca)
				return {}, .Invalid_Table_Format
			}

			prev_offset = current_offset
		}
	}

	return Table_Entry{data = loca, destroy = destroy_loca_table}, .None
}

destroy_loca_table :: proc(data: rawptr) {
	if data == nil {return}
	loca := cast(^Loca_Table)data
	free(loca)
}

// Get the raw offset at a specific index in the loca table
get_offset_at :: proc(loca: ^Loca_Table, glyph_id: Glyph) -> uint {
	if loca == nil || uint(glyph_id) > uint(loca.num_glyphs) {
		return 0
	}
	index := uint(glyph_id)
	if loca.format == .Short {
		// Short format: 16-bit offsets divided by 2
		if bounds_check(index * 2 + 1 >= uint(len(loca.raw_data))) {
			return 0
		}
		return uint(read_u16(loca.raw_data, index * 2)) * 2
	} else {
		// Long format: 32-bit offsets
		if bounds_check(index * 4 + 3 >= uint(len(loca.raw_data))) {
			return 0
		}
		return uint(read_u32(loca.raw_data, index * 4))
	}
}

// Get the offset and length for a specific glyph ID
get_glyph_location :: proc(
	loca: ^Loca_Table,
	glyph_id: Glyph,
) -> (
	offset: uint,
	length: uint,
	found: bool,
) {
	if loca == nil {
		return 0, 0, false
	}

	gid := uint(glyph_id)
	if gid >= uint(loca.num_glyphs) {
		return 0, 0, false // Glyph ID out of range
	}

	// Get offset for this glyph and the next one
	glyph_offset := get_offset_at(loca, glyph_id)
	next_offset := get_offset_at(loca, glyph_id + 1)

	// Calculate length (can be zero for empty glyphs)
	glyph_length := next_offset - glyph_offset

	return glyph_offset, glyph_length, true
}

// Check if a glyph has an outline
has_glyph_outline :: proc(loca: ^Loca_Table, glyph_id: Glyph) -> bool {
	_, length, found := get_glyph_location(loca, glyph_id)
	return found && length > 0
}
