package chordvk

import "base:runtime"
import vk "vendor:vulkan"

when ODIN_OS == .Darwin {
	// NOTE: just a bogus import of the system library,
	// needed so we can add a linker flag to point to /usr/local/lib (where vulkan is installed by default)
	// when trying to load vulkan.
	@(require, extra_linker_flags = "-rpath /usr/local/lib")
	foreign import __ "system:System.framework"
}


deviceExtensions := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME, vk.KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME}
