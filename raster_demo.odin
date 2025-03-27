package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

import raster "./raster"
import shaper "./shaper"
import ttf "./ttf"

import "base:runtime"
import "core:prof/spall"
import "core:sync"

spall_ctx: spall.Context
@(thread_local)
spall_buffer: spall.Buffer

@(instrumentation_enter)
spall_enter :: proc "contextless" (
	proc_address, call_site_return_address: rawptr,
	loc: runtime.Source_Code_Location,
) {
	spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
}

@(instrumentation_exit)
spall_exit :: proc "contextless" (
	proc_address, call_site_return_address: rawptr,
	loc: runtime.Source_Code_Location,
) {
	spall._buffer_end(&spall_ctx, &spall_buffer)
}

// main :: proc() {
// 	when ODIN_DEBUG {
// 		track: mem.Tracking_Allocator
// 		mem.tracking_allocator_init(&track, context.allocator)
// 		context.allocator = mem.tracking_allocator(&track)

// 		defer {
// 			if len(track.allocation_map) > 0 {
// 				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
// 				for _, entry in track.allocation_map {
// 					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
// 				}
// 			}
// 			mem.tracking_allocator_destroy(&track)
// 		}
// 	}

// 	_main()
// }

main :: proc() {
	spall_ctx = spall.context_create("rune.spall")
	defer spall.context_destroy(&spall_ctx)

	buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE * 1024)
	defer delete(buffer_backing)

	spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))
	defer spall.buffer_destroy(&spall_ctx, &spall_buffer)
	/////////////////////////////////////////////////////////////////////
	// defer fmt.println("Main Finished")

	engine := shaper.create_engine()
	defer shaper.destroy_engine(engine)

	// Load and register a font
	font_path := "./segoeui.ttf"
	font, err := ttf.load_font(font_path)
	if err != .None {
		fmt.eprintln("Error loading font:", err)
		return
	}
	// defer ttf.destroy_font(&font) // <- the engine will delete them; maybe have that be an optional flag

	font_id, ok := shaper.register_font(engine, &font)
	if !ok {
		fmt.eprintln("Error registering font")
		return
	}

	// fmt.println("Font loaded and registered successfully")
	// fmt.println("Units per em:", font.units_per_em)

	// test_specific_glyphs(&font)

	test_text_rendering(engine, font_id, &font)
}

test_specific_glyphs :: proc(font: ^ttf.Font) {
	// fmt.println("\nTesting specific glyphs...")

	cmap_table, has_cmap := ttf.get_table(font, "cmap", ttf.load_cmap_table, ttf.CMAP_Table)
	if !has_cmap {
		// fmt.println("Error: Could not load cmap table")
		return
	}

	iacute_rune: rune = 'í'
	iacute_glyph, found_iacute := ttf.get_glyph_from_cmap(font, iacute_rune)

	if found_iacute {
		// fmt.printf("Found iacute glyph (ID: %d)\n", iacute_glyph)
		render_single_glyph(font, iacute_glyph, 72, "TEST_IMAGE.bmp")
		// fmt.println("Done with render_single_glyph")
	} else {
		fmt.println("Could not find iacute glyph")
	}
}

// Render the individual components of a composite glyph
render_component_glyphs :: proc(font: ^ttf.Font, glyph_id: ttf.Glyph) {
	glyf_table, has_glyf := ttf.get_table(font, "glyf", ttf.load_glyf_table, ttf.Glyf_Table)
	if !has_glyf {
		return
	}

	glyph_entry, got_entry := ttf.get_glyf_entry(glyf_table, glyph_id)
	if !got_entry || glyph_entry.is_empty || !ttf.is_composite_glyph(glyph_entry) {
		return
	}

	parser, parser_ok := ttf.init_component_parser(glyph_entry)
	if !parser_ok {
		return
	}

	component_index := 0
	for {
		component, comp_ok := ttf.next_component(&parser)
		if !comp_ok {
			break
		}

		// Render each component separately
		component_filename := fmt.tprintf("component_%d.bmp", component.glyph_index)
		render_single_glyph(font, component.glyph_index, 72, component_filename)

		// fmt.printf(
		// 	"Rendered component %d (Glyph ID: %d) to %s\n",
		// 	component_index,
		// 	component.glyph_index,
		// 	component_filename,
		// )

		component_index += 1
	}
}

