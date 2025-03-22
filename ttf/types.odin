package ttf

Name_ID :: enum u16 {
	Copyright                  = 0,
	FontFamily                 = 1,
	FontSubfamily              = 2,
	UniqueIdentifier           = 3,
	FullName                   = 4,
	Version                    = 5,
	PostScriptName             = 6,
	Trademark                  = 7,
	Manufacturer               = 8,
	Designer                   = 9,
	Description                = 10,
	VendorURL                  = 11,
	DesignerURL                = 12,
	LicenseDescription         = 13,
	LicenseURL                 = 14,
	Reserved                   = 15,
	TypographicFamily          = 16,
	TypographicSubfamily       = 17,
	CompatibleFull             = 18,
	SampleText                 = 19,
	PostScriptCID              = 20,
	WWSFamily                  = 21,
	WWSSubfamily               = 22,
	LightBackgroundPalette     = 23,
	DarkBackgroundPalette      = 24,
	VariationsPostScriptPrefix = 25,
}

Variation_Axis_Tag :: distinct string // e.g. "wght", "wdth", etc.

// Glyph_Outline :: struct {
// 	// For TrueType outlines
// 	contours:  []Contour,
// 	// For CFF outlines
// 	operators: []CFF_Operator,
// }

// Contour :: struct {
// 	points:    []Point,
// 	is_closed: bool,
// }

// Point :: struct {
// 	x, y:        i16,
// 	is_on_curve: bool,
// }

Variation_Axis :: struct {
	tag:           Variation_Axis_Tag,
	name:          string,
	min_value:     f32,
	default_value: f32,
	max_value:     f32,
}

// CFF_Operator :: struct {} // CFF-specific operator types
