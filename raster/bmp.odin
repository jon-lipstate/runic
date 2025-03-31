package rasterizer

import "../ttf"
import "core:fmt"
import "core:math"
import "core:os"

// Simple bitmap representation
Bitmap :: struct {
	width:  int,
	height: int,
	data:   []u8, // One byte per pixel (0=black, 255=white)
}

// Create a new bitmap with white background
create_bitmap :: proc(width, height: int) -> Bitmap {
	bitmap := Bitmap {
		width  = width,
		height = height,
		data   = make([]u8, width * height),
	}
	for i := 0; i < len(bitmap.data); i += 1 {
		bitmap.data[i] = 255 // Initialize to white background
	}

	return bitmap
}

// Draw a pixel with alpha blending
draw_pixel :: proc(bitmap: ^Bitmap, x, y: int, color: u8) {
	if x < 0 || x >= bitmap.width || y < 0 || y >= bitmap.height {return}
	idx := y * bitmap.width + x
	bitmap.data[idx] = color
}

// Draw a line with Bresenham's algorithm
draw_line :: proc(bitmap: ^Bitmap, x0, y0, x1, y1: int, color: u8 = 0) {
	// Fast path for horizontal and vertical lines
	if x0 == x1 {
		// Vertical line
		start, end := y0, y1
		if y0 > y1 {
			start, end = y1, y0
		}
		for y := start; y <= end; y += 1 {
			draw_pixel(bitmap, x0, y, color)
		}
		return
	}

	if y0 == y1 {
		// Horizontal line
		start, end := x0, x1
		if x0 > x1 {
			start, end = x1, x0
		}
		for x := start; x <= end; x += 1 {
			draw_pixel(bitmap, x, y0, color)
		}
		return
	}

	// Bresenham's algorithm for arbitrary lines
	dx := abs(x1 - x0)
	dy := -abs(y1 - y0)
	sx := x0 < x1 ? 1 : -1
	sy := y0 < y1 ? 1 : -1
	err := dx + dy

	x, y := x0, y0

	for {
		draw_pixel(bitmap, x, y, color)

		if x == x1 && y == y1 {
			break
		}

		e2 := 2 * err
		if e2 >= dy {
			if x == x1 {break}
			err += dy
			x += sx
		}

		if e2 <= dx {
			if y == y1 {break}
			err += dx
			y += sy
		}
	}
}

// Draw a quadratic bezier curve
draw_quad_bezier :: proc(bitmap: ^Bitmap, x0, y0, x1, y1, x2, y2: int, color: u8 = 0) {
	// If control point is close to either endpoint, just draw a line
	if (abs(x0 - x1) + abs(y0 - y1) <= 1) && (abs(x2 - x1) + abs(y2 - y1) <= 1) {
		draw_line(bitmap, x0, y0, x2, y2, color)
		return
	}

	// Calculate number of segments based on curve length
	dx1, dy1 := x1 - x0, y1 - y0
	dx2, dy2 := x2 - x1, y2 - y1

	// Approximate length
	approx_length := math.sqrt(f32(dx1 * dx1 + dy1 * dy1)) + math.sqrt(f32(dx2 * dx2 + dy2 * dy2))
	segments := int(approx_length / 2)
	if segments < 10 {
		segments = 10
	}
	if segments > 100 {
		segments = 100 // Cap to avoid too many segments
	}

	prev_x, prev_y := x0, y0

	for i := 1; i <= segments; i += 1 {
		t := f32(i) / f32(segments)
		u := 1.0 - t

		// Quadratic Bezier formula
		x := int(u * u * f32(x0) + 2 * u * t * f32(x1) + t * t * f32(x2))
		y := int(u * u * f32(y0) + 2 * u * t * f32(y1) + t * t * f32(y2))

		draw_line(bitmap, prev_x, prev_y, x, y, color)
		prev_x, prev_y = x, y
	}
}

// Rasterizer context for glyph rendering
Rasterizer :: struct {
	bitmap:   ^Bitmap, // Target bitmap
	font:     ^ttf.Font, // Font data reference
	size_px:  f32, // Size in pixels
	glyph_id: ttf.Glyph, // Current glyph being rendered

	// Transformation parameters
	scale:    f32, // Scale factor based on size
	center_x: f32, // X center position in bitmap
	center_y: f32, // Y center position in bitmap

	// Glyph metrics
	bbox:     ttf.Bounding_Box, // Glyph bounding box
}

