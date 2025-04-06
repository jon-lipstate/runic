package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/gsub
// GSUB Hierchical Organization:
// Scripts → Language Systems → Features → Lookups → Subtables
/*
Logical organization of the table; data locations are all offset based
GSUB Table
├── Header
├── ScriptList
│   └── []ScriptRecords
│       ├── ScriptTag
│       └── []Scripts
│           └── []LangSysRecords
│               ├── LangSysTag
│               ├── RequiredFeatureIndex
│               └── []FeatureIndex
├── FeatureList
│   └── []FeatureRecord
│       ├── FeatureTag
│       └── Feature
│           └── []LookupListIndex
└── LookupList
    └── []Lookup
        ├── LookupType
        ├── LookupFlag
		└── Subtables (format depends on lookupType)
			├── Single Substitution (type 1)
			├── Multiple Substitution (type 2)
			├── Alternate Substitution (type 3)
			├── Ligature Substitution (type 4)
			├── Contextual Substitution (type 5)
			├── Chained Contextual Substitution (type 6)
			├── Extension Substitution (type 7)
			└── Reverse Chained Contextual Single Substitution (type 8)
*/
GSUB_Table :: struct {
	raw_data:           []u8,
	header:             ^OpenType_GSUB_Header,
	script_list:        ^OpenType_Script_List,
	feature_list:       ^OpenType_Feature_List,
	lookup_list:        ^OpenType_Lookup_List,
	feature_variations: ^OpenType_Feature_Variations,
}
OpenType_GSUB_Header :: struct #packed {
	version:                   GSUB_Version, // 0x00010000 for version 1.0, 0x00010001 for version 1.1
	script_list_offset:        Offset16, // From beginning of GSUB table
	feature_list_offset:       Offset16, // From beginning of GSUB table
	lookup_list_offset:        Offset16, // From beginning of GSUB table
	feature_variations_offset: Offset32, // Offset to FeatureVariations table (version 1.1 only)
}

GSUB_Version :: enum u32be {
	Version_1_0 = 0x00010000,
	Version_1_1 = 0x00010001,
}

OpenType_Script_List :: struct #packed {
	script_count:   u16be,
	script_records: [^]OpenType_Script_Record, // [script_count] ScriptRecords
}

OpenType_Script_Record :: struct #packed {
	script_tag:    [4]byte,
	script_offset: Offset16, // From beginning of ScriptList
}

OpenType_Script :: struct #packed {
	default_lang_sys_offset: Offset16, // From beginning of Script table (0 if none)
	lang_sys_count:          u16be,
	lang_sys_records:        [^]OpenType_LangSys_Record, // [lang_sys_count] LangSysRecords
}

OpenType_LangSys_Record :: struct #packed {
	lang_sys_tag:    [4]byte,
	lang_sys_offset: Offset16, // From beginning of Script table
}

OpenType_LangSys :: struct #packed {
	lookup_order_offset:    Offset16, // = NULL (reserved for offset to reordering table)
	required_feature_index: u16be, // Index of required feature (0xFFFF = none)
	feature_index_count:    u16be,
	feature_indices:        [^]u16be, // [feature_index_count] feature indices
}

OpenType_Feature_List :: struct #packed {
	feature_count:   u16be,
	feature_records: [^]OpenType_Feature_Record, // [feature_count] FeatureRecords
}

OpenType_Feature_Record :: struct #packed {
	feature_tag:    [4]byte,
	feature_offset: Offset16, // From beginning of FeatureList
}

// Feature Table
OpenType_Feature :: struct #packed {
	feature_params_offset: Offset16, // Offset to FeatureParams table (0 if none)
	lookup_index_count:    u16be,
	lookup_list_indices:   [^]u16be, // Points into the LookupList
}

// Lookup List Table
OpenType_Lookup_List :: struct #packed {
	lookup_count:   u16be,
	lookup_offsets: [^]Offset16, // From beginning of LookupList
}

