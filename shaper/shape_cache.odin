package rune

import ttf "../ttf"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:time"
import "core:unicode/utf8"

Shaping_Cache_Key :: struct {
	font_id:           ^Font, // Unique identifier for the font
	script:            Script_Tag, // Script being shaped
	language:          Language_Tag, // Language for shaping
	features:          Feature_Set, // Enabled features
	disabled_features: Feature_Set, // Explicitly disabled features
	// features_hash:     uint, // todo: convert features into a hash
}

Shaping_Cache :: struct {
	// Cache key components
	using key:            Shaping_Cache_Key,

	// Optimization data
	gsub_lookups:         []u16, // Cached array of lookup indices to apply
	gsub_script_record:   ^ttf.OpenType_Script_Record,
	gsub_script_offset:   uint, // Absolute offset to script table
	gsub_lang_sys_offset: uint, // Absolute offset to language system

	// Additional fields for GPOS
	gpos_lookups:         []u16, // Cached array of GPOS lookup indices
	gpos_script_record:   ^ttf.OpenType_Script_Record,
	gpos_script_offset:   uint, // Absolute offset to GPOS script table
	gpos_lang_sys_offset: uint, // Absolute offset to GPOS language system
	// coverage_accelerators: map[uint]Coverage_Accelerator, // index is abs offset of entire file
}

// Coverage_Accelerator :: struct {
// 	table_offset: uint, // Offset to coverage table
// 	format:       u16, // Format of coverage table (1 or 2)

// 	// For Format 1 (direct array)
// 	glyphs:       []Glyph, // Sorted array of covered glyphs

// 	// For Format 2 (ranges)
// 	ranges:       []struct {
// 		// Array of range records
// 		start: Glyph, // First glyph in range 
// 		end:   Glyph, // Last glyph in range
// 		index: u16, // Starting coverage index
// 	},
// }

// Get or create a shaping cache entry
//
// Returns `nil` if there is no gsub table
// Get or create a shaping cache entry
//
// Returns `nil` if there is no gsub table
// Get or create a shaping cache entry
//
// Returns `nil` if there are no applicable shaping tables

