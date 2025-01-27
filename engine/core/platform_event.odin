package core

import sdl "vendor:sdl2"

platform_process_events :: proc() {
	e: sdl.Event
	for sdl.PollEvent(&e) {
		#partial switch e.type {
		case .QUIT:
			event_publish({.PLATFORM_WINDOW_CLOSED, nil})
		case .KEYDOWN:
			event_publish({.PLATFORM_KEYDOWN, e.key.keysym.sym})
		case .KEYUP:
			event_publish({.PLATFORM_KEYUP, e.key.keysym.sym})
		case .WINDOWEVENT:
			#partial switch e.window.event {
			case .SIZE_CHANGED, .RESIZED:
				event_publish({.PLATFORM_WINDOW_RESIZED, nil})
			case .CLOSE:
				event_publish({.PLATFORM_WINDOW_CLOSED, nil})
			}
		}
	}
}