test_text_rendering :: proc(engine: ^shaper.Rune, font_id: shaper.Font_ID, font: ^ttf.Font) {
	// test_text := "Affinity for Odin-native font shaping."
	test_text := `
	// GenerateAnimalURL creates a URL for accessing the animal record
func GenerateAnimalURL(ctx context.Context, societyID int, animalID int, registryID string, isRef bool) (string, error) {
    // Get society slug
    var societySlug string
    err := db.Conn.QueryRow(ctx, '
        SELECT slug FROM societies WHERE society_id = $1
    ', societyID).Scan(&societySlug)

    if err != nil {
        return "", err
    }

    // For registered animals with a registry ID
    if registryID != "" {
        if isRef {
            // Reference animals use a different URL pattern
            return fmt.Sprintf("https://pedigree.dev/#/%s/animals/ref/%s", societySlug, registryID), nil
        } else {
            // Directly registered animals
            return fmt.Sprintf("https://pedigree.dev/#/%s/animals/%s", societySlug, registryID), nil
        }
    }

    // For animals without registration IDs
    return fmt.Sprintf("https://pedigree.dev/#/%s/animals/id/%d", societySlug, animalID), nil
}
`


	features := shaper.create_feature_set(
		.ccmp, // Glyph composition/decomposition
		.liga, // Standard ligatures
		.clig, // Contextual ligatures
		.dlig, // discretionary ligatures
		.kern, // Kerning
		.mark, // Mark positioning
		.hlig,
		.rlig,
		.ccmp,
	)

	size_px := f32(72)

	buffer, shape_ok := shaper.shape_text_with_font(
		engine,
		font_id,
		test_text,
		.latn,
		.dflt,
		features,
	)
	defer shaper.release_buffer(engine, buffer)

	if !shape_ok {
		fmt.eprintln("Error shaping text")
		return
	}

	// fmt.println("\nShaped text:", test_text)
	// fmt.println("Glyph count:", len(buffer.glyphs))

	// fmt.println("\nRendering text...")
	// render_text(font, buffer, size_px, "text.bmp")
}


