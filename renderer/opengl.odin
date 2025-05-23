package renderer

import "../hinter"
import "../shaper"
import "../ttf"
import "core:fmt"
import la "core:math/linalg"
import glsl "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:OpenGL"

OpenGL_Renderer :: struct {
	// OpenGL resources
	shader_program:   u32,
	vao:              u32, // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
	vbo:              u32,
	ebo:              u32,
	// Font instances for different sizes/hinting
	font_instances:   map[Font_Face]^OpenGL_Font_Face_Instance,
	scratch_vertices: [dynamic]Vertex,
	scratch_indices:  [dynamic]u32,
	allocator:        mem.Allocator,
}

Font_Face :: struct {
	font:         ^ttf.Font,
	size_px:      f32,
	dpi:          f32,
	hinting_mode: hinter.Hinting_Mode,
}

OpenGL_Font_Face_Instance :: struct {
	face:           Font_Face,
	glyf:           ^ttf.Glyf_Table,
	scale_factor:   f32,
	hinter:         ^hinter.Hinter_Program,
	// GPU resources specific to this font instance
	curves_buffer:  u32,
	curves_tbo:     u32,
	glyphs_buffer:  u32,
	glyphs_tbo:     u32,

	// CPU-side data for building GPU buffers
	buffer_curves:  [dynamic]Buffer_Curve,
	buffer_glyphs:  [dynamic]Buffer_Glyph, // maps into `buffer_curves`
	glyph_to_index: map[ttf.Glyph]int, // Maps into `buffer_glyphs`
	// any change to cache above requires re-upload:
	needs_upload:   bool,
}

// Single quadratic Bézier curve 
Buffer_Curve :: struct {
	start:   [2]f32, // First control point (on-curve)
	control: [2]f32, // Second control point (off-curve, the "control" point)
	end:     [2]f32, // Third control point (on-curve)
}

// Provides Indexing into `buffer_curves`
Buffer_Glyph :: struct {
	start: i32, // Index of first curve for this glyph in the curves array
	count: i32, // Number of curves that belong to this glyph
}

Vertex :: struct {
	position: [2]f32, // vertexPosition
	uv:       [2]f32, // vertexUV  
	index:    i32, // vertexIndex (buffer index)
}

create_opengl_renderer :: proc(allocator: mem.Allocator) -> (OpenGL_Renderer, bool) {
	r := OpenGL_Renderer {
		allocator        = allocator,
		font_instances   = make(map[Font_Face]^OpenGL_Font_Face_Instance, allocator),
		scratch_indices  = make([dynamic]u32, allocator),
		scratch_vertices = make([dynamic]Vertex, allocator),
	}

	// Create empty VAO for rendering quads
	gl.GenVertexArrays(1, &r.vao) // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
	if r.vao == 0 { 	// no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
		fmt.eprintln("Failed to create VAO")
		return r, false
	}

	gl.GenBuffers(1, &r.vbo)
	gl.GenBuffers(1, &r.ebo)

	// Setup VAO with vertex attributes
	gl.BindVertexArray(r.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, r.vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, r.ebo)

	// Setup vertex attributes (matches your Vertex struct)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, position))
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribIPointer(2, 1, gl.INT, size_of(Vertex), offset_of(Vertex, index))


	// Load shaders from files using #load
	vertex_shader_source := string(#load("font.vs"))
	fragment_shader_source := string(#load("font.fs"))

	// Compile shader program
	program, ok := compile_shader_program(vertex_shader_source, fragment_shader_source)
	if !ok {
		fmt.eprintln("Failed to compile font shader program")
		gl.DeleteVertexArrays(1, &r.vao) // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
		return r, false
	}

	r.shader_program = program

	gl.BindVertexArray(0)

	return r, true
}

compile_shader_program :: proc(vertex_source, fragment_source: string) -> (pid: u32, ok: bool) {
	// Compile vertex shader
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	vertex_str := cstring(raw_data(vertex_source))
	vertex_len := i32(len(vertex_source))
	gl.ShaderSource(vertex_shader, 1, &vertex_str, &vertex_len)
	gl.CompileShader(vertex_shader)

	// Verify vertex shader compilation
	status: i32
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &status)
	if status == 0 {
		log_length: i32
		gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &log_length)
		if log_length > 0 {
			log_data := make([]u8, log_length)
			defer delete(log_data)
			gl.GetShaderInfoLog(vertex_shader, log_length, nil, raw_data(log_data))
			fmt.eprintln("Vertex shader compilation failed:", string(log_data))
		}
		gl.DeleteShader(vertex_shader)
		return 0, false
	}

	// Compile fragment shader
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	fragment_str := cstring(raw_data(fragment_source))
	fragment_len := i32(len(fragment_source))
	gl.ShaderSource(fragment_shader, 1, &fragment_str, &fragment_len)
	gl.CompileShader(fragment_shader)

	// Check fragment shader compilation
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &status)
	if status == 0 {
		log_length: i32
		gl.GetShaderiv(fragment_shader, gl.INFO_LOG_LENGTH, &log_length)
		if log_length > 0 {
			log_data := make([]u8, log_length)
			defer delete(log_data)
			gl.GetShaderInfoLog(fragment_shader, log_length, nil, raw_data(log_data))
			fmt.eprintln("Fragment shader compilation failed:", string(log_data))
		}
		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragment_shader)
		return 0, false
	}

	// Link program
	program := gl.CreateProgram()
	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragment_shader)
	gl.LinkProgram(program)

	// Check program linking
	gl.GetProgramiv(program, gl.LINK_STATUS, &status)
	if status == 0 {
		log_length: i32
		gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &log_length)
		if log_length > 0 {
			log_data := make([]u8, log_length)
			defer delete(log_data)
			gl.GetProgramInfoLog(program, log_length, nil, raw_data(log_data))
			fmt.eprintln("Program linking failed:", string(log_data))
		}
		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragment_shader)
		gl.DeleteProgram(program)
		return 0, false
	}

	// Clean up shaders (they're linked into the program now)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	return program, true
}

