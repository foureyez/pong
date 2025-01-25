package chordvk

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strconv"
import "core:strings"
import "engine:core"
import "vendor:glfw"
import vk "vendor:vulkan"


ENABLE_VALIDATION_LAYERS :: true
validationLayers := []cstring{"VK_LAYER_KHRONOS_validation"}
deviceExtensions := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME, vk.KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME}

when ODIN_OS == .Darwin {
	// NOTE: just a bogus import of the system library,
	// needed so we can add a linker flag to point to /usr/local/lib (where vulkan is installed by default)
	// when trying to load vulkan.
	@(require, extra_linker_flags = "-rpath /usr/local/lib")
	foreign import __ "system:System.framework"
}

Device :: struct {
	handle:            vk.Device,
	physical_handle:   vk.PhysicalDevice,
	device_properties: vk.PhysicalDeviceProperties,
	command_pool:      vk.CommandPool,
	graphics_queue:    Queue,
	present_queue:     Queue,
}

Queue :: struct {
	vk_queue:     vk.Queue,
	family_index: u32,
}


create_device :: proc() -> Device {
	p_device, p_device_properties := pick_physical_device()
	log.infof("Selected Device: %v", strings.trim_right_null(string(p_device_properties.deviceName[:])))
	log.infof("DeviceType: %v", p_device_properties.deviceType)

	logical_device, graphics_queue, present_queue := create_logical_device(p_device)
	command_pool := create_command_pool(logical_device, graphics_queue)

	return Device {
		handle = logical_device,
		physical_handle = p_device,
		device_properties = p_device_properties,
		present_queue = present_queue,
		graphics_queue = graphics_queue,
		command_pool = command_pool,
	}
}

