package chordvk

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strconv"
import "core:strings"
import "engine:window"
import "vendor:glfw"
import vk "vendor:vulkan"


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
