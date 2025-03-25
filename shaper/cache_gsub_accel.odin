package shaper

import "../ttf"
import "core:slice"


GSUB_Accelerator :: struct {
	// Lookup type-specific accelerators
	single_subst:    map[u16]Single_Subst_Accelerator, // For single substitutions
	ligature_subst:  map[u16]Ligature_Subst_Accelerator, // For ligature substitutions

	// Coverage acceleration - quick check if a glyph is in coverage
	coverage_digest: map[uint]Coverage_Digest, // offset → digest

	// Feature flag acceleration
	feature_lookups: map[Feature_Tag][]u16, // feature → lookup indices
}

// Fast coverage testing using a digest/bloom filter approach
Coverage_Digest :: struct {
	// Bitmap-based digest for quick rejection testing
	// If a bit corresponding to a glyph is not set,
	// the glyph is definitely not in the coverage
	digest:        [8]u32, // 256-bit digest

	// For small coverage sets, direct map is more efficient
	direct_map:    map[Glyph]bool,

	// Optional sorted array for binary search (for larger sets)
	sorted_glyphs: []Glyph,
}

// Accelerator for single substitution lookups
Single_Subst_Accelerator :: struct {
	format:      ttf.GSUB_Lookup_Type,
	is_delta:    bool,
	delta_value: i16,
	mapping:     map[Glyph]Glyph, // Direct mapping
	coverage:    Coverage_Digest,
}

// Accelerator for ligature substitution lookups
Ligature_Subst_Accelerator :: struct {
	format:          ttf.GSUB_Lookup_Type,

	// Quick bitmap to check if a glyph could start a ligature
	starts_ligature: map[Glyph]bool,

	// Map from first glyph to all possible sequences with that first glyph
	ligature_map:    map[Glyph][dynamic]Ligature_Sequence,
}

Ligature_Sequence :: struct {
	components: []Glyph, // Full sequence including first glyph
	ligature:   Glyph, // Resulting ligature glyph
}

// // Build GSUB accelerator for a specific lookup
// build_gsub_accelerator :: proc(font: ^Font, cache: ^Shaping_Cache) -> bool {
// 	gsub, has_gsub := ttf.get_table(font, "GSUB", ttf.load_gsub_table, ttf.GSUB_Table)
// 	if !has_gsub || cache.gsub_lookups == nil {return false}

// 	accel := &cache.gsub_accel

// 	// Process each lookup in the cache's lookup list
// 	for lookup_idx in cache.gsub_lookups {
// 		lookup_type, lookup_flags, lookup_offset, lookup_ok := ttf.get_lookup_info(
// 			gsub,
// 			lookup_idx,
// 		)
// 		if !lookup_ok {continue}

// 		// Start subtable iteration
// 		subtable_iter, iter_ok := ttf.into_subtable_iter(gsub, lookup_idx)
// 		if !iter_ok {continue}

// 		// Process each subtable based on lookup type
// 		for subtable_offset, has_more := ttf.iter_subtable_offset(&subtable_iter);
// 		    has_more;
// 		    subtable_offset, has_more = ttf.iter_subtable_offset(&subtable_iter) {

// 			// Build coverage digest first (used by all lookups)
// 			coverage_offset := ttf.read_u16(gsub.raw_data, subtable_offset + 2)
// 			abs_coverage_offset := subtable_offset + uint(coverage_offset)

// 			// Create coverage digest
// 			digest := build_coverage_digest(gsub, abs_coverage_offset)
// 			accel.coverage_digest[abs_coverage_offset] = digest

// 			#partial switch lookup_type {
// 			case .Single:
// 				accelerate_single_substitution(
// 					gsub,
// 					accel,
// 					lookup_idx,
// 					subtable_offset,
// 					abs_coverage_offset,
// 				)

// 			case .Ligature:
// 				accelerate_ligature_substitution(
// 					gsub,
// 					accel,
// 					lookup_idx,
// 					subtable_offset,
// 					abs_coverage_offset,
// 				)

