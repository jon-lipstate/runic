package shaper

import "../ttf"
import "core:fmt"
import "core:slice"


GSUB_Accelerator :: struct {
	// Lookup type-specific accelerators
	single_subst:          map[u16]Single_Subst_Accelerator, // For single substitutions
	ligature_subst:        map[u16]Ligature_Subst_Accelerator, // For ligature substitutions
	multiple_subst:        map[u16]Multiple_Subst_Accelerator, // For multiple substitutions
	alternate_subst:       map[u16]Alternate_Subst_Accelerator, // For alternate substitutions
	context_subst:         map[u16]Context_Accelerator, // For context substitutions
	chained_context_subst: map[u16]Chained_Context_Accelerator, // For chained context substitutions
	reverse_chained_subst: map[u16]Reverse_Chained_Accelerator, // For reverse chained substitutions

	// Coverage acceleration - quick check if a glyph is in coverage
	coverage_digest:       map[uint]Coverage_Digest, // offset → digest

	// Feature flag acceleration
	feature_lookups:       map[Feature_Tag][]u16, // feature → lookup indices
	extension_map:         map[u16]Extension_Info,
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

Extension_Info :: struct {
	lookup_type:      ttf.GSUB_Lookup_Type, // Actual lookup type being referenced
	extension_offset: uint, // Offset to the actual lookup subtable
	is_processed:     bool, // Whether this extension has been processed
}

Chained_Context_Accelerator :: struct {
	format:              u16,

	// Format-specific data
	// For Format 3:
	backtrack_coverages: []Coverage_Digest,
	input_coverages:     []Coverage_Digest,
	lookahead_coverages: []Coverage_Digest,

	// Substitution records
	substitutions:       []Substitution_Record,
}

Substitution_Record :: struct {
	sequence_index:    u16,
	lookup_list_index: u16,
}

Context_Accelerator :: struct {
	format:          u16,

	// Format 1: Rule sets based on first glyph
	rule_sets:       map[Glyph][]Context_Rule, // For Format 1

	// Format 2: Class-based approach
	class_def:       map[Glyph]u16, // Class definition table
	class_sets:      map[u16][]Context_Rule, // Rules by class

	// Format 3: Coverage-based approach
	coverage_tables: []Coverage_Digest, // Array of coverage tables

	// Shared data
	substitutions:   []Substitution_Record,
}

Context_Rule :: struct {
	// For Format 1
	input_sequence:       []Glyph, // Input sequence (excluding first glyph)

	// For Format 2
	input_classes:        []u16, // Input classes (excluding first class)

	// Shared
	substitution_records: []Substitution_Record,
}

Reverse_Chained_Accelerator :: struct {
	format:              u16, // Always 1 for Reverse Chained

	// Coverage for the target glyphs
	coverage:            Coverage_Digest,

	// Backtrack and lookahead coverages
	backtrack_coverages: []Coverage_Digest,
	lookahead_coverages: []Coverage_Digest,

	// Substitution mapping
	substitution_map:    map[Glyph]Glyph, // Original → Substitute
}

Multiple_Subst_Accelerator :: struct {
	format:       ttf.GSUB_Lookup_Type,
	coverage:     Coverage_Digest,

	// Map from input glyph to output sequence
	sequence_map: map[Glyph][]Glyph,
}

Alternate_Subst_Accelerator :: struct {
	format:        ttf.GSUB_Lookup_Type,
	coverage:      Coverage_Digest,

	// Map from input glyph to alternate options
	alternate_map: map[Glyph][]Glyph,
}

// Helper to determine if cache has GSUB acceleration
has_gsub_acceleration :: proc(cache: ^Shaping_Cache) -> bool {
	// Check if any acceleration structures are populated
	has_singles := len(cache.gsub_accel.single_subst) > 0
	has_ligatures := len(cache.gsub_accel.ligature_subst) > 0
	return has_singles || has_ligatures
}

// Build GSUB accelerator for a specific lookup
build_gsub_accelerator :: proc(font: ^Font, cache: ^Shaping_Cache) -> bool {
	gsub, has_gsub := ttf.get_table(font, "GSUB", ttf.load_gsub_table, ttf.GSUB_Table)
	if !has_gsub || cache.gsub_lookups == nil {return false}

	accel := &cache.gsub_accel

	// First pass: Identify and resolve extension lookups
	for lookup_idx in cache.gsub_lookups {
		lookup_type, lookup_flags, lookup_offset, lookup_ok := ttf.get_lookup_info(
			gsub,
			lookup_idx,
		)
		if !lookup_ok {continue}

		// If this is an extension lookup, resolve it
		if lookup_type == .Extension {
			subtable_iter, iter_ok := ttf.into_subtable_iter(gsub, lookup_idx)
			if !iter_ok {continue}

			for subtable_offset in ttf.iter_subtable_offset(&subtable_iter) {
				accelerate_extension_substitution(gsub, accel, lookup_idx, subtable_offset)
			}
		}
	}

	// Second pass: Process all lookups, including resolved extensions
	for lookup_idx in cache.gsub_lookups {
		lookup_type, lookup_flags, lookup_offset, lookup_ok := ttf.get_lookup_info(
			gsub,
			lookup_idx,
		)
		if !lookup_ok {continue}

		// Check if this is a resolved extension lookup
		if lookup_type == .Extension {
			if ext_info, has_ext := accel.extension_map[lookup_idx];
			   has_ext && !ext_info.is_processed {
				// Process the extension subtable using the resolved type
				process_lookup_subtable(
					gsub,
					accel,
					lookup_idx,
					ext_info.lookup_type,
					ext_info.extension_offset,
				)

				// Mark as processed
				ext_info.is_processed = true
				accel.extension_map[lookup_idx] = ext_info
				continue
			}
		}

		// Process regular lookup subtables
		subtable_iter, iter_ok := ttf.into_subtable_iter(gsub, lookup_idx)
		if !iter_ok {continue}

		for subtable_offset in ttf.iter_subtable_offset(&subtable_iter) {
			process_lookup_subtable(gsub, accel, lookup_idx, lookup_type, subtable_offset)
		}
	}

	build_feature_lookup_map(gsub, cache, accel)

	return true
}

// Build coverage digest for quick testing
build_coverage_digest :: proc(gsub: ^ttf.GSUB_Table, coverage_offset: uint) -> Coverage_Digest {
	digest: Coverage_Digest

	// Initialize 256-bit digest (8 u32s) to zeros
	digest.direct_map = make(map[Glyph]bool)

	// Read coverage format
	if coverage_offset + 2 > uint(len(gsub.raw_data)) {
		fmt.printf("Coverage digest: offset out of bounds %d\n", coverage_offset)
		return digest
	}

	format := ttf.read_u16(gsub.raw_data, coverage_offset)

	if format != 1 && format != 2 {
		fmt.printf("Coverage digest: invalid format %d at offset %d\n", format, coverage_offset)
		return digest
	}

	// Create a coverage iterator
	coverage_iter, coverage_ok := ttf.into_coverage_iter(gsub, 0, u16(coverage_offset))
	if !coverage_ok {return digest}

	// Process all entries in the coverage
	glyphs := make([dynamic]Glyph)
	defer delete(glyphs)

	for entry in ttf.iter_coverage_entry(&coverage_iter) {
		switch e in entry {
		case ttf.Coverage_Format1_Entry:
			// Add to digest
			glyph_id := uint(e.glyph)
			digest_idx := glyph_id / 32
			bit_pos := glyph_id % 32

			if digest_idx < 8 {
				digest.digest[digest_idx] |= (1 << bit_pos)
			}
			glyph := Glyph(e.glyph)
			// Add to direct map for small coverage sets
			digest.direct_map[glyph] = true
			append(&glyphs, glyph)

		case ttf.Coverage_Format2_Entry:
			// Add all glyphs in the range
			for gid := e.start; gid <= e.end; gid += 1 {
				glyph_id := uint(gid)
				digest_idx := glyph_id / 32
				bit_pos := glyph_id % 32

				if digest_idx < 8 {
					digest.digest[digest_idx] |= (1 << bit_pos)
				}
				glyph := Glyph(gid)
				// Add to direct map for small coverage sets
				digest.direct_map[glyph] = true
				append(&glyphs, glyph)
			}
		}
	}

	// For larger sets (more than ~50 glyphs), create a sorted array for binary search
	if len(digest.direct_map) > 50 {
		digest.sorted_glyphs = make([]Glyph, len(glyphs))
		copy(digest.sorted_glyphs, glyphs[:])
		slice.sort(digest.sorted_glyphs)
	}

	return digest
}

// Accelerate single substitution lookup
accelerate_single_substitution :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	coverage_offset: uint,
) {
	if bounds_check(subtable_offset + 4 >= uint(len(gsub.raw_data))) {return}

	format := ttf.read_u16(gsub.raw_data, subtable_offset)

	// Initialize accelerator
	single_accel := Single_Subst_Accelerator {
		format   = .Single,
		is_delta = format == 1,
		coverage = accel.coverage_digest[coverage_offset],
	}

	if format == 1 {
		// Format 1: Delta substitution
		if bounds_check(subtable_offset + 6 >= uint(len(gsub.raw_data))) {return}

		delta_glyph_id := ttf.read_i16(gsub.raw_data, subtable_offset + 4)
		single_accel.delta_value = delta_glyph_id

		// Pre-compute all mappings
		for glyph, _ in single_accel.coverage.direct_map {
			result_glyph := Glyph(int(glyph) + int(delta_glyph_id))
			single_accel.mapping[glyph] = result_glyph
		}

	} else if format == 2 {
		// Format 2: Direct mapping
		if bounds_check(subtable_offset + 6 >= uint(len(gsub.raw_data))) {return}

		glyph_count := ttf.read_u16(gsub.raw_data, subtable_offset + 4)
		substitute_offset := subtable_offset + 6

		// Create mapping from coverage to substitutes
		i := 0
		for glyph, _ in single_accel.coverage.direct_map {
			if i >= int(glyph_count) ||
			   bounds_check(substitute_offset + uint(i) * 2 >= uint(len(gsub.raw_data))) {
				i += 1
				continue
			}

			subst_glyph := ttf.Glyph(ttf.read_u16(gsub.raw_data, substitute_offset + uint(i) * 2))
			single_accel.mapping[glyph] = subst_glyph
			i += 1
		}
	}

	// Store the accelerator
	accel.single_subst[lookup_idx] = single_accel
}

