package ttf


Glyph :: distinct u16
Table_Tag :: distinct string // [4]u8 into string

Font :: struct {
	// Public
	filepath:     string,
	units_per_em: u16,
	num_glyphs:   u16,
	features:     Font_Features,
	table_tags:   [dynamic]Table_Tag,

	// Internal Use Only
	_data:        []byte,
	_tables:      []Table_Record,
	_offsets:     Offset_Table,
	_cache:       map[Table_Tag]Table_Entry,
}

Table_Entry :: struct {
	data:    rawptr,
	destroy: proc(ref: rawptr),
}

Font_Error :: enum {
	None,
	File_Not_Found,
	Table_Not_Found,
	Invalid_Font_Format,
	Invalid_Table_Format,
	Missing_Required_Table,
	Invalid_Table_Offset,
}

Font_Feature :: enum {
	// Core features
	TRUETYPE_OUTLINES, // Has 'glyf' table
	CFF_OUTLINES, // Has 'CFF' or 'CFF2' table
	BITMAP_GLYPHS, // Has 'EBDT'/'EBLC' or 'CBDT'/'CBLC'
	SVG_GLYPHS, // Has 'SVG' table
	COLOR_GLYPHS, // Has 'COLR'/'CPAL'

	// Typography features 
	KERNING, // Has 'kern' or 'GPOS' with kerning
	LIGATURES, // Has 'GSUB' with ligature features
	MARK_POSITIONING, // Has 'GPOS' with mark positioning
	VERTICAL_METRICS, // Has 'vhea'/'vmtx'

	// Variable fonts
	VARIABLE_FONT, // Has 'fvar'

	// Other common features
	HINTING, // Has hinting tables ('fpgm', 'prep', 'cvt')
	MATHEMATICAL, // Has 'MATH' table
	GRAPHITE, // Has SIL Graphite tables
	AAT, // Has Apple Advanced Typography tables
}

Font_Features :: bit_set[Font_Feature]

Offset_Table :: struct {
	sfnt_version:   u32, // 0x00010000 for TTF, "OTTO" for OTF
	num_tables:     u16, // Number of tables
	search_range:   u16, // (Maximum power of 2 <= numTables) * 16
	entry_selector: u16, // Log2(maximum power of 2 <= numTables)
	range_shift:    u16, // NumTables * 16 - searchRange
}

Table_Record :: struct {
	tag:      [4]u8,
	checksum: u32,
	offset:   u32, // from beginning of font file
	length:   u32,
}

Bounding_Box :: struct {
	min: [2]i16,
	max: [2]i16,
}


Destroy_Table :: #type proc(data: rawptr)

register_table :: proc(
	font: ^Font,
	tag: Table_Tag,
	data: rawptr,
	destroy_proc: Destroy_Table,
	replace_existing := false,
) -> (
	success: bool,
) {
	existing, exists := font._cache[tag]

	if exists {
		if !replace_existing {return false} 	// Table already exists and we're not replacing
		// Clean up existing table before replacing
		if existing.destroy != nil {
			existing.destroy(existing.data)
		}
	}

	// Register new table
	font._cache[tag] = Table_Entry {
		data    = data,
		destroy = destroy_proc,
	}

	return true
}


//////////////////////////////////////////////////////////////////////////////////////////////////////
