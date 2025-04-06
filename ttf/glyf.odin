package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/glyf
// glyf — Glyph Data Table
/*
The glyf table contains the glyph outlines. Each glyph outline is described using a
sequence of contours. For simple glyphs, these contours directly represent the glyph shape.
For composite glyphs, the contours from other glyphs are combined to form the final glyph.
*/
import "core:fmt"
import "base:runtime"

Glyf_Table :: struct {
	data: []byte, // Raw glyf table data
	loca: ^Loca_Table,
}

// Minimalist glyph representation that maintains just enough info for parsing
Glyf_Entry :: struct {
	header:   ^OpenType_Glyf_Entry_Header,
	slice:    []byte, // Raw glyph data - includes header at the beginning
	index:    Glyph, // Glyph ID
	is_empty: bool, // True for empty glyphs (e.g., space)
}

OpenType_Glyf_Entry_Header :: struct #packed {
	number_of_contours: i16be, // Negative for composite glyphs
	x_min:              i16be,
	y_min:              i16be,
	x_max:              i16be,
	y_max:              i16be,
}

Glyph_Extents :: struct {
	x_bearing: i16, // Left side bearing
	y_bearing: i16, // Top side bearing
	width:     i16, // Width
	height:    i16, // Height
}

// Simple_Glyph_Flag :: bit_field u8 {
// 	ON_CURVE_POINT: bool | 1, // 1 = on-curve, 0 = off-curve
// 	X_SHORT_VECTOR: bool | 1, // 1 = x-coord is 1 byte, 0 = x-coord is 2 bytes
// 	Y_SHORT_VECTOR: bool | 1, // 1 = y-coord is 1 byte, 0 = y-coord is 2 bytes
// 	REPEAT_FLAG:    bool | 1, // 1 = next byte is repeat count
// 	X_IS_SAME:      bool | 1, // 1 = x-coord is same as previous (if X_SHORT=0), else x-coord is positive (1) or negative (0)
// 	Y_IS_SAME:      bool | 1, // 1 = y-coord is same as previous (if Y_SHORT=0), else y-coord is positive (1) or negative (0)
// 	OVERLAP_SIMPLE: bool | 1, // 1 = contour overlaps other contours
// 	RESERVED:       bool | 1, // Reserved, set to 0
// }
Simple_Glyph_Flag :: enum u8 {
	ON_CURVE_POINT,
	X_SHORT_VECTOR,
	Y_SHORT_VECTOR,
	REPEAT_FLAG,
	X_IS_SAME,
	Y_IS_SAME,
	OVERLAP_SIMPLE,
}

Simple_Glyph_Flags :: bit_set[Simple_Glyph_Flag;u8]

read_simple_glyph_flags :: proc(f: byte) -> Simple_Glyph_Flags {
	flags := Simple_Glyph_Flags{}
	if (f & 0x01) != 0 {flags += {.ON_CURVE_POINT}}
	if (f & 0x02) != 0 {flags += {.X_SHORT_VECTOR}}
	if (f & 0x04) != 0 {flags += {.Y_SHORT_VECTOR}}
	if (f & 0x08) != 0 {flags += {.REPEAT_FLAG}}
	if (f & 0x10) != 0 {flags += {.X_IS_SAME}}
	if (f & 0x20) != 0 {flags += {.Y_IS_SAME}}
	if (f & 0x40) != 0 {flags += {.OVERLAP_SIMPLE}}
	return flags
}

// Composite glyph flags
Composite_Glyph_Flag :: enum u16 {
	ARG_1_AND_2_ARE_WORDS, // 1 = args are words, 0 = args are bytes
	ARGS_ARE_XY_VALUES, // 1 = args are x,y values, 0 = args are points
	ROUND_XY_TO_GRID, // 1 = round x,y to grid
	WE_HAVE_A_SCALE, // 1 = there is a scale
	// RESERVED, // Reserved, set to 0
	MORE_COMPONENTS, // 1 = more components follow
	WE_HAVE_AN_X_AND_Y_SCALE, // 1 = we have an x and y scale
	WE_HAVE_A_TWO_BY_TWO, // 1 = we have a 2x2 transformation
	WE_HAVE_INSTRUCTIONS, // 1 = we have instructions
	USE_MY_METRICS, // 1 = use metrics from this component
	OVERLAP_COMPOUND, // 1 = this component overlaps others
	SCALED_COMPONENT_OFFSET, // 1 = component offset scaled
	UNSCALED_COMPONENT_OFFSET, // 1 = component offset unscaled
	// RESERVED2 bits (14-15) are omitted as they're reserved
}