// Lookup Table
OpenType_Lookup_GSUB :: struct #packed {
	lookup_type:        GSUB_Lookup_Type,
	lookup_flag:        Lookup_Flags,
	subtable_count:     u16be,
	subtable_offsets:   [^]Offset16, // From beginning of Lookup table
	mark_filtering_set: u16be, // Index of mark filtering set (only present if USE_MARK_FILTERING_SET bit set)
}

GSUB_Lookup_Type :: enum u16be {
	Single         = 1, // Single substitution
	Multiple       = 2, // Multiple substitution
	Alternate      = 3, // Alternate substitution
	Ligature       = 4, // Ligature substitution
	Context        = 5, // Contextual substitution
	ChainedContext = 6, // Chained contextual substitution
	Extension      = 7, // Extension substitution
	ReverseChained = 8, // Reverse chained contextual single substitution
}


Lookup_Flag :: enum u8 {
	RIGHT_TO_LEFT,
	IGNORE_BASE_GLYPHS,
	IGNORE_LIGATURES,
	IGNORE_MARKS,
	USE_MARK_FILTERING_SET,
}
Lookup_Flag_Set :: bit_set[Lookup_Flag;u8]

Lookup_Flags :: struct {
	flags:                  Lookup_Flag_Set,
	mark_attachment_filter: u8,
	// RIGHT_TO_LEFT,                bool | 1, // bit 0
	// IGNORE_BASE_GLYPHS:           bool | 1, // bit 1
	// IGNORE_LIGATURES:             bool | 1, // bit 2
	// IGNORE_MARKS:                 bool | 1, // bit 3
	// USE_MARK_FILTERING_SET:       bool | 1, // bit 4
	// reserved:                     u8   | 3, // bits 5-7
	// MARK_ATTACHMENT_CLASS_FILTER: u8   | 8, // bits 8-15
}

OpenType_Coverage :: struct #packed {
	format: Coverage_Format, // Format identifier
	count:  u16be, // Count (interpretation depends on format)
	// Format 1: count = glyph_count, data = array of GlyphIDs
	// Format 2: count = range_count, data = array of RangeRecords
	data:   [^]byte, // Format-specific data follows
}

Coverage_Format :: enum USHORT {
	List   = 1, // List of individual glyph IDs
	Ranges = 2, // Ranges of glyph IDs
}

OpenType_Coverage_Format_1 :: struct #packed {
	format:      u16be, // = 1
	glyph_count: u16be,
	glyph_array: [^]Raw_Glyph, // [glyph_count] GlyphIDs in numerical order
}

OpenType_Range_Record :: struct #packed {
	start_glyph_id:       Raw_Glyph,
	end_glyph_id:         Raw_Glyph,
	start_coverage_index: u16be,
}

OpenType_Coverage_Format_2 :: struct #packed {
	format:        u16be, // = 2
	range_count:   u16be,
	range_records: [^]OpenType_Range_Record, // sorted by start_glyph_id
}

// GSUB Subtable formats
// 1. Single Substitution
OpenType_Single_Subst :: struct #packed {
	format: Single_Subst_Format,
	table:  struct #raw_union {
		fmt1: OpenType_Single_Subst_Format_1,
		fmt2: OpenType_Single_Subst_Format_2,
	},
}
Single_Subst_Format :: enum u16be {
	Format_1 = 1, // Delta-based substitution
	Format_2 = 2, // Array-based substitution
}
OpenType_Single_Subst_Format_1 :: struct #packed {
	coverage_offset: Offset16, // From beginning of substitution table
	delta_glyph_id:  SHORT, // Add to original GlyphID to get substitute GlyphID
}

OpenType_Single_Subst_Format_2 :: struct #packed {
	coverage_offset:   Offset16, // From beginning of substitution table
	glyph_count:       USHORT,
	substitute_glyphs: [^]Raw_Glyph, // [glyph_count] substitute glyphs
}

// Multiple Substitution - Format 1
OpenType_Multiple_Subst :: struct #packed {
	format:           u16be, // Only format 1 is defined
	coverage_offset:  Offset16, // From beginning of substitution table
	sequence_count:   u16be,
	sequence_offsets: [^]Offset16, // From beginning of substitution table
}

