package rune

import ttf "../ttf"
import "core:fmt"

// TODO: think about refactor and move these to ttf:
// match_input_sequence, match_input_class_sequence, match_backtrack_sequence, match_lookahead_sequence

// Apply single substitution subtable (format 1 or 2)
apply_single_substitution_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if buffer == nil || len(buffer.glyphs) == 0 {return false}

	// Check format
	if bounds_check(subtable_offset + 4 > uint(len(gsub.raw_data))) {return false}

	format := read_u16(gsub.raw_data, subtable_offset)
	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	// Process each glyph in the buffer
	changed := false

	for pos := 0; pos < len(buffer.glyphs); pos += 1 {
		glyph_id := buffer.glyphs[pos].glyph_id

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(buffer.glyphs[pos].category, buffer.flags, buffer.skip_mask) {
			continue
		}

		// Check if the glyph is covered
		coverage_index, is_covered := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph_id,
		)

		if !is_covered {continue}

		// Apply substitution based on format
		if format == 1 {
			// Format 1: Add delta to glyph ID
			if bounds_check(subtable_offset + 6 > uint(len(gsub.raw_data))) {continue}

			delta_glyph_id := read_i16(gsub.raw_data, subtable_offset + 4)
			new_glyph_id := Glyph(i16(glyph_id) + delta_glyph_id)

			// Apply substitution
			buffer.glyphs[pos].glyph_id = new_glyph_id
			buffer.glyphs[pos].flags += {.Substituted}
			changed = true

		} else if format == 2 {
			// Format 2: Look up in array
			substitute_offset := subtable_offset + 6 + uint(coverage_index * 2)

			if bounds_check(substitute_offset + 2 > uint(len(gsub.raw_data))) {continue}

			new_glyph_id := Glyph(read_u16(gsub.raw_data, substitute_offset))

			// Apply substitution
			buffer.glyphs[pos].glyph_id = new_glyph_id
			buffer.glyphs[pos].flags += {.Substituted}
			changed = true
		}
	}

	return changed
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
apply_multiple_substitution_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if buffer == nil || len(buffer.glyphs) == 0 {return false}

	// Validate format
	if bounds_check(subtable_offset + 4 > uint(len(gsub.raw_data))) {
		return false
	}

	format := read_u16(gsub.raw_data, subtable_offset)
	if format != 1 {return false} 	// Only Format 1 is defined for Multiple Substitution

	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	// Get sequence count and validate
	sequence_count := read_u16(gsub.raw_data, subtable_offset + 4)
	if bounds_check(subtable_offset + 6 + uint(sequence_count) * 2 > uint(len(gsub.raw_data))) {
		return false
	}

	changed := false

	// We need to process the buffer in reverse order to avoid index shifting issues
	// when inserting multiple glyphs
	for pos := len(buffer.glyphs) - 1; pos >= 0; pos -= 1 {
		glyph := buffer.glyphs[pos]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
			continue
		}

		// Check if glyph is in coverage
		coverage_index, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph.glyph_id,
		)

		if !in_coverage || coverage_index >= sequence_count {continue}

		// Get sequence table for this coverage index
		sequence_offset_pos := subtable_offset + 6 + uint(coverage_index) * 2
		if bounds_check(sequence_offset_pos + 2 > uint(len(gsub.raw_data))) {
			continue
		}

		sequence_offset := read_u16(gsub.raw_data, sequence_offset_pos)
		abs_sequence_offset := subtable_offset + uint(sequence_offset)

		// Read the sequence length
		if bounds_check(abs_sequence_offset + 2 > uint(len(gsub.raw_data))) {
			continue
		}

		glyph_count := read_u16(gsub.raw_data, abs_sequence_offset)
		if glyph_count == 0 {continue}

		// Ensure we can read all glyphs in the sequence
		if bounds_check(
			abs_sequence_offset + 2 + uint(glyph_count) * 2 > uint(len(gsub.raw_data)),
		) {
			continue
		}

		// Use buffer's scratch space for temporary storage of replacement glyphs
		clear(&buffer.scratch.glyphs)
		// reserve(&buffer.scratch.glyphs, int(glyph_count))

		// Read the replacement glyphs into scratch space
		for i := 0; i < int(glyph_count); i += 1 {
			glyph_id_offset := abs_sequence_offset + 2 + uint(i) * 2
			replacement_glyph := Glyph(read_u16(gsub.raw_data, glyph_id_offset))
			gi := Glyph_Info {
				glyph_id = replacement_glyph,
				cluster  = glyph.cluster,
				category = .Base, // Default category
				flags    = {.Substituted, .Multiplied},
			}
			append(&buffer.scratch.glyphs, gi)
		}

		if len(buffer.scratch.glyphs) == 0 {continue}

		// Replace the current glyph with the first replacement
		buffer.glyphs[pos].glyph_id = buffer.scratch.glyphs[0].glyph_id
		buffer.glyphs[pos].flags += {.Substituted, .Multiplied}

		// Insert any additional replacement glyphs
		if len(buffer.scratch.glyphs) > 1 {
			// if cap(buffer.glyphs) < len(buffer.glyphs) + len(buffer.scratch.glyphs) - 1 {
			// 	reserve(&buffer.glyphs, len(buffer.glyphs) + len(buffer.scratch.glyphs) - 1)
			// }

			// Insert additional glyphs after the current position
			insert_at_elem(&buffer.glyphs, pos + 1, ..buffer.scratch.glyphs[1:])
		}

		changed = true
	}

	return changed
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
apply_alternate_substitution_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if buffer == nil || len(buffer.glyphs) == 0 {return false}

	// Validate format
	if bounds_check(subtable_offset + 4 > uint(len(gsub.raw_data))) {
		return false
	}

	format := read_u16(gsub.raw_data, subtable_offset)
	if format != 1 {return false} 	// Only Format 1 is defined for Alternate Substitution

	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	// Get alternate set count
	alternate_set_count := read_u16(gsub.raw_data, subtable_offset + 4)
	if bounds_check(
		subtable_offset + 6 + uint(alternate_set_count) * 2 > uint(len(gsub.raw_data)),
	) {
		return false
	}

	changed := false

	// Process each glyph in the buffer
	for pos := 0; pos < len(buffer.glyphs); pos += 1 {
		glyph := &buffer.glyphs[pos]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
			continue
		}

		// Check if glyph is in coverage
		coverage_index, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph.glyph_id,
		)

		if !in_coverage || coverage_index >= alternate_set_count {continue}

		// Get alternate set for this coverage index
		alternate_set_offset_pos := subtable_offset + 6 + uint(coverage_index) * 2
		if bounds_check(alternate_set_offset_pos + 2 > uint(len(gsub.raw_data))) {
			continue
		}

		alternate_set_offset := read_u16(gsub.raw_data, alternate_set_offset_pos)
		abs_alternate_set_offset := subtable_offset + uint(alternate_set_offset)

		// Read the alternate count
		if bounds_check(abs_alternate_set_offset + 2 > uint(len(gsub.raw_data))) {
			continue
		}

		alternate_count := read_u16(gsub.raw_data, abs_alternate_set_offset)
		if alternate_count == 0 {
			continue
		}

		// Ensure we can read all alternate glyphs
		if bounds_check(
			abs_alternate_set_offset + 2 + uint(alternate_count) * 2 > uint(len(gsub.raw_data)),
		) {
			continue
		}

		// Select which alternate to use
		// TODO: This should be controlled by the client application
		// For now, just use the first alternate (index 0)
		alternate_index := 0

		// Validate alternate index is in range
		if alternate_index >= int(alternate_count) {continue}

		// Get the selected alternate glyph ID
		glyph_id_offset := abs_alternate_set_offset + 2 + uint(alternate_index) * 2
		alternate_glyph := Glyph(read_u16(gsub.raw_data, glyph_id_offset))

		// Apply the substitution
		glyph.glyph_id = alternate_glyph
		glyph.flags += {.Substituted}
		changed = true
	}

	return changed
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
apply_ligature_substitution_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if buffer == nil || len(buffer.glyphs) == 0 {return false}

	// Validate format
	if bounds_check(subtable_offset + 6 > uint(len(gsub.raw_data))) {
		return false
	}

	format := read_u16(gsub.raw_data, subtable_offset)
	if format != 1 {return false} 	// Only Format 1 is defined for Ligature Substitution

	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	// Get ligature set count
	ligature_set_count := read_u16(gsub.raw_data, subtable_offset + 4)
	if bounds_check(
		subtable_offset + 6 + uint(ligature_set_count) * 2 > uint(len(gsub.raw_data)),
	) {
		return false
	}

	changed := false

	// Process each glyph as a potential ligature start
	for pos := 0; pos < len(buffer.glyphs); {
		first_glyph := &buffer.glyphs[pos]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(first_glyph.category, buffer.flags, buffer.skip_mask) {
			pos += 1
			continue
		}

		// Check if this glyph is a potential ligature start (in coverage table)
		coverage_index, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			first_glyph.glyph_id,
		)

		if !in_coverage || coverage_index >= ligature_set_count {
			pos += 1
			continue
		}

		// Get ligature set for this first glyph
		ligature_set_offset_pos := subtable_offset + 6 + uint(coverage_index) * 2
		if bounds_check(ligature_set_offset_pos + 2 > uint(len(gsub.raw_data))) {
			pos += 1
			continue
		}

		ligature_set_offset := read_u16(gsub.raw_data, ligature_set_offset_pos)
		abs_ligature_set_offset := subtable_offset + uint(ligature_set_offset)

		// Read ligature count
		if bounds_check(abs_ligature_set_offset + 2 > uint(len(gsub.raw_data))) {
			pos += 1
			continue
		}

		ligature_count := read_u16(gsub.raw_data, abs_ligature_set_offset)

		if ligature_count == 0 {
			pos += 1
			continue
		}

		// Check if we can read all ligature offsets
		if bounds_check(
			abs_ligature_set_offset + 2 + uint(ligature_count) * 2 > uint(len(gsub.raw_data)),
		) {
			pos += 1
			continue
		}

		// Try each potential ligature for this first glyph
		ligature_found := false

		for lig_index := 0; lig_index < int(ligature_count); lig_index += 1 {
			// Get offset to this ligature table
			lig_offset_pos := abs_ligature_set_offset + 2 + uint(lig_index) * 2
			lig_offset := read_u16(gsub.raw_data, lig_offset_pos)
			abs_lig_offset := abs_ligature_set_offset + uint(lig_offset)

			// Try to match this ligature
			ligature_glyph, component_count, matched := try_match_ligature(
				gsub,
				buffer,
				abs_lig_offset,
				pos,
			)

			if matched {
				// We found a ligature match - apply it

				// Get earliest cluster value among the components (for cluster mapping)
				min_cluster := first_glyph.cluster
				for i := pos + 1; i < pos + component_count; i += 1 {
					if i >= len(buffer.glyphs) {
						break
					}
					if buffer.glyphs[i].cluster < min_cluster {
						min_cluster = buffer.glyphs[i].cluster
					}
				}

				// Create component info for the ligature
				ligature_info := Ligature_Info {
					component_index  = 0,
					total_components = u8(component_count),
					original_glyph   = first_glyph.glyph_id,
				}

				// Replace the first glyph with the ligature
				first_glyph.glyph_id = ligature_glyph
				first_glyph.cluster = min_cluster
				first_glyph.category = .Ligature
				first_glyph.flags += {.Substituted, .Ligated}
				first_glyph.ligature_components = ligature_info

				if component_count > 1 {
					// Safety check
					if pos + component_count > len(buffer.glyphs) {
						component_count = len(buffer.glyphs) - pos
					}

					// Remove components in reverse order to avoid index shifting issues
					for i := component_count - 1; i > 0; i -= 1 {
						component_pos := pos + i
						if component_pos < len(buffer.glyphs) {
							ordered_remove(&buffer.glyphs, component_pos)
						}
					}
				}

				ligature_found = true
				changed = true
				break // Found a ligature, move to the next potential start
			}
		}

		// If we found a ligature, we don't advance pos since the new ligature
		// might participate in another ligature in the next iteration
		if !ligature_found {
			pos += 1
		}
	}

	return changed
}

