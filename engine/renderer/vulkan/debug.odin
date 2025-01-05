package chordvk

import "core:log"
import vk "vendor:vulkan"

ENABLE_VALIDATION_LAYERS :: true
validationLayers := []cstring{"VK_LAYER_KHRONOS_validation"}

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
