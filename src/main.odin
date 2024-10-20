package main

import "core:fmt"
import "core:math"
import "core:mem"
import gl "vendor:OpenGL"
import fw "vendor:glfw"

GL_MINOR_VERSION :: 3
GL_MAJOR_VERSION :: 3

WIN_W: i32 : 960
WIN_H: i32 : 540

vertex_shader_source: cstring = `#version 330 core
layout (location = 0) in vec3 aPos;

void main()
{
gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}`
fragment_shader_source: cstring = `#version 330 core
out vec4 FragColor;

void main()
{
FragColor = vec4(1.0f, 0.984f, 0.0f, 1.0f);
}`

fragment_shader_source2: cstring = `#version 330 core
out vec4 FragColor;

uniform vec4 ourColor;

void main()
{
FragColor = ourColor;
}`

wireframe_mode := false

main :: proc() {
	// track for memory leaks
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	if fw.Init() != true {
		fmt.eprintln("Failed to init GLFW")
		return
	}
	fmt.println("GLFW initialized")
	defer fw.Terminate()

	fw.WindowHint(fw.CONTEXT_VERSION_MINOR, GL_MAJOR_VERSION)
	fw.WindowHint(fw.CONTEXT_VERSION_MAJOR, GL_MINOR_VERSION)
	fw.WindowHint(fw.OPENGL_PROFILE, fw.OPENGL_CORE_PROFILE)

	window := fw.CreateWindow(WIN_W, WIN_H, "Learn OpenGL", nil, nil)
	defer fw.DestroyWindow(window)

	if window == nil {
		fmt.eprintln("Failed to create GLFW Window")
		return
	}
	fmt.println("Window created")

	fw.MakeContextCurrent(window)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, fw.gl_set_proc_address)

	fw.SetFramebufferSizeCallback(window, framebuffer_size_callback)
	fw.SetKeyCallback(window, key_callback)

	// SHADERS
	vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	defer gl.DeleteShader(vertex_shader)

	gl.ShaderSource(vertex_shader, 1, &vertex_shader_source, nil)
	gl.CompileShader(vertex_shader)

	success: i32
	info_log: []u8
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)

	if success != 1 {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, raw_data(info_log))
		fmt.eprintln("Failed to compile vertex shader: ", info_log)
	}

	fragment_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	defer gl.DeleteShader(fragment_shader)

	gl.ShaderSource(fragment_shader, 1, &fragment_shader_source, nil)
	gl.CompileShader(fragment_shader)

	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)

	if success != 1 {
		gl.GetShaderInfoLog(fragment_shader, 512, nil, raw_data(info_log))
		fmt.eprintln("Failed to compile fragment shader: ", info_log)
	}

	shader_program: u32 = gl.CreateProgram()
	defer gl.DeleteProgram(shader_program)

	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)

	fragment_shader2: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	defer gl.DeleteShader(fragment_shader2)

	gl.ShaderSource(fragment_shader2, 1, &fragment_shader_source2, nil)
	gl.CompileShader(fragment_shader2)

	gl.GetShaderiv(fragment_shader2, gl.COMPILE_STATUS, &success)

	if success != 1 {
		gl.GetShaderInfoLog(fragment_shader2, 512, nil, raw_data(info_log))
		fmt.eprintln("Failed to compile fragment shader: ", info_log)
	}

	shader_program2: u32 = gl.CreateProgram()
	defer gl.DeleteProgram(shader_program2)

	gl.AttachShader(shader_program2, vertex_shader)
	gl.AttachShader(shader_program2, fragment_shader2)
	gl.LinkProgram(shader_program2)

	// vertices: []f32 = {0.5, 0.5, 0.0, 0.5, -0.5, 0.0, -0.5, -0.5, 0.0, -0.5, 0.5, 0.0}
	vertices: []f32 = {-0.5, 0.5, 0, 0, -0.5, 0, -1, -0.5, 0}
	vertices2: []f32 = {0.5, 0.5, 0, 1, -0.5, 0, 0, -0.5, 0}
	indices: []u32 = {0, 1, 2}
	vbo, vao, vbo2, vao2, ebo: u32

	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)

	gl.BindVertexArray(vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		size_of(vertices[0]) * len(vertices),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.GenVertexArrays(1, &vao2)
	defer gl.DeleteVertexArrays(1, &vao2)

	gl.GenBuffers(1, &vbo2)
	defer gl.DeleteBuffers(1, &vbo2)

	gl.BindVertexArray(vao2)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo2)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		size_of(vertices2[0]) * len(vertices2),
		raw_data(vertices2),
		gl.STATIC_DRAW,
	)

	// gl.GenBuffers(1, &ebo)
	// defer gl.DeleteBuffers(1, &ebo)

	// gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	// gl.BufferData(
	// 	gl.ELEMENT_ARRAY_BUFFER,
	// 	size_of(indices[0]) * len(indices),
	// 	raw_data(indices),
	// 	gl.STATIC_DRAW,
	// )

	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0)
	gl.EnableVertexAttribArray(0)
	// gl.BindVertexArray(0)

	for !fw.WindowShouldClose(window) {
		gl.ClearColor(0.2, 0.3, 0.3, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		if wireframe_mode {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
		} else {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
		}

		gl.UseProgram(shader_program)
		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		gl.UseProgram(shader_program2)

		time := fw.GetTime()
		green: f32 = f32(math.sin(time)) / 2 + 0.5
		vertex_color_location := gl.GetUniformLocation(shader_program2, "ourColor")
		gl.Uniform4f(vertex_color_location, 0, green, 0, 1.0)

		gl.BindVertexArray(vao2)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)
		// gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

		fw.SwapBuffers(window)
		fw.PollEvents()
	}
}

framebuffer_size_callback :: proc "c" (win: fw.WindowHandle, w, h: i32) {
	gl.Viewport(0, 0, w, h)
}

key_callback :: proc "c" (win: fw.WindowHandle, key, scancode, action, mods: i32) {
	if key == fw.KEY_ESCAPE && action == fw.PRESS {
		fw.SetWindowShouldClose(win, true)
	} else if key == fw.KEY_W && action == fw.PRESS {
		wireframe_mode = !wireframe_mode
	}
}