// Helper function to try matching a ligature
try_match_ligature :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	abs_lig_offset: uint,
	start_pos: int,
) -> (
	ligature_glyph: Glyph,
	component_count: int,
	matched: bool,
) {
	// Check if we can read the ligature data
	if bounds_check(abs_lig_offset + 4 > uint(len(gsub.raw_data))) {
		return 0, 0, false
	}

	// Read ligature glyph ID and component count
	ligature_glyph = Glyph(read_u16(gsub.raw_data, abs_lig_offset))
	component_count = int(read_u16(gsub.raw_data, abs_lig_offset + 2))

	// A ligature must have at least 2 components
	if component_count < 2 {
		return 0, 0, false
	}

	// Check if we can read all component glyph IDs
	if bounds_check(
		abs_lig_offset + 4 + (uint(component_count) - 1) * 2 > uint(len(gsub.raw_data)),
	) {
		return 0, 0, false
	}

	// fmt.printf(
	// 	"Trying to match ligature with %d components at pos %d\n",
	// 	component_count,
	// 	start_pos,
	// )

	// First component is already matched (it's in the coverage table)
	// Try to match remaining components
	curr_pos := start_pos + 1
	next_comp := 1 // Start matching from second component

	// Try to match remaining components
	for next_comp < component_count {
		// Skip glyphs that should be ignored based on lookup flags
		for curr_pos < len(buffer.glyphs) {
			if curr_pos >= len(buffer.glyphs) {
				// fmt.println("Ran out of glyphs to match")
				return 0, 0, false
			}

			if !should_skip_glyph(
				buffer.glyphs[curr_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				break
			}
			curr_pos += 1
		}

		// Check if we've gone beyond the end of the buffer
		if curr_pos >= len(buffer.glyphs) {
			// fmt.println("Ran out of glyphs to match")
			return 0, 0, false
		}

		// Read component glyph ID from the ligature table
		component_pos := abs_lig_offset + 4 + uint(next_comp - 1) * 2
		component_glyph := Glyph(read_u16(gsub.raw_data, component_pos))

		// Check if the current glyph matches this component
		current_glyph := buffer.glyphs[curr_pos].glyph_id
		// fmt.printf(
		// 	"Matching component %d: expected %d, found %d\n",
		// 	next_comp,
		// 	component_glyph,
		// 	current_glyph,
		// )

		if current_glyph != component_glyph {
			// fmt.println("Component mismatch")
			return 0, 0, false
		}

		// Move to next component
		next_comp += 1
		curr_pos += 1
	}

	// If we get here, all components were matched successfully
	// fmt.println("All components matched successfully!")
	return ligature_glyph, component_count, true
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
apply_context_substitution_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if buffer == nil || len(buffer.glyphs) == 0 {return false}

	if bounds_check(subtable_offset + 2 > uint(len(gsub.raw_data))) {return false}
	format := read_u16(gsub.raw_data, subtable_offset)

	changed := false

	switch format {
	case 1:
		changed = apply_context_format1(gsub, subtable_offset, buffer)
	case 2:
		changed = apply_context_format2(gsub, subtable_offset, buffer)
	case 3:
		changed = apply_context_format3(gsub, subtable_offset, buffer)
	}

	return changed
}

// Format 1: Context Substitution - Simple Glyph Contexts
apply_context_format1 :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 6 > uint(len(gsub.raw_data))) {
		return false
	}

	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	subst_rule_set_count := read_u16(gsub.raw_data, subtable_offset + 4)
	if subst_rule_set_count == 0 {return false}

	// Ensure we can read all rule set offsets
	if bounds_check(
		subtable_offset + 6 + uint(subst_rule_set_count) * 2 > uint(len(gsub.raw_data)),
	) {
		return false
	}

	changed := false

	// Process each glyph as a potential context start
	for pos := 0; pos < len(buffer.glyphs); pos += 1 {
		glyph := buffer.glyphs[pos]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
			continue
		}

		// Check if glyph is in the coverage table (potential context start)
		coverage_index, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph.glyph_id,
		)

		if !in_coverage || coverage_index >= subst_rule_set_count {continue}

		// Get substitution rule set for this start glyph
		rule_set_offset_pos := subtable_offset + 6 + uint(coverage_index) * 2
		rule_set_offset := read_u16(gsub.raw_data, rule_set_offset_pos)

		if rule_set_offset == 0 {continue}

		abs_rule_set_offset := subtable_offset + uint(rule_set_offset)

		// Check if we can read the rule count
		if bounds_check(abs_rule_set_offset + 2 > uint(len(gsub.raw_data))) {
			continue
		}

		rule_count := read_u16(gsub.raw_data, abs_rule_set_offset)
		if rule_count == 0 {continue}

		// Ensure we can read all rule offsets
		if bounds_check(
			abs_rule_set_offset + 2 + uint(rule_count) * 2 > uint(len(gsub.raw_data)),
		) {
			continue
		}

		// Try each context rule in order
		rule_loop: for rule_index := 0; rule_index < int(rule_count); rule_index += 1 {
			rule_offset_pos := abs_rule_set_offset + 2 + uint(rule_index) * 2
			rule_offset := read_u16(gsub.raw_data, rule_offset_pos)
			abs_rule_offset := abs_rule_set_offset + uint(rule_offset)

			// Check if we can read rule data
			if bounds_check(abs_rule_offset + 4 > uint(len(gsub.raw_data))) {
				continue
			}

			// Get glyph count and substitution count
			glyph_count := read_u16(gsub.raw_data, abs_rule_offset)
			subst_count := read_u16(gsub.raw_data, abs_rule_offset + 2)

			// Need at least 2 glyphs for context (1 is covered by single substitution)
			if glyph_count < 2 {continue}

			// Check if we can read input sequence and substitution records
			if bounds_check(
				abs_rule_offset + 4 + (uint(glyph_count) - 1) * 2 + uint(subst_count) * 4 >
				uint(len(gsub.raw_data)),
			) {
				continue
			}

			// Match input sequence (first glyph already matched via coverage)
			if !match_input_sequence(gsub, buffer, abs_rule_offset + 4, glyph_count - 1, pos + 1) {
				continue
			}

			// Apply substitutions for this context
			subst_table_start := abs_rule_offset + 4 + (uint(glyph_count) - 1) * 2
			if apply_substitutions(
				gsub,
				buffer,
				subst_table_start,
				subst_count,
				glyph_count,
				pos,
			) {
				changed = true
				break rule_loop // Found and applied a matching rule
			}
		}
	}

	return changed
}
// Match an input sequence of glyphs
match_input_sequence :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	input_sequence_offset: uint,
	input_count: u16,
	start_pos: int,
) -> (
	ok: bool,
) {
	if input_count == 0 {return true} 	// No input to match

	curr_pos := start_pos

	for i := 0; i < int(input_count); i += 1 {
		// Skip glyphs that should be ignored based on lookup flags
		skip: for {
			if curr_pos >= len(buffer.glyphs) {return false}

			// If we found a glyph that shouldn't be skipped, we'll process it
			if !should_skip_glyph(
				buffer.glyphs[curr_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				break skip
			}

			// This glyph should be skipped, so move to the next one
			curr_pos += 1
		}

		// Check if we've gone beyond valid positions after skipping
		if curr_pos >= len(buffer.glyphs) {return false}

		// Get input glyph at this position in the sequence
		input_glyph_offset := input_sequence_offset + uint(i) * 2
		input_glyph := Glyph(read_u16(gsub.raw_data, input_glyph_offset))

		// Check if current glyph matches input
		if buffer.glyphs[curr_pos].glyph_id != input_glyph {return false}

		// Move to the next position for the next input glyph
		curr_pos += 1
	}

	return true
}

// Apply substitutions within a context
apply_substitutions :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	subst_records_offset: uint,
	subst_count: u16,
	glyph_count: u16,
	context_start: int,
) -> bool {
	if subst_count == 0 {return false}

	// Save original buffer cursor
	original_cursor := buffer.cursor

	applied := false

	// Apply each substitution
	for i := 0; i < int(subst_count); i += 1 {
		subst_offset := subst_records_offset + uint(i) * 4

		if bounds_check(subst_offset + 4 > uint(len(gsub.raw_data))) {
			continue
		}

		// Get sequence index and lookup index
		sequence_index := read_u16(gsub.raw_data, subst_offset)
		lookup_index := read_u16(gsub.raw_data, subst_offset + 2)

		// Validate sequence index
		if sequence_index >= glyph_count {continue}

		// Calculate the position of the glyph to substitute
		glyph_pos := context_start

		// Skip ignored glyphs to find the real position of the target glyph
		skip_count := int(sequence_index)
		curr_pos := context_start

		for skip_count >= 0 && curr_pos < len(buffer.glyphs) {
			if !should_skip_glyph(
				buffer.glyphs[curr_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				if skip_count == 0 {
					glyph_pos = curr_pos
					break
				}
				skip_count -= 1
			}

			curr_pos += 1
		}

		if glyph_pos >= len(buffer.glyphs) {continue}

		// Get lookup type and flags
		lookup_type, lookup_flags, _, lookup_ok := ttf.get_lookup_info(gsub, lookup_index)

		if !lookup_ok {continue}

		// Save original flags and set new flags for this lookup
		original_flags := buffer.flags
		buffer.flags = lookup_flags

		// Set cursor position to the glyph to be substituted
		buffer.cursor = glyph_pos

		// Apply the nested lookup
		apply_lookup(gsub, lookup_index, lookup_type, lookup_flags, buffer)

		// Restore original flags
		buffer.flags = original_flags

		applied = true
	}

	// Restore original buffer cursor
	buffer.cursor = original_cursor

	return applied
}

// Format 2: Context Substitution - Class-based Glyph Contexts
apply_context_format2 :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 10 > uint(len(gsub.raw_data))) {
		return false
	}

	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	class_def_offset := read_u16(gsub.raw_data, subtable_offset + 4)
	absolute_class_def_offset := subtable_offset + uint(class_def_offset)

	subst_class_set_count := read_u16(gsub.raw_data, subtable_offset + 6)

	// Ensure we can read all class set offsets
	if bounds_check(
		subtable_offset + 8 + uint(subst_class_set_count) * 2 > uint(len(gsub.raw_data)),
	) {
		return false
	}

	changed := false

	// Process each glyph as a potential context start
	for pos := 0; pos < len(buffer.glyphs); pos += 1 {
		glyph := buffer.glyphs[pos]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
			continue
		}

		// Check if glyph is in the coverage table
		_, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph.glyph_id,
		)

		if !in_coverage {continue}

		// Get class of the current glyph
		glyph_class := ttf.get_class_value(
			gsub.raw_data,
			absolute_class_def_offset,
			glyph.glyph_id,
		)

		if glyph_class >= subst_class_set_count {continue}

		// Get class set offset
		class_set_offset_pos := subtable_offset + 8 + uint(glyph_class) * 2
		class_set_offset := read_u16(gsub.raw_data, class_set_offset_pos)

		// A zero offset means no rules for this class
		if class_set_offset == 0 {continue}

		abs_class_set_offset := subtable_offset + uint(class_set_offset)

		// Check if we can read the rule count
		if bounds_check(abs_class_set_offset + 2 > uint(len(gsub.raw_data))) {
			continue
		}

		rule_count := read_u16(gsub.raw_data, abs_class_set_offset)
		if rule_count == 0 {continue}

		// Ensure we can read all rule offsets
		if bounds_check(
			abs_class_set_offset + 2 + uint(rule_count) * 2 > uint(len(gsub.raw_data)),
		) {
			continue
		}

		// Try each class rule in order
		rule_loop: for rule_index := 0; rule_index < int(rule_count); rule_index += 1 {
			rule_offset_pos := abs_class_set_offset + 2 + uint(rule_index) * 2
			rule_offset := read_u16(gsub.raw_data, rule_offset_pos)
			abs_rule_offset := abs_class_set_offset + uint(rule_offset)

			// Check if we can read rule data
			if bounds_check(abs_rule_offset + 4 > uint(len(gsub.raw_data))) {
				continue
			}

			// Get class count and substitution count
			class_count := read_u16(gsub.raw_data, abs_rule_offset)
			subst_count := read_u16(gsub.raw_data, abs_rule_offset + 2)

			// Need at least 2 glyphs for context
			if class_count < 2 {continue}

			// Check if we can read input sequence classes and substitution records
			if bounds_check(
				abs_rule_offset + 4 + (uint(class_count) - 1) * 2 + uint(subst_count) * 4 >
				uint(len(gsub.raw_data)),
			) {
				continue
			}

			// Match input sequence by class (first class already matched)
			if !match_input_class_sequence(
				gsub,
				buffer,
				abs_rule_offset + 4,
				class_count - 1,
				pos + 1,
				absolute_class_def_offset,
			) {
				continue
			}

			// Apply substitutions for this context
			subst_table_start := abs_rule_offset + 4 + (uint(class_count) - 1) * 2
			if apply_substitutions(
				gsub,
				buffer,
				subst_table_start,
				subst_count,
				class_count,
				pos,
			) {
				changed = true
				break rule_loop // Found and applied a matching rule
			}
		}
	}

	return changed
}

