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
	shader_program: u32,
	quad_vao:       u32, // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
	// Font instances for different sizes/hinting
	font_instances: map[Font_Face]^OpenGL_Font_Face_Instance,
	allocator:      mem.Allocator,
}

Font_Face :: struct {
	font:         ^ttf.Font,
	size_px:      f32,
	dpi:          f32,
	hinting_mode: hinter.Hinting_Mode,
}

OpenGL_Font_Face_Instance :: struct {
	face:           Font_Face,
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

create_opengl_renderer :: proc(allocator: mem.Allocator) -> (OpenGL_Renderer, bool) {
	r := OpenGL_Renderer {
		allocator      = allocator,
		font_instances = make(map[Font_Face]^OpenGL_Font_Face_Instance, allocator),
	}

	// Create empty VAO for rendering quads
	gl.GenVertexArrays(1, &r.quad_vao) // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
	if r.quad_vao == 0 { 	// no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
		fmt.eprintln("Failed to create VAO")
		return r, false
	}

	// Load shaders from files using #load
	vertex_shader_source := string(#load("font.vs"))
	fragment_shader_source := string(#load("font.fs"))

	// Compile shader program
	program, ok := compile_shader_program(vertex_shader_source, fragment_shader_source)
	if !ok {
		fmt.eprintln("Failed to compile font shader program")
		gl.DeleteVertexArrays(1, &r.quad_vao) // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
		return r, false
	}

	r.shader_program = program

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

	// Calculate scale factor (font units to pixels)
	// TODO: revisit when testing hinter:
	instance.scale_factor = size_px / f32(font.units_per_em)

	// Initialize dynamic arrays
	instance.buffer_curves = make([dynamic]Buffer_Curve, r.allocator)
	instance.buffer_glyphs = make([dynamic]Buffer_Glyph, r.allocator)
	instance.glyph_to_index = make(map[ttf.Glyph]int, 0, r.allocator)

	// Create OpenGL resources
	gl.GenBuffers(1, &instance.curves_buffer)
	gl.GenTextures(1, &instance.curves_tbo)
	gl.GenBuffers(1, &instance.glyphs_buffer)
	gl.GenTextures(1, &instance.glyphs_tbo)

	// Setup texture buffer objects
	gl.BindTexture(gl.TEXTURE_BUFFER, instance.curves_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32F, instance.curves_buffer)

	gl.BindTexture(gl.TEXTURE_BUFFER, instance.glyphs_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32I, instance.glyphs_buffer)

	// Unbind
	gl.BindTexture(gl.TEXTURE_BUFFER, 0)

	// Configure hinting for this size
	// hinter.set_pixel_size(font, size_px, dpi, hinting_mode)
	prog, prg_ok := hinter.hinter_program_make(font, ff.size_px, ff.dpi, r.allocator)
	instance.needs_upload = false

	// Store in the renderer's cache
	r.font_instances[ff] = instance

	return face, prg_ok
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

	// Clean up OpenGL resources
	if r.shader_program != 0 {
		gl.DeleteProgram(r.shader_program)
	}
	if r.quad_vao != 0 { 	// no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
		gl.DeleteVertexArrays(1, &r.quad_vao) // no vertices bound here - TODO: move to explicit vertex buffers so one call can render entire strings; current method calls draw on each glyph
	}
}

destroy_font_face :: proc(instance: ^OpenGL_Font_Face_Instance) {
	if instance == nil do return

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
		if _, exists := face.glyph_to_index[glyph_info.glyph_id]; !exists {
			// Extract glyph, convert to curves, add to buffers
			success := add_glyph_to_gpu_cache(face, glyph_info.glyph_id)
			if !success do return false
		}
	}

	// Upload GPU buffers if any new glyphs were added
	if face.needs_upload {
		upload_gpu_buffers(face)
		face.needs_upload = false
	}

	return true
}

render_text :: proc(
	r: ^OpenGL_Renderer,
	face: ^OpenGL_Font_Face_Instance,
	buf: ^shaper.Shaping_Buffer,
	projection: matrix[4, 4]f32,
	view: matrix[4, 4]f32,
	model: matrix[4, 4]f32 = 1, // Handles position, rotation, scale
	color: [4]f32 = {1, 1, 1, 1},
	// options: Render_Options = {},
) {
	unimplemented() // TODO:
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
