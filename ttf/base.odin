package ttf

// FIXME: this file is not reviewed or edited; fair # of makes; likely slop

// https://docs.microsoft.com/en-us/typography/opentype/spec/base
// BASE — Baseline Table
/*
The Baseline table (BASE) provides information used to align glyphs of different scripts and sizes 
in a line of text. OpenType fonts with CJK ideographic glyphs typically define a different baseline 
than Latin, Greek, and Cyrillic fonts. Without baseline adjustment, the ideographic glyphs appear 
too high when mixed with the Latin glyphs.
*/

OpenType_Base_Table :: struct {
	raw_data:        []byte, // Reference to raw data
	header:          ^OpenType_Base_Header,
	horizontal_axis: ^OpenType_Base_Axis_Table,
	vertical_axis:   ^OpenType_Base_Axis_Table,
	font:            ^Font, // Reference to parent font
}

// BASE table header
OpenType_Base_Header :: struct #packed {
	major_version:         u16be, // Major version (= 1)
	minor_version:         u16be, // Minor version (= 0 or 1)
	horizontal_offset:     Offset16, // Offset to HorizAxis table (may be NULL)
	vertical_offset:       Offset16, // Offset to VertAxis table (may be NULL)
	item_var_store_offset: Offset32, // Offset to ItemVariationStore table (= 0 if version < 1.1)
}

// BASE Axis table (used for both horizontal and vertical axes)
OpenType_Base_Axis_Table :: struct #packed {
	base_tag_list_offset:    Offset16, // Offset to BaseTagList table (may be NULL)
	base_script_list_offset: Offset16, // Offset to BaseScriptList table
}

// BaseTagList table 
OpenType_Base_Tag_List :: struct #packed {
	base_tag_count: u16be, // Number of baseline identification tags
	base_tags:      [^]Tag, // [baseTagCount] Array of 4-byte baseline identification tags
}

// BaseScriptList table
OpenType_Base_Script_List :: struct #packed {
	base_script_count:   u16be, // Number of BaseScriptRecords
	base_script_records: [^]OpenType_Base_Script_Record, // [baseScriptCount] Array of BaseScriptRecords
}

// BaseScriptRecord
OpenType_Base_Script_Record :: struct #packed {
	base_script_tag:    Tag, // 4-byte script identification tag
	base_script_offset: Offset16, // Offset to BaseScript table from beginning of BaseScriptList
}

// BaseScript table
OpenType_Base_Script :: struct #packed {
	base_values_offset:      Offset16, // Offset to BaseValues table (may be NULL)
	default_min_max_offset:  Offset16, // Offset to MinMax table (may be NULL)
	feature_min_max_count:   u16be, // Number of BaseFeatMinMaxRecords (may be 0)
	feature_min_max_records: [^]OpenType_Base_Feature_Min_Max_Record, // [featMinMaxCount] Array of MinMax records
}

// BaseFeatMinMaxRecord
OpenType_Base_Feature_Min_Max_Record :: struct #packed {
	feature_tag:    Tag, // 4-byte feature identification tag
	min_max_offset: Offset16, // Offset to MinMax table
}

// BaseValues table
OpenType_Base_Values :: struct #packed {
	default_base_tag_index: u16be, // Index of default baseline tag id
	base_coords_count:      u16be, // Number of BaseCoord tables
	base_coords:            [^]Offset16, // [baseCoordCount] Offsets to BaseCoord tables
}

// MinMax table
OpenType_Base_Min_Max :: struct #packed {
	min_coord_offset:        Offset16, // Offset to BaseCoord table for minimum extent value (may be NULL)
	max_coord_offset:        Offset16, // Offset to BaseCoord table for maximum extent value (may be NULL)
	feature_min_max_count:   u16be, // Number of BaseFeatMinMaxRecords (may be 0)
	feature_min_max_records: [^]OpenType_Base_Feature_Min_Max_Record, // [featMinMaxCount] Array of feature MinMax records
}

