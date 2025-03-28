package shaper

import ttf "../ttf"
import "core:fmt"
import "core:unicode/utf8"

// Main shaping entry point that leverages the engine and cache
shape_text_with_font :: proc(
	engine: ^Rune,
	font_id: Font_ID,
	text: string,
	script: Script_Tag = .latn,
	language: Language_Tag = .dflt,
	requested_features: Feature_Set = {},
	disabled_features: Feature_Set = {},
	clustering_policy: Clustering_Policy = .Preserve_Character_Ordering,
) -> (
	buffer: ^Shaping_Buffer,
	ok: bool,
) {
	// Validate inputs
	identity, found := engine.loaded_fonts[font_id]
	if !found {
		fmt.eprintln("Font ID not found:", font_id)
		return nil, false
	}
	font := identity.font
	// Use default features if none specified
	actual_features := requested_features
	if is_feature_set_empty(actual_features) {
		actual_features = get_default_features(script)
	}

	// Get buffer from the engine pool
	buffer = get_buffer(engine)

	// Prepare the buffer for shaping
	prepare_text(buffer, text)
	set_script(buffer, script, language)
	buffer.clustering_policy = clustering_policy

	// Get or create the shaping cache for both GSUB and GPOS
	cache := get_or_create_shape_cache(
		engine,
		font,
		script,
		language,
		actual_features,
		disabled_features,
	)

	// Shape the text with the buffer and cache
	ok = shape_with_cache(engine, font, buffer, cache)
	if !ok {
		release_buffer(engine, buffer)
		return nil, false
	}

	return buffer, true
}


// Shape text using the cached data
// Shape text using the cached data
shape_with_cache :: proc(
	engine: ^Rune,
	font: ^Font,
	buffer: ^Shaping_Buffer,
	cache: ^Shaping_Cache,
) -> (
	ok: bool,
) {
	if buffer == nil {return false}

	// Map runes to initial glyphs (1:1 mapping)
	reserve(&buffer.glyphs, len(buffer.runes))
	map_runes_to_glyphs(font, buffer, cache)


	// for gi in buffer.glyphs {
	// 	fmt.printf("%v -> %v \n", buffer.runes[gi.cluster], gi.glyph_id)
	// }

	// If cache couldn't be created, fall back to basic shaping
	if cache == nil {
		return shape_text_basic_with_buffer(font, buffer)
	}

	// Apply substitutions (GSUB)
	gsub, has_gsub := ttf.get_table(font, "GSUB", ttf.load_gsub_table, ttf.GSUB_Table)
	if has_gsub && len(cache.gsub_lookups) > 0 {
		// Check if we have acceleration structures built
		if len(cache.gsub_accel.single_subst) > 0 || len(cache.gsub_accel.ligature_subst) > 0 {
			apply_gsub_with_accelerator(font, buffer, cache)
		} else {
			// Fall back to standard lookup application
			apply_gsub_lookups(gsub, cache.gsub_lookups, buffer)
		}
	}

	// Allocate and initialize glyph positions
	resize(&buffer.positions, len(buffer.glyphs))

	// Initialize positions with zero values
	for i := 0; i < len(buffer.positions); i += 1 {
		buffer.positions[i] = Glyph_Position {
			x_advance = 0,
			y_advance = 0,
			x_offset  = 0,
			y_offset  = 0,
		}
	}

	// Apply basic positioning first
	apply_basic_positioning(font, buffer, cache)

	// Apply positioning (GPOS)
	gpos, has_gpos := ttf.get_table(font, "GPOS", ttf.load_gpos_table, ttf.GPOS_Table)
	if has_gpos && len(cache.gpos_lookups) > 0 {
		// Apply positioning lookups from the cache
		apply_positioning_lookups(gpos, cache.gpos_lookups, buffer)
	}

	return true
}

shape_text_basic_with_buffer :: proc(font: ^Font, buffer: ^Shaping_Buffer) -> (ok: bool) {
	if buffer == nil {return false}

	// Apply basic positioning
	apply_basic_positioning(font, buffer, nil)

	return true
}

// Convenience wrapper for retrieving and shaping a string
shape_string :: proc(
	engine: ^Rune,
	font_id: Font_ID,
	text: string,
) -> (
	buffer: ^Shaping_Buffer,
	ok: bool,
) {
	// Use default settings from the engine
	return shape_text_with_font(
		engine,
		font_id,
		text,
		engine.default_script,
		engine.default_language,
		engine.default_features,
		{}, // No disabled features
		.Preserve_Character_Ordering,
	)
}