render_text :: proc(
	font: ^ttf.Font,
	buffer: ^shaper.Shaping_Buffer,
	size_px: f32,
	filename: string,
) -> bool {
	hhea_table, has_hhea := ttf.get_table(
		font,
		"hhea",
		ttf.load_hhea_table,
		ttf.OpenType_Hhea_Table,
	)
	if !has_hhea {
		fmt.println("ERROR: HHea table not found")
		return false
	}

	ascender := ttf.get_ascender(hhea_table)
	descender := ttf.get_descender(hhea_table)

	// fmt.printf("Font metrics: ascender=%d, descender=%d\n", ascender, descender)

	// Scale factor for font units to pixels
	scale := size_px / f32(font.units_per_em)
	// fmt.printf("Scale factor: %f\n", scale)

	// Calculate total advance to determine width
	total_advance := 0
	for i := 0; i < len(buffer.positions); i += 1 {
		total_advance += int(buffer.positions[i].x_advance)
	}

	// fmt.printf("Total advance in font units: %d\n", total_advance)

	// Padding around text
	padding := 20

	// Calculate bitmap dimensions
	scaled_width := int(f32(total_advance) * scale)
	scaled_height := int(f32(ascender - descender) * scale)

	bitmap_width := scaled_width + padding * 2
	bitmap_height := scaled_height + padding * 2

	// fmt.printf("Creating bitmap: %d x %d pixels\n", bitmap_width, bitmap_height)

	// Create bitmap
	bitmap := raster.create_bitmap(bitmap_width, bitmap_height)
	defer delete(bitmap.data)

	// Initial cursor position (left padding)
	cursor_x := padding

	// Baseline position (from top)
	baseline_y := padding + int(f32(ascender) * scale)

	// fmt.printf("Baseline position: %d pixels from top\n", baseline_y)

	// Draw baseline (for debugging)
	for x := 0; x < bitmap_width; x += 1 {
		raster.draw_pixel(&bitmap, x, baseline_y, 200)
	}

	glyf, has_glyf := ttf.get_table(font, "glyf", ttf.load_glyf_table, ttf.Glyf_Table)
	assert(has_glyf)

	// Place each glyph
	for i := 0; i < len(buffer.glyphs); i += 1 {
		glyph_id := buffer.glyphs[i].glyph_id

		// Get position adjustments from shaper
		x_offset := int(f32(buffer.positions[i].x_offset) * scale)
		y_offset := int(f32(buffer.positions[i].y_offset) * scale)

		// Get the glyph outline
		outline, got_outline := ttf.parse_glyph_outline(glyf, glyph_id)
		if !got_outline {
			// Skip this glyph but apply advance
			cursor_x += int(f32(buffer.positions[i].x_advance) * scale)
			continue
		}
		defer ttf.destroy_glyph_outline(&outline)

		// Skip empty glyphs (spaces, etc.) but apply advance
		if outline.is_empty {
			cursor_x += int(f32(buffer.positions[i].x_advance) * scale)
			continue
		}

		// Calculate glyph position including offsets
		glyph_x := cursor_x + x_offset
		glyph_y := baseline_y + y_offset

		cluster_index := buffer.glyphs[i].cluster

		// fmt.printf(
		// 	"Placing glyph %d (ID: %d, cluster: %v) at x: %d, y: %d\n",
		// 	i,
		// 	glyph_id,
		// 	cluster_index,
		// 	glyph_x,
		// 	glyph_y,
		// )

		// Draw bounding box around glyph for debugging
		left := glyph_x + int(f32(outline.bounds.min.x) * scale)
		right := glyph_x + int(f32(outline.bounds.max.x) * scale)
		top := glyph_y - int(f32(outline.bounds.max.y) * scale)
		bottom := glyph_y - int(f32(outline.bounds.min.y) * scale)

		// Draw rect outline for debugging
		for x := left; x <= right; x += 1 {
			raster.draw_pixel(&bitmap, x, top, 150)
			raster.draw_pixel(&bitmap, x, bottom, 150)
		}
		for y := top; y <= bottom; y += 1 {
			raster.draw_pixel(&bitmap, left, y, 150)
			raster.draw_pixel(&bitmap, right, y, 150)
		}

		// Render each contour in the glyph
		for &contour in outline.contours {
			// Render all segments in the contour
			for segment in contour.segments {
				switch s in segment {
				case ttf.Line_Segment:
					// Convert to bitmap coordinates
					x1 := glyph_x + int(f32(s.a[0]) * scale)
					y1 := glyph_y - int(f32(s.a[1]) * scale) // Flip Y axis
					x2 := glyph_x + int(f32(s.b[0]) * scale)
					y2 := glyph_y - int(f32(s.b[1]) * scale) // Flip Y axis

					// Draw the line
					raster.draw_line(&bitmap, x1, y1, x2, y2, 0)

				case ttf.Quad_Bezier_Segment:
					// Convert to bitmap coordinates
					x1 := glyph_x + int(f32(s.a[0]) * scale)
					y1 := glyph_y - int(f32(s.a[1]) * scale) // Flip Y axis
					cx := glyph_x + int(f32(s.control[0]) * scale)
					cy := glyph_y - int(f32(s.control[1]) * scale) // Flip Y axis
					x2 := glyph_x + int(f32(s.b[0]) * scale)
					y2 := glyph_y - int(f32(s.b[1]) * scale) // Flip Y axis

					// Draw the quadratic bezier
					raster.draw_quad_bezier(&bitmap, x1, y1, cx, cy, x2, y2, 0)
				}
			}
		}

		// Move cursor by advance
		cursor_x += int(f32(buffer.positions[i].x_advance) * scale)
	}

	// Save bitmap to file
	return raster.save_bitmap_to_bmp(&bitmap, filename)
}

