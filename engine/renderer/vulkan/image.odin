package chordvk

import vk "vendor:vulkan"

Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
}