// // Debug: Print features that will be applied
// feats := get_enabled_features(applied_features)
// fmt.print("Applied GPOS Features: ")
// for f in feats {
// 	fmt.printf("%v, ", f)
// }
// fmt.println()
// fmt.println("GPOS lookup indices:", gpos_lookup_indices[:])
get_or_create_shape_cache :: proc(
	engine: ^Rune,
	font: ^Font,
	script: Script_Tag,
	language: Language_Tag,
	features: Feature_Set,
	disabled_features: Feature_Set,
) -> (
	cache: ^Shaping_Cache,
) {
	// Create cache key
	cache_key := Shaping_Cache_Key {
		font_id           = font,
		script            = script,
		language          = language,
		features          = features,
		disabled_features = disabled_features,
	}

	// Check if we already have this cache entry
	if cached, found := &engine.caches[cache_key]; found {
		engine.cache_hits += 1
		return cached
	} else {
		engine.cache_misses += 1
	}

	// Initialize cache structure
	new_cache := Shaping_Cache {
		key = cache_key,
	}
	has_shaping_data := false

	// --- Process GSUB lookups ---
	gsub, has_gsub := ttf.get_table(font, "GSUB", ttf.load_gsub_table, ttf.GSUB_Table)
	if has_gsub {
		// Find language system
		gsub_script_record, gsub_script_offset, gsub_lang_sys_offset, gsub_found :=
			find_language_system_gsub(gsub, script, language)

		if gsub_found {
			has_shaping_data = true

			// Store script and language system info
			new_cache.gsub_script_record = gsub_script_record
			new_cache.gsub_script_offset = gsub_script_offset
			new_cache.gsub_lang_sys_offset = gsub_lang_sys_offset

			feature_index, _, feature_offset, has_required := get_required_feature_gsub(
				gsub,
				gsub_lang_sys_offset,
			)
			gsub_processed_lookups: Lookup_Set
			gsub_lookup_indices := make([dynamic]u16)

			if has_required {
				fmt.printf("Adding required GSUB feature (index %d)\n", feature_index)
				lookup_list_offset := uint(gsub.header.lookup_list_offset)

				lookup_iter, ok := ttf.into_lookup_iter(gsub.raw_data, feature_offset)
				if !ok {return}

				for lookup_index in ttf.iter_lookup_index(&lookup_iter) {
					if !lookup_set_try_add(&gsub_processed_lookups, lookup_index) {
						append(&gsub_lookup_indices, lookup_index)
						fmt.println("Added Required Index", lookup_index)
					}
				}
			}
			// Get number of features in this language system
			if !bounds_check(gsub_lang_sys_offset + 6 > uint(len(gsub.raw_data))) {
				feature_count := read_u16(gsub.raw_data, gsub_lang_sys_offset + 4)

				if feature_count > 0 {
					// Get script-specific feature stages and required stage count
					feature_stages, required_stages := get_script_feature_stages(script)

					// Combine selected features with default features, respecting disabled features
					features_to_apply := select_features_to_apply(
						script,
						features,
						disabled_features,
					)

					// Use the helper function to collect all lookups
					ok := collect_feature_lookups(
						gsub.raw_data,
						uint(feature_count),
						feature_stages,
						required_stages,
						&features_to_apply,
						gsub_lang_sys_offset,
						uint(gsub.header.feature_list_offset),
						uint(gsub.header.lookup_list_offset),
						&gsub_processed_lookups,
						&gsub_lookup_indices,
					)

					if ok {
						new_cache.gsub_lookups = gsub_lookup_indices[:]
					} else {
						delete(gsub_lookup_indices)
						return
					}
				}
			}
		}
	}

	// --- Process GPOS lookups ---
	gpos, has_gpos := ttf.get_table(font, "GPOS", ttf.load_gpos_table, ttf.GPOS_Table)
	if has_gpos {
		fmt.println("---- Processing GPOS ----")
		// Find language system for GPOS
		gpos_script_record, gpos_script_offset, gpos_lang_sys_offset, gpos_found :=
			find_language_system_gpos(gpos, script, language)

		if gpos_found {
			has_shaping_data = true

			// Store script and language system info
			new_cache.gpos_script_record = gpos_script_record
			new_cache.gpos_script_offset = gpos_script_offset
			new_cache.gpos_lang_sys_offset = gpos_lang_sys_offset

			feature_index, _, feature_offset, has_required := get_required_feature_gpos(
				gpos,
				gpos_lang_sys_offset,
			)

			gpos_processed_lookups: Lookup_Set
			gpos_lookup_indices := make([dynamic]u16)

			if has_required {
				fmt.printf("Adding required gpos feature (index %d)\n", feature_index)
				lookup_list_offset := uint(gpos.header.lookup_list_offset)

				lookup_iter, ok := ttf.into_lookup_iter(gpos.raw_data, feature_offset)
				if !ok {
					delete(new_cache.gsub_lookups)
					delete(gpos_lookup_indices)
					return
				}

				for lookup_index in ttf.iter_lookup_index(&lookup_iter) {
					if !lookup_set_try_add(&gpos_processed_lookups, lookup_index) {
						append(&gpos_lookup_indices, lookup_index)
					}
				}
			}

			// Get number of features in this language system
			if !bounds_check(gpos_lang_sys_offset + 6 > uint(len(gpos.raw_data))) {
				feature_count := read_u16(gpos.raw_data, gpos_lang_sys_offset + 4)

				if feature_count > 0 {
					// Get script-specific feature stages and required stage count
					feature_stages, required_stages := get_script_feature_stages(script)

					// Combine selected features with default features, respecting disabled features
					features_to_apply := select_features_to_apply(
						script,
						features,
						disabled_features,
					)

					// Use the helper function to collect all lookups
					ok := collect_feature_lookups(
						gpos.raw_data,
						uint(feature_count),
						feature_stages,
						required_stages,
						&features_to_apply,
						gpos_lang_sys_offset,
						uint(gpos.header.feature_list_offset),
						uint(gpos.header.lookup_list_offset),
						&gpos_processed_lookups,
						&gpos_lookup_indices,
					)

					if ok {
						new_cache.gpos_lookups = gpos_lookup_indices[:]
					} else {
						delete(new_cache.gsub_lookups)
						delete(gpos_lookup_indices)
						return
					}
				}
			}
		}
	}

	if has_shaping_data {
		fmt.println("Created Shaping_Cache")
		fmt.println("GSUB Lookups", new_cache.gsub_lookups)
		fmt.println("GPOS Lookups", new_cache.gpos_lookups)
		engine.caches[cache_key] = new_cache
		return &engine.caches[cache_key]
	}

	return nil
}

// is_glyph_covered :: proc(acc: ^Coverage_Accelerator, glyph: Glyph) -> (index: u16, covered: bool) {
// 	if acc.format == 1 {
// 		// Binary search in sorted array
// 		low, high := 0, len(acc.glyphs) - 1
// 		for low <= high {
// 			mid := (low + high) >> 1
// 			if acc.glyphs[mid] < glyph {
// 				low = mid + 1
// 			} else if acc.glyphs[mid] > glyph {
// 				high = mid - 1
// 			} else {
// 				return u16(mid), true
// 			}
// 		}
// 	} else { 	// Format 2
// 		// Binary search in ranges
// 		low, high := 0, len(acc.ranges) - 1
// 		for low <= high {
// 			mid := (low + high) >> 1
// 			if acc.ranges[mid].end < glyph {
// 				low = mid + 1
// 			} else if acc.ranges[mid].start > glyph {
// 				high = mid - 1
// 			} else {
// 				// Glyph is in this range
// 				index := acc.ranges[mid].index + u16(glyph - acc.ranges[mid].start)
// 				return index, true
// 			}
// 		}
// 	}
// 	return 0, false
// }

// // Then look up or create the accelerator
// accelerator, exists := cache.coverage_accelerators[absolute_coverage_offset]
// if !exists {
//     accelerator = create_coverage_accelerator(font.data, absolute_coverage_offset)
//     cache.coverage_accelerators[absolute_coverage_offset] = accelerator
// }
