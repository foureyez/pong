package chordvk

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"
import "engine:window"
import vk "vendor:vulkan"

@(private)
has_window_required_instance_extensions :: proc() -> (string, bool) {
	count: u32
	_ = vk.EnumerateInstanceExtensionProperties(nil, &count, nil)

	extensions := make([]vk.ExtensionProperties, count)
	defer delete(extensions)

	_ = vk.EnumerateInstanceExtensionProperties(nil, &count, raw_data(extensions))

	required_extensions := get_required_extensions()
	for e in required_extensions {
		found: bool
		for a in &extensions {
			available_extension := a.extensionName
			if byte_arr_str(&available_extension) == string(e) {
				found = true
				break
			}
		}
		if !found {
			return string(e), false
		}
	}
	return "", true
}

@(private)
get_required_extensions :: proc() -> [dynamic]string {
	extensions := make([dynamic]string)
	append(&extensions, ..window.get_vulkan_extensions())
	if ENABLE_VALIDATION_LAYERS {
		append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
	}
	return extensions
}

@(private)
get_required_device_extensions :: proc(dev: vk.PhysicalDevice) -> [dynamic]cstring {
	count: u32
	vk.EnumerateDeviceExtensionProperties(dev, nil, &count, nil)

	available_extensions := make([]vk.ExtensionProperties, count, context.temp_allocator)
	vk.EnumerateDeviceExtensionProperties(dev, nil, &count, raw_data(available_extensions))

	required_extensions := slice.clone_to_dynamic(deviceExtensions, context.temp_allocator)
	for extension in available_extensions {
		name := extension.extensionName
		// If portability subset extension is available, need to add it to 
		// device extension list
		if byte_arr_str(&name) == "VK_KHR_portability_subset" {
			append(&required_extensions, "VK_KHR_portability_subset")
			break
		}
	}
	return required_extensions
}

@(private)
check_device_extension_support :: proc(dev: vk.PhysicalDevice) -> bool {
	count: u32
	vk.EnumerateDeviceExtensionProperties(dev, nil, &count, nil)

	available_extensions := make([]vk.ExtensionProperties, count, context.temp_allocator)
	vk.EnumerateDeviceExtensionProperties(dev, nil, &count, raw_data(available_extensions))

	for extension in deviceExtensions {
		found := false
		for available_ext in available_extensions {
			name := available_ext.extensionName
			if string(extension) == byte_arr_str(&name) {
				found = true
				break
			}
		}
		if !found {
			log.errorf("Unable to find extension: %v, for device: %v", string(extension), dev)
			return false
		}
	}
	return true
}