// BaseCoord table
OpenType_Base_Coord :: struct #packed {
	coord_format: u16be, // Format identifier
	table:        struct #raw_union {
		fmt1: OpenType_Base_Coord_Format1, // Format 1 data
		fmt2: OpenType_Base_Coord_Format2, // Format 2 data
		fmt3: OpenType_Base_Coord_Format3, // Format 3 data
	},
}

// BaseCoord Format 1 - simple coordinate value
OpenType_Base_Coord_Format1 :: struct #packed {
	coordinate: i16be, // X or Y coordinate in design units
}

// BaseCoord Format 2 - coordinate with control point
OpenType_Base_Coord_Format2 :: struct #packed {
	coordinate:       i16be, // X or Y coordinate in design units
	reference_glyph:  Raw_Glyph, // GlyphID of control point glyph
	base_coord_point: u16be, // Index of contour point on the reference glyph
}

// BaseCoord Format 3 - coordinate with Device table
OpenType_Base_Coord_Format3 :: struct #packed {
	coordinate:          i16be, // X or Y coordinate in design units
	device_table_offset: Offset16, // Offset to Device table
}

// Load the BASE table
load_base_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	base_data, ok := get_table_data(font, .BASE)
	if !ok {
		return {}, .Table_Not_Found
	}

	// Check minimum size for header
	if len(base_data) < size_of(OpenType_Base_Header) {
		return {}, .Invalid_Table_Format
	}

	// Allocate the table structure
	base := new(OpenType_Base_Table)
	base.raw_data = base_data
	base.header = cast(^OpenType_Base_Header)&base_data[0]
	base.font = font

	// Check version - we support 1.0 and 1.1
	if (base.header.major_version != 1) || (base.header.minor_version > 1) {
		free(base)
		return {}, .Invalid_Table_Format
	}

	// Load horizontal axis data if present
	if base.header.horizontal_offset > 0 {
		horiz_offset := uint(base.header.horizontal_offset)
		if horiz_offset + size_of(OpenType_Base_Axis_Table) <= uint(len(base_data)) {
			base.horizontal_axis = cast(^OpenType_Base_Axis_Table)&base_data[horiz_offset]
		}
	}

	// Load vertical axis data if present
	if base.header.vertical_offset > 0 {
		vert_offset := uint(base.header.vertical_offset)
		if vert_offset + size_of(OpenType_Base_Axis_Table) <= uint(len(base_data)) {
			base.vertical_axis = cast(^OpenType_Base_Axis_Table)&base_data[vert_offset]
		}
	}

	return Table_Entry{data = base, destroy = destroy_base_table}, .None
}

destroy_base_table :: proc(data: rawptr) {
	if data == nil {return}
	base := cast(^OpenType_Base_Table)data
	free(base)
}