// Render a single glyph to a bitmap file
render_single_glyph :: proc(
	font: ^ttf.Font,
	glyph_id: ttf.Glyph,
	size_px: f32,
	filename: string,
) -> bool {
	glyf, has_glyf := ttf.get_table(font, "glyf", ttf.load_glyf_table, ttf.Glyf_Table)
	assert(has_glyf)
	// Get glyph outline
	outline, ok := ttf.parse_glyph_outline(glyf, glyph_id)
	if !ok {
		fmt.println("Error: Could not parse glyph outline")
		return false
	}
	defer ttf.destroy_glyph_outline(&outline)

	// For empty glyphs (like space), create a minimal bitmap
	width, height: int
	if outline.is_empty {
		width, height = 100, 100
	} else {
		// Calculate bitmap size based on glyph metrics and scale
		scale := size_px / f32(font.units_per_em)
		width = int(f32(outline.bounds.max.x - outline.bounds.min.x) * scale) + 40 // Add padding
		height = int(f32(outline.bounds.max.y - outline.bounds.min.y) * scale) + 40

		// Ensure minimum size
		if width < 100 {width = 100}
		if height < 100 {height = 100}
	}

	// Create bitmap
	bitmap := raster.create_bitmap(width, height)
	defer delete(bitmap.data)

	// Draw debug grid
	raster.draw_debug_grid(&bitmap)
	// Rasterize the glyph
	if !raster.rasterize_glyph(font, glyph_id, &bitmap, size_px) {
		fmt.printf("Error rasterizing glyph %d\n", glyph_id)
		return false
	}

	// Save to file
	if !raster.save_bitmap_to_bmp(&bitmap, filename) {
		fmt.printf("Error saving bitmap to %s\n", filename)
		return false
	}

	// fmt.printf("Saved glyph %d to %s\n", glyph_id, filename)

	// Print component information if this is a composite glyph

	glyph_entry, got_entry := ttf.get_glyf_entry(glyf, glyph_id)
	if !got_entry || glyph_entry.is_empty {
		return true
	}

	// Print information about its components if it's a composite
	if ttf.is_composite_glyph(glyph_entry) {
		// fmt.printf("Glyph %d is a composite glyph with components:\n", glyph_id)

		// Initialize component parser
		parser, parser_ok := ttf.init_component_parser(glyph_entry)
		if !parser_ok {
			return true
		}

		component_index := 0
		for {
			component, comp_ok := ttf.next_component(&parser)
			if !comp_ok {
				break
			}

			// Print component info
			// fmt.printf(
			// 	"  Component %d: Glyph ID %d, offset (%d, %d)\n",
			// 	component_index,
			// 	component.glyph_index,
			// 	component.x_offset,
			// 	component.y_offset,
			// )

			if component.flags.WE_HAVE_A_SCALE {
				// fmt.printf("    Scale: %f\n", component.scale_x)
			} else if component.flags.WE_HAVE_AN_X_AND_Y_SCALE {
				// fmt.printf("    Scale X: %f, Scale Y: %f\n", component.scale_x, component.scale_y)
			} else if component.flags.WE_HAVE_A_TWO_BY_TWO {
				// fmt.printf(
				// 	"    Matrix: [%f %f; %f %f]\n",
				// 	component.matrx[0],
				// 	component.matrx[1],
				// 	component.matrx[2],
				// 	component.matrx[3],
				// )
			}

			component_index += 1
		}
	}

	return true
}
