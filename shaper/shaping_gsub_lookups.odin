package shaper

import ttf "../ttf"

// Apply standard lookup at a specific offset (for extension lookups)
apply_standard_lookup_at_offset :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	lookup_idx: u16,
	lookup_type: ttf.GSUB_Lookup_Type,
	lookup_flags: ttf.Lookup_Flags,
	subtable_offset: uint,
) -> bool {
	// Save original cursor and flags
	saved_cursor := buffer.cursor
	saved_flags := buffer.flags

	buffer.flags = lookup_flags

	applied := false

	switch lookup_type {
	case .Single:
		applied = apply_single_substitution_subtable(gsub, subtable_offset, buffer)
	case .Multiple:
		applied = apply_multiple_substitution_subtable(gsub, subtable_offset, buffer)
	case .Alternate:
		applied = apply_alternate_substitution_subtable(gsub, subtable_offset, buffer)
	case .Ligature:
		applied = apply_ligature_substitution_subtable(gsub, subtable_offset, buffer)
	case .Context:
		applied = apply_context_substitution_subtable(gsub, subtable_offset, buffer)
	case .ChainedContext:
		applied = apply_chained_context_subtable(gsub, subtable_offset, buffer)
	case .ReverseChained:
		applied = apply_reverse_chained_subtable(gsub, subtable_offset, buffer)
	case .Extension:
		// (should not happen here)
		applied = false
	}

	// Restore original settings
	buffer.cursor = saved_cursor
	buffer.flags = saved_flags

	return applied
}


// Apply a sequence of lookups to shape text
apply_gsub_lookups :: proc(gsub: ^ttf.GSUB_Table, lookup_indices: []u16, buffer: ^Shaping_Buffer) {
	if gsub == nil || len(lookup_indices) == 0 || buffer == nil || len(buffer.glyphs) == 0 {
		return
	}

	// Process each lookup in order
	for lookup_index in lookup_indices {
		// Get lookup information
		lookup_type, lookup_flags, _, ok := ttf.get_lookup_info(gsub, lookup_index)
		if !ok {continue} // TODO(Jeroen): Can this be replaced with `or_continue`?

		// Save original flags and update with current lookup flags
		saved_flags := buffer.flags
		buffer.flags = lookup_flags
		apply_lookup(gsub, lookup_index, lookup_type, lookup_flags, buffer)

		buffer.flags = saved_flags
	}
}

// Apply a single lookup to the buffer
apply_lookup :: proc(
	gsub: ^ttf.GSUB_Table,
	lookup_index: u16,
	lookup_type: ttf.GSUB_Lookup_Type,
	lookup_flags: ttf.Lookup_Flags,
	buffer: ^Shaping_Buffer,
) {
	// Create iterator for the lookup's subtables
	subtable_iter, ok := ttf.into_subtable_iter(gsub, lookup_index)
	if !ok {return}
	// fmt.printf(
	// 	"Applying Lookup Index %v, type: %v, flags:%v\n",
	// 	lookup_index,
	// 	lookup_type,
	// 	lookup_flags,
	// )

	// Check if mark filtering is being used
	if .USE_MARK_FILTERING_SET in lookup_flags.flags {
		mark_set, has_filter := ttf.get_mark_filtering_set(&subtable_iter)
		if has_filter {
			// Store the mark filtering set in buffer for use during processing
			buffer.skip_mask = mark_set
			// fmt.println("Has mark filtering set (u16 cast:)", u16(mark_set))
		}
	} else {
		buffer.skip_mask = 0
	}

	// Process each subtable
	for subtable_offset in ttf.iter_subtable_offset(&subtable_iter) {
		if subtable_offset == 0 {continue}

		// Reset cursor position for each new subtable
		buffer.cursor = 0

		// Apply the appropriate substitution based on lookup type
		applied := false

		switch lookup_type {
		case .Single:
			applied = apply_single_substitution_subtable(gsub, subtable_offset, buffer)
		case .Multiple:
			applied = apply_multiple_substitution_subtable(gsub, subtable_offset, buffer)
		case .Alternate:
			applied = apply_alternate_substitution_subtable(gsub, subtable_offset, buffer)
		case .Ligature:
			applied = apply_ligature_substitution_subtable(gsub, subtable_offset, buffer)
		case .Context:
			applied = apply_context_substitution_subtable(gsub, subtable_offset, buffer)
		case .ChainedContext:
			applied = apply_chained_context_subtable(gsub, subtable_offset, buffer)
		case .Extension:
			applied = apply_extension_substitution_subtable(gsub, subtable_offset, buffer)
		case .ReverseChained:
			applied = apply_reverse_chained_subtable(gsub, subtable_offset, buffer)
		}
		// fmt.println("Did Apply?", applied)

		// If a substitution was applied, we're done with this lookup
		if applied {break}
	}
}

// Helper function to determine if a glyph should be skipped based on lookup flags
should_skip_glyph :: proc(
	gc: ttf.Glyph_Category,
	flags: ttf.Lookup_Flags,
	skip_mask: u16be = 0,
) -> bool {
	if .IGNORE_BASE_GLYPHS in flags.flags && gc == .Base {
		return true
	}

	if .IGNORE_LIGATURES in flags.flags && gc == .Ligature {
		return true
	}

	if .IGNORE_MARKS in flags.flags && gc == .Mark {
		return true
	}

	// Handle mark filtering set if specified
	if .USE_MARK_FILTERING_SET in flags.flags && gc == .Mark {
		// FIXME: Implement mark filtering set logic
		// Currently just returning false to not skip
	}

	return false
}
