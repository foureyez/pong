package core

EventCode :: u16

EngineEventCodes :: enum {
	KEY_PRESSED  = 0,
	KEY_RELEASED = 0,
}

event: Event

Event :: struct {
	data: any,
}

on_event :: proc(event: Event)

event_initialize :: proc() {

}

event_register :: proc(code: EventCode) {

}

event_shutdown :: proc() {

}