Composite_Glyph_Flags :: bit_set[Composite_Glyph_Flag;u16]

read_composite_glyph_flags :: proc(f: u16) -> Composite_Glyph_Flags {
	flags := Composite_Glyph_Flags{}

	// Check each bit and set the corresponding flag
	if (f & 0x0001) != 0 {flags += {.ARG_1_AND_2_ARE_WORDS}}
	if (f & 0x0002) != 0 {flags += {.ARGS_ARE_XY_VALUES}}
	if (f & 0x0004) != 0 {flags += {.ROUND_XY_TO_GRID}}
	if (f & 0x0008) != 0 {flags += {.WE_HAVE_A_SCALE}}
	// if (f & 0x0010) != 0 {flags += {.RESERVED}}
	if (f & 0x0020) != 0 {flags += {.MORE_COMPONENTS}}
	if (f & 0x0040) != 0 {flags += {.WE_HAVE_AN_X_AND_Y_SCALE}}
	if (f & 0x0080) != 0 {flags += {.WE_HAVE_A_TWO_BY_TWO}}
	if (f & 0x0100) != 0 {flags += {.WE_HAVE_INSTRUCTIONS}}
	if (f & 0x0200) != 0 {flags += {.USE_MY_METRICS}}
	if (f & 0x0400) != 0 {flags += {.OVERLAP_COMPOUND}}
	if (f & 0x0800) != 0 {flags += {.SCALED_COMPONENT_OFFSET}}
	if (f & 0x1000) != 0 {flags += {.UNSCALED_COMPONENT_OFFSET}}
	// Bits 14-15 (0x6000) are reserved and not mapped to enum values

	return flags
}

///////////////////////////////////////////////////////////////////////////////////////////////

load_glyf_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	glyf_data, ok := get_table_data(font, .glyf)
	if !ok {return {}, .Table_Not_Found}

	// The glyf table just consists of a block of glyph data
	// We need the loca table to index into it correctly
	loca, has_loca := get_table(font, .loca, load_loca_table, Loca_Table)
	if !has_loca {return {}, .Missing_Required_Table}

	// Create the glyf table structure
	glyf := new(Glyf_Table, font.allocator)
	glyf.data = glyf_data
	glyf.loca = loca

	return Table_Entry{data = glyf}, .None
}

///////////////////////////////////////////////////////////////////////////////////////////////

// Get a glyph's data from the glyf table
get_glyf_entry :: proc(glyf: ^Glyf_Table, glyph_id: Glyph) -> (glyph: Glyf_Entry, ok: bool) {
	if glyf == nil || glyf.loca == nil {return}

	offset, length := get_glyph_location(glyf.loca, glyph_id) or_return

	glyph = Glyf_Entry {
		index    = glyph_id,
		is_empty = length == 0,
	}

	// Only set the slice if this isn't an empty glyph
	if !glyph.is_empty {
		if bounds_check(offset + length > uint(len(glyf.data))) {return}
		glyph.slice = glyf.data[offset:offset + length]
		glyph.header = transmute(^OpenType_Glyf_Entry_Header)&glyph.slice[0]
	}

	return glyph, true
}

is_composite_glyph :: proc(glyph: Glyf_Entry) -> bool {
	if glyph.is_empty {return false}
	return glyph.header.number_of_contours < 0
}

// Get glyph bounding box
get_bbox :: proc(glyph: Glyf_Entry) -> (bbox: Bounding_Box, ok: bool) {
	if glyph.is_empty {return {}, true}

	bbox = Bounding_Box {
		min = {i16(glyph.header.x_min), i16(glyph.header.y_min)},
		max = {i16(glyph.header.x_max), i16(glyph.header.y_max)},
	}

	return bbox, true
}