create_font_face :: proc(
	r: ^OpenGL_Renderer,
	font: ^ttf.Font,
	size_px: f32,
	hinting_mode: hinter.Hinting_Mode = .Normal,
	dpi: f32 = 96,
) -> (
	face: ^OpenGL_Font_Face_Instance,
	ok: bool,
) {
	// Create the font face key
	ff := Font_Face {
		font         = font,
		size_px      = size_px,
		hinting_mode = hinting_mode,
		dpi          = dpi,
	}
	existing, found := r.font_instances[ff]
	// prevent duplicates:
	if found {return existing, true}

	// Create new font face instance
	instance := new(OpenGL_Font_Face_Instance, r.allocator)
	instance.face = ff
	// Get glyf table for outline extraction
	glyf, has_glyf := ttf.get_table(font, .glyf, ttf.load_glyf_table, ttf.Glyf_Table)
	if !has_glyf {
		fmt.println("No Glyf")
		return nil, false
	}
	instance.glyf = glyf
	// Calculate scale factor (font units to pixels)
	// TODO: revisit when testing hinter:
	instance.scale_factor = size_px / f32(font.units_per_em)

	// Initialize dynamic arrays
	curve_err, glyph_err, index_err: mem.Allocator_Error
	instance.buffer_curves, curve_err = make([dynamic]Buffer_Curve, r.allocator)
	instance.buffer_glyphs, glyph_err = make([dynamic]Buffer_Glyph, r.allocator)
	instance.glyph_to_index, index_err = make(map[ttf.Glyph]int, 0, r.allocator)
	assert(curve_err == nil, "allocation error")
	assert(glyph_err == nil, "allocation error")
	assert(index_err == nil, "allocation error")

	// Create OpenGL resources
	gl.GenBuffers(1, &instance.curves_buffer)
	gl.GenTextures(1, &instance.curves_tbo)
	gl.GenBuffers(1, &instance.glyphs_buffer)
	gl.GenTextures(1, &instance.glyphs_tbo)

	// Create empty curves buffer with some initial capacity
	gl.BindBuffer(gl.TEXTURE_BUFFER, instance.curves_buffer)
	gl.BufferData(gl.TEXTURE_BUFFER, 1 * size_of(Buffer_Curve), nil, gl.STATIC_DRAW)

	// Create empty glyphs buffer with some initial capacity  
	gl.BindBuffer(gl.TEXTURE_BUFFER, instance.glyphs_buffer)
	gl.BufferData(gl.TEXTURE_BUFFER, 1 * size_of(Buffer_Glyph), nil, gl.STATIC_DRAW)

	// Setup texture buffer objects
	gl.BindTexture(gl.TEXTURE_BUFFER, instance.curves_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32F, instance.curves_buffer)

	gl.BindTexture(gl.TEXTURE_BUFFER, instance.glyphs_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32I, instance.glyphs_buffer)

	// Unbind everything
	gl.BindBuffer(gl.TEXTURE_BUFFER, 0)
	gl.BindTexture(gl.TEXTURE_BUFFER, 0)

	// Configure hinting for this size
	// hinter.set_pixel_size(font, size_px, dpi, hinting_mode)
	// prog, prg_ok := hinter.hinter_program_make(font, ff.size_px, ff.dpi, r.allocator)
	instance.needs_upload = false

	// Store in the renderer's cache
	r.font_instances[ff] = instance
	// fmt.println("hinter ok", prg_ok) // FIXME: hinter failing??
	return instance, true
}
// REVISIT: i am assuming the `Font_Face` is the accessor, but this requires unneccesary map lookups; maybe the instance should be the passed object
get_font_instance :: proc(
	r: ^OpenGL_Renderer,
	face: Font_Face,
) -> (
	inst: ^OpenGL_Font_Face_Instance,
	ok: bool,
) {
	return r.font_instances[face]
}

