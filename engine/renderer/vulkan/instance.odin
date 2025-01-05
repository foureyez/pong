package chordvk

import "core:fmt"
import "core:strings"
import vk "vendor:vulkan"

/**
* Creates vk.Instance object
**/
@(private)
create_instance :: proc() -> vk.Instance {
	assert(vk.CreateInstance != nil, "Vulkan function pointer not loaded")

	instance: vk.Instance
	extensions := get_required_extensions()

	create_info: vk.InstanceCreateInfo = {
		sType            = .INSTANCE_CREATE_INFO,
		pApplicationInfo = &vk.ApplicationInfo {
			sType = .APPLICATION_INFO,
			pApplicationName = "Hello Vulkan",
			applicationVersion = vk.MAKE_VERSION(0, 0, 1),
			pEngineName = "No Engine",
			engineVersion = vk.MAKE_VERSION(0, 0, 1),
			apiVersion = vk.API_VERSION_1_3,
		},
	}

	when ODIN_OS == .Darwin {
		create_info.flags |= {.ENUMERATE_PORTABILITY_KHR}
		append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
	}

	cextensions := convert_to_cstring(extensions[:])
	create_info.enabledExtensionCount = cast(u32)len(cextensions)
	create_info.ppEnabledExtensionNames = raw_data(cextensions)

	if ENABLE_VALIDATION_LAYERS {
		assert(check_validation_layer_support(), "Validation layer not supported")

		debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = {}
		create_info.enabledLayerCount = cast(u32)len(validationLayers)
		create_info.ppEnabledLayerNames = raw_data(validationLayers)
		populate_debug_messenger_create_info(&debug_create_info)
		create_info.pNext = &debug_create_info
	} else {
		create_info.enabledLayerCount = 0
		create_info.pNext = nil
	}

	if vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS {
		panic("Unable to create vk instance")
	}

	if ext, ok := has_window_required_instance_extensions(); !ok {
		panic(fmt.tprintf("Required glfw extension not found: %v", ext))
	}
	vk.load_proc_addresses_instance(instance)
	return instance
}

@(private)
check_validation_layer_support :: proc() -> bool {
	count: u32
	result := vk.EnumerateInstanceLayerProperties(&count, nil)

	available_layers := make([]vk.LayerProperties, count, context.temp_allocator)
	vk.EnumerateInstanceLayerProperties(&count, raw_data(available_layers))
	for name in validationLayers {
		layer_found := false
		for properties in available_layers {
			alayer_name := properties.layerName
			available_layer_name := byte_arr_str(&alayer_name)
			desc := properties.description
			if available_layer_name == string(name) {
				layer_found = true
				break
			}
		}

		if (!layer_found) {
			return false
		}
	}
	return true
}

convert_to_cstring :: proc(ins: []string) -> (outs: []cstring) {
	outs = make([]cstring, len(ins))
	for s, i in ins {
		outs[i] = strings.clone_to_cstring(s)
	}
	return outs
}
