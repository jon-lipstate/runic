package ttf

import "core:fmt"

// Get the coverage index for a glyph in a coverage table
get_coverage_index :: proc(
	data: []byte,
	coverage_offset: uint,
	glyph_id: Glyph,
) -> (
	index: u16,
	found: bool,
) {
	if bounds_check(coverage_offset + 2 > uint(len(data))) {
		fmt.printf("Bounds check failed at coverage offset %d\n", coverage_offset)
		return 0, false
	}
	be_glyph_id := cast(Raw_Glyph)glyph_id

	format := read_u16(data, coverage_offset)
	// fmt.printf(
	// 	"Checking coverage for glyph %d at offset %d, format: %d\n",
	// 	be_glyph_id,
	// 	coverage_offset,
	// 	format,
	// )

	if format == 1 {
		// Format A more reliable implementation of Format 1
		if bounds_check(coverage_offset + 4 > uint(len(data))) {
			fmt.println("Bounds check failed reading glyph count")
			return 0, false
		}

		glyph_count := read_u16(data, coverage_offset + 2)
		// fmt.printf("Format 1: Glyph count = %d\n", glyph_count)

		// Binary search for the glyph ID
		low := 0
		high := int(glyph_count) - 1

		for low <= high {
			mid := (low + high) / 2
			glyph_offset := coverage_offset + 4 + uint(mid) * 2

			if bounds_check(glyph_offset + 2 > uint(len(data))) {
				fmt.println("Bounds check failed in binary search")
				return 0, false
			}

			current_glyph := cast(Raw_Glyph)read_u16be(data, glyph_offset)
			// fmt.printf(
			// 	"Comparing glyph %d at mid=%d (low=%d,high=%d)\n",
			// 	current_glyph,
			// 	mid,
			// 	low,
			// 	high,
			// )

			if be_glyph_id < current_glyph {
				high = mid - 1
			} else if be_glyph_id > current_glyph {
				low = mid + 1
			} else {
				// Found the glyph
				// fmt.printf("Match found at index %d\n", mid)
				return u16(mid), true
			}
		}

		// fmt.println("Glyph not found in Format 1 coverage table")
	} else if format == 2 {
		// Format 2: Range records
		if bounds_check(coverage_offset + 4 > uint(len(data))) {
			fmt.println("Bounds check failed reading range count")
			return 0, false
		}

		range_count := read_u16(data, coverage_offset + 2)
		// fmt.printf("Format 2: Range count = %d\n", range_count)

		// Binary search for the range containing the glyph ID
		low := 0
		high := int(range_count) - 1

		for low <= high {
			mid := (low + high) / 2
			range_offset := coverage_offset + 4 + uint(mid) * 6

			if bounds_check(range_offset + 6 > uint(len(data))) {
				fmt.println("Bounds check failed in range search")
				return 0, false
			}

			start_glyph := cast(Raw_Glyph)read_u16be(data, range_offset)
			end_glyph := cast(Raw_Glyph)read_u16be(data, range_offset + 2)
			start_coverage_index := read_u16(data, range_offset + 4)

			// fmt.printf(
			// 	"Checking range %d-%d at mid=%d (low=%d,high=%d)\n",
			// 	start_glyph,
			// 	end_glyph,
			// 	mid,
			// 	low,
			// 	high,
			// )

			if be_glyph_id < start_glyph {
				high = mid - 1
			} else if be_glyph_id > end_glyph {
				low = mid + 1
			} else {
				// Found the range, calculate the coverage index
				index := start_coverage_index + u16(be_glyph_id - start_glyph)
				// fmt.printf("Match found in range, index = %d\n", index)
				return index, true
			}
		}

		// fmt.println("Glyph not found in Format 2 coverage table")
	} else {
		// fmt.printf("Unsupported coverage format: %d\n", format)
	}

	// Glyph not found in the coverage table
	return 0, false
}


// // A comprehensive metrics struct
// Glyph_Metrics :: struct {
// 	advance_width:  u16, // How far to move horizontally after this glyph
// 	advance_height: u16, // How far to move vertically (usually 0 for horizontal text)
// 	lsb:            i16, // Left side bearing
// 	rsb:            i16, // Right side bearing
// 	bbox:           Bounding_Box, // Glyph bounding box
// 	has_bbox:       bool, // Whether bbox data was available
// }

// // A single function that returns everything needed for layout
// get_glyph_metrics :: proc(font: ^Font, glyph_id: Glyph) -> Glyph_Metrics {
// 	metrics: Glyph_Metrics

// 	// Get horizontal metrics from hmtx
// 	hmtx, has_hmtx := ttf.get_table(font, "hmtx", ttf.load_hmtx_table, ttf.OpenType_Hmtx_Table)
// 	if has_hmtx {
// 		metrics.advance_width, metrics.lsb = get_h_metrics(hmtx, glyph_id)
// 	}

