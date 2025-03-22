package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/vmtx
// vmtx — Vertical Metrics Table
/*
The vertical metrics table contains vertical metrics for each glyph in the font.
It is similar to the horizontal metrics table (hmtx), but for vertical layout.
The table consists of two main parts:
1. An array of 'vMetrics' records, each containing an advance height and top side bearing
2. An array of top side bearings (used for glyphs with the same advance height)
*/

import "core:fmt"

OpenType_Vmtx_Table :: struct {
	metrics:             []OpenType_Vertical_Metric, // Array of metrics [num_of_long_metrics]
	top_side_bearings:   []SHORT, // Top side bearings for glyphs with same advance height
	num_glyphs:          u16, // Total number of glyphs (from maxp table)
	num_of_long_metrics: u16, // Number of entries in the metrics array (from vhea table)
	raw_data:            []byte, // Reference to raw font data
}

// The main metrics record containing advance height and top side bearing
OpenType_Vertical_Metric :: struct #packed {
	advance_height:   USHORT, // Advance height in font design units
	top_side_bearing: SHORT, // Top side bearing in font design units
}

// Load the vmtx table
load_vmtx_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	vmtx_data, ok := get_table_data(font, "vmtx")
	if !ok {return {}, .Table_Not_Found}

	// Need vhea table to properly parse vmtx
	vhea, ok_vhea := get_table(font, "vhea", load_vhea_table, Vhea_Table)
	if !ok_vhea {return {}, .Missing_Required_Table}

	// Allocate the vmtx table structure
	vmtx := new(OpenType_Vmtx_Table)
	vmtx.raw_data = vmtx_data
	vmtx.num_glyphs = font.num_glyphs
	vmtx.num_of_long_metrics = get_number_of_v_metrics(vhea)

	// Check if table size is valid
	min_size := int(vmtx.num_of_long_metrics) * 4
	if vmtx.num_of_long_metrics < vmtx.num_glyphs {
		// Additional TSBs for monospaced glyphs
		min_size += int(vmtx.num_glyphs - vmtx.num_of_long_metrics) * 2
	}

	if len(vmtx_data) < min_size {
		fmt.println("vmtx too small for data")
		free(vmtx)
		return {}, .Invalid_Table_Format
	}

	// Create slices that point directly into the raw data buffer
	metrics_ptr := cast([^]OpenType_Vertical_Metric)&vmtx_data[0]
	vmtx.metrics = metrics_ptr[:vmtx.num_of_long_metrics]

	// If there are additional top side bearings for glyphs with same advance height
	if vmtx.num_of_long_metrics < vmtx.num_glyphs {
		tsb_ptr := cast([^]SHORT)&vmtx_data[vmtx.num_of_long_metrics * size_of(OpenType_Vertical_Metric)]
		vmtx.top_side_bearings = tsb_ptr[:vmtx.num_glyphs - vmtx.num_of_long_metrics]
	}

	return Table_Entry{data = vmtx, destroy = destroy_vmtx_table}, .None
}

destroy_vmtx_table :: proc(data: rawptr) {
	if data == nil {return}
	vmtx := cast(^OpenType_Vmtx_Table)data
	free(vmtx)
}

//////////////////////////////////////////////////////////////////////////////////////////
// API Functions

// Get vertical metrics for a specific glyph
get_v_metrics :: proc(
	vmtx: ^OpenType_Vmtx_Table,
	glyph_id: Glyph,
) -> (
	advance_height: u16,
	tsb: i16,
) {
	if vmtx == nil || len(vmtx.metrics) == 0 {return 0, 0}

	gid := uint(glyph_id)

	// Bounds check
	if gid >= uint(vmtx.num_glyphs) {
		return 0, 0
	}

	if gid < uint(vmtx.num_of_long_metrics) {
		metric := vmtx.metrics[gid]
		advance_height = u16(metric.advance_height)
		tsb = i16(metric.top_side_bearing)
	} else {
		// For glyphs beyond numOfVMetrics, the advance height is the same as the last entry
		// Use the last entry in the metrics array
		advance_height = u16(vmtx.metrics[vmtx.num_of_long_metrics - 1].advance_height)

		// Get the top side bearing from the additional array
		tsb_index := gid - uint(vmtx.num_of_long_metrics)
		if tsb_index < uint(len(vmtx.top_side_bearings)) {
			tsb = i16(vmtx.top_side_bearings[tsb_index])
		}
	}

	return advance_height, tsb
}

// Get just the advance height for a glyph
get_advance_height :: proc(vmtx: ^OpenType_Vmtx_Table, glyph_id: Glyph) -> u16 {
	if vmtx == nil || len(vmtx.metrics) == 0 {return 0}

	gid := uint(glyph_id)

	// Bounds check
	if gid >= uint(vmtx.num_glyphs) {return 0}

	// For all glyphs beyond numOfVMetrics, use the last metrics entry's advance
	metric_index := min(gid, uint(vmtx.num_of_long_metrics) - 1)
	return u16(vmtx.metrics[metric_index].advance_height)
}

// Get just the top side bearing for a glyph
get_top_side_bearing :: proc(vmtx: ^OpenType_Vmtx_Table, glyph_id: Glyph) -> i16 {
	if vmtx == nil {return 0}

	gid := uint(glyph_id)

	// Bounds check
	if gid >= uint(vmtx.num_glyphs) {return 0}

	if gid < uint(vmtx.num_of_long_metrics) {
		// Get TSB from metrics array
		return i16(vmtx.metrics[gid].top_side_bearing)
	} else {
		// Get TSB from additional bearings array
		tsb_index := gid - uint(vmtx.num_of_long_metrics)
		if tsb_index < uint(len(vmtx.top_side_bearings)) {
			return i16(vmtx.top_side_bearings[tsb_index])
		}
	}

	return 0
}

// Calculate the bottom side bearing for a glyph
// Note: This requires glyph bounding box data, typically from the glyf table
calculate_bottom_side_bearing :: proc(
	vmtx: ^OpenType_Vmtx_Table,
	glyph_id: Glyph,
	glyph_height: i16,
	glyph_ymin: i16,
) -> i16 {
	if vmtx == nil {return 0}

	// Get top side bearing and advance height
	advance_height, tsb := get_v_metrics(vmtx, glyph_id)

	// Calculate bottom side bearing: advanceHeight - (TSB + (yMax - yMin))
	// where yMax - yMin is the glyph height
	return i16(advance_height) - (tsb + glyph_height)
}

// Calculate the vertical origin for a glyph in vertical typesetting
// Note: This is a simplified approach; some fonts have more complex calculations
calculate_vertical_origin :: proc(
	vmtx: ^OpenType_Vmtx_Table,
	glyph_id: Glyph,
	glyph_height: i16,
	units_per_em: u16,
) -> i16 {
	if vmtx == nil {return 0}

	advance_height := get_advance_height(vmtx, glyph_id)

	// In many CJK fonts, the vertical origin is typically at:
	// - The center of the glyph horizontally
	// - Half the em height from the top of the glyph vertically
	// TODO:
	// A simple approximation: place origin at half the advance height
	return i16(advance_height) / 2
}
