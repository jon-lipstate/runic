package ttf


// https://learn.microsoft.com/en-us/typography/opentype/spec/gdef
// GDEF — Glyph Definition Table
// This table defines four classifications for glyphs in a font:
// - Base glyph
// - Ligature glyph
// - Mark glyph
// - Component glyph
/*
GDEF Table Organization:
GDEF Header
├── GlyphClassDef (offset)
├── AttachmentPointList (offset)
├── LigatureCaretList (offset)
├── MarkAttachClassDef (offset)
├── MarkGlyphSetsDef (offset) - Version 1.2
└── ItemVarStore (offset) - Version 1.3
*/

GDEF_Table :: struct {
	header:              ^OpenType_GDEF_Header,
	glyph_class_def:     ^OpenType_Class_Definition_Table,
	attachment_list:     ^OpenType_Attachment_List_Table,
	ligature_caret_list: ^OpenType_Ligature_Caret_List,
	mark_attach_class:   ^OpenType_Class_Definition_Table,
	mark_glyph_sets:     ^OpenType_Mark_Glyph_Sets_Def,
	item_var_store:      ^OpenType_Item_Var_Store,
	raw_data:            []byte,
}

OpenType_GDEF_Header :: struct #packed {
	version:                      GDEF_Version,
	glyph_class_def_offset:       Offset16, // Offset to Class Definition table
	attachment_list_offset:       Offset16, // Offset to Attachment Point List table
	ligature_caret_list_offset:   Offset16, // Offset to Ligature Caret List table
	mark_attach_class_def_offset: Offset16, // Offset to Mark Attachment Class Def table

	// Version 1.2
	mark_glyph_sets_def_offset:   Offset16, // Offset to Mark Glyph Sets table

	// Version 1.3
	item_var_store_offset:        Offset32, // Offset to Item Variation Store
}

GDEF_Version :: enum u32be {
	Version_1_0 = 0x00010000,
	Version_1_2 = 0x00010002,
	Version_1_3 = 0x00010003,
}

Glyph_Class :: enum u16be {
	Base      = 1,
	Ligature  = 2,
	Mark      = 3,
	Component = 4,
}

// Class Definition Table - same format used in other tables
OpenType_Class_Definition_Table :: struct #packed {
	format: Class_Def_Format,
	data:   struct #raw_union {
		fmt1: OpenType_Class_Definition_Format1,
		fmt2: OpenType_Class_Definition_Format2,
	},
}

// Class Definition Format 1 (range of sequential glyph IDs)
OpenType_Class_Definition_Format1 :: struct #packed {
	start_glyph_id: Raw_Glyph, // First glyph ID in the range
	glyph_count:    u16be, // Number of glyphs in the range
	class_values:   [^]u16be, // [glyph_count] Class values array
}

// Class Definition Format 2 (ranges of glyph IDs)
OpenType_Class_Definition_Format2 :: struct #packed {
	class_range_count: u16be, // Number of ClassRangeRecords
	class_ranges:      [^]OpenType_Class_Range_Record, // [class_range_count] ClassRangeRecords
}

// Class Range Record
OpenType_Class_Range_Record :: struct #packed {
	start_glyph_id: Raw_Glyph, // First glyph ID in the range
	end_glyph_id:   Raw_Glyph, // Last glyph ID in the range
	class:          u16be, // Class value for the range
}

// Attachment List Table
OpenType_Attachment_List_Table :: struct #packed {
	coverage_offset:          Offset16, // Offset to Coverage table
	glyph_count:              u16be, // Number of glyphs with attachment points
	attachment_point_offsets: [^]Offset16, // [glyph_count] offsets to AttachmentPoint arrays
}

// Attachment Point table
OpenType_Attachment_Point :: struct #packed {
	point_count:   u16be, // Number of attachment points
	point_indices: [^]u16be, // [point_count] attachment point indices
}

// Ligature Caret List table
OpenType_Ligature_Caret_List :: struct #packed {
	coverage_offset:        Offset16, // Offset to Coverage table for ligature glyphs
	ligature_glyph_count:   u16be, // Number of ligature glyphs
	ligature_glyph_offsets: [^]Offset16, // [ligature_glyph_count] offsets to LigatureGlyph tables
}

// Ligature Glyph table
OpenType_Ligature_Glyph :: struct #packed {
	caret_count:   u16be, // Number of caret values
	caret_offsets: [^]Offset16, // [caret_count] offsets to CaretValue tables
}

// Caret Value Format enumeration
Caret_Value_Format :: enum u16be {
	Format_1 = 1, // Designed for non-variable fonts
	Format_2 = 2, // Designed for non-variable fonts
	Format_3 = 3, // Designed for variable fonts
}

// Caret Value format 1 (X Coordinate)
// Caret Value Table
OpenType_Caret_Value :: struct #packed {
	format: Caret_Value_Format,
	value:  struct #raw_union {
		fmt1: OpenType_Caret_Value_Format1_Data,
		fmt2: OpenType_Caret_Value_Format2_Data,
		fmt3: OpenType_Caret_Value_Format3_Data,
	},
}

// Format 1 data (X Coordinate)
OpenType_Caret_Value_Format1_Data :: struct #packed {
	coordinate: i16be, // X coordinate of caret position
}

// Format 2 data (Point Index)
OpenType_Caret_Value_Format2_Data :: struct #packed {
	caret_value_point_index: u16be, // Index of contour point that defines the caret position
}

// Format 3 data (Device Table)
OpenType_Caret_Value_Format3_Data :: struct #packed {
	coordinate:    i16be, // X coordinate of caret position
	device_offset: Offset16, // Offset to Device table for X coordinate
}

