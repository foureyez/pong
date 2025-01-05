package window

import "base:runtime"
import "core:fmt"
import "core:log"
import "vendor:glfw"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"


WindowType :: enum {
	GLFW,
	SDL,
}

g_ctx: runtime.Context
window: ^Window

Window :: struct {
	width:               u32,
	height:              u32,
	title:               string,
	handle:              ^sdl.Window,
	framebuffer_resized: bool,
}

init :: proc(title: string, width: u32 = 0, height: u32 = 0, flags: sdl.WindowFlags = {}) {
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

get_instance :: proc() -> Window {
	return window^
}

wait_events :: proc() {
	//sdl.Wait
}

get_id :: proc() -> u32 {
	return sdl.GetWindowID(window.handle)
}

destroy :: proc() {
	sdl.DestroyWindow(window.handle)
	free(window)
}

create_vulkan_surface :: proc(instance: vk.Instance) -> vk.SurfaceKHR {
	surface: vk.SurfaceKHR
	if ok := sdl.Vulkan_CreateSurface(window.handle, instance, &surface); !ok {
		log.panicf("Unable to create vulkan surface", sdl.GetError())
	}
	return surface
}

get_window_extent :: proc() -> [2]u32 {
	width, height: i32
	sdl.GetWindowSize(window.handle, &width, &height)
	return {u32(width), u32(height)}
}

get_vulkan_extensions :: proc() -> []string {
	ext_count: u32
	sdl.Vulkan_GetInstanceExtensions(window.handle, &ext_count, nil)

	ext_names := make([dynamic]cstring, len = ext_count, cap = ext_count)
	sdl.Vulkan_GetInstanceExtensions(window.handle, &ext_count, raw_data(ext_names))

	extensions := make([]string, ext_count)
	for e, i in ext_names {
		extensions[i] = string(e)
	}
	delete(ext_names)
	return extensions
}

get_aspect_ratio :: proc() -> f32 {
	return f32(window.width) / f32(window.height)
}

is_framebuffer_resized :: proc() -> bool {
	return window.framebuffer_resized
}

set_framebuffer_resized :: proc(resized: bool) {
	window.framebuffer_resized = resized
}