// 			// TODO: Other lookup types
// 			}
// 		}
// 	}

// 	build_feature_lookup_map(gsub, cache, accel)

// 	return true
// }

// // Build coverage digest for quick testing
// build_coverage_digest :: proc(gsub: ^ttf.GSUB_Table, coverage_offset: uint) -> Coverage_Digest {
// 	digest: Coverage_Digest

// 	// Initialize 256-bit digest (8 u32s) to zeros
// 	digest.direct_map = make(map[Glyph]bool)

// 	// Create a coverage iterator
// 	coverage_iter, coverage_ok := ttf.into_coverage_iter(gsub, 0, u16(coverage_offset))
// 	if !coverage_ok {return digest}

// 	// Process all entries in the coverage
// 	glyphs := make([dynamic]Glyph)
// 	defer delete(glyphs)

// 	for entry in ttf.iter_coverage_entry(&coverage_iter) {
// 		switch e in entry {
// 		case ttf.Coverage_Format1_Entry:
// 			// Add to digest
// 			glyph_id := uint(e.glyph)
// 			digest_idx := glyph_id / 32
// 			bit_pos := glyph_id % 32

// 			if digest_idx < 8 {
// 				digest.digest[digest_idx] |= (1 << bit_pos)
// 			}
// 			glyph := Glyph(e.glyph)
// 			// Add to direct map for small coverage sets
// 			digest.direct_map[glyph] = true
// 			append(&glyphs, glyph)

// 		case ttf.Coverage_Format2_Entry:
// 			// Add all glyphs in the range
// 			for gid := e.start; gid <= e.end; gid += 1 {
// 				glyph_id := uint(gid)
// 				digest_idx := glyph_id / 32
// 				bit_pos := glyph_id % 32

// 				if digest_idx < 8 {
// 					digest.digest[digest_idx] |= (1 << bit_pos)
// 				}
// 				glyph := Glyph(gid)
// 				// Add to direct map for small coverage sets
// 				digest.direct_map[glyph] = true
// 				append(&glyphs, glyph)
// 			}
// 		}
// 	}

// 	// For larger sets (more than ~50 glyphs), create a sorted array for binary search
// 	if len(digest.direct_map) > 50 {
// 		digest.sorted_glyphs = make([]Glyph, len(glyphs))
// 		copy(digest.sorted_glyphs, glyphs[:])
// 		slice.sort(digest.sorted_glyphs)
// 	}

// 	return digest
// }

// // Accelerate single substitution lookup
// accelerate_single_substitution :: proc(
// 	gsub: ^ttf.GSUB_Table,
// 	accel: ^GSUB_Accelerator,
// 	lookup_idx: u16,
// 	subtable_offset: uint,
// 	coverage_offset: uint,
// ) {
// 	if bounds_check(subtable_offset + 4 >= uint(len(gsub.raw_data))) {return}

// 	format := ttf.read_u16(gsub.raw_data, subtable_offset)

// 	// Initialize accelerator
// 	single_accel := Single_Subst_Accelerator {
// 		format   = .Single,
// 		is_delta = format == 1,
// 		coverage = accel.coverage_digest[coverage_offset],
// 	}

// 	if format == 1 {
// 		// Format 1: Delta substitution
// 		if bounds_check(subtable_offset + 6 >= uint(len(gsub.raw_data))) {return}

// 		delta_glyph_id := ttf.read_i16(gsub.raw_data, subtable_offset + 4)
// 		single_accel.delta_value = delta_glyph_id

// 		// Pre-compute all mappings
// 		for glyph, _ in single_accel.coverage.direct_map {
// 			result_glyph := Glyph(int(glyph) + int(delta_glyph_id))
// 			single_accel.mapping[glyph] = result_glyph
// 		}

// 	} else if format == 2 {
// 		// Format 2: Direct mapping
// 		if bounds_check(subtable_offset + 6 >= uint(len(gsub.raw_data))) {return}

// 		glyph_count := ttf.read_u16(gsub.raw_data, subtable_offset + 4)
// 		substitute_offset := subtable_offset + 6

