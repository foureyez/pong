package main

import "core:fmt"
import "core:log"
import "core:mem"
import "engine:app"
import "engine:renderer"
import "game"

main :: proc() {
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	cfg := app.AppConfig {
		log_level = .Debug,
		title     = "PONG",
		size      = {1280, 720},
	}
	app.init(cfg)
	defer app.cleanup()
	defer app.reset_tracking_allocator(context.allocator)

	game.init()
	app.start(game.update, game.render)
}