// Helper to read baseline values for a specific script
get_script_baseline_values :: proc(
	base_table: ^OpenType_Base_Table,
	script_tag: string,
	is_vertical: bool,
) -> (
	baseline_tags: []Tag,
	baseline_values: []i16,
	default_baseline_index: u16,
	found: bool,
) {
	if base_table == nil {
		return nil, nil, 0, false
	}

	// Select the appropriate axis
	axis: ^OpenType_Base_Axis_Table
	if is_vertical {
		axis = base_table.vertical_axis
	} else {
		axis = base_table.horizontal_axis
	}

	if axis == nil || axis.base_script_list_offset == 0 {
		return nil, nil, 0, false
	}

	// Get the script list
	axis_offset := uint(0)
	if is_vertical {
		axis_offset = uint(base_table.header.vertical_offset)
	} else {
		axis_offset = uint(base_table.header.horizontal_offset)
	}

	script_list_offset := axis_offset + uint(axis.base_script_list_offset)
	if bounds_check(script_list_offset + 2 > uint(len(base_table.raw_data))) {
		return nil, nil, 0, false
	}

	script_count := read_u16(base_table.raw_data, script_list_offset)
	if script_count == 0 {
		return nil, nil, 0, false
	}

	// Convert script_tag to Tag
	tag_bytes: [4]byte
	for i := 0; i < min(len(script_tag), 4); i += 1 {
		tag_bytes[i] = byte(script_tag[i])
	}
	script_tag_value := tag_to_u32(tag_bytes)

	// Search for the script
	script_offset := uint(0)
	for i: uint = 0; i < uint(script_count); i += 1 {
		record_offset := script_list_offset + 2 + i * 6
		if bounds_check(record_offset + 6 > uint(len(base_table.raw_data))) {
			break
		}

		record_tag := read_u32(base_table.raw_data, record_offset)
		if record_tag == u32(script_tag_value) {
			script_offset =
				script_list_offset + uint(read_u16(base_table.raw_data, record_offset + 4))
			break
		}
	}

	if script_offset == 0 {
		return nil, nil, 0, false // Script not found
	}

	// Read BaseScript table
	if bounds_check(script_offset + 6 > uint(len(base_table.raw_data))) {
		return nil, nil, 0, false
	}

	base_values_offset := uint(read_u16(base_table.raw_data, script_offset))
	if base_values_offset == 0 {
		return nil, nil, 0, false // No baseline values for this script
	}

	// Read BaseValues table
	values_offset := script_offset + base_values_offset
	if bounds_check(values_offset + 6 > uint(len(base_table.raw_data))) {
		return nil, nil, 0, false
	}

	default_baseline_index = read_u16(base_table.raw_data, values_offset)
	coords_count := read_u16(base_table.raw_data, values_offset + 2)
	if coords_count == 0 {
		return nil, nil, 0, false
	}

	// Get baseline tags from BaseTagList if available
	baseline_tags_array: []Tag = nil
	if axis.base_tag_list_offset > 0 {
		tag_list_offset := axis_offset + uint(axis.base_tag_list_offset)
		if !bounds_check(tag_list_offset + 2 > uint(len(base_table.raw_data))) {
			tag_count := read_u16(base_table.raw_data, tag_list_offset)
			if tag_count > 0 &&
			   !bounds_check(
					   tag_list_offset + 2 + uint(tag_count) * 4 > uint(len(base_table.raw_data)),
				   ) {
				// Create slice of tags
				tags_ptr := transmute([^]Tag)&base_table.raw_data[tag_list_offset + 2]
				baseline_tags_array = tags_ptr[:tag_count]
			}
		}
	}

	// Read coordinate values
	baseline_values_array := make([]i16, coords_count)
	for i: uint = 0; i < uint(coords_count); i += 1 {
		coord_offset_pos := values_offset + 4 + i * 2
		if bounds_check(coord_offset_pos + 2 > uint(len(base_table.raw_data))) {
			delete(baseline_values_array)
			return nil, nil, 0, false
		}

		coord_offset := values_offset + uint(read_u16(base_table.raw_data, coord_offset_pos))
		if bounds_check(coord_offset + 4 > uint(len(base_table.raw_data))) {
			delete(baseline_values_array)
			return nil, nil, 0, false
		}

		coord_format := read_u16(base_table.raw_data, coord_offset)
		// All formats have the coordinate at the same position
		baseline_values_array[i] = i16(read_i16(base_table.raw_data, coord_offset + 2))
	}

	return baseline_tags_array, baseline_values_array, default_baseline_index, true
}

// Get the default baseline value for a script
get_default_baseline :: proc(
	base_table: ^OpenType_Base_Table,
	script_tag: string,
	is_vertical: bool,
) -> (
	baseline_value: i16,
	found: bool,
) {
	_, values, default_index, ok := get_script_baseline_values(base_table, script_tag, is_vertical)
	if !ok || len(values) == 0 || int(default_index) >= len(values) {
		return 0, false
	}

	return values[default_index], true
}

