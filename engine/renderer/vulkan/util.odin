package chordvk

import "core:log"
import "core:strings"
import vk "vendor:vulkan"

KB :: 1024
MB :: KB * 1024

convert_to_cstring :: proc(ins: []string) -> (outs: []cstring) {
	outs = make([]cstring, len(ins))
	for s, i in ins {
		outs[i] = strings.clone_to_cstring(s)
	}
	return outs
}

@(private)
find_memory_type :: proc(filter: u32, properties: vk.MemoryPropertyFlags) -> u32 {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(vk_ctx.device.physical_handle, &mem_properties)

	for i in 0 ..< mem_properties.memoryTypeCount {
		if filter & 1 << i == 1 && mem_properties.memoryTypes[i].propertyFlags & properties == properties {
			return i
		}
	}
	return 0
}

@(private)
byte_arr_str :: proc(arr: ^[$N]byte) -> string {
	return strings.truncate_to_byte(string(arr[:]), 0)
}
