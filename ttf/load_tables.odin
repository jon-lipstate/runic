package ttf


// These would be internal functions called by the API when needed
// load_head_table :: proc(font: ^Font) -> (^HEAD_Table, Font_Error)
// load_hhea_table :: proc(font: ^Font) -> (^HHEA_Table, Font_Error)
// load_hmtx_table :: proc(font: ^Font) -> (^HMTX_Table, Font_Error)
// load_glyf_table :: proc(font: ^Font) -> (^GLYF_Table, Font_Error)
// load_loca_table :: proc(font: ^Font) -> (^LOCA_Table, Font_Error)
// load_name_table :: proc(font: ^Font) -> (^NAME_Table, Font_Error)
// load_os2_table :: proc(font: ^Font) -> (^OS2_Table, Font_Error)
// load_post_table :: proc(font: ^Font) -> (^POST_Table, Font_Error)
// load_gsub_table :: proc(font: ^Font) -> (^GSUB_Table, Font_Error)
// load_gpos_table :: proc(font: ^Font) -> (^GPOS_Table, Font_Error)

get_table :: proc(
	font: ^Font,
	tag: Table_Tag,
	loader: proc(f: ^Font) -> (Table_Entry, Font_Error),
	$T: typeid,
) -> (
	^T,
	bool,
) {
	if entry, exists := font._cache[tag]; exists {return transmute(^T)entry.data, true}
	entry, err := loader(font)
	if err != nil {return nil, false}
	ok := register_table(font, tag, entry.data, entry.destroy)
	return transmute(^T)entry.data, ok
}
