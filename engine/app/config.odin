package app

import "core:log"

AppConfig :: struct {
	title:     string,
	size:      [2]u32,
	log_level: log.Level,
}
