package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/maxp
// maxp — Maximum Profile Table
/*
The maximum profile table contains font-wide limits and parameters that are needed
to allocate storage for various tables in the font. It comes in two versions:
- Version 0.5: Used for CFF OpenType fonts (with PostScript outlines)
- Version 1.0: Used for TrueType fonts

The table provides information about maximum glyph counts, storage needs, and
complexity that can be used by applications to allocate memory when processing fonts.
*/

// The maxp table structure used in the API
Maxp_Table :: struct {
	version:  Maxp_Version, // Table version (0.5 or 1.0)
	data:     struct #raw_union {
		v0_5: ^OpenType_Maxp_Table_V0_5, // For version 0.5
		v1_0: ^OpenType_Maxp_Table_V1_0, // For version 1.0
	},
	raw_data: []byte, // Reference to raw data
}

// Maximum Profile table version
Maxp_Version :: enum u32be {
	Version_0_5 = 0x00005000, // Version 0.5 (CFF fonts)
	Version_1_0 = 0x00010000, // Version 1.0 (TrueType fonts)
}

// Maximum Profile table - Version 0.5 (CFF OpenType fonts)
OpenType_Maxp_Table_V0_5 :: struct #packed {
	version:    Maxp_Version, // Table version (0.5)
	num_glyphs: u16be, // The number of glyphs in the font
}

// Maximum Profile table - Version 1.0 (TrueType fonts)
OpenType_Maxp_Table_V1_0 :: struct #packed {
	version:                  Maxp_Version, // Table version (1.0)
	num_glyphs:               u16be, // The number of glyphs in the font
	max_points:               u16be, // Maximum points in a non-composite glyph
	max_contours:             u16be, // Maximum contours in a non-composite glyph
	max_composite_points:     u16be, // Maximum points in a composite glyph
	max_composite_contours:   u16be, // Maximum contours in a composite glyph
	max_zones:                u16be, // 1 if instructions do not use the twilight zone, 2 if they do
	max_twilight_points:      u16be, // Maximum points used in Z0 (twilight zone)
	max_storage:              u16be, // Number of Storage Area locations
	max_function_defs:        u16be, // Number of FDEFs (function definitions)
	max_instruction_defs:     u16be, // Number of IDEFs (instruction definitions)
	max_stack_elements:       u16be, // Maximum stack depth across all programs
	max_size_of_instructions: u16be, // Maximum byte count for glyph instructions
	max_component_elements:   u16be, // Maximum number of components referenced at top level
	max_component_depth:      u16be, // Maximum levels of recursion (1 for simple components)
}


// Load the maxp table
load_maxp_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	maxp_data, ok := get_table_data(font, .maxp)
	if !ok {return {}, .Table_Not_Found}

	// Check minimum size for version field
	if len(maxp_data) < 4 {
		return {}, .Invalid_Table_Format
	}

	// Determine table version
	version := cast(Maxp_Version)read_u32(maxp_data, 0)

	// Create a new Maxp_Table structure
	maxp := new(Maxp_Table)
	maxp.raw_data = maxp_data
	maxp.version = version

	// Validate and set up based on version
	switch version {
	case .Version_0_5:
		if len(maxp_data) < size_of(OpenType_Maxp_Table_V0_5) {
			free(maxp)
			return {}, .Invalid_Table_Format
		}
		maxp.data.v0_5 = cast(^OpenType_Maxp_Table_V0_5)&maxp_data[0]

	case .Version_1_0:
		if len(maxp_data) < size_of(OpenType_Maxp_Table_V1_0) {
			free(maxp)
			return {}, .Invalid_Table_Format
		}
		maxp.data.v1_0 = cast(^OpenType_Maxp_Table_V1_0)&maxp_data[0]

	case:
		// Unknown version
		free(maxp)
		return {}, .Invalid_Table_Format
	}

	return Table_Entry{data = maxp, destroy = destroy_maxp_table}, .None
}

destroy_maxp_table :: proc(data: rawptr) {
	if data == nil {return}
	maxp := cast(^Maxp_Table)data
	free(maxp)
}

////////////////////////////////////////////////////////////////////////////////////////
// API Functions

// Get the number of glyphs in the font
get_num_glyphs :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil {return 0}

	if maxp.version == .Version_0_5 && maxp.data.v0_5 != nil {
		return u16(maxp.data.v0_5.num_glyphs)
	} else if maxp.version == .Version_1_0 && maxp.data.v1_0 != nil {
		return u16(maxp.data.v1_0.num_glyphs)
	}

	return 0
}

// The following are only valid for TrueType fonts (version 1.0)

// Get the maximum points in a non-composite glyph
get_max_points :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_points)
}

// Get the maximum contours in a non-composite glyph
get_max_contours :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_contours)
}

// Get the maximum points in a composite glyph
get_max_composite_points :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_composite_points)
}

// Get the maximum contours in a composite glyph
get_max_composite_contours :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_composite_contours)
}

// Get the maximum zones (1 if no twilight zone, 2 if there is)
get_max_zones :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_zones)
}

// Get the maximum points used in the twilight zone
get_max_twilight_points :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_twilight_points)
}

// Get the number of Storage Area locations
get_max_storage :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_storage)
}

// Get the number of function definitions
get_max_function_defs :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_function_defs)
}

// Get the number of instruction definitions
get_max_instruction_defs :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_instruction_defs)
}

// Get the maximum stack depth
get_max_stack_elements :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_stack_elements)
}

// Get the maximum byte count for glyph instructions
get_max_size_of_instructions :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_size_of_instructions)
}

// Get the maximum number of components referenced at top level
get_max_component_elements :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_component_elements)
}

// Get the maximum levels of recursion
get_max_component_depth :: proc(maxp: ^Maxp_Table) -> u16 {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0
	}
	return u16(maxp.data.v1_0.max_component_depth)
}

// Helper function to check if font has TrueType outlines
has_truetype_outlines :: proc(maxp: ^Maxp_Table) -> bool {
	if maxp == nil {return false}
	return maxp.version == .Version_1_0
}

// Helper function to check if font has CFF outlines
has_cff_outlines :: proc(maxp: ^Maxp_Table) -> bool {
	if maxp == nil {return false}
	return maxp.version == .Version_0_5
}

// Helper functions for memory allocation when processing fonts

// Calculate approximate memory needed for glyph processing (TrueType)
calculate_glyph_memory_requirements :: proc(maxp: ^Maxp_Table) -> (points: u32, contours: u32) {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0, 0
	}

	// For simple glyphs
	max_points := u32(maxp.data.v1_0.max_points)
	max_contours := u32(maxp.data.v1_0.max_contours)

	// For composite glyphs
	max_composite_points := u32(maxp.data.v1_0.max_composite_points)
	max_composite_contours := u32(maxp.data.v1_0.max_composite_contours)

	// Return the larger of the simple and composite requirements
	return max(max_points, max_composite_points), max(max_contours, max_composite_contours)
}

// Calculate approximate memory needed for TrueType instructions
calculate_instruction_memory_requirements :: proc(
	maxp: ^Maxp_Table,
) -> (
	storage: u32,
	stack: u32,
	functions: u32,
) {
	if maxp == nil || maxp.version != .Version_1_0 || maxp.data.v1_0 == nil {
		return 0, 0, 0
	}

	return u32(
		maxp.data.v1_0.max_storage,
	), u32(maxp.data.v1_0.max_stack_elements), u32(maxp.data.v1_0.max_function_defs + maxp.data.v1_0.max_instruction_defs)
}
