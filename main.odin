package main

import "core:fmt"
import "core:os"
import "core:unicode/utf8"

import shaper "./shaper"
import ttf "./ttf"

xmain :: proc() {
	// Initialize the font shaping engine
	engine := shaper.create_engine()
	defer shaper.destroy_engine(engine)

	// Load and register a font
	font, err := ttf.load_font("./segoeui.ttf") // Update with your font path
	defer ttf.destroy_font(&font)
	if err != .None {
		fmt.eprintln("Error loading font:", err)
		return
	}

	font_id, ok := shaper.register_font(engine, &font)
	if !ok {
		fmt.eprintln("Error registering font")
		return
	}

	// Example texts to test
	examples := []string {
		// "ffi", // Test ligatures
		// "AVA", // Test kerning
		"To TO to", // Simple text with potential kerning
		// "آب", // Arabic text (Right-to-Left)
		// "नमस्ते", // Hindi with combining marks
	}

	// Enable typical OpenType features
	features := shaper.create_feature_set(
		.ccmp, // Glyph composition/decomposition
		.liga, // Standard ligatures
		.clig, // Contextual ligatures
		.dlig,
		.kern, // Kerning
		.mark, // Mark positioning
		.mkmk, // Mark to mark positioning
		.cpsp,
		.dist,
	)

	// Process each example
	for text in examples {
		fmt.println("\n----- Shaping text:", text, "-----")

		script := detect_script_for_text(text)
		language := detect_language_for_text(text)

		// Shape the text
		buffer, s_ok := shaper.shape_text_with_font(
			engine,
			font_id,
			text,
			script,
			language,
			features,
		)
		defer shaper.release_buffer(engine, buffer)

		if !s_ok {
			fmt.eprintln("Error shaping text:", text)
			continue
		}

		// Display the shaped glyphs and their positions
		text_shapers := utf8.string_to_runes(text)

		fmt.println("Glyph Count:", len(buffer.glyphs))
		fmt.println("Original text length:", len(text_shapers))
		fmt.println()

		fmt.println("Glyphs:")
		for i := 0; i < len(buffer.glyphs); i += 1 {
			gi := buffer.glyphs[i]
			pos := buffer.positions[i]

			fmt.println("Glyph", i)
			fmt.println("  ID:", gi.glyph_id)
			fmt.println("  Cluster:", gi.cluster)
			fmt.println("  Category:", gi.category)

			// Show the original character if possible
			if int(gi.cluster) < len(text_shapers) {
				ch := text_shapers[gi.cluster]
				fmt.printf("  Original: %c (U+%04X)\n", ch, ch)
			}

			// Display positioning information
			fmt.println("  Position:")
			fmt.println("    X Advance:", pos.x_advance)
			fmt.println("    Y Advance:", pos.y_advance)
			fmt.println("    X Offset:", pos.x_offset)
			fmt.println("    Y Offset:", pos.y_offset)

			// Show flags
			fmt.println("  Flags:", gi.flags)

			// For ligatures, show components info
			if .Ligated in gi.flags {
				fmt.println("  Ligature Components:", gi.ligature_components)
			}

			fmt.println()
		}

	}
}

// Helper function to detect script for the text
detect_script_for_text :: proc(text: string) -> shaper.Script_Tag {
	// A simple heuristic based on the first character
	if len(text) == 0 {
		return .latn // Default to Latin
	}

	r := utf8.rune_at(text, 0)

	if r >= 0x0600 && r <= 0x06FF {
		return .arab // Arabic
	}

	if r >= 0x0900 && r <= 0x097F {
		return .deva // Devanagari
	}

	if r >= 0x3040 && r <= 0x309F {
		return .hira // Hiragana
	}

	if r >= 0x30A0 && r <= 0x30FF {
		return .kana // Katakana
	}

	if r >= 0x4E00 && r <= 0x9FFF {
		return .hani // Han (Chinese)
	}

	if r >= 0xAC00 && r <= 0xD7AF {
		return .hang // Hangul (Korean)
	}

	// Default to Latin
	return .latn
}
// Helper function to detect language for the text
detect_language_for_text :: proc(text: string) -> shaper.Language_Tag {
	// A simple heuristic based on script
	script := detect_script_for_text(text)

	#partial switch script {
	case .arab:
		return .ARA // Arabic
	case .deva:
		return .HIN // Hindi
	case .hira, .kana:
		return .JAN // Japanese
	case .hani:
		return .ZHS // Simplified Chinese (default)
	case .hang:
		return .KOR // Korean
	}

	// Default to English for Latin script
	return .dflt
}