// Match an input sequence by glyph class
match_input_class_sequence :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	input_class_sequence_offset: uint,
	class_count: u16,
	start_pos: int,
	class_def_offset: uint,
) -> (
	ok: bool,
) {
	if class_count == 0 {return true} 	// No input to match

	curr_pos := start_pos

	for i := 0; i < int(class_count); i += 1 {
		// Skip glyphs that should be ignored based on lookup flags
		skip: for {
			if curr_pos >= len(buffer.glyphs) {return false}

			if !should_skip_glyph(
				buffer.glyphs[curr_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				break skip
			}

			curr_pos += 1
		}

		if curr_pos >= len(buffer.glyphs) {return false}

		// Get required class at this position in the sequence
		input_class_offset := input_class_sequence_offset + uint(i) * 2
		input_class := read_u16(gsub.raw_data, input_class_offset)

		// Get actual class of the current glyph
		glyph_class := ttf.get_class_value(
			gsub.raw_data,
			class_def_offset,
			buffer.glyphs[curr_pos].glyph_id,
		)

		// Check if class matches
		if glyph_class != input_class {return false}

		curr_pos += 1
	}

	return true
}

// Format 3: Context Substitution - Coverage-based Glyph Contexts
apply_context_format3 :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 6 > uint(len(gsub.raw_data))) {
		return false
	}

	glyph_count := read_u16(gsub.raw_data, subtable_offset + 2)
	subst_count := read_u16(gsub.raw_data, subtable_offset + 4)

	// Need at least 1 glyph for context
	if glyph_count < 1 {return false}

	// Ensure we can read all coverage offsets and substitution records
	if bounds_check(
		subtable_offset + 6 + uint(glyph_count) * 2 + uint(subst_count) * 4 >
		uint(len(gsub.raw_data)),
	) {
		return false
	}

	changed := false

	// Process each potential context start position
	for pos := 0; pos <= len(buffer.glyphs) - int(glyph_count); pos += 1 {
		match_start_pos := pos

		// Check if all glyphs in the sequence match their respective coverage tables
		sequence_matched := true

		for i := 0; i < int(glyph_count); i += 1 {
			glyph_pos := match_start_pos + i

			if glyph_pos >= len(buffer.glyphs) {
				sequence_matched = false
				break
			}

			glyph := buffer.glyphs[glyph_pos]

			// Skip if this glyph should be ignored based on lookup flags
			if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
				// For format 3, we need to adjust matching position if we skip glyphs
				sequence_matched = false
				break
			}

			// Get coverage offset for this position
			coverage_offset_pos := subtable_offset + 6 + uint(i) * 2
			coverage_offset := read_u16(gsub.raw_data, coverage_offset_pos)
			abs_coverage_offset := subtable_offset + uint(coverage_offset)

			// Check if glyph is in this position's coverage table
			_, in_coverage := ttf.get_coverage_index(
				gsub.raw_data,
				abs_coverage_offset,
				glyph.glyph_id,
			)

			if !in_coverage {
				sequence_matched = false
				break
			}
		}

		if sequence_matched {
			// Apply substitutions for this context
			subst_table_start := subtable_offset + 6 + uint(glyph_count) * 2
			if apply_substitutions(
				gsub,
				buffer,
				subst_table_start,
				subst_count,
				glyph_count,
				match_start_pos,
			) {
				changed = true
				// Format 3 can have overlapping matches, so we don't break here
			}
		}
	}

	return changed
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Main entry point for chained context substitution
apply_chained_context_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 2 > uint(len(gsub.raw_data))) {return false}

	format := read_u16(gsub.raw_data, subtable_offset)
	changed := false
	switch format {
	case 1:
		changed = apply_chained_context_format1(gsub, subtable_offset, buffer)
	case 2:
		changed = apply_chained_context_format2(gsub, subtable_offset, buffer)
	case 3:
		changed = apply_chained_context_format3(gsub, subtable_offset, buffer)
	}

	return changed
}