// Get minimum and maximum extents for a script
get_script_extents :: proc(
	base_table: ^OpenType_Base_Table,
	script_tag: string,
	is_vertical: bool,
) -> (
	min_extent: i16,
	max_extent: i16,
	found: bool,
) {
	if base_table == nil {
		return 0, 0, false
	}

	// Select the appropriate axis
	axis: ^OpenType_Base_Axis_Table
	if is_vertical {
		axis = base_table.vertical_axis
	} else {
		axis = base_table.horizontal_axis
	}

	if axis == nil || axis.base_script_list_offset == 0 {
		return 0, 0, false
	}

	// Get the script list
	axis_offset := uint(0)
	if is_vertical {
		axis_offset = uint(base_table.header.vertical_offset)
	} else {
		axis_offset = uint(base_table.header.horizontal_offset)
	}

	script_list_offset := axis_offset + uint(axis.base_script_list_offset)
	if bounds_check(script_list_offset + 2 > uint(len(base_table.raw_data))) {
		return 0, 0, false
	}

	script_count := read_u16(base_table.raw_data, script_list_offset)
	if script_count == 0 {
		return 0, 0, false
	}

	// Convert script_tag to Tag
	tag_bytes: [4]byte
	for i := 0; i < min(len(script_tag), 4); i += 1 {
		tag_bytes[i] = byte(script_tag[i])
	}
	script_tag_value := tag_to_u32(tag_bytes)

	// Search for the script
	script_offset := uint(0)
	for i: uint = 0; i < uint(script_count); i += 1 {
		record_offset := script_list_offset + 2 + i * 6
		if bounds_check(record_offset + 6 > uint(len(base_table.raw_data))) {
			break
		}

		record_tag := read_u32(base_table.raw_data, record_offset)
		if record_tag == u32(script_tag_value) {
			script_offset =
				script_list_offset + uint(read_u16(base_table.raw_data, record_offset + 4))
			break
		}
	}

	if script_offset == 0 {
		return 0, 0, false // Script not found
	}

	// Read BaseScript table
	if bounds_check(script_offset + 6 > uint(len(base_table.raw_data))) {
		return 0, 0, false
	}

	min_max_offset := uint(read_u16(base_table.raw_data, script_offset + 2))
	if min_max_offset == 0 {
		return 0, 0, false // No min/max values for this script
	}

	// Read MinMax table
	min_max_offset = script_offset + min_max_offset
	if bounds_check(min_max_offset + 4 > uint(len(base_table.raw_data))) {
		return 0, 0, false
	}

	min_coord_offset := uint(read_u16(base_table.raw_data, min_max_offset))
	max_coord_offset := uint(read_u16(base_table.raw_data, min_max_offset + 2))

	// Read min coordinate
	found_min := false
	if min_coord_offset > 0 {
		min_coord_offset = min_max_offset + min_coord_offset
		if !bounds_check(min_coord_offset + 4 > uint(len(base_table.raw_data))) {
			min_extent = i16(read_i16(base_table.raw_data, min_coord_offset + 2))
			found_min = true
		}
	}

	// Read max coordinate
	found_max := false
	if max_coord_offset > 0 {
		max_coord_offset = min_max_offset + max_coord_offset
		if !bounds_check(max_coord_offset + 4 > uint(len(base_table.raw_data))) {
			max_extent = i16(read_i16(base_table.raw_data, max_coord_offset + 2))
			found_max = true
		}
	}

	return min_extent, max_extent, found_min || found_max
}

// Get a list of all script tags supported by the BASE table
get_supported_baseline_scripts :: proc(
	base_table: ^OpenType_Base_Table,
	is_vertical: bool,
) -> (
	script_tags: []string,
	found: bool,
) {
	if base_table == nil {
		return nil, false
	}

	// Select the appropriate axis
	axis: ^OpenType_Base_Axis_Table
	if is_vertical {
		axis = base_table.vertical_axis
	} else {
		axis = base_table.horizontal_axis
	}

	if axis == nil || axis.base_script_list_offset == 0 {
		return nil, false
	}

	// Get the script list
	axis_offset := uint(0)
	if is_vertical {
		axis_offset = uint(base_table.header.vertical_offset)
	} else {
		axis_offset = uint(base_table.header.horizontal_offset)
	}

	script_list_offset := axis_offset + uint(axis.base_script_list_offset)
	if bounds_check(script_list_offset + 2 > uint(len(base_table.raw_data))) {
		return nil, false
	}

	script_count := read_u16(base_table.raw_data, script_list_offset)
	if script_count == 0 {
		return nil, false
	}

	// Read script tags
	tags := make([]string, script_count)
	for i: uint = 0; i < uint(script_count); i += 1 {
		record_offset := script_list_offset + 2 + i * 6
		if bounds_check(record_offset + 4 > uint(len(base_table.raw_data))) {
			delete(tags)
			return nil, false
		}

		// Convert tag to string
		tag := transmute(^[4]byte)&base_table.raw_data[record_offset]
		tags[i] = string(tag[:])
	}

	return tags, true
}