// Accelerate ligature substitution lookup
accelerate_ligature_substitution :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
	coverage_offset: uint,
) {
	if bounds_check(subtable_offset + 6 >= uint(len(gsub.raw_data))) {
		return
	}

	format := ttf.read_u16(gsub.raw_data, subtable_offset)
	if format != 1 {return} 	// Only format 1 is defined for ligatures

	ligature_set_count := ttf.read_u16(gsub.raw_data, subtable_offset + 4)
	ligature_set_offset := subtable_offset + 6

	// Initialize accelerator
	lig_accel := Ligature_Subst_Accelerator {
		format          = .Ligature,
		starts_ligature = make(map[Glyph]bool),
		ligature_map    = make(map[Glyph][dynamic]Ligature_Sequence),
	}

	// Process the coverage as starting glyphs for ligatures
	for glyph, _ in accel.coverage_digest[coverage_offset].direct_map {
		lig_accel.starts_ligature[glyph] = true

		// Initialize empty dynamic array for this glyph
		lig_accel.ligature_map[glyph] = make([dynamic]Ligature_Sequence)
	}

	// Process each ligature set
	for i := 0; i < int(ligature_set_count); i += 1 {
		if bounds_check(ligature_set_offset + uint(i) * 2 >= uint(len(gsub.raw_data))) {
			continue
		}

		// Get coverage glyph based on coverage index
		coverage_iter, coverage_ok := ttf.into_coverage_iter(gsub, 0, u16(coverage_offset))
		if !coverage_ok {
			continue
		}

		// Find the glyph for this coverage index
		glyph: Glyph
		found := false

		glyph_count := 0
		for entry in ttf.iter_coverage_entry(&coverage_iter) {
			if glyph_count == i {
				switch e in entry {
				case ttf.Coverage_Format1_Entry:
					glyph = Glyph(e.glyph)
					found = true
					break
				case ttf.Coverage_Format2_Entry:
					glyph = Glyph(u16(e.start) + u16(e.start_index))
					found = true
					break
				}
			}
			glyph_count += 1
		}

		if !found {
			continue
		}

		// Get offset to ligature set
		ligature_set_ptr := ttf.read_u16(gsub.raw_data, ligature_set_offset + uint(i) * 2)
		abs_ligature_set_offset := subtable_offset + uint(ligature_set_ptr)

		if bounds_check(abs_ligature_set_offset + 2 >= uint(len(gsub.raw_data))) {
			continue
		}

		// Get number of ligatures in this set
		ligature_count := ttf.read_u16(gsub.raw_data, abs_ligature_set_offset)
		ligature_array_offset := abs_ligature_set_offset + 2

		// Process each ligature
		for j := 0; j < int(ligature_count); j += 1 {
			if bounds_check(ligature_array_offset + uint(j) * 2 >= uint(len(gsub.raw_data))) {
				continue
			}

			// Get offset to ligature
			ligature_offset := ttf.read_u16(gsub.raw_data, ligature_array_offset + uint(j) * 2)
			abs_ligature_offset := abs_ligature_set_offset + uint(ligature_offset)

			if bounds_check(abs_ligature_offset + 4 >= uint(len(gsub.raw_data))) {
				continue
			}

			// Read ligature glyph and component count
			ligature_glyph := ttf.Glyph(ttf.read_u16(gsub.raw_data, abs_ligature_offset))
			component_count := ttf.read_u16(gsub.raw_data, abs_ligature_offset + 2)
			components_array_offset := abs_ligature_offset + 4

			// Need at least 2 components for a ligature (including first glyph)
			if component_count < 2 ||
			   bounds_check(
				   components_array_offset + uint(component_count - 2) * 2 >=
				   uint(len(gsub.raw_data)),
			   ) {
				continue
			}

			// Create component array (first component is the coverage glyph)
			components := make([]Glyph, component_count)
			components[0] = glyph

			// Read remaining components
			for k := 0; k < int(component_count) - 1; k += 1 {
				components[k + 1] = ttf.Glyph(
					ttf.read_u16(gsub.raw_data, components_array_offset + uint(k) * 2),
				)
			}

			// Create ligature sequence
			sequence := Ligature_Sequence {
				components = components,
				ligature   = ligature_glyph,
			}

			// Add to mapping
			seq_arr := &lig_accel.ligature_map[glyph]
			append(seq_arr, sequence)

			// fmt.printf(
			// 	"Adding ligature sequence for glyph %d: components %v -> ligature %d\n",
			// 	glyph,
			// 	components,
			// 	ligature_glyph,
			// )
		}
	}

	accel.ligature_subst[lookup_idx] = lig_accel
}