destroy_opengl_renderer :: proc(r: ^OpenGL_Renderer) {
	// Clean up all font instances
	for key, instance in r.font_instances {
		destroy_font_face(instance)
	}
	delete(r.font_instances)
	delete(r.scratch_indices)
	delete(r.scratch_vertices)

	// Clean up OpenGL resources
	if r.shader_program != 0 {
		gl.DeleteProgram(r.shader_program)
	}
	if r.vao != 0 { 	// no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
		gl.DeleteVertexArrays(1, &r.vao) // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
	}
	if r.vbo != 0 {
		gl.DeleteBuffers(1, &r.vbo)
	}
	if r.ebo != 0 {
		gl.DeleteBuffers(1, &r.ebo)
	}
}

destroy_font_face :: proc(instance: ^OpenGL_Font_Face_Instance) {
	if instance == nil {return}

	hinter.hinter_program_delete(instance.hinter)

	// Delete OpenGL resources
	if instance.curves_buffer != 0 {
		gl.DeleteBuffers(1, &instance.curves_buffer)
	}
	if instance.curves_tbo != 0 {
		gl.DeleteTextures(1, &instance.curves_tbo)
	}
	if instance.glyphs_buffer != 0 {
		gl.DeleteBuffers(1, &instance.glyphs_buffer)
	}
	if instance.glyphs_tbo != 0 {
		gl.DeleteTextures(1, &instance.glyphs_tbo)
	}

	// Free dynamic arrays
	delete(instance.buffer_curves)
	delete(instance.buffer_glyphs)
	delete(instance.glyph_to_index)

	free(instance)
}

prepare_shaped_text :: proc(
	r: ^OpenGL_Renderer,
	face: ^OpenGL_Font_Face_Instance,
	buf: ^shaper.Shaping_Buffer,
) -> (
	ok: bool,
) {
	// Ensure all glyphs in the shaped buffer are in the GPU cache
	for glyph_info in buf.glyphs {
		// if glyph_info.glyph_id not_in face.glyph_to_index {
		// 	fmt.println("TEST OK")
		// }
		if _, exists := face.glyph_to_index[glyph_info.glyph_id]; !exists {
			// Extract glyph, convert to curves, add to buffers
			success := add_glyph_to_gpu_cache(face, glyph_info.glyph_id)
			if !success {return false}
		}
	}

	// Upload GPU buffers if any new glyphs were added
	if face.needs_upload {
		upload_gpu_buffers(face)
		face.needs_upload = false
	}

	return true
}


