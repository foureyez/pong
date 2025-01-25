package app

import "core:log"
import "core:mem"
import "core:time"
import "engine:core"
import "engine:renderer"

curr_time: time.Time
delta_time: f64
logger: log.Logger

init :: proc(cfg: AppConfig) {
	logger = log.create_console_logger(lowest = cfg.log_level)
	context.logger = logger

	core.event_system_initialize()
	core.window_initialize(cfg.title, cfg.size.x, cfg.size.y, {})
	renderer.init(cfg.title)
}

start :: proc(update: proc(dt: f64), render: proc()) {
	context.logger = logger
	for {
		if !core.window_process_events() {
			break
		}

		new_time := time.now()
		delta_time = time.duration_seconds(time.diff(curr_time, new_time))
		curr_time = new_time
		update(delta_time)
		render()
	}
}

cleanup :: proc() {
	renderer.destroy()
	core.window_destroy()
}

reset_tracking_allocator :: proc(allocator: mem.Allocator) -> bool {
	context.logger = logger
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
