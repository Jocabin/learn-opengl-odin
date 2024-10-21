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

	shader_program, shader_loaded := gl.load_shaders("shaders/vertex.vs", "shaders/fragment.fs")
	defer gl.DeleteProgram(shader_program)

	if shader_loaded == false {
		fmt.eprintln("Error: failed to load shader program")
	}

	vertices := []f32{-.5, -.5, 0, 1, 0, 0, .5, -.5, 0, 0, 1, 0, 0, .5, 0, 0, 0, 1}

	vao, vbo: u32
	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)

	gl.BindVertexArray(vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices), gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 6 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	// color attribute
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 6 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)

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