// 		// Create mapping from coverage to substitutes
// 		i := 0
// 		for glyph, _ in single_accel.coverage.direct_map {
// 			if i >= int(glyph_count) ||
// 			   bounds_check(substitute_offset + uint(i) * 2 >= uint(len(gsub.raw_data))) {
// 				i += 1
// 				continue
// 			}

// 			subst_glyph := ttf.Glyph(ttf.read_u16(gsub.raw_data, substitute_offset + uint(i) * 2))
// 			single_accel.mapping[glyph] = subst_glyph
// 			i += 1
// 		}
// 	}

// 	// Store the accelerator
// 	accel.single_subst[lookup_idx] = single_accel
// }

// // Accelerate ligature substitution lookup
// accelerate_ligature_substitution :: proc(
// 	gsub: ^ttf.GSUB_Table,
// 	accel: ^GSUB_Accelerator,
// 	lookup_idx: u16,
// 	subtable_offset: uint,
// 	coverage_offset: uint,
// ) {
// 	if !bounds_check(subtable_offset + 6 <= uint(len(gsub.raw_data))) {
// 		return
// 	}

// 	format := ttf.read_u16(gsub.raw_data, subtable_offset)
// 	if format != 1 {
// 		return // Only format 1 is defined for ligatures
// 	}

// 	ligature_set_count := ttf.read_u16(gsub.raw_data, subtable_offset + 4)
// 	ligature_set_offset := subtable_offset + 6

// 	// Initialize accelerator
// 	lig_accel := Ligature_Subst_Accelerator {
// 		format          = .Ligature,
// 		starts_ligature = make(map[Glyph]bool),
// 		ligature_map    = make(map[Glyph][dynamic]Ligature_Sequence),
// 	}

// 	// Process the coverage as starting glyphs for ligatures
// 	for glyph, _ in accel.coverage_digest[coverage_offset].direct_map {
// 		lig_accel.starts_ligature[glyph] = true
// 	}

// 	// Process each ligature set
// 	i := 0
// 	for glyph, _ in lig_accel.starts_ligature {
// 		if i >= int(ligature_set_count) ||
// 		   bounds_check(ligature_set_offset + uint(i) * 2 >= uint(len(gsub.raw_data))) {
// 			i += 1
// 			continue
// 		}

// 		// Get offset to ligature set
// 		ligature_set_ptr := ttf.read_u16(gsub.raw_data, ligature_set_offset + uint(i) * 2)
// 		abs_ligature_set_offset := subtable_offset + uint(ligature_set_ptr)

// 		if bounds_check(abs_ligature_set_offset + 2 >= uint(len(gsub.raw_data))) {
// 			i += 1
// 			continue
// 		}

// 		// Get number of ligatures in this set
// 		ligature_count := ttf.read_u16(gsub.raw_data, abs_ligature_set_offset)
// 		ligature_array_offset := abs_ligature_set_offset + 2

// 		// Process each ligature
// 		for j := 0; j < int(ligature_count); j += 1 {
// 			if bounds_check(ligature_array_offset + uint(j) * 2 >= uint(len(gsub.raw_data))) {
// 				continue
// 			}

// 			// Get offset to ligature
// 			ligature_offset := ttf.read_u16(gsub.raw_data, ligature_array_offset + uint(j) * 2)
// 			abs_ligature_offset := abs_ligature_set_offset + uint(ligature_offset)

// 			if bounds_check(abs_ligature_offset + 4 >= uint(len(gsub.raw_data))) {
// 				continue
// 			}

// 			// Read ligature glyph and component count
// 			ligature_glyph := ttf.Glyph(ttf.read_u16(gsub.raw_data, abs_ligature_offset))
// 			component_count := ttf.read_u16(gsub.raw_data, abs_ligature_offset + 2)
// 			components_array_offset := abs_ligature_offset + 4

// 			// Need at least 2 components for a ligature (including first glyph)
// 			if component_count < 2 ||
// 			   bounds_check(
// 				   components_array_offset + uint(component_count - 2) * 2 >=
// 				   uint(len(gsub.raw_data)),
// 			   ) {
// 				continue
// 			}