// 	// Get vertical metrics if available
// 	vmtx, has_vmtx := ttf.get_table(font, "vmtx", ttf.load_vmtx_table, ttf.OpenType_Vmtx_Table)
// 	if has_vmtx {
// 		metrics.advance_height, _ = get_v_metrics(vmtx, glyph_id)
// 	}

// 	// Get bounding box
// 	glyf, has_glyf := ttf.get_table(font, "glyf", ttf.load_glyf_table, ttf.Glyf_Table)
// 	if has_glyf {
// 		metrics.bbox, metrics.has_bbox = get_glyph_bbox(glyf, glyph_id)

// 		// Calculate RSB if we have bbox
// 		if metrics.has_bbox {
// 			glyph_width := metrics.bbox.max.x - metrics.bbox.min.x
// 			metrics.rsb = i16(metrics.advance_width) - (metrics.lsb + i16(glyph_width))
// 		}
// 	}

// 	return metrics
// }


// // Get right side bearing (RSB) for a glyph
// get_rsb :: proc(
// 	glyf: ^Glyf_Table, // Glyph table reference
// 	glyph_id: Glyph, // The glyph ID
// 	advance_width: u16, // From get_h_metrics
// 	lsb: i16, // From get_h_metrics
// ) -> (
// 	rsb: i16,
// 	ok: bool,
// ) {
// 	// Get the glyph bounding box
// 	bbox, found := get_glyph_bbox(glyf, glyph_id)
// 	if !found {
// 		return 0, false
// 	}

// 	// Calculate the glyph width from its bounding box
// 	glyph_width := bbox.max.x - bbox.min.x

// 	// Calculate RSB: advance_width - (LSB + glyph_width)
// 	rsb = i16(advance_width) - (lsb + i16(glyph_width))

// 	return rsb, true
// }

// // Get bounding box for a glyph from the glyf table
// get_glyph_bbox :: proc(glyf: ^Glyf_Table, glyph_id: Glyph) -> (bbox: Bounding_Box, ok: bool) {
// 	if glyf == nil {
// 		return {}, false
// 	}

// 	// Get the offset and length of the glyph data
// 	offset, length, found := get_glyph_offset(glyf, glyph_id)
// 	if !found || length == 0 {return {}, false} 	// Glyph not found or is an empty glyph

// 	// Check if we have enough data to read the bounding box
// 	if offset + 10 > uint(len(glyf.data)) {
// 		return {}, false
// 	}

// 	// Read the number of contours (first 2 bytes)
// 	// Negative means composite glyph, positive means simple glyph
// 	num_contours := read_i16(glyf.data, offset)

// 	// Read the bounding box (bytes 2-10)
// 	x_min := read_i16(glyf.data, offset + 2)
// 	y_min := read_i16(glyf.data, offset + 4)
// 	x_max := read_i16(glyf.data, offset + 6)
// 	y_max := read_i16(glyf.data, offset + 8)

// 	// Create the bounding box
// 	bbox = Bounding_Box {
// 		min = {x_min, y_min},
// 		max = {x_max, y_max},
// 	}

// 	// Handle composite glyphs if necessary
// 	if num_contours < 0 {
// 		// TODO:
// 		// For composite glyphs, we might need to consider component transformations
// 		// This is a simplified version; a full implementation would need to process
// 		// all components and calculate the combined bounding box

// 		// For now, just return the bbox read from the composite glyph header
// 	}

// 	return bbox, true
// }

// // Helper to get glyph offset in the glyf table
// get_glyph_offset :: proc(
// 	glyf: ^Glyf_Table,
// 	glyph_id: Glyph,
// ) -> (
// 	offset: uint,
// 	length: uint,
// 	found: bool,
// ) {
// 	// Get loca table to find glyph offsets
// 	loca, has_loca := get_table(glyf.font, "loca", load_loca_table, Loca_Table)
// 	if !has_loca {
// 		return 0, 0, false
// 	}

// 	gid := uint(glyph_id)

// 	// Check bounds
// 	if gid >= uint(loca.num_glyphs) {
// 		return 0, 0, false
// 	}

// 	// Get offset from loca table
// 	glyph_offset := loca.offsets[gid]
// 	next_offset := uint(0)

// 	if gid < uint(loca.num_glyphs - 1) {
// 		next_offset = loca.offsets[gid + 1]
// 	} else {
// 		next_offset = uint(len(glyf.data))
// 	}

// 	// Calculate length
// 	glyph_length := next_offset - glyph_offset

// 	// Check if this is a valid glyph
// 	if glyph_offset >= uint(len(glyf.data)) {
// 		return 0, 0, false
// 	}

// 	return glyph_offset, glyph_length, true
// }
