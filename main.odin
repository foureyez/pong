package main

import "core:log"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:time"
import "engine"
import "engine:input"
import "engine:renderer"
import "engine:window"
import sdl "vendor:sdl2"

main :: proc() {
	cl := log.create_console_logger(lowest = .Debug)
	context.logger = cl
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	width: u32 = 1280
	height: u32 = 720
	title := "Starter App"

	window.init(title, width, height, {})
	renderer.init(title)

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
	reset_tracking_allocator(cast(^mem.Tracking_Allocator)context.allocator.data)
}

reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
	err := false
	if len(a.allocation_map) > 0 {
		log.warnf("Leaked allocation count: %v", len(a.allocation_map))
	}
	for _, v in a.allocation_map {
		log.warnf("%v: Leaked %v bytes", v.location, v.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}
