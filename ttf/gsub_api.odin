package ttf
// Extract lookup information from the GSUB table
get_lookup_info :: proc(
	gsub: ^GSUB_Table,
	lookup_index: u16,
) -> (
	lookup_type: GSUB_Lookup_Type,
	lookup_flags: Lookup_Flags,
	lookup_offset: uint,
	ok: bool,
) {
	// Check if lookup index is valid
	lookup_list_offset := uint(gsub.header.lookup_list_offset)
	if bounds_check(lookup_list_offset + 2 > uint(len(gsub.raw_data))) {
		ok = false
		return
	}

	lookup_count := read_u16(gsub.raw_data, lookup_list_offset)
	if bounds_check(lookup_index >= lookup_count) {
		ok = false
		return
	}

	// Get offset to the lookup table
	lookup_offset_pos := lookup_list_offset + 2 + uint(lookup_index) * 2
	if bounds_check(lookup_offset_pos + 2 > uint(len(gsub.raw_data))) {
		ok = false
		return
	}

	rel_lookup_offset := read_u16(gsub.raw_data, lookup_offset_pos)
	abs_lookup_offset := lookup_list_offset + uint(rel_lookup_offset)
	if bounds_check(abs_lookup_offset + 6 > uint(len(gsub.raw_data))) {
		ok = false
		return
	}

	// Read lookup type and flags
	lookup_type = cast(GSUB_Lookup_Type)read_u16(gsub.raw_data, abs_lookup_offset)
	lookup_flags = transmute(Lookup_Flags)read_u16(gsub.raw_data, abs_lookup_offset + 2)

	return lookup_type, lookup_flags, abs_lookup_offset, true
}


// Helper function to get a glyph's class from a class definition table
get_class_value :: proc(data: []byte, class_def_offset: uint, glyph_id: Glyph) -> u16 {
	if bounds_check(class_def_offset + 2 > uint(len(data))) {return 0}

	format := read_u16(data, class_def_offset)

	switch format {
	case 1:
		// Format 1: Class Range Table
		if bounds_check(class_def_offset + 6 > uint(len(data))) {return 0}

		start_glyph := read_u16(data, class_def_offset + 2)
		glyph_count := read_u16(data, class_def_offset + 4)

		// Check if glyph is in range
		if u16(glyph_id) < start_glyph || u16(glyph_id) >= start_glyph + glyph_count {
			return 0 // Default class 0 for glyphs not in range
		}

		class_offset := class_def_offset + 6 + (uint(glyph_id) - uint(start_glyph)) * 2

		if bounds_check(class_offset + 2 > uint(len(data))) {return 0}

		return read_u16(data, class_offset)

	case 2:
		// Format 2: Class Range Record Table
		if bounds_check(class_def_offset + 4 > uint(len(data))) {return 0}

		class_range_count := read_u16(data, class_def_offset + 2)

		// Binary search for the class range containing this glyph
		low := 0
		high := int(class_range_count) - 1

		for low <= high {
			mid := (low + high) / 2
			range_offset := class_def_offset + 4 + uint(mid) * 6

			if bounds_check(range_offset + 6 > uint(len(data))) {return 0}

			start_glyph := read_u16(data, range_offset)
			end_glyph := read_u16(data, range_offset + 2)
			class_value := read_u16(data, range_offset + 4)

			if u16(glyph_id) < start_glyph {
				high = mid - 1
			} else if u16(glyph_id) > end_glyph {
				low = mid + 1
			} else {
				return class_value // Found the class
			}
		}

		return 0 // Default class 0 for glyphs not in any range
	}

	return 0 // Default class 0 for invalid format
}
