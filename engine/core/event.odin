package core

import "core:log"

EventCode :: enum u16 {
	KEY_PRESSED    = 0,
	KEY_RELEASED   = 1,
	WINDOW_RESIZED = 3,
}

Event :: struct {
	data: any,
}

Handle_Event :: proc(code: EventCode, listener: rawptr, event: Event) -> bool

MAX_EVENT_CODE :: 10000

RegisteredEvent :: struct {
	listener: rawptr,
	callback: Handle_Event,
}

EventSystemState :: struct {
	registered_events: [MAX_EVENT_CODE][dynamic]RegisteredEvent,
}

event_state: EventSystemState

event_system_initialize :: proc() {
	event_state.registered_events = make([dynamic]RegisteredEvent, 0)
}

event_register :: proc(code: EventCode, listener: rawptr, callback: Handle_Event) -> bool {
	if u32(code) >= MAX_EVENT_CODE {
		log.errorf("unable to register event code greater than %v", MAX_EVENT_CODE)
		return false
	}

	if event_state.registered_events[code] == nil {
		event_state.registered_events[code] = make([dynamic]RegisteredEvent, 0)
	}

	for re in event_state.registered_events[code] {
		if re.listener == listener {
			log.warnf("event code %v is already registered with the same listener", code)
			return false
		}
	}

	append(&event_state.registered_events[code], RegisteredEvent{listener = listener, callback = callback})
	return true
}

event_publish :: proc(code: EventCode, event: Event) -> bool {
	if event_state.registered_events[code] == nil {
		return false
	}

	for re in event_state.registered_events[code] {
		if re.callback(code, re.listener, event) {
			log.debug("event handled by %v, not processing other callbacks", re.listener)
			return true
		}
	}
	return true
}

event_system_cleanup :: proc() {
}
