package renderer

import "../shaper"
import "../ttf"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import la "core:math/linalg"
import glsl "core:math/linalg/glsl"
import "core:mem"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"

width: i32 = 1200
height: i32 = 800

// Global state
transform: Transform
drag_controller: DragController
renderer: OpenGL_Renderer
engine: ^shaper.Engine
face: ^OpenGL_Font_Face_Instance
shaped_text: ^shaper.Shaping_Buffer

// UI state
anti_aliasing_window_size: f32 = 1.0
enable_supersampling_anti_aliasing: bool = true
enable_control_points_visualization: bool = false
show_help: bool = true

// Text to render
main_text := `In the center of Fedora, that gray stone metropolis, stands a metal building
with a crystal globe in every room. Looking into each globe, you see a blue
city, the model of a different Fedora. These are the forms the city could have
taken if, for one reason or another, it had not become what we see today.

[from Invisible Cities by Italo Calvino]`


setup_transform :: proc() {
	transform.fovy = math.to_radians_f32(60.0)
	transform.distance = 3.0
	transform.rotation = glsl.mat4(1.0)
	transform.position = glsl.vec4(0.0)
}

setup :: proc() -> bool {
	// enable_debug_output()

	// Create our new renderer
	renderer_ok: bool
	renderer, renderer_ok = create_opengl_renderer(context.allocator)
	if !renderer_ok {
		fmt.println("Failed to create OpenGL renderer")
		return false
	}

	// Create shaping engine
	engine = shaper.create_engine()
	if engine == nil {
		fmt.println("Failed to create shaping engine")
		return false
	}

	// Load and register font
	font, err := ttf.load_font_from_path("../arial.ttf", context.allocator)
	if err != nil {
		fmt.println("Failed to load font")
		return false
	}

	font_id, reg_ok := shaper.register_font(engine, font)
	if !reg_ok {
		fmt.println("Failed to register font")
		return false
	}

	shape_ok, face_ok: bool
	// Create font face for rendering
	face, face_ok = create_font_face(&renderer, font, 48.0, .Normal, 96.0)
	if !face_ok {
		fmt.println("Failed to create font face")
		return false
	}

	// Shape the text
	shaped_text, shape_ok = shaper.shape_text_with_font(engine, font_id, main_text, .latn, .dflt)
	if !shape_ok {
		fmt.println("Failed to shape text")
		return false
	}
	// Prepare text for GPU rendering
	prep_ok := prepare_shaped_text(&renderer, face, shaped_text)
	if !prep_ok {
		fmt.println("Failed to prepare shaped text")
		return false
	}

	init_drag_controller(&drag_controller, &transform)

	return true
}

cleanup :: proc() {
	if shaped_text != nil {
		shaper.release_buffer(engine, shaped_text)
	}
	if engine != nil {
		shaper.destroy_engine(engine)
	}
	destroy_opengl_renderer(&renderer)
}