// Sequence table for Multiple Substitution
OpenType_Sequence :: struct #packed {
	glyph_count:       u16be,
	substitute_glyphs: [^]Raw_Glyph,
}

// 3. Alternate Substitution
OpenType_Alternate_Subst :: struct #packed {
	format:                USHORT, // Only format 1 is defined
	coverage_offset:       Offset16, // From beginning of substitution table
	alternate_set_count:   USHORT,
	alternate_set_offsets: [^]Offset16, // From beginning of substitution table
}
// AlternateSet table
OpenType_Alternate_Set :: struct #packed {
	glyph_count:      USHORT,
	alternate_glyphs: [^]Raw_Glyph, // [glyph_count] alternate glyphs
}

// 4. Ligature Substitution
OpenType_Ligature_Subst :: struct #packed {
	format:               u16be, // Only format 1 is defined
	coverage_offset:      Offset16, // From beginning of substitution table
	ligature_set_count:   u16be,
	ligature_set_offsets: [^]Offset16, // From beginning of substitution table
}

// LigatureSet table for Ligature Substitution
OpenType_Ligature_Set :: struct #packed {
	ligature_count:   u16be,
	ligature_offsets: [^]Offset16, // From beginning of LigatureSet table
}

// Ligature table for Ligature Substitution
OpenType_Ligature :: struct #packed {
	ligature_glyph:   Raw_Glyph,
	component_count:  u16be, // includes first component
	component_glyphs: [^]Raw_Glyph, // [component_count - 1] GlyphIDs for components after the first
}

// 5. Contextual Substitution (already defined)
OpenType_Context_Subst :: struct #packed {
	format: Context_Format,
	table:  struct #raw_union {
		fmt1: OpenType_Context_Subst_Format_1,
		fmt2: OpenType_Context_Subst_Format_2,
		fmt3: OpenType_Context_Subst_Format_3,
	},
}

OpenType_Context_Subst_Format_1 :: struct #packed {
	coverage_offset:  Offset16, // From beginning of substitution table
	rule_set_count:   u16be,
	rule_set_offsets: [^]Offset16, // From beginning of substitution table
}

OpenType_Context_Subst_Format_2 :: struct #packed {
	coverage_offset:   Offset16, // From beginning of substitution table
	class_def_offset:  Offset16, // From beginning of substitution table
	class_set_count:   u16be,
	class_set_offsets: [^]Offset16, // From beginning of substitution table
}

OpenType_Context_Subst_Format_3 :: struct #packed {
	glyph_count:        u16be,
	substitute_count:   u16be,
	coverage_offsets:   [^]Offset16, // [glyph_count] offsets from beginning of substitution table
	substitute_records: [^]OpenType_Substitute_Record,
}

// Context Rule Set table (for Format 1)
OpenType_Context_Rule_Set :: struct #packed {
	rule_count:   USHORT,
	rule_offsets: [^]Offset16, // From beginning of RuleSet table
}
// Context Rule table (for Format 1)
OpenType_Context_Rule :: struct #packed {
	glyph_count:        USHORT, // Includes first glyph
	substitute_count:   USHORT,
	input_sequence:     [^]Raw_Glyph, // [glyph_count - 1] input glyph IDs
	substitute_records: [^]OpenType_Substitute_Record,
}
// Class Rule Set table (for Format 2)
OpenType_Class_Rule_Set :: struct #packed {
	class_rule_count:   USHORT,
	class_rule_offsets: [^]Offset16, // From beginning of ClassRuleSet table
}

// Class Rule table (for Format 2)
OpenType_Class_Rule :: struct #packed {
	glyph_count:        USHORT, // Total number of glyphs in input sequence
	substitute_count:   USHORT,
	input_sequence:     [^]USHORT, // [glyph_count - 1] input class values
	substitute_records: [^]OpenType_Substitute_Record,
}