// Helper to get end points for simple glyphs
get_end_points :: proc(glyph: Glyf_Entry) -> (end_points: []u16be, ok: bool) {
	if glyph.is_empty || bounds_check(len(glyph.slice) < size_of(OpenType_Glyf_Entry_Header)) {
		return
	}
	// Validate num_contours
	if is_composite_glyph(glyph) {return}
	// Calculate offset to end points array
	end_points_offset := uint(size_of(OpenType_Glyf_Entry_Header))
	if end_points_offset + uint(glyph.header.number_of_contours) * size_of(u16) >
	   uint(len(glyph.slice)) {
		return
	}

	// Create a slice over the existing data - no allocation
	end_points_ptr := cast([^]u16be)&glyph.slice[end_points_offset]
	end_points = end_points_ptr[:glyph.header.number_of_contours]

	return end_points, true
}

// Get total number of points in a simple glyph
get_point_count :: proc(glyph: Glyf_Entry) -> (count: u16, ok: bool) {
	end_points, got_end_points := get_end_points(glyph)
	if !got_end_points || len(end_points) == 0 {
		return 0, false
	}
	// Last end point + 1 = total number of points
	return u16(end_points[len(end_points) - 1]) + 1, true
}

// Get instruction length and offset
get_instructions :: proc(glyph: Glyf_Entry) -> (instructions: []byte, ok: bool) {
	if glyph.is_empty || bounds_check(len(glyph.slice) < size_of(OpenType_Glyf_Entry_Header)) {
		return nil, false
	}

	if is_composite_glyph(glyph) {
		// For composite glyphs, instructions come after all components
		// TODO:
		return nil, false
	}

	// Get instruction length
	end_points_offset := uint(size_of(OpenType_Glyf_Entry_Header))
	instruction_len_offset := end_points_offset + uint(glyph.header.number_of_contours) * 2

	if bounds_check(instruction_len_offset + 2 > uint(len(glyph.slice))) {
		return nil, false
	}

	instruction_length := read_u16(glyph.slice, instruction_len_offset)
	instruction_offset := instruction_len_offset + 2

	if bounds_check(instruction_offset + uint(instruction_length) > uint(len(glyph.slice))) {
		return nil, false
	}

	if instruction_length == 0 {return nil, true}

	return glyph.slice[instruction_offset:instruction_offset + uint(instruction_length)], true
}

get_glyph_extents :: proc(
	glyf: ^Glyf_Table,
	glyph: Glyf_Entry,
) -> (
	extents: Glyph_Extents,
	ok: bool,
) {
	if glyph.is_empty {return {}, true} 	// Empty glyph (e.g., space) - zero extents

	extents = Glyph_Extents {
		x_bearing = i16(glyph.header.x_min),
		y_bearing = i16(glyph.header.y_max),
		width     = i16(glyph.header.x_max - glyph.header.x_min),
		height    = i16(glyph.header.y_max - glyph.header.y_min),
	}

	return extents, true
}

///////////////////////////////////////////////////////////////////////////////////////////////

// Iterator for composite glyph components
Component_Parser :: struct {
	glyph:          Glyf_Entry,
	current_offset: uint,
	has_more:       bool,
}

Glyph_Point :: struct {
	x, y:     i16, // Coordinates
	on_curve: bool, // Whether the point is on the curve
}

// Information about a composite glyph component for the API
Composite_Component :: struct {
	glyph_index:    Glyph, // Glyph ID of the component
	x_offset:       i16, // X offset
	y_offset:       i16, // Y offset
	scale_x:        f32, // X scaling factor (default 1.0)
	scale_y:        f32, // Y scaling factor (default 1.0)
	matrx:          [4]f32, // 2x2 transformation matrix (if applicable)
	flags:          Composite_Glyph_Flags, // Flags
	use_my_metrics: bool, // Whether to use the metrics from this component
}

// Initialize a parser for composite glyph components
init_component_parser :: proc(glyph: Glyf_Entry) -> (parser: Component_Parser, ok: bool) {
	if glyph.is_empty || !is_composite_glyph(glyph) {
		return {}, false
	}

	parser = Component_Parser {
		glyph          = glyph,
		current_offset = size_of(OpenType_Glyf_Entry_Header),
		has_more       = true,
	}

	return parser, true
}

