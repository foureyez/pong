package chordvk

import glm "core:math/linalg/glsl"
import vma "deps:vma"
import vk "vendor:vulkan"


UniformBufferObject :: struct {
	buffers:        []Buffer,
	layout:         DescriptorSetLayout,
	descriptor_set: []vk.DescriptorSet,
}


initialize_global_ubo :: proc(ubo_type: typeid) -> (ubo: UniformBufferObject) {
	buffers := make([]Buffer, vk_ctx.max_frames_in_flight)
	for i in 0 ..< len(buffers) {
		buffers[i] = create_buffer(size_of(ubo_type), {.UNIFORM_BUFFER}, .CPU_TO_GPU)
	}

	ds_layout := create_descriptor_set_layout(vk.DescriptorSetLayoutBinding{0, .UNIFORM_BUFFER, 1, {.VERTEX}, nil})

	descriptor_sets := make([]vk.DescriptorSet, vk_ctx.max_frames_in_flight)
	for i in 0 ..< vk_ctx.max_frames_in_flight {
		buffer_info := buffer_descriptor_info(buffers[i])
		descriptor_write := add_buffer_descriptor(0, ds_layout, &buffer_info)
		descriptor_sets[i] = update_descriptor_set(&ds_layout, descriptor_write)
	}

	ubo.buffers = buffers
	ubo.layout = ds_layout
	ubo.descriptor_set = descriptor_sets

	return ubo
}
