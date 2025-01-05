package chordvk

import "core:log"
import vk "vendor:vulkan"

/****************
* DescriptorPool
****************/

create_descriptor_pool :: proc(
	max_sets: u32,
	pool_flags: vk.DescriptorPoolCreateFlags,
	pool_sizes: ..vk.DescriptorPoolSize,
) -> vk.DescriptorPool {
	descriptor_pool: vk.DescriptorPool

	descriptor_pool_info := vk.DescriptorPoolCreateInfo{}
	descriptor_pool_info.sType = .DESCRIPTOR_POOL_CREATE_INFO
	descriptor_pool_info.poolSizeCount = u32(len(pool_sizes))
	descriptor_pool_info.pPoolSizes = raw_data(pool_sizes)
	descriptor_pool_info.maxSets = max_sets
	descriptor_pool_info.flags = pool_flags

	if vk.CreateDescriptorPool(vk_ctx.device.handle, &descriptor_pool_info, nil, &descriptor_pool) != .SUCCESS {
		panic("failed to create descriptor pool")
	}
	return descriptor_pool
}

destroy_descriptor_pool :: proc() {
	vk.DestroyDescriptorPool(vk_ctx.device.handle, vk_ctx.descriptor_pool, nil)
}

allocate_descriptor_set :: proc(descriptor_set_layout: ^vk.DescriptorSetLayout) -> (descriptor_set: vk.DescriptorSet) {

	allocInfo := vk.DescriptorSetAllocateInfo{}
	allocInfo.sType = .DESCRIPTOR_SET_ALLOCATE_INFO
	allocInfo.descriptorPool = vk_ctx.descriptor_pool
	allocInfo.pSetLayouts = descriptor_set_layout
	allocInfo.descriptorSetCount = 1

	// Might want to create a "DescriptorPoolManager" class that handles this case, and builds
	// a new pool whenever an old pool fills up. But this is beyond our current scope
	if (vk.AllocateDescriptorSets(vk_ctx.device.handle, &allocInfo, &descriptor_set) != .SUCCESS) {
		return {}
	}
	return descriptor_set
}

free_descriptors :: proc(descriptors: []vk.DescriptorSet) {
	vk.FreeDescriptorSets(vk_ctx.device.handle, vk_ctx.descriptor_pool, u32(len(descriptors)), raw_data(descriptors))
}

reset_pool :: proc() {
	vk.ResetDescriptorPool(vk_ctx.device.handle, vk_ctx.descriptor_pool, {})
}

/************************
* Descriptor Set Layout
************************/

DescriptorSetLayout :: struct {
	bindings:              map[u32]vk.DescriptorSetLayoutBinding,
	descriptor_set_layout: vk.DescriptorSetLayout,
}

create_descriptor_set_layout :: proc(bindings: ..vk.DescriptorSetLayoutBinding) -> (descriptor_set_layout: DescriptorSetLayout) {
	//TODO: Check if bindings are valid, i.e. two bindings should not use same bind index
	for binding in bindings {
		if _, ok := descriptor_set_layout.bindings[binding.binding]; ok {
			log.panic("binding already exists")
		}
		descriptor_set_layout.bindings[binding.binding] = binding
	}
	descriptor_set_layout_info := vk.DescriptorSetLayoutCreateInfo{}
	descriptor_set_layout_info.sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	descriptor_set_layout_info.bindingCount = u32(len(bindings))
	descriptor_set_layout_info.pBindings = raw_data(bindings)

	if (vk.CreateDescriptorSetLayout(
			   vk_ctx.device.handle,
			   &descriptor_set_layout_info,
			   nil,
			   &descriptor_set_layout.descriptor_set_layout,
		   ) !=
		   .SUCCESS) {
		log.panic("unable to create descriptor set layout")
	}
	return descriptor_set_layout
}

delete_descriptor_set_layout :: proc(device: Device, descriptor_set_layout: ^DescriptorSetLayout) {
	vk.DestroyDescriptorSetLayout(vk_ctx.device.handle, descriptor_set_layout.descriptor_set_layout, nil)
}


/************************
* Descriptor Set Layout
************************/
DescriptorOption :: struct {
	set_writes: [dynamic]vk.WriteDescriptorSet,
}

add_buffer_descriptor :: proc(
	binding: u32,
	set_layout: DescriptorSetLayout,
	buffer_info: ^vk.DescriptorBufferInfo,
) -> vk.WriteDescriptorSet {
	assert((binding in set_layout.bindings), "Layout does not contain specified binding")

	binding_description := set_layout.bindings[binding]
	assert(binding_description.descriptorCount == 1, "Binding multiple descriptor info, but binding expects single")

	write := vk.WriteDescriptorSet{}
	write.sType = .WRITE_DESCRIPTOR_SET
	write.descriptorType = binding_description.descriptorType
	write.dstBinding = binding
	write.pBufferInfo = buffer_info
	write.descriptorCount = 1
	return write
}

add_image_descriptor :: proc(binding: u32, set_layout: DescriptorSetLayout, image_info: ^vk.DescriptorImageInfo) -> vk.WriteDescriptorSet {
	assert((binding in set_layout.bindings), "Layout does not contain specified binding")

	binding_description := set_layout.bindings[binding]
	assert(binding_description.descriptorCount == 1, "Binding single descriptor info, but binding expects multiple")

	write := vk.WriteDescriptorSet{}
	write.sType = .WRITE_DESCRIPTOR_SET
	write.descriptorType = binding_description.descriptorType
	write.dstBinding = binding
	write.pImageInfo = image_info
	write.descriptorCount = 1
	return write
}

update_descriptor_set :: proc(set_layout: ^DescriptorSetLayout, write_descriptor_sets: ..vk.WriteDescriptorSet) -> vk.DescriptorSet {
	set: vk.DescriptorSet = allocate_descriptor_set(&set_layout.descriptor_set_layout)
	if set == 0 {
		return 0
	}

	for &write in write_descriptor_sets {
		write.dstSet = set
	}
	vk.UpdateDescriptorSets(vk_ctx.device.handle, u32(len(write_descriptor_sets)), raw_data(write_descriptor_sets), 0, nil)
	return set
}