create_instance :: proc(app_name: string) -> vk.Instance {
	assert(vk.CreateInstance != nil, "Vulkan function pointer not loaded")

	instance: vk.Instance
	extensions := get_required_extensions()

	create_info: vk.InstanceCreateInfo = {
		sType            = .INSTANCE_CREATE_INFO,
		pApplicationInfo = &vk.ApplicationInfo {
			sType = .APPLICATION_INFO,
			pApplicationName = strings.clone_to_cstring(app_name),
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

destroy_device :: proc() {
}


@(private)
pick_physical_device :: proc() -> (vk.PhysicalDevice, vk.PhysicalDeviceProperties) {
	dev_count: u32
	_ = vk.EnumeratePhysicalDevices(vk_ctx.instance, &dev_count, nil)

	devices := make([]vk.PhysicalDevice, dev_count, context.temp_allocator)
	_ = vk.EnumeratePhysicalDevices(vk_ctx.instance, &dev_count, raw_data(devices))

	for physical_device in devices {
		if is_device_suitable(physical_device, vk_ctx.surface) {
			properties: vk.PhysicalDeviceProperties
			vk.GetPhysicalDeviceProperties(physical_device, &properties)
			return physical_device, properties
		}
	}
	log.panic("no suitable device found")
}

@(private)
create_logical_device :: proc(p_device: vk.PhysicalDevice) -> (device: vk.Device, graphics_queue, present_queue: Queue) {
	graphics_queue.family_index, present_queue.family_index = find_queue_families(p_device, vk_ctx.surface)

	unique_queue_families := make(map[u32]struct {}, allocator = context.temp_allocator)
	unique_queue_families[graphics_queue.family_index] = {}
	unique_queue_families[present_queue.family_index] = {}

	queue_create_infos := make([dynamic]vk.DeviceQueueCreateInfo, 0, len(unique_queue_families), context.temp_allocator)
	queue_priority: f32 = 1.0
	for qf in unique_queue_families {
		append(
			&queue_create_infos,
			vk.DeviceQueueCreateInfo {
				sType = .DEVICE_QUEUE_CREATE_INFO,
				queueCount = 1,
				queueFamilyIndex = qf,
				pQueuePriorities = &queue_priority,
			},
		)
	}


	extensions := get_required_device_extensions(p_device)
	features := vk.PhysicalDeviceFeatures2 {
		sType = .PHYSICAL_DEVICE_FEATURES_2,
		pNext = &vk.PhysicalDeviceBufferDeviceAddressFeatures {
			sType = .PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES,
			bufferDeviceAddress = true,
		},
		features = {samplerAnisotropy = true},
	}

	create_info := vk.DeviceCreateInfo {
		sType                   = .DEVICE_CREATE_INFO,
		queueCreateInfoCount    = u32(len(queue_create_infos)),
		pQueueCreateInfos       = raw_data(queue_create_infos),
		enabledExtensionCount   = u32(len(extensions)),
		ppEnabledExtensionNames = raw_data(extensions),
		pNext                   = &features,
	}

	if vk.CreateDevice(p_device, &create_info, nil, &device) != .SUCCESS {
		log.panic("unable to create vulkan device")
	}

	vk.load_proc_addresses_device(device)

	// Get created device queues
	vk.GetDeviceQueue(device, graphics_queue.family_index, 0, &graphics_queue.vk_queue)
	vk.GetDeviceQueue(device, present_queue.family_index, 0, &present_queue.vk_queue)
	return device, graphics_queue, present_queue
}

@(private)
create_command_pool :: proc(device: vk.Device, graphics_queue: Queue) -> vk.CommandPool {
	command_pool: vk.CommandPool
	pool_info := vk.CommandPoolCreateInfo {
		sType            = .COMMAND_POOL_CREATE_INFO,
		queueFamilyIndex = graphics_queue.family_index,
		flags            = {.TRANSIENT, .RESET_COMMAND_BUFFER},
	}

	if vk.CreateCommandPool(device, &pool_info, nil, &command_pool) != .SUCCESS {
		log.panic("unable to create command pool")
	}
	return command_pool
}


@(private)
is_device_suitable :: proc(dev: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> bool {
	graphics_family_index, present_family_index := find_queue_families(dev, surface)
	extensions_supported := check_device_extension_support(dev)
	swap_chain_adequate: bool
	if extensions_supported {
		surface_formats := vk_get_physical_device_surface_formats(dev)
		present_modes := vk_get_physical_device_surface_present_modes(dev)
		swap_chain_adequate = len(surface_formats) != 0 && len(present_modes) != 0
	}

	buffer_device_address_features := vk.PhysicalDeviceBufferDeviceAddressFeatures{}
	buffer_device_address_features.sType = .PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES
	device_features := vk.PhysicalDeviceFeatures2{}
	device_features.sType = .PHYSICAL_DEVICE_FEATURES_2
	device_features.pNext = &buffer_device_address_features

	vk.GetPhysicalDeviceFeatures2(dev, &device_features)

	return(
		graphics_family_index >= 0 &&
		present_family_index >= 0 &&
		extensions_supported &&
		swap_chain_adequate &&
		buffer_device_address_features.bufferDeviceAddress == true \
	)
}


find_queue_families :: proc(dev: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> (u32, u32) {
	count: u32
	graphics_index, present_index := -1, -1

	vk.GetPhysicalDeviceQueueFamilyProperties(dev, &count, nil)
	queue_family_props := make([]vk.QueueFamilyProperties, count, context.temp_allocator)
	vk.GetPhysicalDeviceQueueFamilyProperties(dev, &count, raw_data(queue_family_props))

	for qfp, i in queue_family_props {
		if qfp.queueCount > 0 && .GRAPHICS in qfp.queueFlags {
			graphics_index = i
		}

		present_support: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(dev, u32(i), surface, &present_support)
		if qfp.queueCount > 0 && present_support {
			present_index = i
		}

		if graphics_index >= 0 && present_index >= 0 {
			break
		}
	}
	return u32(graphics_index), u32(present_index)
}

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
	append(&extensions, ..core.get_vulkan_extensions())
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

@(private)
create_debug_messenger :: proc() -> vk.DebugUtilsMessengerEXT {
	debug_messenger: vk.DebugUtilsMessengerEXT
	if !ENABLE_VALIDATION_LAYERS {
		return 0
	}

	create_info := vk.DebugUtilsMessengerCreateInfoEXT{}
	populate_debug_messenger_create_info(&create_info)

	proc_func := cast(vk.ProcCreateDebugUtilsMessengerEXT)vk.GetInstanceProcAddr(vk_ctx.instance, "vkCreateDebugUtilsMessengerEXT")

	if proc_func != nil {
		if proc_func(vk_ctx.instance, &create_info, nil, &debug_messenger) != .SUCCESS {
			panic("Unable to create debug messenger")
		}
	}
	return debug_messenger
}

@(private)
populate_debug_messenger_create_info :: proc(create_info: ^vk.DebugUtilsMessengerCreateInfoEXT) {
	create_info.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
	create_info.messageSeverity = {.WARNING, .ERROR}
	create_info.messageType = {.GENERAL, .VALIDATION, .PERFORMANCE, .DEVICE_ADDRESS_BINDING}
	create_info.pfnUserCallback = vk_messenger_callback
	create_info.pUserData = nil
}

@(private)
vk_messenger_callback :: proc "system" (
	messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
	messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> b32 {
	context = vk_ctx.g_ctx

	level: log.Level
	if .ERROR in messageSeverity {
		level = .Error
	} else if .WARNING in messageSeverity {
		level = .Warning
	} else if .INFO in messageSeverity {
		level = .Info
	} else {
		level = .Debug
	}

	log.logf(level, "vulkan[%v]: %s", messageTypes, pCallbackData.pMessage)
	return false
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