// 			// Create component array (first component is the coverage glyph)
// 			components := make([]Glyph, component_count)
// 			components[0] = glyph

// 			// Read remaining components
// 			for k := 0; k < int(component_count) - 1; k += 1 {
// 				components[k + 1] = ttf.Glyph(
// 					ttf.read_u16(gsub.raw_data, components_array_offset + uint(k) * 2),
// 				)
// 			}

// 			// Create ligature sequence
// 			sequence := Ligature_Sequence {
// 				components = components,
// 				ligature   = ligature_glyph,
// 			}
// 			seq_arr := &lig_accel.ligature_map[glyph]
// 			// Add to mapping
// 			append(seq_arr, sequence)
// 		}

// 		i += 1
// 	}

// 	accel.ligature_subst[lookup_idx] = lig_accel
// }

// // Build feature to lookup mapping for faster feature selection
// build_feature_lookup_map :: proc(
// 	gsub: ^ttf.GSUB_Table,
// 	cache: ^Shaping_Cache,
// 	accel: ^GSUB_Accelerator,
// ) {
// 	// Iterate through all features
// 	feature_iter, iter_ok := ttf.into_feature_iter_gsub(gsub, cache.gsub_lang_sys_offset)
// 	if !iter_ok {
// 		return
// 	}

// 	for feature_index, record, feature_offset, has_more := ttf.iter_feature_gsub(&feature_iter);
// 	    has_more;
// 	    feature_index, record, feature_offset, has_more = ttf.iter_feature_gsub(&feature_iter) {

// 		// Get feature tag
// 		feature_tag := Feature_Tag(ttf.tag_to_u32(record.feature_tag))

// 		// Get lookup indices for this feature
// 		lookup_iter, lookup_ok := ttf.into_lookup_iter(gsub.raw_data, feature_offset)
// 		if !lookup_ok {
// 			continue
// 		}

// 		// Collect all lookup indices for this feature
// 		lookups := make([dynamic]u16)
// 		for lookup_index in ttf.iter_lookup_index(&lookup_iter) {
// 			append(&lookups, lookup_index)
// 		}

// 		// Store in map
// 		accel.feature_lookups[feature_tag] = lookups[:]
// 	}
// }

// //////////////////////////////////////////////////////////////////////////////////////////////////////////////
// // Apply GSUB using accelerator
// apply_gsub_with_accelerator :: proc(
// 	font: ^Font,
// 	buffer: ^Shaping_Buffer,
// 	cache: ^Shaping_Cache,
// ) -> bool {
// 	if cache == nil {
// 		// Fall back to standard GSUB application
// 		return apply_gsub_standard(font, buffer)
// 	}

// 	gsub, has_gsub := ttf.get_table(font, "GSUB", ttf.load_gsub_table, ttf.GSUB_Table)
// 	if !has_gsub {
// 		return false
// 	}

// 	accel := &cache.gsub_accel

// 	// Apply each lookup in the optimized order
// 	for lookup_idx in cache.gsub_lookups {
// 		lookup_type, lookup_flags, lookup_offset, ok := ttf.get_lookup_info(gsub, lookup_idx)
// 		if !ok {continue}

// 		#partial switch lookup_type {
// 		case .Single:
// 			if single_accel, has_accel := accel.single_subst[lookup_idx]; has_accel {
// 				apply_accelerated_single_subst(buffer, single_accel, lookup_flags)
// 			}

// 		case .Ligature:
// 			if lig_accel, has_accel := accel.ligature_subst[lookup_idx]; has_accel {
// 				apply_accelerated_ligature_subst(buffer, lig_accel, lookup_flags)
// 			}

// 		// Other cases fall back to standard implementation
// 		case:
// 			apply_standard_lookup(gsub, buffer, lookup_idx, lookup_type, lookup_flags)
// 		}
// 	}

// 	return true
// }

