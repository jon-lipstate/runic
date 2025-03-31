package ttf

// #+feature custom-attribute @(api) TODO: propose to bill rather than build arg
import "core:os"
import "core:slice"
import "core:strings"

import "../ttf2"

load_font :: proc {
	load_font_from_path,
	load_font_from_data,
}

load_font_from_path :: proc(filepath: string) -> (Font, Font_Error) {
	data, ok := os.read_entire_file(filepath)
	if !ok {
		return {}, .File_Not_Found
	}
	font, err := load_font_from_data(data)
	font.filepath = filepath
	return font, err
}


load_font_from_data :: proc(data: []byte) -> (font: Font, err: Font_Error) {
	font._data = data
	font._cache = make(map[Table_Tag]Table_Entry)

	parse_offset_table(&font) or_return
	parse_table_directory(&font) or_return
	extract_table_tags(&font)
	detect_features(&font)
	extract_basic_metadata(&font)

	font_ok: bool
	font._v2, font_ok = ttf2.font_make_from_data(data, context.allocator)
	if ! font_ok {
		return {}, .Unknown
	}

	return font, .None
}

destroy_font :: proc(font: ^Font) {
	for _, entry in font._cache {
		if entry.destroy != nil {
			entry.destroy(entry.data)
		}
	}
	delete(font._cache)
	delete(font._data)
	delete(font._tables)
	delete(font.table_tags)
	ttf2.font_delete(font._v2)
}

// sfnt header
parse_offset_table :: proc(font: ^Font) -> Font_Error {
	if len(font._data) < size_of(Offset_Table) {
		return .Invalid_Font_Format
	}

	raw_offset_table := (cast(^Offset_Table)&font._data[0])

	font._offsets.sfnt_version = be_to_host_u32(raw_offset_table.sfnt_version)
	font._offsets.num_tables = be_to_host_u16(raw_offset_table.num_tables)
	font._offsets.search_range = be_to_host_u16(raw_offset_table.search_range)
	font._offsets.entry_selector = be_to_host_u16(raw_offset_table.entry_selector)
	font._offsets.range_shift = be_to_host_u16(raw_offset_table.range_shift)

	// Validate sfnt version
	if font._offsets.sfnt_version != 0x00010000 &&
	   font._offsets.sfnt_version != 0x4F54544F  /* "OTTO" */{
		return .Invalid_Font_Format
	}

	return .None
}

// Parse the font's table directory
parse_table_directory :: proc(font: ^Font) -> Font_Error {
	offset := size_of(Offset_Table)

	table_records_size := int(font._offsets.num_tables) * size_of(Table_Record)
	if len(font._data) < offset + table_records_size {
		return .Invalid_Font_Format
	}

	font._tables = make([]Table_Record, font._offsets.num_tables)
	for i := 0; i < int(font._offsets.num_tables); i += 1 {
		table_offset := offset + i * size_of(Table_Record)
		raw_record := (cast(^Table_Record)&font._data[table_offset])^

		font._tables[i].tag = raw_record.tag
		font._tables[i].checksum = be_to_host_u32(raw_record.checksum)
		font._tables[i].offset = be_to_host_u32(raw_record.offset)
		font._tables[i].length = be_to_host_u32(raw_record.length)
	}

	return .None
}

extract_table_tags :: proc(font: ^Font) {
	font.table_tags = make([dynamic]Table_Tag, 0, len(font._tables))
	for &table in font._tables {
		append(&font.table_tags, cast(Table_Tag)tag_to_str(&table.tag))
	}
	// Sort tags alphabetically
	slice.sort(font.table_tags[:])
}
// Extract the slice of that table from `_tables`
get_table_data :: proc(font: ^Font, tag: Table_Tag) -> ([]byte, bool) {
	tbl_srch: for &table in font._tables {
		table_tag := cast(Table_Tag)tag_to_str(&table.tag)
		if table_tag == tag {
			start := int(table.offset)
			end := start + int(table.length)

			if start < len(font._data) && end <= len(font._data) {
				return font._data[start:end], true
			}
			break tbl_srch
		}
	}
	return nil, false
}

extract_basic_metadata :: proc(font: ^Font) -> Font_Error {
	// Get units per em from 'head' table
	head_data, h_ok := get_table_data(font, "head")
	if !h_ok || len(head_data) < 18 {
		return .Missing_Required_Table // head table is required
	}

	em_offset := transmute(^u16)&head_data[18]
	font.units_per_em = be_to_host_u16(em_offset^)

	// A valid font must have non-zero units_per_em
	if font.units_per_em == 0 {return .Invalid_Font_Format}

	// Get num glyphs from 'maxp' table
	maxp_data, m_ok := get_table_data(font, "maxp")
	if !m_ok || len(maxp_data) < 6 {return .Missing_Required_Table} 	// maxp table is required 

	ng_offset := transmute(^u16)&maxp_data[4]
	font.num_glyphs = be_to_host_u16(ng_offset^)

	if font.num_glyphs == 0 {return .Invalid_Font_Format} 	// A valid font must have at least one glyph

	return .None
}
tag_to_str :: proc(tag: ^[4]u8) -> string {
	p: [^]u8 = &tag[0]
	table_tag := string(p[:4])

	// Handle potential null bytes in the tag
	clean_len := 4
	for i := 0; i < 4; i += 1 {
		if tag[i] == 0 {
			clean_len = i
			break
		}
	}
	return string(p[:clean_len])
}

detect_features :: proc(font: ^Font) -> Font_Error {
	for tag in font.table_tags {
		tag_str := string(tag)

		switch tag_str {
		case "glyf":
			font.features += {.TRUETYPE_OUTLINES}
		case "CFF ", "CFF2":
			font.features += {.CFF_OUTLINES}
		case "GSUB":
			font.features += {.LIGATURES} // Assume ligatures if GSUB exists
		// Could be refined later by actually checking feature list
		case "GPOS":
			font.features += {.KERNING, .MARK_POSITIONING}
		case "kern":
			font.features += {.KERNING}
		case "fvar":
			font.features += {.VARIABLE_FONT}
		case "COLR":
			if has_table(font, "CPAL") {
				font.features += {.COLOR_GLYPHS}
			}
		case "SVG ":
			font.features += {.SVG_GLYPHS}
		case "EBDT", "CBDT":
			font.features += {.BITMAP_GLYPHS}
		case "vhea", "vmtx":
			font.features += {.VERTICAL_METRICS}
		case "MATH":
			font.features += {.MATHEMATICAL}
		case "Silf", "Glat", "Gloc", "Feat":
			font.features += {.GRAPHITE}
		case "morx", "kerx", "feat":
			font.features += {.AAT}
		case "fpgm", "prep", "cvt ":
			font.features += {.HINTING}
		}
	}

	// Some features need multiple tables - check for additional combinations
	if .COLOR_GLYPHS not_in font.features {
		// Check for other color glyph formats that need multiple tables
		has_cbdt := has_table(font, "CBDT")
		has_cblc := has_table(font, "CBLC")
		if has_cbdt && has_cblc {
			font.features += {.COLOR_GLYPHS, .BITMAP_GLYPHS}
		}
	}

	return .None
}

has_table :: proc(font: ^Font, tag: Table_Tag) -> bool {
	_, found := slice.binary_search(font.table_tags[:], tag)
	return found
}
