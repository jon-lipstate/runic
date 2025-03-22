package ttf


// GDEF Class Definition Iterator
GDEF_Class_Definition_Iterator :: struct {
	gdef:             ^GDEF_Table,
	class_def_offset: uint, // Absolute offset to class definition table
	current_index:    uint,
	count:            uint,
	format:           u16,
	start_glyph_id:   Raw_Glyph, // Only used for format 1
}

// Initialize a class definition iterator
into_gdef_class_definition_iter :: proc(
	gdef: ^GDEF_Table,
) -> (
	GDEF_Class_Definition_Iterator,
	bool,
) {
	if gdef == nil || gdef.glyph_class_def == nil {
		return {}, false
	}

	class_def_offset := uint(gdef.header.glyph_class_def_offset)
	if bounds_check(class_def_offset + 4 > uint(len(gdef.raw_data))) {
		return {}, false
	}

	format := read_u16(gdef.raw_data, class_def_offset)
	if bounds_check(format != 1 && format != 2) {
		return {}, false // Invalid class definition format
	}

	count: uint
	start_glyph_id: u16be = 0

	if format == 1 {
		// Format 1: Class values for a range of glyph IDs
		start_glyph_id = read_u16be(gdef.raw_data, class_def_offset + 2)
		glyph_count := uint(read_u16(gdef.raw_data, class_def_offset + 4))
		count = glyph_count

		if count > 0 && bounds_check(class_def_offset + 6 + count * 2 > uint(len(gdef.raw_data))) {
			return {}, false
		}
	} else {
		// Format 2: Class ranges
		count = uint(read_u16(gdef.raw_data, class_def_offset + 2))
		if count > 0 && bounds_check(class_def_offset + 4 + count * 6 > uint(len(gdef.raw_data))) {
			return {}, false
		}
	}

	return GDEF_Class_Definition_Iterator {
			gdef = gdef,
			class_def_offset = class_def_offset,
			current_index = 0,
			count = count,
			format = format,
			start_glyph_id = Raw_Glyph(start_glyph_id),
		},
		true
}

// Get the glyph class for a specific glyph ID
get_glyph_class :: proc(gdef: ^GDEF_Table, glyph_id: Glyph) -> (class: Glyph_Class, found: bool) {
	if gdef == nil || gdef.glyph_class_def == nil {
		return {}, false
	}

	offset := uint(gdef.header.glyph_class_def_offset)
	format := read_u16(gdef.raw_data, offset)

	if format == 1 {
		start_glyph_id := uint(read_u16be(gdef.raw_data, offset + 2))
		glyph_count := uint(read_u16(gdef.raw_data, offset + 4))

		gid := uint(glyph_id)
		if gid >= start_glyph_id && gid < start_glyph_id + glyph_count {
			class_idx := offset + 6 + (gid - start_glyph_id) * 2
			class_value := read_u16be(gdef.raw_data, class_idx)
			return Glyph_Class(class_value), true
		}
	} else if format == 2 {
		range_count := uint(read_u16(gdef.raw_data, offset + 2))
		for i: uint = 0; i < range_count; i += 1 {
			range_offset := offset + 4 + i * 6
			start_glyph := uint(read_u16be(gdef.raw_data, range_offset))
			end_glyph := uint(read_u16be(gdef.raw_data, range_offset + 2))
			class_value := read_u16be(gdef.raw_data, range_offset + 4)

			if uint(glyph_id) >= start_glyph && uint(glyph_id) <= end_glyph {
				return Glyph_Class(class_value), true
			}
		}
	}

	return {}, false
}

// Mark Glyph Sets Iterator
Mark_Set_Iterator :: struct {
	gdef:          ^GDEF_Table,
	current_index: uint,
	count:         uint,
}