// Mark Glyph Sets Definition Table (Version 1.2+)
OpenType_Mark_Glyph_Sets_Def :: struct #packed {
	format:           u16be, // Format identifier (= 1)
	mark_set_count:   u16be, // Number of mark sets defined
	coverage_offsets: [^]Offset32, // [mark_set_count] offsets to Coverage tables
}

// Item Variation Store (Version 1.3+)
// This references the same structure used in GPOS/GSUB for variable fonts
OpenType_Item_Var_Store :: struct #packed {
	format:                       u16be, // Format = 1
	// Format 1 Fields: (the only format)
	variation_region_list_offset: Offset32, // Offset to variation region list
	item_variation_data_count:    u16be, // Number of item variation data subtables
	item_variation_data_offsets:  [^]Offset32, // [item_variation_data_count] offsets
}

// Variation Region List
OpenType_Variation_Region_List :: struct #packed {
	axis_count:        u16be, // Number of axes
	region_count:      u16be, // Number of variation regions
	variation_regions: [^]OpenType_Variation_Region, // [region_count] variation regions
}

// Variation Region
OpenType_Variation_Region :: struct #packed {
	region_axes: [^]OpenType_Region_Axis_Coordinates, // [axis_count] axis coordinates for this region
}

// Region Axis Coordinates
OpenType_Region_Axis_Coordinates :: struct #packed {
	start_coord: F2DOT14, // Region start coordinate
	peak_coord:  F2DOT14, // Region peak coordinate
	end_coord:   F2DOT14, // Region end coordinate
}

// Item Variation Data
OpenType_Item_Variation_Data :: struct #packed {
	item_count:         u16be, // Number of items in this subtable
	word_delta_count:   u16be, // Number of word-sized deltas
	region_index_count: u16be, // Number of regions referenced
	region_indices:     [^]u16be, // [region_index_count] indices into the variation region list
	delta_sets:         rawptr, // Delta set data
}

load_gdef_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	gdef_data, ok := get_table_data(font, .GDEF)
	if !ok {
		return {}, .Table_Not_Found
	}

	// Check minimum size for header
	if len(gdef_data) < size_of(OpenType_GDEF_Header) {
		return {}, .Invalid_Table_Format
	}

	// Allocate the table structure
	gdef := new(GDEF_Table)
	gdef.raw_data = gdef_data
	gdef.header = cast(^OpenType_GDEF_Header)&gdef_data[0]

	// Get version to determine which offsets to process
	version := gdef.header.version

	// Process Glyph Class Definition table
	if gdef.header.glyph_class_def_offset > 0 {
		gdef_offset := uint(gdef.header.glyph_class_def_offset)
		if bounds_check(gdef_offset + 2 > uint(len(gdef_data))) {
			free(gdef)
			return {}, .Invalid_Table_Offset
		}
		gdef.glyph_class_def = cast(^OpenType_Class_Definition_Table)&gdef_data[gdef_offset]
	}

	// Process Attachment Point List
	if gdef.header.attachment_list_offset > 0 {
		attach_offset := uint(gdef.header.attachment_list_offset)
		if bounds_check(attach_offset + 4 > uint(len(gdef_data))) {
			free(gdef)
			return {}, .Invalid_Table_Offset
		}
		gdef.attachment_list = cast(^OpenType_Attachment_List_Table)&gdef_data[attach_offset]
	}

	// Process Ligature Caret List
	if gdef.header.ligature_caret_list_offset > 0 {
		lig_offset := uint(gdef.header.ligature_caret_list_offset)
		if bounds_check(lig_offset + 4 > uint(len(gdef_data))) {
			free(gdef)
			return {}, .Invalid_Table_Offset
		}
		gdef.ligature_caret_list = cast(^OpenType_Ligature_Caret_List)&gdef_data[lig_offset]
	}

	// Process Mark Attachment Class Definition table
	if gdef.header.mark_attach_class_def_offset > 0 {
		mark_offset := uint(gdef.header.mark_attach_class_def_offset)
		if bounds_check(mark_offset + 2 > uint(len(gdef_data))) {
			free(gdef)
			return {}, .Invalid_Table_Offset
		}
		gdef.mark_attach_class = cast(^OpenType_Class_Definition_Table)&gdef_data[mark_offset]
	}

	// Process Mark Glyph Sets table (version 1.2+)
	if (version == .Version_1_2 || version == .Version_1_3) &&
	   gdef.header.mark_glyph_sets_def_offset > 0 {
		mark_sets_offset := uint(gdef.header.mark_glyph_sets_def_offset)
		if bounds_check(mark_sets_offset + 4 > uint(len(gdef_data))) {
			free(gdef)
			return {}, .Invalid_Table_Offset
		}
		gdef.mark_glyph_sets = cast(^OpenType_Mark_Glyph_Sets_Def)&gdef_data[mark_sets_offset]
	}

	// Process Item Variation Store (version 1.3 only)
	if version == .Version_1_3 && gdef.header.item_var_store_offset > 0 {
		var_store_offset := uint(gdef.header.item_var_store_offset)
		if bounds_check(var_store_offset + 2 > uint(len(gdef_data))) {
			free(gdef)
			return {}, .Invalid_Table_Offset
		}
		gdef.item_var_store = cast(^OpenType_Item_Var_Store)&gdef_data[var_store_offset]
	}

	return Table_Entry{data = gdef, destroy = destroy_gdef_table}, .None
}

destroy_gdef_table :: proc(tbl: rawptr) {
	if tbl == nil {return}
	gdef := cast(^GDEF_Table)tbl
	free(gdef)
}