// Accelerate extension substitution by resolving the actual lookup type
accelerate_extension_substitution :: proc(
	gsub: ^ttf.GSUB_Table,
	accel: ^GSUB_Accelerator,
	lookup_idx: u16,
	subtable_offset: uint,
) {
	if bounds_check(subtable_offset + 8 >= uint(len(gsub.raw_data))) {
		return
	}

	format := ttf.read_u16(gsub.raw_data, subtable_offset)
	if format != 1 {return} 	// Only format 1 is defined for extension substitution

	// Read extension lookup type and offset
	extension_lookup_type := ttf.GSUB_Lookup_Type(ttf.read_u16(gsub.raw_data, subtable_offset + 2))
	extension_offset := ttf.read_u32(gsub.raw_data, subtable_offset + 4)

	// Calculate absolute offset to the actual lookup subtable
	abs_extension_offset := subtable_offset + uint(extension_offset)

	// Store extension resolution info
	ext_info := Extension_Info {
		lookup_type      = extension_lookup_type,
		extension_offset = abs_extension_offset,
		is_processed     = false, // Will be processed later
	}
	// fmt.printf(
	// 	"Extension: lookup_idx=%d, type=%v, offset=%d, absolute=%d\n",
	// 	lookup_idx,
	// 	extension_lookup_type,
	// 	extension_offset,
	// 	abs_extension_offset,
	// )

	accel.extension_map[lookup_idx] = ext_info
}