// Initialize a mark set iterator
into_mark_set_iter :: proc(gdef: ^GDEF_Table) -> (Mark_Set_Iterator, bool) {
	if gdef == nil || gdef.mark_glyph_sets == nil {
		return {}, false
	}

	mark_sets_offset := uint(gdef.header.mark_glyph_sets_def_offset)
	count := uint(read_u16(gdef.raw_data, mark_sets_offset + 2))

	return Mark_Set_Iterator{gdef = gdef, current_index = 0, count = count}, true
}

// Get the coverage offset for the current mark set and advance to the next one
iter_mark_set :: proc(it: ^Mark_Set_Iterator) -> (coverage_offset: uint, has_more: bool) {
	if it.current_index >= it.count {
		return 0, false
	}

	mark_sets_base := uint(it.gdef.header.mark_glyph_sets_def_offset)
	offset_pos := mark_sets_base + 4 + it.current_index * 4

	if bounds_check(offset_pos + 4 > uint(len(it.gdef.raw_data))) {
		it.current_index += 1
		return 0, it.current_index < it.count
	}

	coverage_offset = mark_sets_base + uint(read_u32(it.gdef.raw_data, offset_pos))
	it.current_index += 1

	return coverage_offset, it.current_index < it.count
}

// Check if a glyph is in a specific mark set
is_glyph_in_mark_set :: proc(gdef: ^GDEF_Table, glyph_id: Glyph, mark_set_index: u16) -> bool {
	if gdef == nil || gdef.mark_glyph_sets == nil {
		return false
	}

	mark_sets_base := uint(gdef.header.mark_glyph_sets_def_offset)
	mark_set_count := uint(read_u16(gdef.raw_data, mark_sets_base + 2))

	if uint(mark_set_index) >= mark_set_count {
		return false
	}

	// Get coverage table offset for the specified mark set
	offset_pos := mark_sets_base + 4 + uint(mark_set_index) * 4
	if bounds_check(offset_pos + 4 > uint(len(gdef.raw_data))) {
		return false
	}

	coverage_offset := mark_sets_base + uint(read_u32(gdef.raw_data, offset_pos))

	// Check if glyph is in the coverage table
	_, found := get_coverage_index(gdef.raw_data, coverage_offset, glyph_id)
	return found
}

// Attachment Points Iterator for a specific glyph
Attachment_Points_Iterator :: struct {
	gdef:          ^GDEF_Table,
	points_offset: uint,
	current_index: uint,
	count:         uint,
}

// Initialize an attachment points iterator for a glyph
into_attachment_points_iter :: proc(
	gdef: ^GDEF_Table,
	glyph_id: Glyph,
) -> (
	Attachment_Points_Iterator,
	bool,
) {
	if gdef == nil || gdef.attachment_list == nil {
		return {}, false
	}

	attach_list_offset := uint(gdef.header.attachment_list_offset)
	coverage_offset := attach_list_offset + uint(gdef.attachment_list.coverage_offset)

	// Check if glyph is in coverage
	coverage_index, found := get_coverage_index(gdef.raw_data, coverage_offset, glyph_id)
	if !found {
		return {}, false
	}

	// Get offset to attachment point table for this glyph
	offset_pos := attach_list_offset + 4 + uint(coverage_index) * 2
	if bounds_check(offset_pos + 2 > uint(len(gdef.raw_data))) {
		return {}, false
	}

	attachment_offset := read_u16(gdef.raw_data, offset_pos)
	points_offset := attach_list_offset + uint(attachment_offset)

	if bounds_check(points_offset + 2 > uint(len(gdef.raw_data))) {
		return {}, false
	}

	point_count := uint(read_u16(gdef.raw_data, points_offset))

	return Attachment_Points_Iterator {
			gdef = gdef,
			points_offset = points_offset,
			current_index = 0,
			count = point_count,
		},
		true
}

