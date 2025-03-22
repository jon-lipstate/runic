package ttf

Glyph_Category :: enum u8 {
	Base,
	Mark,
	Ligature,
	Component,
	Joiner,
	Non_Joiner,
}

// Helper to determine glyph category using GDEF and Unicode properties
determine_glyph_category :: proc(
	gdef: ^GDEF_Table,
	gid: Glyph,
	codepoint: rune,
) -> Glyph_Category {
	// TODO: impl gdef
	// if gdef != nil {
	// 	if class, found := get_glyph_class(gdef, gid); found {
	// 		switch class {
	// 		case .Base:
	// 			return .Base
	// 		case .Ligature:
	// 			return .Ligature
	// 		case .Mark:
	// 			return .Mark
	// 		case .Component:
	// 			return .Component
	// 		}
	// 	}
	// }

	// // Fallback to Unicode properties
	// if unichar_is_mark(codepoint) {
	// 	return .Mark
	// } else if codepoint == 0x200C {
	// 	return .Non_Joiner // ZWNJ
	// } else if codepoint == 0x200D {
	// 	return .Joiner // ZWJ
	// }

	return .Base
}
