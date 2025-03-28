package shaper

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
	cmap_accel:           CMAP_Accelerator,
	gsub_accel:           GSUB_Accelerator,
	metrics:              map[Glyph]ttf.Glyph_Metrics, // TODO: make this a dense array (920kb for full dense@65k glyphs)
}

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
	// Preload GDEF & htmx to get the 'hit' during cache creation
	ttf.get_table(font, "GDEF", ttf.load_gdef_table, ttf.GDEF_Table)
	ttf.get_table(font, "htmx", ttf.load_hmtx_table, ttf.OpenType_Hmtx_Table)

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
		key     = cache_key,
		metrics = make(map[Glyph]ttf.Glyph_Metrics),
	}
	has_shaping_data := false

	build_cmap_accelerator(font, &new_cache, script)

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

	build_gsub_accelerator(font, &new_cache)


	// --- Process GPOS lookups ---
	gpos, has_gpos := ttf.get_table(font, "GPOS", ttf.load_gpos_table, ttf.GPOS_Table)
	if has_gpos {
		// fmt.println("---- Processing GPOS ----")
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
		// fmt.println("GSUB Lookups", new_cache.gsub_lookups)
		// fmt.println("GPOS Lookups", new_cache.gpos_lookups)
		engine.caches[cache_key] = new_cache
		return &engine.caches[cache_key]
	}

	return nil
}