// Format 1: Chained Context - Simple Glyph Contexts
apply_chained_context_format1 :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 6 > uint(len(gsub.raw_data))) {return false}

	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	chain_rule_set_count := read_u16(gsub.raw_data, subtable_offset + 4)
	if chain_rule_set_count == 0 {return false}

	// Ensure we can read all rule set offsets
	if bounds_check(
		subtable_offset + 6 + uint(chain_rule_set_count) * 2 > uint(len(gsub.raw_data)),
	) {return false}

	changed := false

	// Save original cursor position
	original_cursor := buffer.cursor

	// Process each glyph as a potential context start
	for buffer.cursor = 0; buffer.cursor < len(buffer.glyphs); buffer.cursor += 1 {
		glyph := buffer.glyphs[buffer.cursor]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
			continue
		}

		// Check if glyph is in the coverage table (potential context start)
		coverage_index, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph.glyph_id,
		)

		if !in_coverage || coverage_index >= chain_rule_set_count {continue}

		// Get chain rule set for this start glyph
		chain_rule_set_offset_pos := subtable_offset + 6 + uint(coverage_index) * 2
		chain_rule_set_offset := read_u16(gsub.raw_data, chain_rule_set_offset_pos)

		if chain_rule_set_offset == 0 {continue}

		abs_chain_rule_set_offset := subtable_offset + uint(chain_rule_set_offset)

		// Check if we can read the rule count
		if bounds_check(abs_chain_rule_set_offset + 2 > uint(len(gsub.raw_data))) {
			continue
		}

		rule_count := read_u16(gsub.raw_data, abs_chain_rule_set_offset)
		if rule_count == 0 {continue}

		// Ensure we can read all rule offsets
		if bounds_check(
			abs_chain_rule_set_offset + 2 + uint(rule_count) * 2 > uint(len(gsub.raw_data)),
		) {continue}

		// Try each chain rule in order
		for rule_index := 0; rule_index < int(rule_count); rule_index += 1 {
			rule_offset_pos := abs_chain_rule_set_offset + 2 + uint(rule_index) * 2
			rule_offset := read_u16(gsub.raw_data, rule_offset_pos)
			abs_rule_offset := abs_chain_rule_set_offset + uint(rule_offset)

			// Check if we can read backtrack count
			if bounds_check(abs_rule_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read backtrack sequence count
			backtrack_count := read_u16(gsub.raw_data, abs_rule_offset)

			// Ensure we can read backtrack sequence
			if bounds_check(
				abs_rule_offset + 2 + uint(backtrack_count) * 2 > uint(len(gsub.raw_data)),
			) {continue}

			// Check backtrack sequence (matches glyphs before current position, in reverse order)
			if !match_backtrack_sequence(
				gsub,
				buffer,
				abs_rule_offset + 2,
				backtrack_count,
				buffer.cursor,
			) {continue}

			// Calculate offset to input sequence
			input_offset := abs_rule_offset + 2 + uint(backtrack_count) * 2

			// Check if we can read input count
			if bounds_check(input_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read input sequence count (excluding the first glyph, which is in the coverage)
			input_count := read_u16(gsub.raw_data, input_offset)

			// Ensure we can read input sequence
			if bounds_check(
				input_offset + 2 + uint(input_count) * 2 > uint(len(gsub.raw_data)),
			) {continue}

			// Check input sequence (matches current position + following glyphs)
			// First glyph already matched via coverage, so start from second glyph
			if !match_input_sequence(
				gsub,
				buffer,
				input_offset + 2,
				input_count,
				buffer.cursor + 1,
			) {continue}

			// Calculate offset to lookahead sequence
			lookahead_offset := input_offset + 2 + uint(input_count) * 2

			// Check if we can read lookahead count
			if bounds_check(lookahead_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read lookahead sequence count
			lookahead_count := read_u16(gsub.raw_data, lookahead_offset)

			// Ensure we can read lookahead sequence
			if bounds_check(
				lookahead_offset + 2 + uint(lookahead_count) * 2 > uint(len(gsub.raw_data)),
			) {continue}

			// Calculate position of first lookahead glyph
			lookahead_pos := buffer.cursor + 1

			// Skip input glyphs to get to lookahead position
			for i := 0; i < int(input_count); i += 1 {
				lookahead_pos = get_next_non_ignored_glyph_position(buffer, lookahead_pos)

				if lookahead_pos >= len(buffer.glyphs) {
					break
				}
			}

			// Check lookahead sequence
			if !match_lookahead_sequence(
				gsub,
				buffer,
				lookahead_offset + 2,
				lookahead_count,
				lookahead_pos,
			) {continue}

			// Calculate offset to substitution records
			subst_offset := lookahead_offset + 2 + uint(lookahead_count) * 2

			// Check if we can read substitution count
			if bounds_check(subst_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read substitution count
			subst_count := read_u16(gsub.raw_data, subst_offset)

			// Apply substitutions if all sequences match
			if apply_substitutions(
				gsub,
				buffer,
				subst_offset + 2,
				subst_count,
				input_count + 1, // +1 because the first glyph is in the coverage
				buffer.cursor,
			) {
				changed = true
				break // Found and applied a matching rule
			}
		}
	}

	// Restore original cursor position
	buffer.cursor = original_cursor

	return changed
}

// Format 2: Chained Context - Class-based Contexts
apply_chained_context_format2 :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 12 > uint(len(gsub.raw_data))) {return false}

	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	// Read class definition tables offsets
	backtrack_class_def_offset := read_u16(gsub.raw_data, subtable_offset + 4)
	abs_backtrack_class_def := subtable_offset + uint(backtrack_class_def_offset)

	input_class_def_offset := read_u16(gsub.raw_data, subtable_offset + 6)
	abs_input_class_def := subtable_offset + uint(input_class_def_offset)

	lookahead_class_def_offset := read_u16(gsub.raw_data, subtable_offset + 8)
	abs_lookahead_class_def := subtable_offset + uint(lookahead_class_def_offset)

	chain_class_set_count := read_u16(gsub.raw_data, subtable_offset + 10)

	// Ensure we can read all class set offsets
	if bounds_check(
		subtable_offset + 12 + uint(chain_class_set_count) * 2 > uint(len(gsub.raw_data)),
	) {return false}

	changed := false

	// Save original cursor position
	original_cursor := buffer.cursor

	// Process each glyph as a potential context start
	for buffer.cursor = 0; buffer.cursor < len(buffer.glyphs); buffer.cursor += 1 {
		if buffer.cursor >= len(buffer.glyphs) {break}

		glyph := buffer.glyphs[buffer.cursor]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {continue}

		// Check if glyph is in the coverage table
		_, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph.glyph_id,
		)

		if !in_coverage {continue}

		// Get class of the current glyph
		input_class := ttf.get_class_value(gsub.raw_data, abs_input_class_def, glyph.glyph_id)

		if input_class >= chain_class_set_count {continue}

		// Get class set offset
		class_set_offset_pos := subtable_offset + 12 + uint(input_class) * 2
		class_set_offset := read_u16(gsub.raw_data, class_set_offset_pos)

		// A zero offset means no rules for this class
		if class_set_offset == 0 {continue}

		abs_class_set_offset := subtable_offset + uint(class_set_offset)

		// Check if we can read the rule count
		if bounds_check(abs_class_set_offset + 2 > uint(len(gsub.raw_data))) {continue}

		rule_count := read_u16(gsub.raw_data, abs_class_set_offset)
		if rule_count == 0 {continue}

		// Ensure we can read all rule offsets
		if bounds_check(
			abs_class_set_offset + 2 + uint(rule_count) * 2 > uint(len(gsub.raw_data)),
		) {continue}

		// Try each class rule in order
		for rule_index := 0; rule_index < int(rule_count); rule_index += 1 {
			rule_offset_pos := abs_class_set_offset + 2 + uint(rule_index) * 2
			rule_offset := read_u16(gsub.raw_data, rule_offset_pos)
			abs_rule_offset := abs_class_set_offset + uint(rule_offset)

			// Check if we can read backtrack count
			if bounds_check(abs_rule_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read backtrack sequence count
			backtrack_count := read_u16(gsub.raw_data, abs_rule_offset)

			// Ensure we can read backtrack sequence
			if bounds_check(
				abs_rule_offset + 2 + uint(backtrack_count) * 2 > uint(len(gsub.raw_data)),
			) {continue}

			// Check backtrack sequence by class
			if !match_backtrack_class_sequence(
				gsub,
				buffer,
				abs_rule_offset + 2,
				backtrack_count,
				buffer.cursor,
				abs_backtrack_class_def,
			) {continue}

			// Calculate offset to input sequence
			input_offset := abs_rule_offset + 2 + uint(backtrack_count) * 2

			// Check if we can read input count
			if bounds_check(input_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read input sequence count (excluding the first glyph, which is matched by class)
			input_count := read_u16(gsub.raw_data, input_offset)

			// Ensure we can read input sequence
			if bounds_check(
				input_offset + 2 + uint(input_count) * 2 > uint(len(gsub.raw_data)),
			) {continue}

			// Check input sequence by class (first class already matched)
			if !match_input_class_sequence(
				gsub,
				buffer,
				input_offset + 2,
				input_count,
				buffer.cursor + 1,
				abs_input_class_def,
			) {continue}

			// Calculate offset to lookahead sequence
			lookahead_offset := input_offset + 2 + uint(input_count) * 2

			// Check if we can read lookahead count
			if bounds_check(lookahead_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read lookahead sequence count
			lookahead_count := read_u16(gsub.raw_data, lookahead_offset)

			// Ensure we can read lookahead sequence
			if bounds_check(
				lookahead_offset + 2 + uint(lookahead_count) * 2 > uint(len(gsub.raw_data)),
			) {continue}

			// Calculate position of first lookahead glyph
			lookahead_pos := buffer.cursor + 1

			// Skip input glyphs to get to lookahead position
			for i := 0; i < int(input_count); i += 1 {
				lookahead_pos = get_next_non_ignored_glyph_position(buffer, lookahead_pos)

				if lookahead_pos >= len(buffer.glyphs) {break}
			}

			// Check lookahead sequence by class
			if !match_lookahead_class_sequence(
				gsub,
				buffer,
				lookahead_offset + 2,
				lookahead_count,
				lookahead_pos,
				abs_lookahead_class_def,
			) {continue}

			// Calculate offset to substitution records
			subst_offset := lookahead_offset + 2 + uint(lookahead_count) * 2

			// Check if we can read substitution count
			if bounds_check(subst_offset + 2 > uint(len(gsub.raw_data))) {continue}

			// Read substitution count
			subst_count := read_u16(gsub.raw_data, subst_offset)

			// Apply substitutions if all sequences match
			if apply_substitutions(
				gsub,
				buffer,
				subst_offset + 2,
				subst_count,
				input_count + 1, // +1 because the first glyph is matched by class
				buffer.cursor,
			) {
				changed = true
				break // Found and applied a matching rule
			}
		}
	}

	// Restore original cursor position
	buffer.cursor = original_cursor

	return changed
}

// Format 3: Chained Context - Coverage-based Contexts
apply_chained_context_format3 :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 10 > uint(len(gsub.raw_data))) {return false}

	// Read coverage counts
	backtrack_count := read_u16(gsub.raw_data, subtable_offset + 2)
	input_offset := subtable_offset + 4 + uint(backtrack_count) * 2

	// Ensure we can read input count
	if bounds_check(input_offset + 2 > uint(len(gsub.raw_data))) {return false}

	input_count := read_u16(gsub.raw_data, input_offset)
	lookahead_offset := input_offset + 2 + uint(input_count) * 2

	// Ensure we can read lookahead count
	if bounds_check(lookahead_offset + 2 > uint(len(gsub.raw_data))) {return false}

	lookahead_count := read_u16(gsub.raw_data, lookahead_offset)

	// Need at least 1 input glyph
	if input_count < 1 {return false}

	// Calculate offset to substitution information
	subst_offset := lookahead_offset + 2 + uint(lookahead_count) * 2

	// Ensure we can read substitution count
	if bounds_check(subst_offset + 2 > uint(len(gsub.raw_data))) {return false}

	// Read substitution count
	subst_count := read_u16(gsub.raw_data, subst_offset)

	changed := false

	// Save original cursor position
	original_cursor := buffer.cursor

	// Process each potential context start position
	for pos := 0; pos <= len(buffer.glyphs) - int(input_count); pos += 1 {
		// Check input sequence (all glyphs must match their coverage tables)
		input_matched := true

		for i := 0; i < int(input_count); i += 1 {
			glyph_pos := pos + i

			if glyph_pos >= len(buffer.glyphs) {
				input_matched = false
				break
			}

			glyph := buffer.glyphs[glyph_pos]
			// Skip if this glyph should be ignored based on lookup flags
			if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
				input_matched = false
				break
			}

			// Get coverage offset for this input position
			coverage_offset_pos := input_offset + 2 + uint(i) * 2
			if bounds_check(coverage_offset_pos + 2 > uint(len(gsub.raw_data))) {
				input_matched = false
				break
			}

			coverage_offset := read_u16(gsub.raw_data, coverage_offset_pos)
			abs_coverage_offset := subtable_offset + uint(coverage_offset)

			// Check if glyph is in this position's coverage table
			_, in_coverage := ttf.get_coverage_index(
				gsub.raw_data,
				abs_coverage_offset,
				glyph.glyph_id,
			)

			if !in_coverage {
				input_matched = false
				break
			}
		}

		if !input_matched {continue}

		// Check backtrack sequence (matches glyphs before current position)
		if backtrack_count > 0 {
			backtrack_matched := true

			for i := 0; i < int(backtrack_count); i += 1 {
				backtrack_pos := pos - 1 - i

				if backtrack_pos < 0 || backtrack_pos >= len(buffer.glyphs) {
					backtrack_matched = false
					break
				}

				glyph := buffer.glyphs[backtrack_pos]

				// Skip if this glyph should be ignored based on lookup flags
				if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
					i -= 1 // Retry with previous position
					continue
				}

				// Get coverage offset for this backtrack position
				coverage_offset_pos := subtable_offset + 4 + uint(i) * 2
				if bounds_check(coverage_offset_pos + 2 > uint(len(gsub.raw_data))) {
					backtrack_matched = false
					break
				}

				coverage_offset := read_u16(gsub.raw_data, coverage_offset_pos)
				abs_coverage_offset := subtable_offset + uint(coverage_offset)

				// Check if glyph is in this position's coverage table
				_, in_coverage := ttf.get_coverage_index(
					gsub.raw_data,
					abs_coverage_offset,
					glyph.glyph_id,
				)

				if !in_coverage {
					backtrack_matched = false
					break
				}
			}

			if !backtrack_matched {continue}
		}

		// Check lookahead sequence (matches glyphs after input sequence)
		if lookahead_count > 0 {
			lookahead_matched := true
			lookahead_pos := pos + int(input_count)

			for i := 0; i < int(lookahead_count); i += 1 {
				if lookahead_pos >= len(buffer.glyphs) {
					lookahead_matched = false
					break
				}

				glyph := buffer.glyphs[lookahead_pos]

				// Skip if this glyph should be ignored based on lookup flags
				if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {
					lookahead_pos += 1
					i -= 1 // Retry with next position
					continue
				}

				// Get coverage offset for this lookahead position
				coverage_offset_pos := lookahead_offset + 2 + uint(i) * 2
				if bounds_check(coverage_offset_pos + 2 > uint(len(gsub.raw_data))) {
					lookahead_matched = false
					break
				}

				coverage_offset := read_u16(gsub.raw_data, coverage_offset_pos)
				abs_coverage_offset := subtable_offset + uint(coverage_offset)

				// Check if glyph is in this position's coverage table
				_, in_coverage := ttf.get_coverage_index(
					gsub.raw_data,
					abs_coverage_offset,
					glyph.glyph_id,
				)

				if !in_coverage {
					lookahead_matched = false
					break
				}

				lookahead_pos += 1
			}

			if !lookahead_matched {continue}
		}

		// If we get here, all sequences matched
		// Apply substitutions
		buffer.cursor = pos // Set cursor to the start of the match

		if apply_substitutions(gsub, buffer, subst_offset + 2, subst_count, input_count, pos) {
			changed = true
			// Format 3 can have overlapping matches, so we don't break here
		}
	}

	// Restore original cursor position
	buffer.cursor = original_cursor

	return changed
}
// Helper function to match a backtrack sequence of glyphs
match_backtrack_sequence :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	backtrack_sequence_offset: uint,
	backtrack_count: u16,
	current_pos: int,
) -> bool {
	if backtrack_count == 0 {return true} 	// No backtrack to match

	// Backtrack sequence is stored in reverse order in the table
	for i := 0; i < int(backtrack_count); i += 1 {
		// Calculate position to check (backwards from current position)
		check_pos := current_pos - 1 - i

		// Skip glyphs that should be ignored based on lookup flags
		skipped := 0
		for check_pos >= 0 {
			if check_pos < 0 || check_pos >= len(buffer.glyphs) {return false}

			if !should_skip_glyph(
				buffer.glyphs[check_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				break
			}

			check_pos -= 1
			skipped += 1
		}

		if check_pos < 0 {return false}

		// Get backtrack glyph at this position in the sequence
		backtrack_glyph_offset := backtrack_sequence_offset + uint(i) * 2
		backtrack_glyph := cast(Glyph)read_u16(gsub.raw_data, backtrack_glyph_offset)

		// Check if glyph matches backtrack
		if buffer.glyphs[check_pos].glyph_id != backtrack_glyph {
			return false
		}
	}

	return true
}

// Helper function to match a lookahead sequence of glyphs
match_lookahead_sequence :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	lookahead_sequence_offset: uint,
	lookahead_count: u16,
	start_pos: int,
) -> bool {
	if lookahead_count == 0 {return true} 	// No lookahead to match

	curr_pos := start_pos

	for i := 0; i < int(lookahead_count); i += 1 {
		// Skip glyphs that should be ignored based on lookup flags
		for curr_pos < len(buffer.glyphs) {
			if curr_pos >= len(buffer.glyphs) {return false}

			if !should_skip_glyph(
				buffer.glyphs[curr_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				break
			}

			curr_pos += 1
		}

		if curr_pos >= len(buffer.glyphs) {return false}

		// Get lookahead glyph at this position in the sequence
		lookahead_glyph_offset := lookahead_sequence_offset + uint(i) * 2
		lookahead_glyph := cast(Glyph)read_u16(gsub.raw_data, lookahead_glyph_offset)

		// Check if current glyph matches lookahead
		if buffer.glyphs[curr_pos].glyph_id != lookahead_glyph {
			return false
		}

		curr_pos += 1
	}

	return true
}

// Get the position of the next glyph that shouldn't be ignored based on lookup flags
get_next_non_ignored_glyph_position :: proc(buffer: ^Shaping_Buffer, start_pos: int) -> int {
	pos := start_pos

	for pos < len(buffer.glyphs) {
		if pos >= len(buffer.glyphs) {
			return len(buffer.glyphs)
		}

		if !should_skip_glyph(buffer.glyphs[pos].category, buffer.flags, buffer.skip_mask) {
			return pos
		}

		pos += 1
	}

	return len(buffer.glyphs)
}
// Helper function to match a backtrack sequence by glyph class
match_backtrack_class_sequence :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	backtrack_class_sequence_offset: uint,
	backtrack_count: u16,
	current_pos: int,
	class_def_offset: uint,
) -> bool {
	if backtrack_count == 0 {return true} 	// No backtrack to match
	// FIXME: This function assumes LTR text - need to adjust logic for RTL text direction

	// Backtrack sequence is stored in reverse order in the table
	for i := 0; i < int(backtrack_count); i += 1 {
		// Calculate position to check (backwards from current position)
		check_pos := current_pos - 1 - i

		// Skip glyphs that should be ignored based on lookup flags
		for check_pos >= 0 {
			if check_pos < 0 || check_pos >= len(buffer.glyphs) {return false}

			if !should_skip_glyph(
				buffer.glyphs[check_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				break
			}

			check_pos -= 1
		}

		if check_pos < 0 {return false}

		// Get required class at this position in the sequence
		backtrack_class_offset := backtrack_class_sequence_offset + uint(i) * 2
		backtrack_class := read_u16(gsub.raw_data, backtrack_class_offset)

		// Get actual class of the current glyph
		glyph_class := ttf.get_class_value(
			gsub.raw_data,
			class_def_offset,
			buffer.glyphs[check_pos].glyph_id,
		)

		// Check if class matches
		if glyph_class != backtrack_class {
			return false
		}
	}

	return true
}
// Helper function to match a lookahead sequence by glyph class
match_lookahead_class_sequence :: proc(
	gsub: ^ttf.GSUB_Table,
	buffer: ^Shaping_Buffer,
	lookahead_class_sequence_offset: uint,
	lookahead_count: u16,
	start_pos: int,
	class_def_offset: uint,
) -> bool {
	if lookahead_count == 0 {return true} 	// No lookahead to match
	// FIXME: This function assumes LTR text - need to adjust logic for RTL text direction

	curr_pos := start_pos

	for i := 0; i < int(lookahead_count); i += 1 {
		// Skip glyphs that should be ignored based on lookup flags
		for curr_pos < len(buffer.glyphs) {
			if curr_pos >= len(buffer.glyphs) {return false}

			if !should_skip_glyph(
				buffer.glyphs[curr_pos].category,
				buffer.flags,
				buffer.skip_mask,
			) {
				break
			}

			curr_pos += 1
		}

		if curr_pos >= len(buffer.glyphs) {return false}

		// Get required class at this position in the sequence
		lookahead_class_offset := lookahead_class_sequence_offset + uint(i) * 2
		lookahead_class := read_u16(gsub.raw_data, lookahead_class_offset)

		// Get actual class of the current glyph
		glyph_class := ttf.get_class_value(
			gsub.raw_data,
			class_def_offset,
			buffer.glyphs[curr_pos].glyph_id,
		)

		// Check if class matches
		if glyph_class != lookahead_class {
			return false
		}

		curr_pos += 1
	}

	return true
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
apply_extension_substitution_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	// Bounds check
	if bounds_check(subtable_offset + 8 > uint(len(gsub.raw_data))) {
		fmt.println("Extension subtable bounds check failed")
		return false
	}

	// Read format
	extension_format := read_u16(gsub.raw_data, subtable_offset)

	if extension_format != 1 {
		fmt.println("Unsupported extension format:", extension_format)
		return false
	}

	// Get actual lookup type and offset
	extension_lookup_type := cast(ttf.GSUB_Lookup_Type)read_u16(gsub.raw_data, subtable_offset + 2)
	extension_offset := read_u32(gsub.raw_data, subtable_offset + 4)

	// Calculate new absolute offset
	extended_subtable_offset := subtable_offset + uint(extension_offset)

	// fmt.printf(
	// 	"Extension redirecting to: %v at offset %d\n",
	// 	extension_lookup_type,
	// 	extended_subtable_offset,
	// )

	// Apply the appropriate subtable based on the extended lookup type
	switch extension_lookup_type {
	case .Single:
		return apply_single_substitution_subtable(gsub, extended_subtable_offset, buffer)
	case .Multiple:
		return apply_multiple_substitution_subtable(gsub, extended_subtable_offset, buffer)
	case .Alternate:
		return apply_alternate_substitution_subtable(gsub, extended_subtable_offset, buffer)
	case .Ligature:
		return apply_ligature_substitution_subtable(gsub, extended_subtable_offset, buffer)
	case .Context:
		return apply_context_substitution_subtable(gsub, extended_subtable_offset, buffer)
	case .ChainedContext:
		return apply_chained_context_subtable(gsub, extended_subtable_offset, buffer)
	case .Extension:
		// Nested extension subtables are not allowed by the spec
		fmt.println("Nested extension subtables are not allowed")
		return false
	case .ReverseChained:
		return apply_reverse_chained_subtable(gsub, extended_subtable_offset, buffer)
	case:
		fmt.println("Unknown extension lookup type:", extension_lookup_type)
		return false
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
apply_reverse_chained_subtable :: proc(
	gsub: ^ttf.GSUB_Table,
	subtable_offset: uint,
	buffer: ^Shaping_Buffer,
) -> bool {
	if bounds_check(subtable_offset + 6 > uint(len(gsub.raw_data))) {return false}

	// Reverse chained contextual substitution has only one format
	format := read_u16(gsub.raw_data, subtable_offset)
	if format != 1 {return false} 	// Only Format 1 is defined for Reverse Chained Substitution

	// Get the coverage offset
	coverage_offset := read_u16(gsub.raw_data, subtable_offset + 2)
	absolute_coverage_offset := subtable_offset + uint(coverage_offset)

	// Check if we can read the backtrack count
	if bounds_check(absolute_coverage_offset + 2 > uint(len(gsub.raw_data))) {return false}

	// Read the backtrack count
	backtrack_count := read_u16(gsub.raw_data, subtable_offset + 4)

	// Ensure we can read all backtrack coverage offsets
	if bounds_check(
		subtable_offset + 6 + uint(backtrack_count) * 2 > uint(len(gsub.raw_data)),
	) {return false}

	// Calculate the offset to lookahead count
	lookahead_offset := subtable_offset + 6 + uint(backtrack_count) * 2

	// Check if we can read the lookahead count
	if bounds_check(lookahead_offset + 2 > uint(len(gsub.raw_data))) {return false}

	// Read the lookahead count
	lookahead_count := read_u16(gsub.raw_data, lookahead_offset)

	// Ensure we can read all lookahead coverage offsets
	if bounds_check(
		lookahead_offset + 2 + uint(lookahead_count) * 2 > uint(len(gsub.raw_data)),
	) {return false}

	// Calculate the offset to substitute count
	substitute_offset := lookahead_offset + 2 + uint(lookahead_count) * 2

	// Check if we can read the substitute count
	if bounds_check(substitute_offset + 2 > uint(len(gsub.raw_data))) {return false}

	// Read the substitute count
	substitute_count := read_u16(gsub.raw_data, substitute_offset)

	// The number of substitute glyphs must match the coverage count
	// But we can't validate this here because we don't know the coverage count yet

	// Ensure we can read all substitute glyph IDs
	if bounds_check(
		substitute_offset + 2 + uint(substitute_count) * 2 > uint(len(gsub.raw_data)),
	) {return false}

	// First, create a list of all glyphs that match the input coverage
	matching_positions: [dynamic]int // TODO: scratch buffer??
	defer delete(matching_positions)

	// Process in reverse order (important for this lookup type)
	for pos := len(buffer.glyphs) - 1; pos >= 0; pos -= 1 {
		glyph := buffer.glyphs[pos]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(glyph.category, buffer.flags, buffer.skip_mask) {continue}

		// Check if the glyph is in the coverage table
		coverage_index, in_coverage := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			glyph.glyph_id,
		)

		if !in_coverage || coverage_index >= substitute_count {continue}

		// Check backtrack sequence (glyphs before the current one)
		backtrack_matched := true

		if backtrack_count > 0 {
			// Start with the glyph immediately before the current one
			check_pos := pos - 1
			backtrack_index := 0

			for backtrack_index < int(backtrack_count) {
				// Find next non-ignored glyph going backward
				for check_pos >= 0 {
					if check_pos < 0 || check_pos >= len(buffer.glyphs) {
						backtrack_matched = false
						break
					}

					if !should_skip_glyph(
						buffer.glyphs[check_pos].category,
						buffer.flags,
						buffer.skip_mask,
					) {
						break
					}

					check_pos -= 1
				}

				if check_pos < 0 {
					backtrack_matched = false
					break
				}

				// Get backtrack coverage offset
				backtrack_coverage_offset_pos := subtable_offset + 6 + uint(backtrack_index) * 2
				backtrack_coverage_offset := read_u16(gsub.raw_data, backtrack_coverage_offset_pos)
				abs_backtrack_coverage_offset := subtable_offset + uint(backtrack_coverage_offset)

				// Check if the glyph is in this backtrack coverage
				_, in_backtrack_coverage := ttf.get_coverage_index(
					gsub.raw_data,
					abs_backtrack_coverage_offset,
					buffer.glyphs[check_pos].glyph_id,
				)

				if !in_backtrack_coverage {
					backtrack_matched = false
					break
				}

				backtrack_index += 1
				check_pos -= 1
			}
		}

		if !backtrack_matched {continue}

		// Check lookahead sequence (glyphs after the current one)
		lookahead_matched := true

		if lookahead_count > 0 {
			// Start with the glyph immediately after the current one
			check_pos := pos + 1
			lookahead_index := 0

			for lookahead_index < int(lookahead_count) {
				// Find next non-ignored glyph going forward
				for check_pos < len(buffer.glyphs) {
					if check_pos >= len(buffer.glyphs) {
						lookahead_matched = false
						break
					}

					if !should_skip_glyph(
						buffer.glyphs[check_pos].category,
						buffer.flags,
						buffer.skip_mask,
					) {
						break
					}

					check_pos += 1
				}

				if check_pos >= len(buffer.glyphs) {
					lookahead_matched = false
					break
				}

				// Get lookahead coverage offset
				lookahead_coverage_offset_pos := lookahead_offset + 2 + uint(lookahead_index) * 2
				lookahead_coverage_offset := read_u16(gsub.raw_data, lookahead_coverage_offset_pos)
				abs_lookahead_coverage_offset := subtable_offset + uint(lookahead_coverage_offset)

				// Check if the glyph is in this lookahead coverage
				_, in_lookahead_coverage := ttf.get_coverage_index(
					gsub.raw_data,
					abs_lookahead_coverage_offset,
					buffer.glyphs[check_pos].glyph_id,
				)

				if !in_lookahead_coverage {
					lookahead_matched = false
					break
				}

				lookahead_index += 1
				check_pos += 1
			}
		}

		if !lookahead_matched {continue}

		// If we get here, the glyph matches the coverage and all context conditions
		// Add to the list of positions to substitute
		append(&matching_positions, pos)
	}

	// If no matches, return false
	if len(matching_positions) == 0 {return false}

	// Now apply substitutions in the original order (left-to-right)
	// This is crucial for reverse chained substitution
	for i := len(matching_positions) - 1; i >= 0; i -= 1 {
		pos := matching_positions[i]

		// Get the coverage index for this glyph
		coverage_index, _ := ttf.get_coverage_index(
			gsub.raw_data,
			absolute_coverage_offset,
			buffer.glyphs[pos].glyph_id,
		)

		// Get the substitute glyph ID
		substitute_glyph_offset := substitute_offset + 2 + uint(coverage_index) * 2
		substitute_glyph := cast(Glyph)read_u16(gsub.raw_data, substitute_glyph_offset)

		// Apply the substitution
		buffer.glyphs[pos].glyph_id = substitute_glyph
		buffer.glyphs[pos].flags += {.Substituted}
	}

	return true
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
