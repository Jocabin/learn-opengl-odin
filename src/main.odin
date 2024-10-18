package main

import "core:fmt"
import "core:mem"
import gl "vendor:OpenGL"
import fw "vendor:glfw"

GL_MINOR_VERSION :: 3
GL_MAJOR_VERSION :: 3

WIN_W: i32 : 1920 / 2
WIN_H: i32 : 1080 / 2

vertex_shader_source: cstring = `       #version 330 core
                                                layout (location = 0) in vec3 aPos;

                                                void main()
                                                {
                                                gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
                                                }`
fragment_shader_source: cstring = `    #version 330 core
                                        out vec4 FragColor;

                                        void main()
                                        {
                                        FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
                                        }`

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

	gl.Viewport(0, 0, WIN_W, WIN_H)
	fw.SetFramebufferSizeCallback(window, framebuffer_size_callback)

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

	shader_program: u32 = gl.CreateProgram()
	defer gl.DeleteProgram(shader_program)

	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)

	vertices: []f32 = {-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0}
	vbo, vao: u32

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
	gl.BindVertexArray(0)

	for !fw.WindowShouldClose(window) {
		process_input(window)

		gl.ClearColor(0.2, 0.3, 0.3, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.UseProgram(shader_program)
		gl.BindVertexArray(vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		fw.SwapBuffers(window)
		fw.PollEvents()
	}
}

framebuffer_size_callback :: proc "c" (win: fw.WindowHandle, w, h: i32) {
	gl.Viewport(0, 0, w, h)
}

process_input :: proc(win: fw.WindowHandle) {
	if fw.GetKey(win, fw.KEY_ESCAPE) == fw.PRESS {
		fw.SetWindowShouldClose(win, true)
	}
}