// Build feature to lookup mapping for faster feature selection
build_feature_lookup_map :: proc(
	gsub: ^ttf.GSUB_Table,
	cache: ^Shaping_Cache,
	accel: ^GSUB_Accelerator,
) {
	feature_iter, iter_ok := ttf.into_feature_iter_gsub(gsub, cache.gsub_lang_sys_offset)
	if !iter_ok {return}

	for feature_index, record, feature_offset in ttf.iter_feature_gsub(&feature_iter) {
		feature_tag := Feature_Tag(ttf.tag_to_u32(record.feature_tag))

		lookup_iter, lookup_ok := ttf.into_lookup_iter(gsub.raw_data, feature_offset)
		if !lookup_ok {continue}

		lookups := make([dynamic]u16)
		for lookup_index in ttf.iter_lookup_index(&lookup_iter) {
			append(&lookups, lookup_index)
		}

		accel.feature_lookups[feature_tag] = lookups[:]
	}
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Apply GSUB using accelerator
// Check if a glyph is in a coverage digest
is_glyph_in_coverage :: proc(digest: Coverage_Digest, glyph: Glyph) -> bool {
	// Quick rejection test using the bloom filter
	glyph_id := uint(glyph)
	digest_idx := glyph_id / 32
	bit_pos := glyph_id % 32

	// If the bit isn't set in the digest, the glyph is definitely not covered
	if digest_idx >= 8 || (digest.digest[digest_idx] & (1 << bit_pos)) == 0 {
		return false
	}

	// Potential match, check for exact match
	if len(digest.direct_map) > 0 {
		// For small coverage sets, check direct map
		if _, in_coverage := digest.direct_map[glyph]; in_coverage {
			return true
		}
	} else if len(digest.sorted_glyphs) > 0 {
		// For larger sets, use binary search
		low, high := 0, len(digest.sorted_glyphs) - 1
		for low <= high {
			mid := (low + high) / 2
			if digest.sorted_glyphs[mid] < glyph {
				low = mid + 1
			} else if digest.sorted_glyphs[mid] > glyph {
				high = mid - 1
			} else {
				return true
			}
		}
	}

	// Not found in the precise check
	return false
}

apply_gsub_with_accelerator :: proc(
	font: ^Font,
	buffer: ^Shaping_Buffer,
	cache: ^Shaping_Cache,
) -> bool {
	assert(cache != nil)

	gsub, has_gsub := ttf.get_table(font, "GSUB", ttf.load_gsub_table, ttf.GSUB_Table)
	if !has_gsub {return false}

	accel := &cache.gsub_accel

	// Apply each lookup in the optimized order
	for lookup_idx in cache.gsub_lookups {
		lookup_type, lookup_flags, lookup_offset, ok := ttf.get_lookup_info(gsub, lookup_idx)
		if !ok {continue}

		// If this is an extension lookup, use the resolved type
		actual_lookup_type := lookup_type
		if lookup_type == .Extension {
			if ext_info, has_ext := accel.extension_map[lookup_idx]; has_ext {
				actual_lookup_type = ext_info.lookup_type
			} else {
				// No extension info available, fall back to standard handling
				apply_lookup(gsub, lookup_idx, lookup_type, lookup_flags, buffer)
				continue
			}
		}

		// Apply lookup based on resolved type
		#partial switch actual_lookup_type {
		case .Single:
			if single_accel, has_accel := accel.single_subst[lookup_idx]; has_accel {
				apply_accelerated_single_subst(buffer, single_accel, lookup_flags)
			} else {
				apply_lookup_fallback(gsub, buffer, lookup_idx, lookup_type, lookup_flags, accel)
			}
		case .Ligature:
			if lig_accel, has_accel := accel.ligature_subst[lookup_idx]; has_accel {
				apply_accelerated_ligature_subst(buffer, lig_accel, lookup_flags)
			} else {
				apply_lookup_fallback(gsub, buffer, lookup_idx, lookup_type, lookup_flags, accel)
			}

		// Other cases fall back to standard implementation
		case:
			apply_lookup_fallback(gsub, buffer, lookup_idx, lookup_type, lookup_flags, accel)
		}
	}
	apply_lookup_fallback :: proc(
		gsub: ^ttf.GSUB_Table,
		buffer: ^Shaping_Buffer,
		lookup_idx: u16,
		lookup_type: ttf.GSUB_Lookup_Type,
		lookup_flags: ttf.Lookup_Flags,
		accel: ^GSUB_Accelerator,
	) {
		if lookup_type == .Extension {
			// For extensions, apply using the resolved subtable
			if ext_info, has_ext := accel.extension_map[lookup_idx]; has_ext {
				apply_standard_lookup_at_offset(
					gsub,
					buffer,
					lookup_idx,
					ext_info.lookup_type,
					lookup_flags,
					ext_info.extension_offset,
				)
			} else {
				// Fall back to regular extension handling
				apply_lookup(gsub, lookup_idx, lookup_type, lookup_flags, buffer)
			}
		} else {
			// Regular lookup
			apply_lookup(gsub, lookup_idx, lookup_type, lookup_flags, buffer)
		}
	}
	return true
}