// 6. Chained Contextual Substitution
OpenType_Chained_Context_Subst :: struct #packed {
	format: Context_Format,
	table:  struct #raw_union {
		fmt1: OpenType_Chained_Context_Subst_Format_1,
		fmt2: OpenType_Chained_Context_Subst_Format_2,
		fmt3: OpenType_Chained_Context_Subst_Format_3,
	},
}

OpenType_Chained_Context_Subst_Format_1 :: struct #packed {
	coverage_offset:        Offset16, // From beginning of substitution table
	chain_rule_set_count:   USHORT,
	chain_rule_set_offsets: [^]Offset16, // From beginning of substitution table
}

OpenType_Chained_Context_Subst_Format_2 :: struct #packed {
	coverage_offset:            Offset16, // From beginning of substitution table
	backtrack_class_def_offset: Offset16,
	input_class_def_offset:     Offset16,
	lookahead_class_def_offset: Offset16,
	chain_class_set_count:      USHORT,
	chain_class_set_offsets:    [^]Offset16, // From beginning of substitution table
}

OpenType_Chained_Context_Subst_Format_3 :: struct #packed {
	backtrack_glyph_count:      USHORT,
	backtrack_coverage_offsets: [^]Offset16, // From beginning of substitution table
	input_glyph_count:          USHORT,
	input_coverage_offsets:     [^]Offset16, // From beginning of substitution table
	lookahead_glyph_count:      USHORT,
	lookahead_coverage_offsets: [^]Offset16, // From beginning of substitution table
	substitute_count:           USHORT,
	substitute_records:         [^]OpenType_Substitute_Record,
}

// Chain Rule Set table (for Format 1)
OpenType_Chain_Rule_Set :: struct #packed {
	chain_rule_count:   USHORT,
	chain_rule_offsets: [^]Offset16, // From beginning of ChainRuleSet table
}

// Chain Rule table (for Format 1)
OpenType_Chain_Rule :: struct #packed {
	backtrack_glyph_count: USHORT,
	backtrack_sequence:    [^]Raw_Glyph,
	input_glyph_count:     USHORT,
	input_sequence:        [^]Raw_Glyph, // [input_glyph_count - 1]
	lookahead_glyph_count: USHORT,
	lookahead_sequence:    [^]Raw_Glyph,
	substitute_count:      USHORT,
	substitute_records:    [^]OpenType_Substitute_Record,
}

// Chain Class Set table (for Format 2)
OpenType_Chain_Class_Set :: struct #packed {
	chain_class_rule_count:   USHORT,
	chain_class_rule_offsets: [^]Offset16, // From beginning of ChainClassSet table
}

// Chain Class Rule table (for Format 2)
OpenType_Chain_Class_Rule :: struct #packed {
	backtrack_glyph_count: USHORT,
	backtrack_sequence:    [^]USHORT, // backtrack class values
	input_glyph_count:     USHORT,
	input_sequence:        [^]USHORT, // [input_glyph_count - 1] input class values
	lookahead_glyph_count: USHORT,
	lookahead_sequence:    [^]USHORT, // lookahead class values
	substitute_count:      USHORT,
	substitute_records:    [^]OpenType_Substitute_Record,
}

// 7. Extension Substitution
OpenType_Extension_Subst :: struct #packed {
	format:                USHORT, // Always 1
	extension_lookup_type: GSUB_Lookup_Type,
	extension_offset:      Offset32, // From beginning of extension subtable to actual subtable
}

// 8. Reverse Chained Contextual Single Substitution
OpenType_Reverse_Chained_Subst :: struct #packed {
	format:                     USHORT, // Always 1
	coverage_offset:            Offset16, // From beginning of substitution table
	backtrack_glyph_count:      USHORT,
	backtrack_coverage_offsets: [^]Offset16, // [backtrack_glyph_count] offsets from beginning of substitution table
	lookahead_glyph_count:      USHORT,
	lookahead_coverage_offsets: [^]Offset16, // [lookahead_glyph_count] offsets from beginning of substitution table
	substitute_glyph_count:     USHORT,
	substitute_glyphs:          [^]Raw_Glyph, // [substitute_glyph_count] substitute glyph IDs
}