// Transform a point from glyph space to bitmap space
transform_point :: proc(rasterizer: ^Rasterizer, x, y: i16) -> (int, int) {
	return transform_point_f32(rasterizer, f32(x), f32(y))
}

// Transform a point from glyph space to bitmap space with float precision
transform_point_f32 :: proc(rasterizer: ^Rasterizer, x, y: f32) -> (int, int) {
	// fmt.printf("transform_point_f32 :: start at x: %v,y: %v\n", x, y)

	// Calculate glyph dimensions in font units
	glyph_width := f32(rasterizer.bbox.max.x - rasterizer.bbox.min.x)
	glyph_height := f32(rasterizer.bbox.max.y - rasterizer.bbox.min.y)

	// Calculate center of the glyph in font units
	glyph_center_x := f32(rasterizer.bbox.min.x + rasterizer.bbox.max.x) / 2
	glyph_center_y := f32(rasterizer.bbox.min.y + rasterizer.bbox.max.y) / 2

	// Translate the point relative to glyph center
	rel_x := x - glyph_center_x
	rel_y := y - glyph_center_y

	// Apply scaling
	scaled_x := rel_x * rasterizer.scale
	scaled_y := -rel_y * rasterizer.scale // Flip Y coordinate

	// Translate to the center position in the bitmap
	pixel_x := int(rasterizer.center_x + scaled_x + 0.5)
	pixel_y := int(rasterizer.center_y + scaled_y + 0.5)
	return pixel_x, pixel_y
}

// Save bitmap to a BMP file
save_bitmap_to_bmp :: proc(bitmap: ^Bitmap, filename: string) -> bool {
	// Create BMP file
	file, err := os.open(filename, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0644)
	if err != 0 {
		fmt.println("Failed to create BMP file")
		return false
	}
	defer os.close(file)

	// Calculate padded row size (BMP rows must be multiples of 4 bytes)
	row_size := uint(bitmap.width * 3 + 3) & ~uint(3)
	pixel_data_size := u32(row_size * uint(bitmap.height))

	// BMP Header (14 bytes)
	header := [14]u8 {
		'B',
		'M', // Signature
		0,
		0,
		0,
		0, // File size (filled below)
		0,
		0,
		0,
		0, // Reserved
		54,
		0,
		0,
		0, // Pixel data offset
	}

	// File size = header (14) + DIB header (40) + pixel data
	file_size := u32(14 + 40 + pixel_data_size)

	// Fill in file size (little-endian)
	header[2] = u8(file_size)
	header[3] = u8(file_size >> 8)
	header[4] = u8(file_size >> 16)
	header[5] = u8(file_size >> 24)

	// DIB Header (BITMAPINFOHEADER - 40 bytes)
	dib_header := [40]u8 {
		40,
		0,
		0,
		0, // Header size
		0,
		0,
		0,
		0, // Width (filled below)
		0,
		0,
		0,
		0, // Height (filled below)
		1,
		0, // Color planes
		24,
		0, // Bits per pixel (24-bit RGB)
		0,
		0,
		0,
		0, // Compression (0 = none)
		0,
		0,
		0,
		0, // Image size (can be 0 for uncompressed)
		0,
		0,
		0,
		0, // Horizontal resolution (pixels/meter)
		0,
		0,
		0,
		0, // Vertical resolution (pixels/meter)
		0,
		0,
		0,
		0, // Colors in palette
		0,
		0,
		0,
		0, // Important colors
	}

	// Fill in width (little-endian)
	width := u32(bitmap.width)
	dib_header[4] = u8(width)
	dib_header[5] = u8(width >> 8)
	dib_header[6] = u8(width >> 16)
	dib_header[7] = u8(width >> 24)

	// Fill in height (little-endian) - negative for top-down image
	height := -u32(bitmap.height) // Negative for top-down orientation
	dib_header[8] = u8(height)
	dib_header[9] = u8(height >> 8)
	dib_header[10] = u8(height >> 16)
	dib_header[11] = u8(height >> 24)

	// Write headers
	os.write(file, header[:])
	os.write(file, dib_header[:])

	// Allocate row buffer with padding
	row := make([]u8, row_size)
	defer delete(row)

	// Convert grayscale to BGR and write pixel data
	for y := 0; y < bitmap.height; y += 1 {
		for x := 0; x < bitmap.width; x += 1 {
			// Get grayscale value (0 = black, 255 = white)
			gray := bitmap.data[y * bitmap.width + x]

			// Convert to BGR (BMP format) - all channels are the same for grayscale
			row[x * 3] = gray // Blue
			row[x * 3 + 1] = gray // Green
			row[x * 3 + 2] = gray // Red
		}

		// Write row data
		os.write(file, row[:])
	}

	return true
}