// 2D convenience wrapper
render_text_2d :: proc(
	r: ^OpenGL_Renderer,
	face: ^OpenGL_Font_Face_Instance,
	buf: ^shaper.Shaping_Buffer,
	screen_width, screen_height: int,
	position: [2]f32, // 2D position is fine here
	color: [4]f32 = {1, 1, 1, 1},
	rotation: f32 = 0, // radians
	scale: f32 = 1,
) {
	projection := glsl.mat4Ortho3d(0, f32(screen_width), 0, f32(screen_height), -1, 1)
	view := glsl.mat4(1.0)

	// Build model matrix from 2D parameters
	translation := glsl.mat4Translate({position.x, position.y, 0})
	rotation_mat := glsl.mat4Rotate({0, 0, 1}, rotation)
	scale_mat := glsl.mat4Scale({scale, scale, 1})

	model := translation * rotation_mat * scale_mat

	render_text(r, face, buf, projection, view, model, color)
}

// 3D convenience wrapper for billboards
render_text_billboard :: proc(
	r: ^OpenGL_Renderer,
	face: ^OpenGL_Font_Face_Instance,
	buf: ^shaper.Shaping_Buffer,
	world_position: [3]f32,
	camera_pos, camera_up: [3]f32,
	projection, view: matrix[4, 4]f32,
	color: [4]f32 = {1, 1, 1, 1},
	scale: f32 = 1,
) {
	billboard := create_billboard_matrix(world_position, camera_pos, camera_up)
	if scale != 1 {
		billboard = billboard * glsl.mat4Scale({scale, scale, 1})
	}
	render_text(r, face, buf, projection, view, billboard, color)
}

create_billboard_matrix :: proc(world_pos, camera_pos, camera_up: [3]f32) -> matrix[4, 4]f32 {
	forward := la.normalize(camera_pos - world_pos)
	right := la.normalize(la.cross(camera_up, forward))
	up := la.cross(forward, right)

	return matrix[4, 4]f32{
		right.x, right.y, right.z, 0, 
		up.x, up.y, up.z, 0, 
		forward.x, forward.y, forward.z, 0, 
		world_pos.x, world_pos.y, world_pos.z, 1, 
	}
}


// 1. Glyph outline to curves conversion
add_glyph_to_gpu_cache :: proc(face: ^OpenGL_Font_Face_Instance, glyph_id: ttf.Glyph) -> bool {
	// Check if already cached
	if _, exists := face.glyph_to_index[glyph_id]; exists {return true}

	// Extract glyph outline from font
	// TODO: better memory management here??
	extracted, extract_ok := ttf.extract_glyph(face.glyf, glyph_id, context.temp_allocator)
	if !extract_ok {return false}
	defer free_all(context.temp_allocator)

	// Convert to outline with path segments
	outline, outline_ok := ttf.create_outline_from_extracted(
		face.glyf,
		&extracted,
		nil, // No transform - use font units
		context.temp_allocator,
	)
	if !outline_ok {
		return false
	}

	// Handle empty glyphs (whitespace, etc.)
	if outline.is_empty || len(outline.contours) == 0 {
		// Create empty glyph entry
		glyph_entry := Buffer_Glyph {
			start = i32(len(face.buffer_curves)),
			count = 0,
		}
		glyph_index := len(face.buffer_glyphs)
		append(&face.buffer_glyphs, glyph_entry)
		face.glyph_to_index[glyph_id] = glyph_index
		face.needs_upload = true
		return true
	}

	// Convert outline segments to GPU curves
	start_index := len(face.buffer_curves)
	curve_count := 0

	// Calculate the scale factor to normalize font units to 0-1 space
	scale := 1.0 / f32(face.face.font.units_per_em)

	for contour in outline.contours {
		for segment in contour.segments {
			switch s in segment {
			case ttf.Line_Segment:
				// Convert line to quadratic bezier (control point at midpoint)
				// This ensures the "curve" is actually straight
				midpoint := [2]f32{(s.a[0] + s.b[0]) / 2, (s.a[1] + s.b[1]) / 2}
				curve := Buffer_Curve {
					start   = s.a * scale,
					control = midpoint * scale,
					end     = s.b * scale,
				}
				append(&face.buffer_curves, curve)
				curve_count += 1

			case ttf.Quad_Bezier_Segment:
				// Already quadratic bezier - perfect!
				curve := Buffer_Curve {
					start   = s.a * scale,
					control = s.control * scale,
					end     = s.b * scale,
				}
				append(&face.buffer_curves, curve)
				curve_count += 1
			}
		}
	}

	// Create glyph entry pointing to our curves
	glyph_entry := Buffer_Glyph {
		start = i32(start_index),
		count = i32(curve_count),
	}
	glyph_index := len(face.buffer_glyphs)
	append(&face.buffer_glyphs, glyph_entry)

	// Map glyph ID to buffer index for fast lookup
	face.glyph_to_index[glyph_id] = glyph_index
	face.needs_upload = true

	return true
}

