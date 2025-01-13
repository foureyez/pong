package chordvk

import "base:runtime"
import "core:log"
import "deps:vma"
import "engine:window"
import stbi "vendor:stb/image"
import vk "vendor:vulkan"

DEFAULT_VERT_SHADER :: "assets/shaders/compiled/simple.vert.spv"
DEFAULT_FRAG_SHADER :: "assets/shaders/compiled/simple.frag.spv"

VulkanContext :: struct {
	g_ctx:                runtime.Context,
	debug_m:              vk.DebugUtilsMessengerEXT,
	allocator:            vma.Allocator,
	instance:             vk.Instance,
	surface:              vk.SurfaceKHR,
	device:               Device,
	swapchain:            Swapchain,
	renderpass:           vk.RenderPass,
	descriptor_pool:      vk.DescriptorPool,
	graphics_pipeline:    GraphicsPipeline,
	global_ubo:           UniformBufferObject,
	command_buffers:      []vk.CommandBuffer,
	image_available:      []vk.Semaphore,
	render_finished:      []vk.Semaphore,
	inflight_fence:       []vk.Fence,
	max_frames_in_flight: u32,
	frame_index:          u32,
}

Image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
}

FrameInfo :: struct {
	clear_color:    [4]f32,
	command_buffer: vk.CommandBuffer,
	frame_buffer:   vk.Framebuffer,
}

UniformBufferObject :: struct {
	buffers:        []Buffer,
	layout:         DescriptorSetLayout,
	descriptor_set: []vk.DescriptorSet,
}

vk_ctx: VulkanContext

init :: proc(name: string, max_frames_in_flight: u32) {
	vk_ctx = VulkanContext {
		max_frames_in_flight = max_frames_in_flight,
	}
	vk_ctx.g_ctx = context
	vk_ctx.instance = create_instance(name)
	vk_ctx.surface = window.create_vulkan_surface(vk_ctx.instance)
	vk_ctx.debug_m = create_debug_messenger()
	vk_ctx.device = create_device()
	vk_ctx.allocator = create_vma_allocator()
	vk_ctx.swapchain = create_swapchain()
	vk_ctx.renderpass = vk_create_renderpass(vk_ctx.swapchain.format.format, .PRESENT_SRC_KHR)
	create_swapchain_frame_buffers()

	vk_ctx.image_available, vk_ctx.render_finished, vk_ctx.inflight_fence = create_sync_objects(max_frames_in_flight)
	vk_ctx.command_buffers = vk_create_command_buffers(max_frames_in_flight)
}


