package shaper

import ttf "../ttf"

map_runes_to_glyphs :: proc(font: ^Font, buffer: ^Shaping_Buffer, cache: ^Shaping_Cache = nil) {
	if buffer == nil || len(buffer.runes) == 0 {return}

	// Ensure we have enough capacity in the glyphs array
	reserve(&buffer.glyphs, len(buffer.runes))

	// Get GDEF table if available
	gdef, has_gdef := ttf.get_table(font, .GDEF, ttf.load_gdef_table, ttf.GDEF_Table)

	// -vet said it was unused, but without it we can't call determine_glyph_category
	// Perhaps `map_runes_to_glyphs` should return an error?
	// Alternatively, if an OTF/TTF *must* contain this table, we can sanity check its existence when loading a font,
	// so we can remove this return value.
	assert(has_gdef)

	// Determine if we need to process in visual RTL order
	is_rtl := buffer.direction == .Right_To_Left

	// Check if we have an accelerator
	has_accelerator := cache != nil && len(cache.cmap_accel.sparse_map) > 0

	// First pass: Map runes to glyphs with basic properties
	for idx: uint = 0; idx < uint(len(buffer.runes)); idx += 1 {
		// Calculate logical index based on text direction
		i := is_rtl ? uint(len(buffer.runes)) - 1 - idx : idx

		codepoint := buffer.runes[i]
		next_codepoint: rune = 0

		// Calculate the adjacent index based on text direction
		next_i := is_rtl ? i - 1 : i + 1

		// Look ahead for variation selectors
		if next_i < uint(len(buffer.runes)) && next_i >= 0 {
			next_codepoint = buffer.runes[next_i]
			is_variation_selector :=
				next_codepoint >= 0xFE00 && next_codepoint <= 0xFE0F ||
				next_codepoint >= 0xE0100 && next_codepoint <= 0xE01EF

			if is_variation_selector {
				var_gid: Glyph
				var_found := false

				// Use accelerator if available
				if has_accelerator {
					var_gid, var_found = get_glyph_accelerated(
						&cache.cmap_accel,
						codepoint,
						next_codepoint,
					)
				} else {
					// Fall back to standard lookup
					var_gid, var_found = ttf.get_variation_selector_glyph(
						font,
						codepoint,
						next_codepoint,
					)
				}

				if var_found {
					// Create the glyph with the variation
					glyph_info := Glyph_Info {
						glyph_id = var_gid,
						cluster  = i,
						category = ttf.determine_glyph_category(gdef, var_gid, codepoint),
						flags    = {},
					}
					append(&buffer.glyphs, glyph_info)

					// Skip the variation selector in the next iteration
					idx += 1
					continue
				}
				// If variation not found, fall through to normal processing
			}
		}

		// Standard glyph mapping
		gid: Glyph
		ok: bool

		// Use accelerator if available
		if has_accelerator {
			gid, ok = get_glyph_accelerated(&cache.cmap_accel, codepoint)
		} else {
			gid, ok = ttf.get_glyph_from_cmap(font, codepoint)
		}

		// Try decomposition if standard mapping fails
		if !ok {
			clear(&buffer.scratch.decomposition)
			// Try decomposition for complex characters
			if ttf.get_glyph_by_decomp(font, &buffer.scratch.decomposition, codepoint) {
				// TODO: Handle decomposition
			}
		}

		// Handle invisible/ignorable characters
		is_default_ignorable := ttf.is_default_ignorable_char(codepoint)

		// Check if this is a mark that needs a dotted circle
		needs_dotted_circle := false
		if .Do_Not_Insert_Dotted_Circle not_in buffer.control_flags {
			// For RTL text, need to check the previous character which is actually
			// the next index in the logical order
			prev_i := is_rtl ? i + 1 : i - 1

			if ttf.unichar_is_mark(codepoint) &&
			   (i == 0 ||
					   prev_i >= uint(len(buffer.runes)) ||
					   ttf.is_default_ignorable_char(buffer.runes[prev_i])) {
				needs_dotted_circle = true
			}
		}

		// Insert dotted circle if needed
		if needs_dotted_circle {
			dotted_circle_gid: Glyph
			has_dotted_circle: bool

			// Use accelerator if available
			if has_accelerator {
				dotted_circle_gid, has_dotted_circle = get_glyph_accelerated(
					&cache.cmap_accel,
					0x25CC,
				)
			} else {
				dotted_circle_gid, has_dotted_circle = ttf.get_glyph_from_cmap(font, 0x25CC)
			}

			if has_dotted_circle {
				dotted_circle := Glyph_Info {
					glyph_id = dotted_circle_gid,
					cluster  = i,
					category = .Base,
					flags    = {},
				}
				append(&buffer.glyphs, dotted_circle)
			}
		}

		// Create the regular glyph info
		glyph_info := Glyph_Info {
			glyph_id = ok ? gid : 0, // Use 0 (missing glyph) if not found
			cluster  = i,
			category = ttf.determine_glyph_category(gdef, gid, codepoint),
			flags    = is_default_ignorable ? {.Default_Ignorable} : {},
		}

		append(&buffer.glyphs, glyph_info)
	}

	// If RTL, the glyphs are now in reverse order of the original text
	// This is correct for display but we need to fix the clustering

	// Second pass: Apply buffer-wide processing
	if .Remove_Default_Ignorables in buffer.control_flags {
		// Filter out default ignorables
		i := 0
		for i < len(buffer.glyphs) {
			if .Default_Ignorable in buffer.glyphs[i].flags {
				ordered_remove(&buffer.glyphs, i)
				// Don't increment i since we need to check the new element at this position
			} else {
				i += 1
			}
		}
	}
}

/////////////////////////////////////////////////////////////////////////
