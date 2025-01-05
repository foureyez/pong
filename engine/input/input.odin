package input

import "base:runtime"
import "core:fmt"
import "core:log"
import "engine:window"
import "vendor:glfw"

@(private)
scroll_xoffset, scroll_yoffset: f32

@(private)
g_ctx: runtime.Context

/**
* Initialize the package with window handle
**/
//init :: proc() {
//	g_ctx = context
//	glfw.SetScrollCallback(window.get_handle(), scroll_callback)
//}
//
//is_key_pressed :: proc(key: KeyCode) -> bool {
//	state := glfw.GetKey(window.get_handle(), i32(key))
//	return state == glfw.PRESS
//}
//
//is_key_released :: proc(key: KeyCode) -> bool {
//	state := glfw.GetKey(window.get_handle(), i32(key))
//	return state == glfw.RELEASE
//}
//
//is_mouse_button_pressed :: proc(mouse: MouseCode) -> bool {
//	state := glfw.GetMouseButton(window.get_handle(), i32(mouse))
//	return state == glfw.PRESS
//}
//
//// Get the current x scroll offsets and then resets the global value
//// So can't be called multiple times for one scroll event
//mouse_xscroll :: proc() -> f32 {
//	scroll := scroll_xoffset
//	scroll_xoffset = 0
//	return scroll
//}
//
//// Get the current y scroll offsets and then resets the global value
//// So can't be called multiple times for one scroll event
//mouse_yscroll :: proc() -> f32 {
//	scroll := scroll_yoffset
//	scroll_yoffset = 0
//	return scroll
//}
//
//get_mouse_position :: proc() -> (f32, f32) {
//	xpos, ypos := glfw.GetCursorPos(window.get_handle())
//	return f32(xpos), f32(ypos)
//}
//
//set_mouse_position :: proc(xpos, ypos: f32) {
//	glfw.SetCursorPos(window.get_handle(), f64(xpos), f64(ypos))
//}
//
///**
//On mac the scroll offset value changes based on the amount of scroll done by user.
//On x server, this value is always 1, while on hyprland this value is 1.5, for each scroll step
//**/
//@(private)
//scroll_callback :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
//	context = g_ctx
//	scroll_xoffset = f32(xoffset)
//	scroll_yoffset = f32(yoffset)
//}