// Apply accelerated single substitution
apply_accelerated_single_subst :: proc(
	buffer: ^Shaping_Buffer,
	accel: Single_Subst_Accelerator,
	lookup_flags: ttf.Lookup_Flags,
) {
	for i := 0; i < len(buffer.glyphs); i += 1 {
		glyph_info := &buffer.glyphs[i]

		if should_skip_glyph(glyph_info.category, lookup_flags) {continue}
		if !is_glyph_in_coverage(accel.coverage, glyph_info.glyph_id) {continue}

		if subst_glyph, found := accel.mapping[glyph_info.glyph_id]; found {
			glyph_info.glyph_id = subst_glyph
			glyph_info.flags += {.Substituted}
		}
	}
}

// Apply accelerated ligature substitution
apply_accelerated_ligature_subst :: proc(
	buffer: ^Shaping_Buffer,
	accel: Ligature_Subst_Accelerator,
	lookup_flags: ttf.Lookup_Flags,
) {
	// Process each glyph as a potential ligature start
	pos := 0
	for pos < len(buffer.glyphs) {
		first_glyph := &buffer.glyphs[pos]

		// Skip if this glyph should be ignored based on lookup flags
		if should_skip_glyph(first_glyph.category, lookup_flags) {
			pos += 1
			continue
		}

		// Quick check if this glyph can start a ligature
		if !accel.starts_ligature[first_glyph.glyph_id] {
			pos += 1
			continue
		}

		// Try to find a ligature match for this glyph
		ligature_found := false

		if sequences, has_sequences := accel.ligature_map[first_glyph.glyph_id]; has_sequences {
			for sequence in sequences {
				// Try to match this ligature sequence
				matched := true
				curr_pos := pos + 1
				next_comp := 1 // Start matching from second component

				// Try to match remaining components
				for next_comp < len(sequence.components) {
					// Skip glyphs that should be ignored based on lookup flags
					for curr_pos < len(buffer.glyphs) {
						if curr_pos >= len(buffer.glyphs) {
							matched = false
							break
						}

						if !should_skip_glyph(buffer.glyphs[curr_pos].category, lookup_flags) {
							break
						}
						curr_pos += 1
					}

					// Check if we've gone beyond the end of the buffer
					if curr_pos >= len(buffer.glyphs) {
						matched = false
						break
					}

					// Check if the current glyph matches this component
					if buffer.glyphs[curr_pos].glyph_id != sequence.components[next_comp] {
						matched = false
						break
					}

					// Move to next component
					next_comp += 1
					curr_pos += 1
				}

				if matched {
					// We found a ligature match - apply it
					component_count := len(sequence.components)

					// Get earliest cluster value among the components
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
					first_glyph.glyph_id = sequence.ligature
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
					break // Stop after first match
				}
			}
		}

		// If we found a ligature, we don't advance pos since the new ligature
		// might participate in another ligature in the next iteration
		if !ligature_found {
			pos += 1
		}
	}
}