// Get the current attachment point and advance to the next one
iter_attachment_point :: proc(
	it: ^Attachment_Points_Iterator,
) -> (
	point_index: u16,
	has_more: bool,
) {
	if it.current_index >= it.count {
		return 0, false
	}

	offset := it.points_offset + 2 + it.current_index * 2
	if bounds_check(offset + 2 > uint(len(it.gdef.raw_data))) {
		it.current_index += 1
		return 0, it.current_index < it.count
	}

	point_index = read_u16(it.gdef.raw_data, offset)
	it.current_index += 1

	return point_index, it.current_index < it.count
}

// Ligature Caret Iterator
Ligature_Caret_Iterator :: struct {
	gdef:            ^GDEF_Table,
	ligature_offset: uint,
	current_index:   uint,
	count:           uint,
}

// Initialize a ligature caret iterator for a ligature glyph
into_ligature_caret_iter :: proc(
	gdef: ^GDEF_Table,
	ligature_glyph: Glyph,
) -> (
	Ligature_Caret_Iterator,
	bool,
) {
	if gdef == nil || gdef.ligature_caret_list == nil {
		return {}, false
	}

	lig_list_offset := uint(gdef.header.ligature_caret_list_offset)
	coverage_offset := lig_list_offset + uint(gdef.ligature_caret_list.coverage_offset)

	// Check if glyph is in coverage
	coverage_index, found := get_coverage_index(gdef.raw_data, coverage_offset, ligature_glyph)
	if !found {
		return {}, false
	}

	// Get offset to ligature glyph table for this glyph
	offset_pos := lig_list_offset + 4 + uint(coverage_index) * 2
	if bounds_check(offset_pos + 2 > uint(len(gdef.raw_data))) {
		return {}, false
	}

	lig_glyph_offset := read_u16(gdef.raw_data, offset_pos)
	ligature_offset := lig_list_offset + uint(lig_glyph_offset)

	if bounds_check(ligature_offset + 2 > uint(len(gdef.raw_data))) {
		return {}, false
	}

	caret_count := uint(read_u16(gdef.raw_data, ligature_offset))

	return Ligature_Caret_Iterator {
			gdef = gdef,
			ligature_offset = ligature_offset,
			current_index = 0,
			count = caret_count,
		},
		true
}

// Get the current caret value and advance to the next one
iter_caret_value :: proc(it: ^Ligature_Caret_Iterator) -> (caret_offset: uint, has_more: bool) {
	if it.current_index >= it.count {
		return 0, false
	}

	offset_pos := it.ligature_offset + 2 + it.current_index * 2
	if bounds_check(offset_pos + 2 > uint(len(it.gdef.raw_data))) {
		it.current_index += 1
		return 0, it.current_index < it.count
	}

	caret_offset_value := read_u16(it.gdef.raw_data, offset_pos)
	caret_offset = it.ligature_offset + uint(caret_offset_value)

	it.current_index += 1

	return caret_offset, it.current_index < it.count
}

// Parse caret value at the given offset
parse_caret_value :: proc(
	gdef: ^GDEF_Table,
	caret_offset: uint,
) -> (
	value: i16,
	is_point_based: bool,
	point_index: u16,
	ok: bool,
) {
	if bounds_check(caret_offset + 4 > uint(len(gdef.raw_data))) {
		return 0, false, 0, false
	}

	format := Caret_Value_Format(read_u16be(gdef.raw_data, caret_offset))

	if format == .Format_1 {
		// X Coordinate
		value = i16(read_i16be(gdef.raw_data, caret_offset + 2))
		return value, false, 0, true

	} else if format == .Format_2 {
		// Point Index
		point_index = read_u16(gdef.raw_data, caret_offset + 2)
		return 0, true, point_index, true

	} else if format == .Format_3 {
		// Coordinate with Device table
		value = i16(read_i16be(gdef.raw_data, caret_offset + 2))
		// Note: We're ignoring the Device table for now
		// FIXME: impl Device Table
		return value, false, 0, true
	}

	return 0, false, 0, false
}
