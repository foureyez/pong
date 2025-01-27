package app

import "core:fmt"
import "core:log"
import "core:mem"
import "core:time"
import "engine:core"
import "engine:renderer"


Application :: struct {
	logger:     log.Logger,
	curr_time:  time.Time,
	delta_time: f64,
	is_running: bool,
}

app := Application{}

init :: proc(cfg: AppConfig) {
	app.logger = log.create_console_logger(lowest = cfg.log_level)
	app.curr_time = time.now()
	context.logger = app.logger

	core.event_system_initialize()
	core.input_system_initialize()
	core.window_initialize(cfg.title, cfg.size.x, cfg.size.y, {})
	renderer.init(cfg.title)
	core.event_register(.WINDOW_CLOSED, nil, handle_app_close_event)
	app.is_running = true
}

start :: proc(update: proc(dt: f64), render: proc()) {
	context.logger = app.logger
	for app.is_running {
		core.platform_process_events()
		log.info(core.is_key_down(.Key_A))
		new_time := time.now()
		app.delta_time = time.duration_seconds(time.diff(app.curr_time, new_time))
		app.curr_time = new_time
		update(app.delta_time)
		render()
	}
}

handle_app_close_event :: proc(listener: rawptr, event: core.Event) -> bool {
	app.is_running = false
	return true
}

cleanup :: proc() {
	renderer.destroy()
	core.window_destroy()
}

reset_tracking_allocator :: proc(allocator: mem.Allocator) -> bool {
	context.logger = app.logger
	a := cast(^mem.Tracking_Allocator)allocator.data
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
