package shaper

import ttf "../ttf"
import "base:runtime"
import "core:unicode/utf8"

CMAP_Accelerator :: struct {
	ascii_direct:  [128]Glyph,
	sparse_map:    map[rune]Glyph,
	// For variation selectors
	variation_map: map[rune]map[rune]Glyph, // base char -> variation selector -> glyph
}


// Get a glyph using the accelerator
get_glyph_accelerated :: proc(
	accel: ^CMAP_Accelerator,
	codepoint: rune,
	variation_selector: rune = 0,
) -> (
	Glyph,
	bool,
) {
	// Check for variation selector
	if variation_selector != 0 {
		if base_map, has_base := accel.variation_map[codepoint]; has_base {
			if glyph, has_var := base_map[variation_selector]; has_var {
				return glyph, true
			}
		}
	}

	// Fast path for ASCII
	if codepoint < 128 {
		glyph := accel.ascii_direct[codepoint]
		return glyph, glyph != 0
	}
	// Fallback to sparse map
	glyph, found := accel.sparse_map[codepoint]

	// TODO: Variation Selectors

	return glyph, found
}

/////////////////////////////////////////////////////////////////////////


// Initialize the CMAP accelerator based on script
build_cmap_accelerator :: proc(font: ^Font, cache: ^Shaping_Cache, script: Script_Tag) -> bool {
	// Initialize the accelerator
	accel := &cache.cmap_accel
	smap, err := runtime.make_map_cap(map[rune]Glyph, 512)
	assert(err == nil)
	accel.sparse_map = smap

	// Get the cmap table
	cmap_table, has_cmap := ttf.get_table(font, "cmap", ttf.load_cmap_table, ttf.CMAP_Table)
	if !has_cmap {
		return false
	}

	// Clear existing data if any
	clear(&accel.sparse_map)
	clear(&accel.variation_map)

	// Always fill ASCII for any script (ASCII is almost always present)
	for codepoint: rune = 0; codepoint < 128; codepoint += 1 {
		glyph, found := ttf.get_glyph_from_cmap(font, codepoint)
		if found {
			accel.ascii_direct[codepoint] = glyph
		}
	}

	// Populate the sparse map based on script
	unicode_range_start, unicode_range_end: rune

	// Determine which Unicode range to preload based on script
	#partial switch script { 	// TODO: rest of scripts
	case .latn:
		// Latin script - Basic Latin + Latin Extended A/B
		unicode_range_start = 0x0000
		unicode_range_end = 0x024F

	case .cyrl:
		// Cyrillic script
		unicode_range_start = 0x0400
		unicode_range_end = 0x052F

	case .grek:
		// Greek script
		unicode_range_start = 0x0370
		unicode_range_end = 0x03FF

	case .arab:
		// Arabic script
		unicode_range_start = 0x0600
		unicode_range_end = 0x06FF

	case .hebr:
		// Hebrew script
		unicode_range_start = 0x0590
		unicode_range_end = 0x05FF

	case .deva, .dev2, .beng, .guru, .gujr, .orya, .taml, .telu, .knda, .mlym, .sinh:
		// Indic scripts - pick appropriate range
		#partial switch script { 	// TODO: rest of scripts
		case .deva, .dev2:
			unicode_range_start, unicode_range_end = 0x0900, 0x097F
		case .beng:
			unicode_range_start, unicode_range_end = 0x0980, 0x09FF
		case .guru:
			unicode_range_start, unicode_range_end = 0x0A00, 0x0A7F
		case .gujr:
			unicode_range_start, unicode_range_end = 0x0A80, 0x0AFF
		case .orya:
			unicode_range_start, unicode_range_end = 0x0B00, 0x0B7F
		case .taml:
			unicode_range_start, unicode_range_end = 0x0B80, 0x0BFF
		case .telu:
			unicode_range_start, unicode_range_end = 0x0C00, 0x0C7F
		case .knda:
			unicode_range_start, unicode_range_end = 0x0C80, 0x0CFF
		case .mlym:
			unicode_range_start, unicode_range_end = 0x0D00, 0x0D7F
		case .sinh:
			unicode_range_start, unicode_range_end = 0x0D80, 0x0DFF
		}

	case .hani, .hans, .hant:
		// CJK ideographs - these are huge ranges, consider if preloading is worth it
		if script == .hans {
			// For simplified Chinese, just do a smaller range
			unicode_range_start = 0x4E00
			unicode_range_end = 0x9FFF
		}

	case .jpan, .hira, .kana:
		// Japanese script
		if script == .hira {
			unicode_range_start, unicode_range_end = 0x3040, 0x309F
		} else if script == .kana {
			unicode_range_start, unicode_range_end = 0x30A0, 0x30FF
		} else {
			// For general Japanese, load both Hiragana and Katakana
			unicode_range_start, unicode_range_end = 0x3040, 0x30FF
		}

	case .hang, .kore:
		// Korean script - Hangul is huge, consider if preloading is worth it
		if script == .hang {
			unicode_range_start, unicode_range_end = 0xAC00, 0xD7AF
		}
	}

	// Populate sparse map with the Unicode range for this script
	if unicode_range_start != 0 || unicode_range_end != 0 {
		for codepoint := unicode_range_start; codepoint <= unicode_range_end; codepoint += 1 {
			// Skip ASCII range as it's already in ascii_direct
			if codepoint < 128 {
				continue
			}

			glyph, found := ttf.get_glyph_from_cmap(font, codepoint)
			if found {
				accel.sparse_map[codepoint] = glyph
			}
		}
	}

	// Process variation selector mappings if we have format 14 subtables
	// for subtable_idx := 0; subtable_idx < len(cmap_table.subtables); subtable_idx += 1 {
	// 	subtable := &cmap_table.subtables[subtable_idx]

	// 	if subtable.format == .Unicode_Variation_Seq {
	// 		if f14, is_f14 := subtable.data.(^Format14); is_f14 {
	// 			// Process variation selectors
	// 			// [same as before - variation selector processing]
	// 		}
	// 	}
	// }

	return true
}
