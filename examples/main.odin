package example

import "../engine"
import "core:log"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:time"
import "engine:input"
import "engine:renderer"
import "engine:window"
import sdl "vendor:sdl2"

main :: proc() {
	cl := log.create_console_logger(lowest = .Debug)
	context.logger = cl

	width: u32 = 1280
	height: u32 = 720
	title := "Starter App"

	window.init(title, width, height, {})
	renderer.init()
	defer cleanup()

	start_loop()
}

update :: proc(dt: f64) {
	// log.info(dt)
}

render :: proc() {
	renderer.clear_background({0, 0, 0, 1})
	renderer.draw_quad({}, {})
}

start_loop :: proc() {
	curr_time := time.now()
	running := true
	for running {
		e: sdl.Event
		for sdl.PollEvent(&e) {
			#partial switch e.type {
			case .QUIT:
				running = false
			case .WINDOWEVENT:
				#partial switch e.window.event {
				case .SIZE_CHANGED, .RESIZED:
					renderer.handle_window_resize()
					continue
				case .CLOSE:
					if e.window.windowID == window.get_id() {
						running = false
					}
				}
			}

			new_time := time.now()
			delta_time := time.duration_seconds(time.diff(curr_time, new_time))
			curr_time = new_time

			update(delta_time)
			renderer.render_begin()
			{
				render()
			}
			renderer.render_end()
		}
	}
}

cleanup :: proc() {
	window.destroy()
}