// 2. GPU buffer upload
upload_gpu_buffers :: proc(face: ^OpenGL_Font_Face_Instance) {
	fmt.printf(
		"DEBUG: Uploading %d curves, %d glyphs\n",
		len(face.buffer_curves),
		len(face.buffer_glyphs),
	)

	if len(face.buffer_curves) == 0 {
		fmt.println("DEBUG: No curves to upload!")
		return
	}

	// Upload curves buffer
	gl.BindBuffer(gl.TEXTURE_BUFFER, face.curves_buffer)
	gl.BufferData(
		gl.TEXTURE_BUFFER,
		len(face.buffer_curves) * size_of(Buffer_Curve),
		raw_data(face.buffer_curves),
		gl.STATIC_DRAW,
	)

	// Upload glyphs buffer  
	gl.BindBuffer(gl.TEXTURE_BUFFER, face.glyphs_buffer)
	gl.BufferData(
		gl.TEXTURE_BUFFER,
		len(face.buffer_glyphs) * size_of(Buffer_Glyph),
		raw_data(face.buffer_glyphs),
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.TEXTURE_BUFFER, 0)
	check_gl_error("Buffer upload")
}

// 3. Main render function
render_text :: proc(
	r: ^OpenGL_Renderer,
	face: ^OpenGL_Font_Face_Instance,
	buf: ^shaper.Shaping_Buffer,
	projection: matrix[4, 4]f32,
	view: matrix[4, 4]f32,
	model: matrix[4, 4]f32 = 1,
	color: [4]f32 = {1, 1, 1, 1},
	anti_alias_filter_size: f32 = 1.0,
	use_super_sampling := true,
) {
	if len(buf.glyphs) == 0 {
		fmt.println("DEBUG: No glyphs in buffer!")
		return
	}

	// fmt.printf("DEBUG: Rendering %d glyphs\n", len(buf.glyphs))
	// fmt.printf("DEBUG: First glyph ID: %v\n", buf.glyphs[0].glyph_id)

	gl.UseProgram(r.shader_program)
	check_gl_error("UseProgram")

	defer gl.UseProgram(0)
	// we need these as pointers, so re-declare to get access as a variable instead of parameter:
	projection := projection
	view := view
	model := model
	color := color

	// anti-aliasing:
	aa_window_loc := gl.GetUniformLocation(r.shader_program, "antiAliasingWindowSize")
	gl.Uniform1f(aa_window_loc, anti_alias_filter_size)

	supersample_loc := gl.GetUniformLocation(r.shader_program, "enableSuperSamplingAntiAliasing")
	gl.Uniform1i(supersample_loc, use_super_sampling ? 1 : 0)

	// Set uniforms
	proj_loc := gl.GetUniformLocation(r.shader_program, "projection")
	gl.UniformMatrix4fv(proj_loc, 1, false, &projection[0, 0])
	if proj_loc == -1 {
		fmt.println("DEBUG: Failed to find 'projection' uniform!")
	}
	view_loc := gl.GetUniformLocation(r.shader_program, "view")
	gl.UniformMatrix4fv(view_loc, 1, false, &view[0, 0])

	model_loc := gl.GetUniformLocation(r.shader_program, "model")
	gl.UniformMatrix4fv(model_loc, 1, false, &model[0, 0])

	color_loc := gl.GetUniformLocation(r.shader_program, "color")
	gl.Uniform4fv(color_loc, 1, &color[0])

	// Bind texture buffers (once per draw call)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_BUFFER, face.glyphs_tbo)
	glyphs_loc := gl.GetUniformLocation(r.shader_program, "glyphs")
	gl.Uniform1i(glyphs_loc, 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_BUFFER, face.curves_tbo)
	curves_loc := gl.GetUniformLocation(r.shader_program, "curves")
	gl.Uniform1i(curves_loc, 1)

	// Generates vertices on-the-fly 
	clear(&r.scratch_indices)
	clear(&r.scratch_vertices)

	// cursor position
	pen: [2]f32

	for i in 0 ..< len(buf.glyphs) {
		glyph_info := buf.glyphs[i]
		position := buf.positions[i]

		buffer_index, exists := face.glyph_to_index[glyph_info.glyph_id]
		if !exists {continue}

		// Use metrics from the shaped glyph
		metrics := glyph_info.metrics

		// Calculate quad bounds and UVs
		left := f32(metrics.bbox.min[0]) * face.scale_factor
		bottom := f32(metrics.bbox.min[1]) * face.scale_factor
		right := f32(metrics.bbox.max[0]) * face.scale_factor
		top := f32(metrics.bbox.max[1]) * face.scale_factor

		x := pen.x + f32(position.x_offset) * face.scale_factor
		y := pen.y + f32(position.y_offset) * face.scale_factor

		// UV coordinates in em units
		uv_left := f32(metrics.bbox.min[0]) / f32(face.face.font.units_per_em)
		uv_bottom := f32(metrics.bbox.min[1]) / f32(face.face.font.units_per_em)
		uv_right := f32(metrics.bbox.max[0]) / f32(face.face.font.units_per_em)
		uv_top := f32(metrics.bbox.max[1]) / f32(face.face.font.units_per_em)

		// Add dilation for anti-aliasing
		dilation := 0.1 / f32(face.face.font.units_per_em)
		uv_left -= dilation
		uv_bottom -= dilation
		uv_right += dilation
		uv_top += dilation

		dilation_px := dilation * f32(face.face.font.units_per_em) * face.scale_factor
		left -= dilation_px
		bottom -= dilation_px
		right += dilation_px
		top += dilation_px

		// Generate quad
		base_vertex := u32(len(r.scratch_vertices))

		append(
			&r.scratch_vertices,
			Vertex{{x + left, y + bottom}, {uv_left, uv_bottom}, i32(buffer_index)},
		)
		append(
			&r.scratch_vertices,
			Vertex{{x + right, y + bottom}, {uv_right, uv_bottom}, i32(buffer_index)},
		)
		append(
			&r.scratch_vertices,
			Vertex{{x + right, y + top}, {uv_right, uv_top}, i32(buffer_index)},
		)
		append(
			&r.scratch_vertices,
			Vertex{{x + left, y + top}, {uv_left, uv_top}, i32(buffer_index)},
		)

		append(&r.scratch_indices, base_vertex + 0, base_vertex + 1, base_vertex + 2)
		append(&r.scratch_indices, base_vertex + 2, base_vertex + 3, base_vertex + 0)

		pen.x += f32(position.x_advance) * face.scale_factor
		pen.y += f32(position.y_advance) * face.scale_factor
	}

	if len(r.scratch_indices) == 0 {
		fmt.println("DEBUG: No indices generated!")
		return
	}
	// fmt.printf(
	// 	"DEBUG: Generated %d vertices, %d indices\n",
	// 	len(r.scratch_vertices),
	// 	len(r.scratch_indices),
	// )

	// Upload vertex data (GL_STREAM_DRAW like Green Lightning)
	gl.BindBuffer(gl.ARRAY_BUFFER, r.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(r.scratch_vertices) * size_of(Vertex),
		raw_data(r.scratch_vertices),
		gl.STREAM_DRAW, // Data changes every frame
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, r.ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(r.scratch_indices) * size_of(u32),
		raw_data(r.scratch_indices),
		gl.STREAM_DRAW, // Data changes every frame
	)

	// Setup vertex attributes and draw
	gl.BindVertexArray(r.vao)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
	defer gl.Disable(gl.BLEND)

	gl.DrawElements(gl.TRIANGLES, i32(len(r.scratch_indices)), gl.UNSIGNED_INT, nil)

	gl.BindVertexArray(0)
}


check_gl_error :: proc(location: string) {
	error := gl.GetError()
	if error != gl.NO_ERROR {
		fmt.printf("OpenGL error at %s: %d\n", location, error)
	}
}
