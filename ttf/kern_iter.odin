package ttf

// Helper struct for kern table iteration
Kern_Subtable_Iterator :: struct {
	data:          []byte,
	offset:        uint,
	max_subtables: u16,
	processed:     u16,
}

// Initialize a kern subtable iterator
into_kern_subtable_iter :: proc(kern: ^OpenType_Kern_Table) -> Kern_Subtable_Iterator {
	offset := kern.subtables_offset

	return Kern_Subtable_Iterator {
		data = kern.raw_data,
		offset = offset,
		max_subtables = u16(kern.num_tables),
		processed = 0,
	}
}

// Get the next kern subtable
iter_kern_subtable :: proc(
	it: ^Kern_Subtable_Iterator,
) -> (
	offset: uint,
	format: Kern_Subtable_Format,
	coverage: Kern_Coverage_Flags,
	has_more: bool,
) {
	if it == nil || it.processed >= it.max_subtables || it.offset >= uint(len(it.data)) {
		return 0, {}, {}, false
	}

	if it.offset + 6 > uint(len(it.data)) {
		it.processed = it.max_subtables // Mark as done
		return 0, {}, {}, false
	}

	// Read subtable header
	subtable_length := read_u16(it.data, it.offset + 2)
	coverage = transmute(Kern_Coverage_Flags)read_u16(it.data, it.offset + 4)
	format = Kern_Subtable_Format(u8(coverage.FORMAT))

	current_offset := it.offset

	// Move to next subtable
	it.offset += uint(subtable_length)
	it.processed += 1

	return current_offset, format, coverage, it.processed < it.max_subtables
}

// Helper struct for Format 0 kerning pair iteration
Kern_Format0_Iterator :: struct {
	data:         []byte,
	pairs_offset: uint,
	pair_count:   u16,
	current:      uint,
}

// Initialize a Format 0 iterator
into_kern_format0_iter :: proc(
	data: []byte,
	subtable_offset: uint,
) -> (
	Kern_Format0_Iterator,
	bool,
) {
	// Format 0 header comes after common header
	header_offset := subtable_offset + 6
	if header_offset + 2 > uint(len(data)) {
		return {}, false
	}

	// Get number of pairs
	pair_count := read_u16(data, header_offset)

	// Calculate pairs offset - after the format-specific header
	pairs_offset := header_offset + 8 // After Format 0 header

	return Kern_Format0_Iterator {
			data = data,
			pairs_offset = pairs_offset,
			pair_count = pair_count,
			current = 0,
		},
		true
}

// Get the next kerning pair
iter_kern_pair :: proc(
	it: ^Kern_Format0_Iterator,
) -> (
	left: Glyph,
	right: Glyph,
	value: i16,
	has_more: bool,
) {
	if it == nil || it.current >= uint(it.pair_count) {
		return 0, 0, 0, false
	}

	pair_offset := it.pairs_offset + it.current * 6

	if pair_offset + 6 > uint(len(it.data)) {
		return 0, 0, 0, false
	}

	left = Glyph(read_u16(it.data, pair_offset))
	right = Glyph(read_u16(it.data, pair_offset + 2))
	value = i16(read_i16(it.data, pair_offset + 4))

	it.current += 1
	has_more = it.current < uint(it.pair_count)

	return left, right, value, has_more
}

// Check if a font has kerning information
has_kerning :: proc(font: ^Font) -> bool {
	_, has_kern := get_table_data(font, "kern")

	// Check for both traditional kern table and GPOS kerning
	if has_kern {
		return true
	}

	// Could also check for GPOS kerning here when GPOS is implemented
	_, has_gpos := get_table_data(font, "GPOS")

	return has_gpos
}

// Get number of kerning pairs in all subtables
get_kerning_pair_count :: proc(kern: ^OpenType_Kern_Table) -> uint {
	if kern == nil {
		return 0
	}

	count: uint = 0
	it := into_kern_subtable_iter(kern)

	for {
		offset, format, _, has_more := iter_kern_subtable(&it)
		if !has_more {
			break
		}

		if format == .Format_0 {
			if format0_it, ok := into_kern_format0_iter(kern.raw_data, offset); ok {
				count += uint(format0_it.pair_count)
			}
		}
		// Other formats would need more complex counting
	}

	return count
}