// Get available baseline tags for an axis
get_baseline_tags :: proc(
	base_table: ^OpenType_Base_Table,
	is_vertical: bool,
) -> (
	baseline_tags: []string,
	found: bool,
) {
	if base_table == nil {
		return nil, false
	}

	// Select the appropriate axis
	axis: ^OpenType_Base_Axis_Table
	if is_vertical {
		axis = base_table.vertical_axis
	} else {
		axis = base_table.horizontal_axis
	}

	if axis == nil || axis.base_tag_list_offset == 0 {
		return nil, false
	}

	// Get the tag list
	axis_offset := uint(0)
	if is_vertical {
		axis_offset = uint(base_table.header.vertical_offset)
	} else {
		axis_offset = uint(base_table.header.horizontal_offset)
	}

	tag_list_offset := axis_offset + uint(axis.base_tag_list_offset)
	if bounds_check(tag_list_offset + 2 > uint(len(base_table.raw_data))) {
		return nil, false
	}

	tag_count := read_u16(base_table.raw_data, tag_list_offset)
	if tag_count == 0 {
		return nil, false
	}

	// Read tags
	tags := make([]string, tag_count)
	for i: uint = 0; i < uint(tag_count); i += 1 {
		tag_offset := tag_list_offset + 2 + i * 4
		if bounds_check(tag_offset + 4 > uint(len(base_table.raw_data))) {
			delete(tags)
			return nil, false
		}

		// Convert tag to string
		tag := transmute(^[4]byte)&base_table.raw_data[tag_offset]
		tags[i] = string(tag[:])
	}

	return tags, true
}

// Check if the font has baseline information
has_baseline_table :: proc(font: ^Font) -> bool {
	return has_table(font, .BASE)
}

// // Get a specific baseline value by tag
// get_baseline_value :: proc(
// 	base_table: ^OpenType_Base_Table,
// 	script_tag: string,
// 	baseline_tag: string,
// 	is_vertical: bool,
// ) -> (
// 	value: i16,
// 	found: bool,
// ) {
// 	tags, values, _, ok := get_script_baseline_values(base_table, script_tag, is_vertical)
// 	if !ok || len(tags) == 0 || len(values) == 0 || len(tags) != len(values) {
// 		return 0, false
// 	}

// 	// Convert baseline_tag to Tag
// 	tag_bytes: [4]byte
// 	for i := 0; i < min(len(baseline_tag), 4); i += 1 {
// 		tag_bytes[i] = byte(baseline_tag[i])
// 	}
// 	baseline_tag_value := tag_to_u32(tag_bytes)

// 	// Find matching tag
// 	for i := 0; i < len(tags); i += 1 {
// 		if u32(tags[i]) == baseline_tag_value {
// 			return values[i], true
// 		}
// 	}

// 	return 0, false
// }

// Calculate baseline offset between scripts
calculate_baseline_offset :: proc(
	base_table: ^OpenType_Base_Table,
	from_script: string,
	to_script: string,
	is_vertical: bool,
) -> (
	offset: i16,
	found: bool,
) {
	// Get default baseline values for both scripts
	from_value, from_ok := get_default_baseline(base_table, from_script, is_vertical)
	to_value, to_ok := get_default_baseline(base_table, to_script, is_vertical)

	if !from_ok || !to_ok {
		return 0, false
	}

	// Calculate the difference (offset) between the baselines
	return to_value - from_value, true
}