init_graphics_pipeline :: proc(ubo_type: typeid) {

	// Create uniform buffers and descriptor set
	vk_ctx.descriptor_pool = create_descriptor_pool(
		vk_ctx.max_frames_in_flight,
		{},
		{.UNIFORM_BUFFER, vk_ctx.max_frames_in_flight},
		{.COMBINED_IMAGE_SAMPLER, vk_ctx.max_frames_in_flight},
	)

	// Load image
	width, height, tex_channels: i32
	pixels := stbi.load("assets/textures/entity.png", &width, &height, &tex_channels, 4)
	if pixels == nil {
		log.panic("unable to load image")
	}

	// Staging buffer
	image_size: vk.DeviceSize = vk.DeviceSize(width * height * 4)
	staging_buffer := create_buffer(2 * MB, {.TRANSFER_SRC}, .CPU_TO_GPU)
	write_to_buffer(staging_buffer, pixels, u64(image_size), 0)
	stbi.image_free(pixels)

	texture_image := vk_create_image(vk.Extent2D{u32(width), u32(height)}, .R8G8B8A8_SRGB, {.TRANSFER_DST, .SAMPLED})
	transition_image_layout(texture_image, .R8G8B8A8_SRGB, .UNDEFINED, .TRANSFER_DST_OPTIMAL)
	copy_buffer_to_image(staging_buffer.vk_buffer, texture_image.handle, u32(width), u32(height), 1)
	transition_image_layout(texture_image, .R8G8B8A8_SRGB, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)
	delete_buffer(&staging_buffer)


	texture_image_view := vk_create_image_view(texture_image.handle, .R8G8B8A8_SRGB, vk.ImageSubresourceRange{{.COLOR}, 0, 1, 0, 1})
	sampler_info := vk.SamplerCreateInfo {
		sType            = .SAMPLER_CREATE_INFO,
		magFilter        = .LINEAR,
		minFilter        = .LINEAR,
		addressModeU     = .REPEAT,
		addressModeV     = .REPEAT,
		addressModeW     = .REPEAT,
		anisotropyEnable = true,
		maxAnisotropy    = 1,
	}
	texture_sampler: vk.Sampler
	vk.CreateSampler(vk_ctx.device.handle, &sampler_info, nil, &texture_sampler)


	// uniform buffers for each frame
	buffers := make([]Buffer, vk_ctx.max_frames_in_flight)
	for i in 0 ..< len(buffers) {
		buffers[i] = create_buffer(size_of(ubo_type), {.UNIFORM_BUFFER}, .CPU_TO_GPU)
	}

	ds_layout := create_descriptor_set_layout({0, .UNIFORM_BUFFER, 1, {.VERTEX}, nil}, {1, .COMBINED_IMAGE_SAMPLER, 1, {.FRAGMENT}, nil})

	descriptor_sets := make([]vk.DescriptorSet, vk_ctx.max_frames_in_flight)
	for i in 0 ..< vk_ctx.max_frames_in_flight {
		buffer_info := buffer_descriptor_info(buffers[i])
		descriptor_write := get_add_buffer_descriptor(0, ds_layout, &buffer_info)
		image_sampler_write := add_image_descriptor(
			1,
			ds_layout,
			&vk.DescriptorImageInfo{imageLayout = .SHADER_READ_ONLY_OPTIMAL, sampler = texture_sampler, imageView = texture_image_view},
		)
		descriptor_sets[i] = update_descriptor_set(&ds_layout, descriptor_write, image_sampler_write)
	}

	vk_ctx.global_ubo.buffers = buffers
	vk_ctx.global_ubo.layout = ds_layout
	vk_ctx.global_ubo.descriptor_set = descriptor_sets


	// Create pipeline layout
	pipeline_config := default_pipeline_config()
	pipeline_config.render_pass = vk_ctx.renderpass
	log.info(vk_ctx.global_ubo.layout)
	pipeline_config.pipeline_layout = create_pipeline_layout(vk_ctx.global_ubo.layout.descriptor_set_layout)
	// pipeline_config.attribute_descriptions = get_attribute_descriptions()
	// pipeline_config.binding_descriptions = get_bindings_descriptions()

	// Create graphics pipeline 
	vk_ctx.graphics_pipeline = create_graphics_pipeline(DEFAULT_VERT_SHADER, DEFAULT_FRAG_SHADER, &pipeline_config)
}


create_sync_objects :: proc(count: u32) -> (image_available: []vk.Semaphore, render_finished: []vk.Semaphore, inflight_fence: []vk.Fence) {
	image_available = make([]vk.Semaphore, count)
	render_finished = make([]vk.Semaphore, count)
	inflight_fence = make([]vk.Fence, count)
	for i in 0 ..< count {
		image_available[i] = vk_create_semaphore({})
		render_finished[i] = vk_create_semaphore({})
		inflight_fence[i] = vk_create_fence({.SIGNALED})
	}
	return image_available, render_finished, inflight_fence
}

create_vma_allocator :: proc() -> (allocator: vma.Allocator) {
	vk_functions := vma.create_vulkan_functions()
	allocator_create_info := vma.AllocatorCreateInfo {
		instance         = vk_ctx.instance,
		device           = vk_ctx.device.handle,
		physicalDevice   = vk_ctx.device.physical_handle,
		flags            = {.BUFFER_DEVICE_ADDRESS},
		pVulkanFunctions = &vk_functions,
	}

	if result := vma.CreateAllocator(&allocator_create_info, &allocator); result != .SUCCESS {
		log.panic("unable to create allocator")
	}
	return allocator
}


get_next_frame :: proc() -> (frame_info: FrameInfo) {
	vk_ctx.frame_index = (vk_ctx.frame_index + 1) % vk_ctx.max_frames_in_flight
	vk.WaitForFences(vk_ctx.device.handle, 1, &vk_ctx.inflight_fence[vk_ctx.frame_index], true, max(u64))
	vk.ResetFences(vk_ctx.device.handle, 1, &vk_ctx.inflight_fence[vk_ctx.frame_index])

	result: vk.Result
	vk_ctx.swapchain.image_index, result = vk_acquire_next_image(vk_ctx.swapchain.handle, vk_ctx.image_available[vk_ctx.frame_index])
	if result == .ERROR_OUT_OF_DATE_KHR {
		//Recreate swapchain
		recreate_swap_chain()
	}

	frame_info.command_buffer = vk_ctx.command_buffers[vk_ctx.frame_index]
	frame_info.frame_buffer = get_swapchain_framebuffer()
	return frame_info
}

