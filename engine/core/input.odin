package core

import "core:log"
import sdl "vendor:sdl2"

InputState :: struct {
	keyboard_state:        KeyboardState,
	platform_key_mappings: map[sdl.Keycode]Keycode,
}
KeyboardState :: struct {
	keys: [256]bool,
}
state: InputState

input_system_init :: proc() {
	state = InputState {
		keyboard_state        = KeyboardState{},
		platform_key_mappings = create_platform_key_mappings(),
	}
	event_register(.PLATFORM_KEYUP, nil, platform_handle_input_keyup)
	event_register(.PLATFORM_KEYDOWN, nil, platform_handle_input_keydown)
}

is_key_down :: proc(keycode: Keycode) -> bool {
	return state.keyboard_state.keys[int(keycode)]
}

platform_handle_input_keyup :: proc(listener: rawptr, event: Event) -> bool {
	key := platform_normalize_key(event.data)
	state.keyboard_state.keys[key] = false
	event_publish({.INPUT_KEYUP, key})
	return false
}

platform_handle_input_keydown :: proc(listener: rawptr, event: Event) -> bool {
	key := platform_normalize_key(event.data)
	state.keyboard_state.keys[key] = true
	event_publish({.INPUT_KEYDOWN, key})
	return false
}

platform_normalize_key :: proc(platform_key: any) -> Keycode {
	return state.platform_key_mappings[platform_key.(sdl.Keycode)]
}

create_platform_key_mappings :: proc() -> (key_mappings: map[sdl.Keycode]Keycode) {
	key_mappings[.a] = .Key_A
	key_mappings[.b] = .Key_B
	key_mappings[.c] = .Key_C
	key_mappings[.d] = .Key_D
	key_mappings[.e] = .Key_E
	key_mappings[.f] = .Key_F
	key_mappings[.g] = .Key_G
	key_mappings[.h] = .Key_H
	key_mappings[.i] = .Key_I
	key_mappings[.j] = .Key_J
	key_mappings[.k] = .Key_K
	key_mappings[.l] = .Key_L
	key_mappings[.m] = .Key_M
	key_mappings[.n] = .Key_N
	key_mappings[.o] = .Key_O
	key_mappings[.p] = .Key_P
	key_mappings[.q] = .Key_Q
	key_mappings[.r] = .Key_R
	key_mappings[.s] = .Key_S
	key_mappings[.t] = .Key_T
	key_mappings[.u] = .Key_U
	key_mappings[.v] = .Key_V
	key_mappings[.w] = .Key_W
	key_mappings[.x] = .Key_X
	key_mappings[.y] = .Key_Y
	key_mappings[.z] = .Key_Z
	return key_mappings
}