// Common structure used by contextual substitutions
OpenType_Substitute_Record :: struct #packed {
	sequence_index:    USHORT, // Index into input sequence where substitution occurs
	lookup_list_index: USHORT, // Index into LookupList for the substitution lookup
}

Context_Format :: enum USHORT {
	GlyphBased    = 1, // Rule sets based on first glyph
	ClassBased    = 2, // Rule sets based on glyph classes  
	CoverageBased = 3, // Rules based on glyph coverages
}

Class_Def_Format :: enum USHORT {
	RangeByGlyphID = 1,
	ClassRanges    = 2,
}

OpenType_Feature_Variations :: struct #packed {
	major_version:             u16be, // Major version (1)
	minor_version:             u16be, // Minor version (0)
	feature_variation_count:   u32be,
	feature_variation_records: [^]OpenType_Feature_Variation_Record, // [feature_variation_count]
}

OpenType_Feature_Variation_Record :: struct #packed {
	conditions_offset:                 Offset32, // From beginning of FeatureVariations table
	feature_table_substitution_offset: Offset32, // From beginning of FeatureVariations table
}

OpenType_Condition_Set :: struct #packed {
	condition_count:   u16be,
	condition_offsets: [^]Offset32, // [condition_count] from beginning of ConditionSet table
}

OpenType_Condition :: struct #packed {
	format:                 u16be, // Format identifier
	axis_index:             u16be, // Index of the axis to test
	filter_range_min_value: F2DOT14, // Minimum value of the range
	filter_range_max_value: F2DOT14, // Maximum value of the range
}

OpenType_Feature_Table_Substitution :: struct #packed {
	major_version:      u16be, // Major version (1)
	minor_version:      u16be, // Minor version (0)
	substitution_count: u16be,
	substitutions:      [^]OpenType_Feature_Table_Substitution_Record, // [substitution_count]
}

OpenType_Feature_Table_Substitution_Record :: struct #packed {
	feature_index:            u16be, // Index of the feature table to substitute
	alternate_feature_offset: Offset32, // Offset to alternate feature table
}


Mark_Attachment_Type :: distinct USHORT

load_gsub_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	gsub_data, ok := get_table_data(font, .GSUB)
	if !ok {
		return {}, .Table_Not_Found
	}

	// Check minimum size for header
	if len(gsub_data) < size_of(OpenType_GSUB_Header) {
		return {}, .Invalid_Table_Format
	}

	// Allocate the table structure
	gsub := new(GSUB_Table, font.allocator)
	gsub.raw_data = gsub_data
	gsub.header = cast(^OpenType_GSUB_Header)&gsub_data[0]

	// Validate and load script list
	script_list_offset := uint(gsub.header.script_list_offset)
	if script_list_offset >= uint(len(gsub_data)) {
		return {}, .Invalid_Table_Offset
	}
	gsub.script_list = cast(^OpenType_Script_List)&gsub_data[script_list_offset]

	// Validate and load feature list
	feature_list_offset := uint(gsub.header.feature_list_offset)
	if feature_list_offset >= uint(len(gsub_data)) {
		return {}, .Invalid_Table_Offset
	}
	gsub.feature_list = cast(^OpenType_Feature_List)&gsub_data[feature_list_offset]

	// Validate and load lookup list
	lookup_list_offset := uint(gsub.header.lookup_list_offset)
	if lookup_list_offset >= uint(len(gsub_data)) {
		return {}, .Invalid_Table_Offset
	}
	gsub.lookup_list = cast(^OpenType_Lookup_List)&gsub_data[lookup_list_offset]

	// If version is 1.1, validate feature_variations_offset
	if gsub.header.version == .Version_1_1 && gsub.header.feature_variations_offset > 0 {
		feature_variations_offset := uint(gsub.header.feature_variations_offset)
		if feature_variations_offset < uint(len(gsub_data)) {
			gsub.feature_variations =
			cast(^OpenType_Feature_Variations)&gsub_data[feature_variations_offset]
		}
	}

	return Table_Entry{data = gsub}, .None
}