recreate_swap_chain :: proc() {
	log.debugf("recreating swapchain")
	vk.DeviceWaitIdle(vk_ctx.device.handle)

	if vk_ctx.swapchain.handle == 0 {
		vk_ctx.swapchain = create_swapchain()
	} else {
		swapchain := create_swapchain(&vk_ctx.swapchain)
		if !compare_swapchain_formats(vk_ctx.swapchain, swapchain) {
			log.panic("swapchain format has changed")
		}
		vk_ctx.swapchain = swapchain
		create_swapchain_frame_buffers()
	}
}

draw_simple :: proc(command_buffer: vk.CommandBuffer) {
	vk.CmdDraw(command_buffer, 6, 1, 0, 0)
}

begin_renderpass :: proc(frame_info: ^FrameInfo) {
	clear_values: [1]vk.ClearValue
	clear_values[0].color = vk.ClearColorValue {
		//float32 = frame_info.clear_color,
		float32 = {0, 1, 1, 1},
	}

	render_pass_info := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = vk_ctx.renderpass,
		framebuffer = frame_info.frame_buffer,
		renderArea = vk.Rect2D{offset = {0, 0}, extent = vk_ctx.swapchain.extent},
		clearValueCount = u32(len(clear_values)),
		pClearValues = raw_data(clear_values[:]),
	}

	vk.CmdBeginRenderPass(frame_info.command_buffer, &render_pass_info, .INLINE)
	viewport := vk.Viewport {
		x        = 0,
		y        = 0,
		width    = f32(vk_ctx.swapchain.extent.width),
		height   = f32(vk_ctx.swapchain.extent.height),
		minDepth = 0,
		maxDepth = 1,
	}

	scissor := vk.Rect2D{{0, 0}, vk_ctx.swapchain.extent}
	vk.CmdSetViewport(frame_info.command_buffer, 0, 1, &viewport)
	vk.CmdSetScissor(frame_info.command_buffer, 0, 1, &scissor)
}

end_renderpass :: proc(command_buffer: vk.CommandBuffer) {
	vk.CmdEndRenderPass(command_buffer)
}

transition_image_layout :: proc(image: Image, format: vk.Format, old_layout, new_layout: vk.ImageLayout) {
	command_buffer := begin_single_time_commands()
	barrier := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image.handle,
		subresourceRange = vk.ImageSubresourceRange {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}

	source_stage, destination_stage: vk.PipelineStageFlags

	switch {
	case old_layout == .UNDEFINED && new_layout == .TRANSFER_DST_OPTIMAL:
		barrier.srcAccessMask = {}
		barrier.dstAccessMask = {.TRANSFER_WRITE}

		source_stage = {.TOP_OF_PIPE}
		destination_stage = {.TRANSFER}
	case old_layout == .TRANSFER_DST_OPTIMAL && new_layout == .SHADER_READ_ONLY_OPTIMAL:
		barrier.srcAccessMask = {.TRANSFER_WRITE}
		barrier.dstAccessMask = {.SHADER_READ}

		source_stage = {.TRANSFER}
		destination_stage = {.FRAGMENT_SHADER}
	case:
		log.panicf("unsupported layout transition: %v, %v", old_layout, new_layout)
	}
	vk.CmdPipelineBarrier(command_buffer, source_stage, destination_stage, {}, 0, nil, 0, nil, 1, &barrier)
	end_single_time_commands(&command_buffer)
}

cleanup :: proc() {
	vk.DeviceWaitIdle(vk_ctx.device.handle)
	free_command_buffers()
	destroy_swapchain()

	for i in 0 ..< vk_ctx.max_frames_in_flight {
		vk.DestroySemaphore(vk_ctx.device.handle, vk_ctx.render_finished[i], nil)
		vk.DestroySemaphore(vk_ctx.device.handle, vk_ctx.image_available[i], nil)
		vk.DestroyFence(vk_ctx.device.handle, vk_ctx.inflight_fence[i], nil)
	}
	// TODO:Destroy descriptor sets
	destroy_device()
	delete(vk_ctx.global_ubo.descriptor_set)
	delete(vk_ctx.global_ubo.buffers)
	delete(vk_ctx.command_buffers)
}
