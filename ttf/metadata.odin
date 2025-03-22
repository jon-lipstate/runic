package ttf

Font_Weight :: enum {
	Thin       = 100,
	ExtraLight = 200,
	Light      = 300,
	Regular    = 400,
	Medium     = 500,
	SemiBold   = 600,
	Bold       = 700,
	ExtraBold  = 800,
	Black      = 900,
}
Font_Width :: enum {
	UltraCondensed,
	ExtraCondensed,
	Condensed,
	SemiCondensed,
	Normal,
	SemiExpanded,
	Expanded,
	ExtraExpanded,
	UltraExpanded,
}
Font_Slant :: enum {
	Normal,
	Italic,
	Oblique,
}
Font_Style :: enum {
	Regular, // Normal/Regular style
	Bold, // Bold weight
	Italic, // Italic style
	Bold_Italic, // Combined Bold and Italic
	Light, // Lighter than Regular
	Medium, // Between Regular and Bold
	SemiBold, // Between Medium and Bold
	ExtraBold, // Heavier than Bold
	Black, // Heaviest weight
	Condensed, // Narrower width
	Expanded, // Wider width
	Oblique, // Slanted (different from true Italic)
	Thin, // Very light weight
	ExtraLight, // Between Thin and Light
}