main :: proc() {
	if !glfw.Init() {
		fmt.println("failed to init glfw")
		return
	}
	defer glfw.Terminate()

	major, minor, rev := glfw.GetVersion()
	fmt.printf("GLFW Version: %d.%d.%d\n", major, minor, rev)

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
	glfw.WindowHint(glfw.SRGB_CAPABLE, glfw.TRUE)

	when ODIN_DEBUG {
		glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, glfw.TRUE)
	}

	window := glfw.CreateWindow(width, height, "GPU Font Rendering Demo", nil, nil)
	if window == nil {
		fmt.println("failed to create window")
		return
	}
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)

	// Load OpenGL functions
	gl.load_up_to(3, 3, glfw.gl_set_proc_address)

	// Print OpenGL version
	fmt.println("OpenGL Version:", gl.GetString(gl.VERSION))
	fmt.println("OpenGL Vendor:", gl.GetString(gl.VENDOR))
	fmt.println("OpenGL Renderer:", gl.GetString(gl.RENDERER))
	fmt.println("GLSL Version:", gl.GetString(gl.SHADING_LANGUAGE_VERSION))

	// Callbacks
	glfw.SetFramebufferSizeCallback(window, size_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetScrollCallback(window, scroll_callback)
	glfw.SetKeyCallback(window, key_callback)

	if !setup() {
		fmt.println("Failed to set up")
		return
	}
	defer cleanup()
	setup_transform()

	// Create background shader for the gradient
	background_shader := create_background_shader()
	defer gl.DeleteProgram(background_shader)

	for !glfw.WindowShouldClose(window) {
		process_input(window)

		fb_width, fb_height := glfw.GetFramebufferSize(window)
		gl.Viewport(0, 0, fb_width, fb_height)

		gl.ClearColor(0.0, 0.0, 0.0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// Draw background gradient
		draw_background(background_shader)

		// Calculate matrices
		aspect := f32(fb_width) / f32(fb_height)
		projection := get_projection_matrix(&transform, aspect)
		view := get_view_matrix(&transform)
		model := glsl.mat4(1.0)
		// Render the text using our new renderer
		render_text(
			&renderer,
			face,
			shaped_text,
			projection,
			view,
			model,
			{1.0, 1.0, 1.0, 1.0}, // white text
			anti_aliasing_window_size,
			enable_supersampling_anti_aliasing,
		)

		// Draw help text if enabled
		if show_help {
			render_help_text(fb_width, fb_height)
		}

		// Check for OpenGL errors
		error := gl.GetError()
		if error != gl.NO_ERROR {
			fmt.println("OpenGL error in main loop:", error)
		}

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

// Create simple background shader
create_background_shader :: proc() -> u32 {
	vertex_source := `#version 330 core
const vec2 vertices[4] = vec2[4](
	vec2(-1.0, -1.0), vec2( 1.0, -1.0),
	vec2(-1.0,  1.0), vec2( 1.0,  1.0)
);
out vec2 position;
void main() {
	position = vertices[gl_VertexID];
	gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
}`


	fragment_source := `#version 330 core
in vec2 position;
out vec3 color;
void main() {
	float t = (position.y + 1.0) / 2.0;
	vec3 bottom = vec3(75.0, 151.0, 201.0) / 255.0;
	vec3 top = vec3(115.0, 193.0, 245.0) / 255.0;
	color = mix(bottom, top, t);
}`


	program, ok := compile_shader_program(vertex_source, fragment_source)
	if !ok {
		fmt.println("Failed to create background shader")
		return 0
	}
	return program
}

// Draw background gradient
draw_background :: proc(shader: u32) {
	gl.UseProgram(shader)
	defer gl.UseProgram(0)

	// Use empty VAO - vertices are generated in shader
	empty_vao: u32
	gl.GenVertexArrays(1, &empty_vao)
	defer gl.DeleteVertexArrays(1, &empty_vao)

	gl.BindVertexArray(empty_vao)
	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	gl.BindVertexArray(0)
}

// Render help text overlay
render_help_text :: proc(screen_width, screen_height: i32) {
	// TODO: Render help text using a smaller font size
	// For now, just demonstrate the concept
	help_text := `Drag and drop a .ttf or .otf file to change the font

Controls:
right drag (or CTRL drag) - move
left drag - trackball rotate  
middle drag - turntable rotate
scroll wheel - zoom

0, 1, 2, 3 - change anti-aliasing window size
A - toggle 2D anti-aliasing
S - reset anti-aliasing settings
C - toggle control points visualization
R - reset view
H - toggle help`


	// Would render with smaller font face here
	// render_text_2d(&renderer, help_font_face, shaped_help, 
	//     screen_width, screen_height, {10, screen_height - 10}, 
	//     {0.8, 0.2, 0.8, 0.8}) // purple help text
}

size_callback :: proc "c" (window: glfw.WindowHandle, w, h: c.int) {
	gl.Viewport(0, 0, w, h)
}

////////////////////////////////////////////////////////////////////////////////
// Transform and UI code (unchanged from your original)

Transform :: struct {
	fovy:     f32,
	distance: f32,
	rotation: glsl.mat4,
	position: glsl.vec4,
}

get_projection_matrix :: proc "c" (transform: ^Transform, aspect: f32) -> glsl.mat4 {
	return glsl.mat4Perspective(transform.fovy, aspect, 0.002, 12.0)
}

get_view_matrix :: proc "c" (transform: ^Transform) -> glsl.mat4 {
	translation := glsl.mat4Translate(transform.position.xyz)
	look_at := glsl.mat4LookAt({0, 0, transform.distance}, {0, 0, 0}, {0, 1, 0})
	return look_at * glsl.mat4(transform.rotation) * translation
}

DragAction :: enum {
	None,
	Translate,
	Rotate_Turntable,
	Rotate_Trackball,
}

DragController :: struct {
	transform:            ^Transform,
	active_button:        i32,
	active_action:        DragAction,
	drag_x, drag_y:       f64,
	wrap_x, wrap_y:       f64,
	virtual_x, virtual_y: f64,
	drag_target:          glsl.vec3,
}

init_drag_controller :: proc(controller: ^DragController, transform: ^Transform) {
	controller.transform = transform
	controller.active_button = -1
	controller.active_action = .None
}

reset_transform :: proc "c" (controller: ^DragController) {
	controller.transform^ = Transform {
		fovy     = math.to_radians_f32(60.0),
		distance = 3.0,
		rotation = glsl.mat4(1.0),
		position = glsl.vec4(0.0),
	}
	controller.active_button = -1
	controller.active_action = .None
}

unproject_mouse_position_to_xy_plane :: proc "c" (
	controller: ^DragController,
	window: glfw.WindowHandle,
	x, y: f64,
	result: ^glsl.vec3,
) -> bool {
	width, height := glfw.GetWindowSize(window)
	width_f64, height_f64 := f64(width), f64(height)

	projection := get_projection_matrix(controller.transform, f32(width_f64 / height_f64))
	view := get_view_matrix(controller.transform)

	rel_x := f32(x / width_f64 * 2.0 - 1.0)
	rel_y := f32(y / height_f64 * 2.0 - 1.0)

	clip_pos := [4]f32{rel_x, -rel_y, 0.5, 1.0}
	inv_mat := glsl.inverse(projection * view)
	world_pos := inv_mat * clip_pos
	world_pos *= 1.0 / world_pos.w

	inv_view := glsl.inverse(view)
	pos := [3]f32{inv_view[0, 3], inv_view[1, 3], inv_view[2, 3]}

	dir := la.normalize(world_pos.xyz - pos.xyz)
	t := -pos.z / dir.z

	result^ = pos + t * dir
	return t > 0.0
}

// Callback implementations (mostly unchanged)
mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	if action == glfw.PRESS && drag_controller.active_button == -1 {
		drag_controller.active_button = button

		if (mods & glfw.MOD_CONTROL) != 0 {
			drag_controller.active_action = .Translate
		} else {
			if button == glfw.MOUSE_BUTTON_2 {
				drag_controller.active_action = .Translate
			} else if button == glfw.MOUSE_BUTTON_3 {
				drag_controller.active_action = .Rotate_Turntable
			} else {
				drag_controller.active_action = .Rotate_Trackball
			}
		}

		drag_controller.drag_x, drag_controller.drag_y = glfw.GetCursorPos(window)
		drag_controller.wrap_x = math.nan_f64()
		drag_controller.wrap_y = math.nan_f64()
		drag_controller.virtual_x = drag_controller.drag_x
		drag_controller.virtual_y = drag_controller.drag_y

		target: glsl.vec3
		ok := unproject_mouse_position_to_xy_plane(
			&drag_controller,
			window,
			drag_controller.drag_x,
			drag_controller.drag_y,
			&target,
		)
		drag_controller.drag_target = ok ? target : glsl.vec3(0)
	} else if action == glfw.RELEASE && drag_controller.active_button == button {
		drag_controller.active_button = -1
		drag_controller.active_action = .None
		drag_controller.drag_x = 0
		drag_controller.drag_y = 0
		drag_controller.wrap_x = math.nan_f64()
		drag_controller.wrap_y = math.nan_f64()
		drag_controller.virtual_x = 0
		drag_controller.virtual_y = 0
		drag_controller.drag_target = glsl.vec3(0)
	}
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, x_pos, y_pos: f64) {
	if drag_controller.active_action == .None {return}

	width, height := glfw.GetWindowSize(window)
	width_f64, height_f64 := f64(width), f64(height)

	delta_x := x_pos - drag_controller.drag_x
	delta_y := y_pos - drag_controller.drag_y

	if !math.is_nan(drag_controller.wrap_x) && !math.is_nan(drag_controller.wrap_y) {
		wrap_delta_x := x_pos - drag_controller.wrap_x
		wrap_delta_y := y_pos - drag_controller.wrap_y

		if wrap_delta_x * wrap_delta_x + wrap_delta_y * wrap_delta_y <
		   delta_x * delta_x + delta_y * delta_y {
			delta_x = wrap_delta_x
			delta_y = wrap_delta_y
			drag_controller.wrap_x = math.nan_f64()
			drag_controller.wrap_y = math.nan_f64()
		}
	}

	drag_controller.drag_x = x_pos
	drag_controller.drag_y = y_pos

	target_x := x_pos
	target_y := y_pos
	changed := false

	if target_x < 0 {
		target_x += width_f64 - 1
		changed = true
	} else if target_x >= width_f64 {
		target_x -= width_f64 - 1
		changed = true
	}

	if target_y < 0 {
		target_y += height_f64 - 1
		changed = true
	} else if target_y >= height_f64 {
		target_y -= height_f64 - 1
		changed = true
	}

	if changed {
		glfw.SetCursorPos(window, target_x, target_y)
		drag_controller.wrap_x = target_x
		drag_controller.wrap_y = target_y
	}

	// Handle different actions
	if drag_controller.active_action == .Translate {
		drag_controller.virtual_x += delta_x
		drag_controller.virtual_y += delta_y

		target: glsl.vec3
		ok := unproject_mouse_position_to_xy_plane(
			&drag_controller,
			window,
			drag_controller.virtual_x,
			drag_controller.virtual_y,
			&target,
		)
		if ok {
			x := drag_controller.transform.position.x
			y := drag_controller.transform.position.y
			delta := target - drag_controller.drag_target
			drag_controller.transform.position.x = math.clamp(x + delta.x, -4.0, 4.0)
			drag_controller.transform.position.y = math.clamp(y + delta.y, -4.0, 4.0)
		}
	} else if drag_controller.active_action == .Rotate_Turntable {
		size := math.min(width_f64, height_f64)
		rx := glsl.mat4Rotate([3]f32{0, 0, 1}, f32(delta_x / size * math.PI))
		ry := glsl.mat4Rotate([3]f32{1, 0, 0}, f32(delta_y / size * math.PI))
		drag_controller.transform.rotation = ry * drag_controller.transform.rotation * rx
	} else if drag_controller.active_action == .Rotate_Trackball {
		size := math.min(width_f64, height_f64)
		rx := glsl.mat4Rotate([3]f32{0, 1, 0}, f32(delta_x / size * math.PI))
		ry := glsl.mat4Rotate([3]f32{1, 0, 0}, f32(delta_y / size * math.PI))
		drag_controller.transform.rotation = ry * rx * drag_controller.transform.rotation
	}
}

scroll_callback :: proc "c" (window: glfw.WindowHandle, x_offset, y_offset: f64) {
	factor := math.clamp(1.0 - f32(y_offset) / 10.0, 0.1, 1.9)
	drag_controller.transform.distance = math.clamp(
		drag_controller.transform.distance * factor,
		0.01,
		10.0,
	)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if action != glfw.PRESS {return}

	switch key {
	case glfw.KEY_R:
		reset_transform(&drag_controller)

	case glfw.KEY_C:
		enable_control_points_visualization = !enable_control_points_visualization

	case glfw.KEY_A:
		enable_supersampling_anti_aliasing = !enable_supersampling_anti_aliasing

	case glfw.KEY_0:
		anti_aliasing_window_size = 0

	case glfw.KEY_1:
		anti_aliasing_window_size = 1

	case glfw.KEY_2:
		anti_aliasing_window_size = 20

	case glfw.KEY_3:
		anti_aliasing_window_size = 40

	case glfw.KEY_S:
		anti_aliasing_window_size = 1
		enable_supersampling_anti_aliasing = true

	case glfw.KEY_H:
		show_help = !show_help
	}
}

process_input :: proc(window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
}

// Debug output (unchanged from your original)
enable_debug_output :: proc() {
	when ODIN_DEBUG {
		fmt.println("enable debug output")
		if gl.DebugMessageCallback != nil {
			gl.Enable(gl.DEBUG_OUTPUT)
			gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
			fmt.printf("DebugMessageCallback: %p\n", gl.DebugMessageCallback)
			fmt.printf("debug_callback: %p\n", debug_callback)
			gl.DebugMessageCallback(debug_callback, nil) // FIXME: this is crashing..
			fmt.println("OpenGL debug output enabled")
		} else {
			fmt.println("OpenGL debug output not available")
		}
	}
}
debug_callback :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {
	return
	// if message == nil {return}
	// context = runtime.default_context()
	// source_str := debug_source_string(source)
	// type_str := debug_type_string(type)
	// severity_str := debug_severity_string(severity)

	// if severity == gl.DEBUG_SEVERITY_NOTIFICATION {
	// 	fmt.printf("GL DEBUG: %s [%s] %s: %s\n", severity_str, source_str, type_str, message)
	// } else {
	// 	fmt.printf("GL DEBUG: %s [%s] %s: %s\n", severity_str, source_str, type_str, message)
	// }
}

debug_source_string :: proc(source: u32) -> string {
	switch source {
	case gl.DEBUG_SOURCE_API:
		return "API"
	case gl.DEBUG_SOURCE_WINDOW_SYSTEM:
		return "Window System"
	case gl.DEBUG_SOURCE_SHADER_COMPILER:
		return "Shader Compiler"
	case gl.DEBUG_SOURCE_THIRD_PARTY:
		return "Third Party"
	case gl.DEBUG_SOURCE_APPLICATION:
		return "Application"
	case gl.DEBUG_SOURCE_OTHER:
		return "Other"
	case:
		return "Unknown"
	}
}

debug_type_string :: proc(type: u32) -> string {
	switch type {
	case gl.DEBUG_TYPE_ERROR:
		return "Error"
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		return "Deprecated Behavior"
	case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		return "Undefined Behavior"
	case gl.DEBUG_TYPE_PORTABILITY:
		return "Portability"
	case gl.DEBUG_TYPE_PERFORMANCE:
		return "Performance"
	case gl.DEBUG_TYPE_MARKER:
		return "Marker"
	case gl.DEBUG_TYPE_PUSH_GROUP:
		return "Push Group"
	case gl.DEBUG_TYPE_POP_GROUP:
		return "Pop Group"
	case gl.DEBUG_TYPE_OTHER:
		return "Other"
	case:
		return "Unknown"
	}
}

debug_severity_string :: proc(severity: u32) -> string {
	switch severity {
	case gl.DEBUG_SEVERITY_HIGH:
		return "HIGH"
	case gl.DEBUG_SEVERITY_MEDIUM:
		return "MEDIUM"
	case gl.DEBUG_SEVERITY_LOW:
		return "LOW"
	case gl.DEBUG_SEVERITY_NOTIFICATION:
		return "NOTIFICATION"
	case:
		return "Unknown"
	}
}
