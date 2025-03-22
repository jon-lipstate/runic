package ttf


// Check if a character is in the default ignorable set
is_default_ignorable_char :: proc(ch: rune) -> bool {
	// Common default ignorables
	// SOFT HYPHEN
	// COMBINING GRAPHEME JOINER
	// ARABIC LETTER MARK
	// HANGUL FILLERS
	// KHMER VOWEL INHERENT AQ/AA
	// MONGOLIAN, ZWSP
	// ZWSP, ZWNJ, ZWJ, LRM, RLM
	// DIRECTIONAL FORMATTING
	// WORD JOINER, etc.
	// VARIATION SELECTORS
	// ZERO WIDTH NO-BREAK SPACE
	// REPLACEMENT CHARACTER
	// TAGS, VARIATION SELECTORS
	if (ch == 0x00AD) ||
	   (ch == 0x034F) ||
	   (ch == 0x061C) ||
	   (ch >= 0x115F && ch <= 0x1160) ||
	   (ch >= 0x17B4 && ch <= 0x17B5) ||
	   (ch >= 0x180B && ch <= 0x180E) ||
	   (ch >= 0x200B && ch <= 0x200F) ||
	   (ch >= 0x202A && ch <= 0x202E) ||
	   (ch >= 0x2060 && ch <= 0x206F) ||
	   (ch >= 0xFE00 && ch <= 0xFE0F) ||
	   (ch == 0xFEFF) ||
	   (ch >= 0xFFF0 && ch <= 0xFFF8) ||
	   (ch >= 0xE0000 && ch <= 0xE0FFF) {
		return true
	}

	return false
}

unichar_is_mark :: proc(ch: rune) -> bool {
	// Combining Diacritical Marks
	// Combining Diacritical Marks Extended
	// Combining Diacritical Marks Supplement
	// Combining Diacritical Marks for Symbols
	// Combining Half Marks
	if (ch >= 0x0300 && ch <= 0x036F) ||
	   (ch >= 0x1AB0 && ch <= 0x1AFF) ||
	   (ch >= 0x1DC0 && ch <= 0x1DFF) ||
	   (ch >= 0x20D0 && ch <= 0x20FF) ||
	   (ch >= 0xFE20 && ch <= 0xFE2F) {
		return true
	}
	// TODO: Could add more ranges or better Unicode property checking
	return false
}

unicode_decompose_canonical :: proc(codepoint: rune) -> []rune {
	// Canonical decompositions produce characters that are considered semantically equivalent to the original.
	// example: "Ä" (U+00C4) → "A" (U+0041) + "◌̈" (U+0308 combining diaeresis)
	//
	// Compatibility decompositions produce characters that may have a different appearance but are considered functionally or semantically related. The result may look visually different from the original.
	// examples:
	// "ℎ" (U+210E, Planck constant) → "h" (U+0068)
	// "①" (U+2460, circled digit one) → "1" (U+0031)
	// "ﬁ" (U+FB01, fi ligature) → "f" (U+0066) + "i" (U+0069)

	// https://www.unicode.org/Public/UNIDATA/UnicodeData.txt
	// <code>;<name>;<category>;<combining>;<bidi>;<decomp>;<decimal>;<digit>;<numeric>;<mirror>;<unicode1name>;<comment>;<upper>;<lower>;<title>
	// 00C4;LATIN CAPITAL LETTER A WITH DIAERESIS;Lu;0;L;0041 0308;;;;N;LATIN CAPITAL LETTER A DIAERESIS;;;00E4;
	/*
	00C4 is the code point (Ä)
	LATIN CAPITAL LETTER A WITH DIAERESIS is the name
	Lu is the general category (uppercase letter)
	0 is the combining class
	L is the bidirectional category
	0041 0308 is the decomposition mapping (A + combining diaeresis)
	//
	00C4 → 0041 0308 (canonical decomposition)
	210E → <font> 0068 (compatibility decomposition with a font tag)
	When processing this file for font rendering purposes, you'll typically:

	// Data Encoding Format:
	use header to binary search the codepoint; store data in variable-length (eg utf8 format); maybe use top bits of the length in data section to even use as flags; base+combining etc
	[Header]
	uint32 entry_count = 1234
	uint32 data_section_offset = 7404  // (entry_count * 6) + header_size

	[Index Section]  // Fixed-size entries
	{codepoint: 0x00C4, offset: 0}     // Ä
	{codepoint: 0x00C5, offset: 6}     // Å
	{codepoint: 0x00C7, offset: 12}    // Ç
	...

	[Data Section]  // Variable-length data
	[2, 0x0041, 0x0308]  // Ä → A + combining diaeresis
	[2, 0x0041, 0x030A]  // Å → A + combining ring above
	[2, 0x0043, 0x0327]  // Ç → C + combining cedilla

	Parse each line
	Extract the code point (field 1) and decomposition (field 6)
	Ignore decompositions with compatibility tags (those with <tag>) if you only care about canonical decompositions
	Convert the hex values in the decomposition field to actual code points
	Build a mapping from each composite character to its sequence of decomposed characters

	If you want to create a compact binary representation, you can then encode this mapping in a way that optimizes for size while maintaining efficient lookup capabilities.
*/
	unimplemented()
}
