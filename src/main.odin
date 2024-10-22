package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import gl "vendor:OpenGL"
import fw "vendor:glfw"
import stbi "vendor:stb/image"

GL_MINOR_VERSION :: 3
GL_MAJOR_VERSION :: 3

WIN_W: i32 : 960
WIN_H: i32 : 540

wireframe_mode := false
opacity: f32 = 0.2

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

	shader_program, shader_loaded := gl.load_shaders(
		"src/shaders/vertex.vs",
		"src/shaders/fragment.fs",
	)
	defer gl.DeleteProgram(shader_program)

	if shader_loaded == false {
		fmt.eprintln("Error: failed to load shader program")
		os.exit(-1)
	}

	vao, vbo, ebo: u32
        // odinfmt:disable
	vertices: []f32 = {
		 0.5,  0.5, 0.0,    1.0, 0.0, 0.0,    2.0, 2.0,
		 0.5, -0.5, 0.0,    0.0, 1.0, 0.0,    2.0, 0.0,
		-0.5, -0.5, 0.0,    0.0, 0.0, 1.0,    0.0, 0.0,
		-0.5,  0.5, 0.0,    1.0, 1.0, 0.0,    0.0, 2.0,
	}
        // odinfmt:enable
	indices: []u32 = {0, 1, 3, 1, 2, 3}

	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)

	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)

	gl.GenBuffers(1, &ebo)
	defer gl.DeleteBuffers(1, &ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(mem.slice_to_bytes(vertices)),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(mem.slice_to_bytes(indices)),
		raw_data(indices),
		gl.STATIC_DRAW,
	)

	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	// color attribute
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 8 * size_of(f32), 3 * size_of(f32))
	gl.EnableVertexAttribArray(1)

	// texture attribute
	gl.VertexAttribPointer(2, 3, gl.FLOAT, false, 8 * size_of(f32), 6 * size_of(f32))
	gl.EnableVertexAttribArray(2)

	texture: u32
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	tex_w, tex_h, tex_chan: i32
	tex_data := stbi.load("assets/container.jpg", &tex_w, &tex_h, &tex_chan, 0)

	if tex_data == nil {
		fmt.eprintln("Error: Failed to load texture data")
		os.exit(-1)
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, tex_w, tex_h, 0, gl.RGB, gl.UNSIGNED_BYTE, tex_data)
	gl.GenerateMipmap(gl.TEXTURE_2D)
	stbi.image_free(tex_data)

	// TEXTURE 2
	texture2: u32
	gl.GenTextures(1, &texture2)
	gl.BindTexture(gl.TEXTURE_2D, texture2)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	tex2_w, tex2_h, tex2_chan: i32
	tex2_data := stbi.load("assets/awesomeface.png", &tex2_w, &tex2_h, &tex2_chan, 0)

	if tex2_data == nil {
		fmt.eprintln("Error: Failed to load texture data")
		os.exit(-1)
	}

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGBA,
		tex2_w,
		tex2_h,
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		tex2_data,
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)
	stbi.image_free(tex2_data)
	// TEXTURE 2

	gl.UseProgram(shader_program)
	gl.Uniform1i(gl.GetUniformLocation(shader_program, "texture1"), 0)
	gl.Uniform1i(gl.GetUniformLocation(shader_program, "texture2"), 1)

	for !fw.WindowShouldClose(window) {
		gl.ClearColor(0, 1, 1, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		if wireframe_mode {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
		} else {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
		}

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture)

		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		gl.BindVertexArray(vao)
		gl.UseProgram(shader_program)
		gl.Uniform1f(gl.GetUniformLocation(shader_program, "opacity"), opacity)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

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
	} else if key == fw.KEY_UP && action == fw.PRESS {
		opacity += 0.2
	} else if key == fw.KEY_DOWN && action == fw.PRESS {
		opacity -= 0.2
	}
}
