package core

import "core:log"

EventCode :: enum u16 {
	PLATFORM_WINDOW_CLOSED  = 0,
	PLATFORM_WINDOW_RESIZED = 1,
	PLATFORM_KEYDOWN        = 2,
	PLATFORM_KEYUP          = 3,
	INPUT_KEYDOWN           = 4,
	INPUT_KEYUP             = 5,
}

Event :: struct {
	code: EventCode,
	data: any,
}

Handle_Event :: proc(listener: rawptr, event: Event) -> bool

MAX_EVENT_CODE :: 10000

RegisteredEvent :: struct {
	listener: rawptr,
	callback: Handle_Event,
}

EventSystemState :: struct {
	registered_events: [MAX_EVENT_CODE][dynamic]RegisteredEvent,
}

event_state: EventSystemState

event_system_init :: proc() {
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

	log.debugf("Registered event callback for: %v", code)
	append(&event_state.registered_events[code], RegisteredEvent{listener = listener, callback = callback})
	return true
}

event_publish :: proc(event: Event) -> bool {
	if event_state.registered_events[event.code] == nil {
		return false
	}

	for re in event_state.registered_events[event.code] {
		if re.callback(re.listener, event) {
			log.debugf("event handled by %v, not processing other callbacks", re.listener)
			return true
		}
	}
	return true
}

event_system_cleanup :: proc() {
}