// // Apply accelerated single substitution
// apply_accelerated_single_subst :: proc(
// 	buffer: ^Shaping_Buffer,
// 	accel: Single_Subst_Accelerator,
// 	lookup_flags: ttf.Lookup_Flags,
// ) {
// 	// Process buffer
// 	for i := 0; i < len(buffer.glyphs); i += 1 {
// 		glyph_info := &buffer.glyphs[i]

// 		// Skip glyphs based on lookup flags
// 		if should_skip_glyph(glyph_info.category, lookup_flags) {
// 			continue
// 		}

// 		// Fast lookup using mapping
// 		if subst_glyph, found := accel.mapping[glyph_info.glyph_id]; found {
// 			glyph_info.glyph_id = subst_glyph
// 			glyph_info.flags += {.Substituted}
// 		}
// 	}
// }

// // Apply accelerated ligature substitution
// apply_accelerated_ligature_subst :: proc(
// 	buffer: ^Shaping_Buffer,
// 	accel: Ligature_Subst_Accelerator,
// 	lookup_flags: ttf.Lookup_Flags,
// ) {
// 	i := 0
// 	for i < len(buffer.glyphs) {
// 		glyph_info := &buffer.glyphs[i]

// 		// Skip glyphs based on lookup flags
// 		if should_skip_glyph(glyph_info.category, lookup_flags) {
// 			i += 1
// 			continue
// 		}

// 		// Quick check if this glyph can start a ligature
// 		if !accel.starts_ligature[glyph_info.glyph_id] {
// 			i += 1
// 			continue
// 		}

// 		// Check for ligature matches
// 		best_match_length := 0
// 		ligature_glyph: Glyph

// 		// Check each potential ligature sequence for this starting glyph
// 		if sequences, has_sequences := accel.ligature_map[glyph_info.glyph_id]; has_sequences {
// 			for sequence in sequences {
// 				// Check if we have enough glyphs left
// 				if i + len(sequence.components) > len(buffer.glyphs) {
// 					continue
// 				}

// 				// Try to match the sequence
// 				match := true
// 				match_pos := 0

// 				for j := 0; j < len(sequence.components); j += 1 {
// 					// Find next non-skipped glyph
// 					for match_pos + j < len(buffer.glyphs) &&
// 					    should_skip_glyph(
// 						    buffer.glyphs[i + match_pos + j].category,
// 						    lookup_flags,
// 					    ) {
// 						match_pos += 1
// 					}

// 					// Check if we ran out of glyphs
// 					if i + match_pos + j >= len(buffer.glyphs) {
// 						match = false
// 						break
// 					}

// 					// Check if glyph matches
// 					if buffer.glyphs[i + match_pos + j].glyph_id != sequence.components[j] {
// 						match = false
// 						break
// 					}
// 				}

// 				// If we found a match and it's longer than previous matches
// 				if match && match_pos + len(sequence.components) > best_match_length {
// 					best_match_length = match_pos + len(sequence.components)
// 					ligature_glyph = sequence.ligature
// 				}
// 			}
// 		}

// 		// Apply the best ligature match if found
// 		if best_match_length > 0 {
// 			// Replace first glyph with ligature
// 			glyph_info.glyph_id = ligature_glyph
// 			glyph_info.flags += {.Ligated, .Substituted}

// 			// Mark component glyphs (will be removed later)
// 			for j := 1; j < best_match_length; j += 1 {
// 				buffer.glyphs[i + j].flags += {.Ligated}
// 			}

// 			// Skip past the ligature components
// 			i += best_match_length
// 		} else {
// 			// No match, move to next glyph
// 			i += 1
// 		}
// 	}

// 	// Remove ligature components (glyphs marked with .Ligated but not .Substituted)
// 	i = 0
// 	for i < len(buffer.glyphs) {
// 		if .Ligated in buffer.glyphs[i].flags && .Substituted not_in buffer.glyphs[i].flags {
// 			ordered_remove(&buffer.glyphs, i)
// 		} else {
// 			i += 1
// 		}
// 	}
// }