// Get the next component
next_component :: proc(parser: ^Component_Parser) -> (component: Composite_Component, ok: bool) {
	if !parser.has_more || parser.current_offset + 4 > uint(len(parser.glyph.slice)) {
		parser.has_more = false
		return {}, false
	}

	// Read flags and glyph index
	flags := read_composite_glyph_flags(read_u16(parser.glyph.slice, parser.current_offset))
	component_glyph_id := Glyph(read_u16(parser.glyph.slice, parser.current_offset + 2))
	current_offset := parser.current_offset + 4

	component = Composite_Component {
		glyph_index    = component_glyph_id,
		flags          = flags,
		scale_x        = 1.0,
		scale_y        = 1.0,
		use_my_metrics = .USE_MY_METRICS in flags,
	}

	// Read arguments based on flags
	if .ARG_1_AND_2_ARE_WORDS in flags {
		// Arguments are 16-bit values
		if current_offset + 4 > uint(len(parser.glyph.slice)) {
			parser.has_more = false
			return {}, false
		}

		if .ARGS_ARE_XY_VALUES in flags {
			// Arguments are x,y offsets
			component.x_offset = read_i16(parser.glyph.slice, current_offset)
			component.y_offset = read_i16(parser.glyph.slice, current_offset + 2)
		} else {
			// Arguments are point indices (not stored in our component struct)
		}
		current_offset += 4
	} else {
		// Arguments are 8-bit values
		if current_offset + 2 > uint(len(parser.glyph.slice)) {
			parser.has_more = false
			return {}, false
		}

		if .ARGS_ARE_XY_VALUES in flags {
			// Arguments are x,y offsets
			component.x_offset = i16(cast(i8)parser.glyph.slice[current_offset])
			component.y_offset = i16(cast(i8)parser.glyph.slice[current_offset + 1])
		} else {
			// Arguments are point indices (not stored in our component struct)
		}
		current_offset += 2
	}

	// Read transformation based on flags
	if .WE_HAVE_A_SCALE in flags {
		// Single scale value for both x and y
		if current_offset + 2 > uint(len(parser.glyph.slice)) {
			parser.has_more = false
			return {}, false
		}

		scale := F2DOT14_to_Float(read_i16be(parser.glyph.slice, current_offset))
		component.scale_x = scale
		component.scale_y = scale
		current_offset += 2
	} else if .WE_HAVE_AN_X_AND_Y_SCALE in flags {
		// Separate scale values for x and y
		if current_offset + 4 > uint(len(parser.glyph.slice)) {
			parser.has_more = false
			return {}, false
		}

		component.scale_x = F2DOT14_to_Float(read_i16be(parser.glyph.slice, current_offset))
		component.scale_y = F2DOT14_to_Float(read_i16be(parser.glyph.slice, current_offset + 2))
		current_offset += 4
	} else if .WE_HAVE_A_TWO_BY_TWO in flags {
		// 2x2 transformation mtrx
		if current_offset + 8 > uint(len(parser.glyph.slice)) {
			parser.has_more = false
			return {}, false
		}

		component.matrx[0] = F2DOT14_to_Float(read_i16be(parser.glyph.slice, current_offset))
		component.matrx[1] = F2DOT14_to_Float(read_i16be(parser.glyph.slice, current_offset + 2))
		component.matrx[2] = F2DOT14_to_Float(read_i16be(parser.glyph.slice, current_offset + 4))
		component.matrx[3] = F2DOT14_to_Float(read_i16be(parser.glyph.slice, current_offset + 6))
		current_offset += 8
	}

	// fmt.printf("Raw flag value: 0x%04x\n", u16(flags))
	// fmt.printf("Interpreted flags:\n")
	// fmt.printf("  ARG_1_AND_2_ARE_WORDS: %v\n", flags.ARG_1_AND_2_ARE_WORDS)
	// fmt.printf("  ARGS_ARE_XY_VALUES: %v\n", flags.ARGS_ARE_XY_VALUES)
	// fmt.printf("  ROUND_XY_TO_GRID: %v\n", flags.ROUND_XY_TO_GRID)
	// fmt.printf("  WE_HAVE_A_SCALE: %v\n", flags.WE_HAVE_A_SCALE)
	// fmt.printf("  MORE_COMPONENTS: %v\n", flags.MORE_COMPONENTS)

	// Update offsets for next component
	parser.current_offset = current_offset
	parser.has_more = .MORE_COMPONENTS in flags

	return component, true
}

get_extracted_glyph :: proc(font: ^Font, glyph_id: Glyph, allocator: runtime.Allocator) -> (Extracted_Glyph, bool) {
	glyf, has_glyf := get_table(font, .glyf, load_glyf_table, Glyf_Table)
	if has_glyf {
		return extract_glyph(glyf, glyph_id, allocator)
	} else {
		return {}, false
	}
}

