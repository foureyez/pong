package core

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:time"
import "vendor:glfw"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"

g_ctx: runtime.Context
window: ^Window

Window :: struct {
	width:               u32,
	height:              u32,
	title:               string,
	handle:              ^sdl.Window,
	framebuffer_resized: bool,
}

window_initialize :: proc(title: string, width: u32 = 0, height: u32 = 0, flags: sdl.WindowFlags = {}) {
	window = new(Window)
	sdl.Init({.VIDEO, .EVENTS})
	ctitle := fmt.caprintf(title)
	defer delete(ctitle)

	libresult := sdl.Vulkan_LoadLibrary(nil)
	if libresult == -1 && ODIN_OS == .Darwin {
		// explicitly use the dylib location on mac
		libresult = sdl.Vulkan_LoadLibrary("/usr/local/lib/libvulkan.dylib")
	}
	assert(libresult == 0, "could not found vulkan library!")

	if width == 0 || height == 0 {
		display_mode: sdl.DisplayMode
		sdl.GetCurrentDisplayMode(0, &display_mode)
		window.handle = sdl.CreateWindow(ctitle, 0, 0, display_mode.w, display_mode.h, flags + {.VULKAN, .ALLOW_HIGHDPI})
	} else {
		window.handle = sdl.CreateWindow(ctitle, 0, 0, i32(width), i32(height), flags + {.VULKAN, .ALLOW_HIGHDPI})
	}

	get_instance_proc_addr := sdl.Vulkan_GetVkGetInstanceProcAddr()
	vk.load_proc_addresses_global(get_instance_proc_addr)
}

window_get_instance :: proc() -> Window {
	return window^
}

window_get_extent :: proc() -> [2]u32 {
	width, height: i32
	sdl.GetWindowSize(window.handle, &width, &height)
	return {u32(width), u32(height)}
}

window_destroy :: proc() {
	sdl.DestroyWindow(window.handle)
	free(window)
}
