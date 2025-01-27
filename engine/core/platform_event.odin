package core

import sdl "vendor:sdl2"

platform_process_events :: proc() {
	e: sdl.Event
	for sdl.PollEvent(&e) {
		#partial switch e.type {
		case .QUIT:
			event_publish(.WINDOW_CLOSED, {})
		case .KEYDOWN:
			event_publish(.INPUT_KEYDOWN, {data = e.key.keysym.sym})
		case .KEYUP:
			event_publish(.INPUT_KEYUP, {data = e.key.keysym.sym})
		case .WINDOWEVENT:
			#partial switch e.window.event {
			case .SIZE_CHANGED, .RESIZED:
				event_publish(.WINDOW_RESIZED, {})
			case .CLOSE:
				event_publish(.WINDOW_CLOSED, {})
			}
		}
	}
}
