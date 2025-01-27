package core

import "core:log"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"

window_create_vk_surface :: proc(instance: vk.Instance) -> vk.SurfaceKHR {
	surface: vk.SurfaceKHR
	if ok := sdl.Vulkan_CreateSurface(window.handle, instance, &surface); !ok {
		log.panicf("Unable to create vulkan surface", sdl.GetError())
	}
	return surface
}

window_get_vk_extensions :: proc() -> []string {
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
