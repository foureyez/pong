package engine

import "core:log"
import "core:time"
import imgui "deps:imgui"
import imsdl "deps:imgui/imgui_impl_sdl2"
import imguivk "deps:imgui/imgui_impl_vulkan"
import "engine:renderer"
import "engine:window"
import "input"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"


init :: proc(width: u32, height: u32, title: string) {
	window.init(title, width, height, {})
	renderer.init()
	//input.init()
}
