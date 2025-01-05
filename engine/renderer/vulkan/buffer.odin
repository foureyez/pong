package chordvk

import "core:log"
import "core:mem"
import "deps:vma"
import vk "vendor:vulkan"

Buffer :: struct {
	vk_buffer:       vk.Buffer,
	allocation:      vma.Allocation,
	allocation_info: vma.AllocationInfo,
}


create_buffer :: proc(alloc_size: u64, usage_flags: vk.BufferUsageFlags, mem_usage: vma.MemoryUsage) -> (buffer: Buffer) {
	bufferInfo: vk.BufferCreateInfo = {}
	bufferInfo.sType = .BUFFER_CREATE_INFO
	bufferInfo.size = vk.DeviceSize(alloc_size)
	bufferInfo.usage = usage_flags
	bufferInfo.sharingMode = .EXCLUSIVE

	alloc_info: vma.AllocationCreateInfo = {}
	alloc_info.usage = mem_usage
	alloc_info.flags = {.MAPPED}

	assert(
		vma.CreateBuffer(vk_ctx.allocator, &bufferInfo, &alloc_info, &buffer.vk_buffer, &buffer.allocation, &buffer.allocation_info) ==
		.SUCCESS,
	)
	return buffer
}

delete_buffer :: proc(buffer: ^Buffer) {
	vk.DestroyBuffer(vk_ctx.device.handle, buffer.vk_buffer, nil)
	//vk.FreeMemory(device.device, buffer.vk_memory, nil)
}

get_buffer_alignment :: proc(instance_size, min_offset_alignment: u64) -> u64 {
	if (min_offset_alignment > 0) {
		return (instance_size + min_offset_alignment - 1) & ~(min_offset_alignment - 1)
	}
	return instance_size
}

write_to_buffer :: proc(buffer: Buffer, data: rawptr, size: u64 = vk.WHOLE_SIZE, offset: u64 = 0) {
	assert(buffer.allocation_info.pMappedData != nil, "Cannot copy to unmapped buffer")
	if (size == vk.WHOLE_SIZE) {
		mem.copy(buffer.allocation_info.pMappedData, data, int(buffer.allocation_info.size))
	} else {
		// Offset a rawptr: 
		// https://discord.com/channels/568138951836172421/568871298428698645/1052827800899424257 
		mem_offset := mem.ptr_offset(cast(^u8)buffer.allocation_info.pMappedData, offset)
		mem.copy(mem_offset, data, int(size))
	}
}

write_to_buffer_index :: proc(data: rawptr, size: u64 = vk.WHOLE_SIZE, offset: u64 = 0) {
	buffer := vk_ctx.global_ubo.buffers[vk_ctx.frame_index]
	assert(buffer.allocation_info.pMappedData != nil, "Cannot copy to unmapped buffer")
	if (size == vk.WHOLE_SIZE) {
		mem.copy(buffer.allocation_info.pMappedData, data, int(buffer.allocation_info.size))
	} else {
		// Offset a rawptr: 
		// https://discord.com/channels/568138951836172421/568871298428698645/1052827800899424257 
		mem_offset := mem.ptr_offset(cast(^u8)buffer.allocation_info.pMappedData, offset)
		mem.copy(mem_offset, data, int(size))
	}
}

/**
 * Flush a memory range of the buffer to make it visible to the device
 *
 * @note Only required for non-coherent memory
 *
 * @param size (Optional) Size of the memory range to flush. Pass VK_WHOLE_SIZE to flush the
 * complete buffer range.
 * @param offset (Optional) Byte offset from beginning
 *
 * @return VkResult of the flush call
 */
flush_buffer :: proc(device: Device, buffer: Buffer, size: u64 = vk.WHOLE_SIZE, offset: u64 = 0) -> vk.Result {
	mapped_range: vk.MappedMemoryRange = {}
	mapped_range.sType = .MAPPED_MEMORY_RANGE
	mapped_range.memory = buffer.allocation_info.deviceMemory
	mapped_range.offset = vk.DeviceSize(offset)
	mapped_range.size = vk.DeviceSize(size)
	return vk.FlushMappedMemoryRanges(device.handle, 1, &mapped_range)
}

/**
 * Invalidate a memory range of the buffer to make it visible to the host
 *
 * @note Only required for non-coherent memory
 *
 * @param size (Optional) Size of the memory range to invalidate. Pass VK_WHOLE_SIZE to invalidate
 * the complete buffer range.
 * @param offset (Optional) Byte offset from beginning
 *
 * @return VkResult of the invalidate call
 */
invalidate_buffer :: proc(device: Device, buffer: Buffer, size: u64 = vk.WHOLE_SIZE, offset: u64 = 0) -> vk.Result {
	mapped_range: vk.MappedMemoryRange = {}
	mapped_range.sType = .MAPPED_MEMORY_RANGE
	mapped_range.memory = buffer.allocation_info.deviceMemory
	mapped_range.offset = vk.DeviceSize(offset)
	mapped_range.size = vk.DeviceSize(size)
	return vk.InvalidateMappedMemoryRanges(device.handle, 1, &mapped_range)
}

/**
 * Create a buffer info descriptor
 *
 * @param size (Optional) Size of the memory range of the descriptor
 * @param offset (Optional) Byte offset from beginning
 *
 * @return VkDescriptorBufferInfo of specified offset and range
 */
buffer_descriptor_info :: proc(using buffer: Buffer, size: u64 = vk.WHOLE_SIZE, offset: u64 = 0) -> vk.DescriptorBufferInfo {
	return vk.DescriptorBufferInfo{vk_buffer, vk.DeviceSize(offset), vk.DeviceSize(size)}
}


