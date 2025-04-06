package ttf

// https://learn.microsoft.com/en-us/typography/opentype/spec/hmtx
// hmtx — Horizontal Metrics Table
/*
The horizontal metrics table contains information for the horizontal layout of each glyph in the font.
The table consists of two main parts:
1. An array of 'longHorMetric' records, each containing an advance width and left side bearing
2. An array of left side bearings (used for glyphs with the same advance width)
*/

import "core:fmt"

OpenType_Hmtx_Table :: struct {
	metrics:             []OpenType_Long_Hor_Metric, // Array of metrics [num_of_long_metrics]
	left_side_bearings:  []SHORT, // Left side bearings for glyphs with same advance width
	num_glyphs:          u16, // Total number of glyphs (from maxp table)
	num_of_long_metrics: u16, // Number of entries in the metrics array (from hhea table)
	raw_data:            []byte, // Reference to raw font data
}

// The main metrics record containing advance width and left side bearing
OpenType_Long_Hor_Metric :: struct #packed {
	advance_width:     USHORT, // Advance width in font design units
	left_side_bearing: SHORT, // Left side bearing in font design units
}


// Load the hmtx table
load_hmtx_table :: proc(font: ^Font) -> (Table_Entry, Font_Error) {
	hmtx_data, ok := get_table_data(font, .hmtx)
	if !ok {return {}, .Table_Not_Found}

	// Need hhea table to properly parse hmtx
	hhea, ok_hhea := get_table(font, .hhea, load_hhea_table, OpenType_Hhea_Table)
	if !ok_hhea {return {}, .Missing_Required_Table}

	// Allocate the hmtx table structure
	hmtx := new(OpenType_Hmtx_Table, font.allocator)
	hmtx.raw_data = hmtx_data
	hmtx.num_glyphs = font.num_glyphs
	hmtx.num_of_long_metrics = u16(hhea.number_of_h_metrics)

	// Check if table size is valid
	min_size := int(hmtx.num_of_long_metrics) * 4
	if hmtx.num_of_long_metrics < hmtx.num_glyphs {
		// Additional LSBs for monospaced glyphs
		min_size += int(hmtx.num_glyphs - hmtx.num_of_long_metrics) * 2
	}

	if len(hmtx_data) < min_size {
		fmt.println("htmx too small for data")
		return {}, .Invalid_Table_Format
	}

	// Create slices that point directly into the raw data buffer
	metrics_ptr := cast([^]OpenType_Long_Hor_Metric)&hmtx_data[0]
	hmtx.metrics = metrics_ptr[:hmtx.num_of_long_metrics]

	// If there are additional left side bearings for monospaced glyphs
	if hmtx.num_of_long_metrics < hmtx.num_glyphs {
		lsb_ptr := cast([^]SHORT)&hmtx_data[hmtx.num_of_long_metrics * size_of(OpenType_Long_Hor_Metric)]
		hmtx.left_side_bearings = lsb_ptr[:hmtx.num_glyphs - hmtx.num_of_long_metrics]
	}

	return Table_Entry{data = hmtx}, .None
}
//////////////////////////////////////////////////////////////////////////////////////////

// Get horizontal metrics for a specific glyph
htmx_get_metrics :: proc(
	hmtx: ^OpenType_Hmtx_Table,
	glyph_id: Glyph,
) -> (
	advance_width: u16,
	lsb: i16,
) {
	if hmtx == nil || len(hmtx.metrics) == 0 {return}

	gid := uint(glyph_id)

	// Bounds check
	if bounds_check(gid >= uint(hmtx.num_glyphs)) {return}

	if gid < uint(hmtx.num_of_long_metrics) {
		metric := hmtx.metrics[gid]
		advance_width = u16(metric.advance_width)
		lsb = i16(metric.left_side_bearing)
	} else {
		// For glyphs beyond numOfHMetrics, the advance width is the same as the last entry
		// Use the last entry in the metrics array
		advance_width = u16(hmtx.metrics[hmtx.num_of_long_metrics - 1].advance_width)

		// Get the left side bearing from the additional array
		lsb_index := gid - uint(hmtx.num_of_long_metrics)
		if lsb_index < uint(len(hmtx.left_side_bearings)) {
			lsb = i16(hmtx.left_side_bearings[lsb_index])
		}
	}

	return advance_width, lsb
}


get_advance_width :: proc(hmtx: ^OpenType_Hmtx_Table, glyph_id: Glyph) -> u16 {
	if hmtx == nil || len(hmtx.metrics) == 0 {
		return 0
	}

	gid := uint(glyph_id)

	// Bounds check
	if gid >= uint(hmtx.num_glyphs) {
		return 0
	}

	// For all glyphs beyond numOfHMetrics, use the last metrics entry's advance
	metric_index := min(gid, uint(hmtx.num_of_long_metrics) - 1)
	return u16(hmtx.metrics[metric_index].advance_width)
}

get_left_side_bearing :: proc(hmtx: ^OpenType_Hmtx_Table, glyph_id: Glyph) -> i16 {
	if hmtx == nil {return 0}

	gid := uint(glyph_id)

	// Bounds check
	if gid >= uint(hmtx.num_glyphs) {
		return 0
	}

	if gid < uint(hmtx.num_of_long_metrics) {
		// Get LSB from metrics array
		return i16(hmtx.metrics[gid].left_side_bearing)
	} else {
		// Get LSB from additional bearings array
		lsb_index := gid - uint(hmtx.num_of_long_metrics)
		if lsb_index < uint(len(hmtx.left_side_bearings)) {
			return i16(hmtx.left_side_bearings[lsb_index])
		}
	}

	return 0
}