// Draw debug grid
draw_debug_grid :: proc(bitmap: ^Bitmap, spacing: int = 10, color: u8 = 200) {
	center_x := bitmap.width / 2
	center_y := bitmap.height / 2

	// Draw vertical and horizontal center lines
	for y := 0; y < bitmap.height; y += 1 {
		draw_pixel(bitmap, center_x, y, color)
	}

	for x := 0; x < bitmap.width; x += 1 {
		draw_pixel(bitmap, x, center_y, color)
	}

	// Draw grid lines
	for y := 0; y < bitmap.height; y += spacing {
		for x := 0; x < bitmap.width; x += 1 {
			draw_pixel(bitmap, x, y, color)
		}
	}

	for x := 0; x < bitmap.width; x += spacing {
		for y := 0; y < bitmap.height; y += 1 {
			draw_pixel(bitmap, x, y, color)
		}
	}
}


rasterize_glyph :: proc(
	font: ^ttf.Font,
	glyph_id: ttf.Glyph,
	bitmap: ^Bitmap,
	size_px: f32,
) -> bool {
	if int(glyph_id) >= len(font._v2.glyphs) {
		return false
	}
	glyf, has_glyf := ttf.get_table(font, "glyf", ttf.load_glyf_table, ttf.Glyf_Table)
	if !has_glyf {return false}
	// Get the glyph outline
	extracted: ttf.Extracted_Glyph
	ok: bool
	if font._v2.glyphs[glyph_id] == nil {
		extracted, ok = ttf.extract_glyph(glyf, glyph_id, font._v2.allocator)
		if ok {
			font._v2.glyphs[glyph_id] = new_clone(extracted, font._v2.allocator)
		}
	} else {
		extracted = font._v2.glyphs[glyph_id]^
		ok = true
	}
	if !ok {
		fmt.println("failed to extract glyph")
	}
	outline, ook := ttf.create_outline_from_extracted(glyf, &extracted)
	if !ook {
		fmt.println("Failed to create contour")
		return false
	}
	defer ttf.destroy_glyph_outline(&outline)
	// Empty glyphs (e.g., space) need no rendering
	if outline.is_empty {return true}

	// Create rasterizer context
	scale := size_px / f32(font.units_per_em)

	rasterizer := Rasterizer {
		bitmap   = bitmap,
		font     = font,
		size_px  = size_px,
		glyph_id = glyph_id,
		scale    = scale,
		center_x = f32(bitmap.width) / 2,
		center_y = f32(bitmap.height) / 2,
		bbox     = outline.bounds,
	}
	// fmt.printf(
	// 	"Rasterizer Starting State: size_px:%v, scale:%v, ctr_x:%v, ctr_y:%v, bbox:%v\n",
	// 	rasterizer.size_px,
	// 	rasterizer.scale,
	// 	rasterizer.center_x,
	// 	rasterizer.center_y,
	// 	rasterizer.bbox,
	// )
	// Render each contour
	for &contour, i in outline.contours {
		// Render all segments in the contour
		for segment, j in contour.segments {
			// fmt.println("Iter ij", i, j)
			switch s in segment {
			case ttf.Line_Segment:
				// fmt.println(s)
				// Transform points to bitmap space
				x1, y1 := transform_point_f32(&rasterizer, s.a[0], s.a[1])
				x2, y2 := transform_point_f32(&rasterizer, s.b[0], s.b[1])
				// fmt.println("calling draw_line", x1, y1, x2, y2)
				// Draw the line
				draw_line(bitmap, x1, y1, x2, y2, 0)

			case ttf.Quad_Bezier_Segment:
				fmt.println(s)
				// Transform points to bitmap space
				x1, y1 := transform_point_f32(&rasterizer, s.a[0], s.a[1])
				cx, cy := transform_point_f32(&rasterizer, s.control[0], s.control[1])
				x2, y2 := transform_point_f32(&rasterizer, s.b[0], s.b[1])
				// fmt.println("calling draw_quad_bezier", x1, y1, cx, cy, x2, y2)

				// Draw the quadratic bezier
				draw_quad_bezier(bitmap, x1, y1, cx, cy, x2, y2, 0)
			}
		}
	}

	return true
}