/**
 * Copies "instanceSize" bytes of data to the mapped buffer at an offset of index * alignmentSize
 *
 * @param data Pointer to the data to copy
 * @param index Used in offset calculation
 *
 */
//write_to_buffer_index :: proc(buffer: Buffer, data: rawptr, index: int) {
//	write_to_buffer(buffer, data, buffer, u64(index) * buffer.alignment_size)
//}

/**
 *  Flush the memory range at index * alignmentSize of the buffer to make it visible to the device
 *
 * @param index Used in offset calculation
 *
 */
//flush_buffer_index :: proc(device: Device, buffer: Buffer, index: int) -> vk.Result {
//	return flush_buffer(device, buffer, buffer.alignment_size, u64(index) * buffer.alignment_size)
//}

/**
 * Create a buffer info descriptor
 *
 * @param index Specifies the region given by index * alignmentSize
 *
 * @return VkDescriptorBufferInfo for instance at index
 */
//buffer_descriptor_info_index :: proc(buffer: Buffer, index: int) -> vk.DescriptorBufferInfo {
//	return buffer_descriptor_info(buffer, buffer.alignment_size, u64(index) * buffer.alignment_size)
//}

/**
 * Invalidate a memory range of the buffer to make it visible to the host
 *
 * @note Only required for non-coherent memory
 *
 * @param index Specifies the region to invalidate: index * alignmentSize
 *
 * @return VkResult of the invalidate call
 */
//invalidate_buffer_index :: proc(device: Device, buffer: Buffer, index: int) -> vk.Result {
//	return invalidate_buffer(device, buffer, buffer.alignment_size, u64(index) * buffer.alignment_size)
//
//}

create_vk_buffer :: proc(
	device: Device,
	size: vk.DeviceSize,
	flags: vk.BufferUsageFlags,
	properties: vk.MemoryPropertyFlags,
) -> (
	vk.Buffer,
	vk.DeviceMemory,
) {
	bufferInfo: vk.BufferCreateInfo = {}
	bufferInfo.sType = .BUFFER_CREATE_INFO
	bufferInfo.size = size
	bufferInfo.usage = flags
	bufferInfo.sharingMode = .EXCLUSIVE

	buffer: vk.Buffer
	if vk.CreateBuffer(device.handle, &bufferInfo, nil, &buffer) != .SUCCESS {
		log.panic("unable to create buffer")
	}

	mem_requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(device.handle, buffer, &mem_requirements)

	alloc_info: vk.MemoryAllocateInfo = {}
	alloc_info.sType = .MEMORY_ALLOCATE_INFO
	alloc_info.allocationSize = mem_requirements.size
	alloc_info.memoryTypeIndex = find_memory_type(mem_requirements.memoryTypeBits, properties)

	buffer_memory: vk.DeviceMemory
	if vk.AllocateMemory(device.handle, &alloc_info, nil, &buffer_memory) != .SUCCESS {
		log.panic("unable to allocate buffer memory")
	}

	vk.BindBufferMemory(device.handle, buffer, buffer_memory, 0)
	return buffer, buffer_memory
}

copy_buffer :: proc(srcBuffer: vk.Buffer, dstBuffer: vk.Buffer, size: u64) {
	command_buffer: vk.CommandBuffer = begin_single_time_commands(vk_ctx.device)

	copy_region: vk.BufferCopy = {}
	copy_region.srcOffset = 0 // Optional
	copy_region.dstOffset = 0 // Optional
	copy_region.size = vk.DeviceSize(size)
	vk.CmdCopyBuffer(command_buffer, srcBuffer, dstBuffer, 1, &copy_region)
	end_single_time_commands(vk_ctx.device, &command_buffer)
}

copy_buffer_to_image :: proc(device: Device, buffer: vk.Buffer, image: vk.Image, width: u32, height: u32, layerCount: u32) {
	commandBuffer: vk.CommandBuffer = begin_single_time_commands(device)

	region: vk.BufferImageCopy = {}
	region.bufferOffset = 0
	region.bufferRowLength = 0
	region.bufferImageHeight = 0

	region.imageSubresource.aspectMask = {.COLOR}
	region.imageSubresource.mipLevel = 0
	region.imageSubresource.baseArrayLayer = 0
	region.imageSubresource.layerCount = layerCount

	region.imageOffset = {0, 0, 0}
	region.imageExtent = {width, height, 1}

	vk.CmdCopyBufferToImage(commandBuffer, buffer, image, .TRANSFER_DST_OPTIMAL, 1, &region)
	end_single_time_commands(device, &commandBuffer)
}

begin_single_time_commands :: proc(device: Device) -> vk.CommandBuffer {
	alloc_info: vk.CommandBufferAllocateInfo = {}
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.level = .PRIMARY
	alloc_info.commandPool = device.command_pool
	alloc_info.commandBufferCount = 1

	command_buffer: vk.CommandBuffer
	vk.AllocateCommandBuffers(device.handle, &alloc_info, &command_buffer)

	begin_info: vk.CommandBufferBeginInfo = {}
	begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO
	begin_info.flags = {.ONE_TIME_SUBMIT}

	vk.BeginCommandBuffer(command_buffer, &begin_info)
	return command_buffer
}

end_single_time_commands :: proc(device: Device, command_buffer: ^vk.CommandBuffer) {
	vk.EndCommandBuffer(command_buffer^)

	submit_info: vk.SubmitInfo = {}
	submit_info.sType = .SUBMIT_INFO
	submit_info.commandBufferCount = 1
	submit_info.pCommandBuffers = command_buffer

	vk.QueueSubmit(device.graphics_queue.vk_queue, 1, &submit_info, 0)
	vk.QueueWaitIdle(device.graphics_queue.vk_queue)

	vk.FreeCommandBuffers(device.handle, device.command_pool, 1, command_buffer)
}
