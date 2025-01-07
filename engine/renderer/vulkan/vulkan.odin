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
	staging_buffer:       Buffer,
	graphics_pipeline:    GraphicsPipeline,
	global_ubo:           UniformBufferObject,
	command_buffers:      []vk.CommandBuffer,
	image_available:      []vk.Semaphore,
	render_finished:      []vk.Semaphore,
	inflight_fence:       []vk.Fence,
	max_frames_in_flight: u32,
	frame_index:          u32,
}


FrameInfo :: struct {
	clear_color:    [4]f32,
	command_buffer: vk.CommandBuffer,
	frame_buffer:   vk.Framebuffer,
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
	vk_ctx.descriptor_pool = create_descriptor_pool(vk_ctx.max_frames_in_flight, {}, {.UNIFORM_BUFFER, vk_ctx.max_frames_in_flight})
	vk_ctx.global_ubo = initialize_global_ubo(ubo_type)

	// Create pipeline layout
	pipeline_config := default_pipeline_config()
	pipeline_config.render_pass = vk_ctx.renderpass
	pipeline_config.pipeline_layout = create_pipeline_layout(vk_ctx.global_ubo.layout.descriptor_set_layout)
	// pipeline_config.attribute_descriptions = get_attribute_descriptions()
	// pipeline_config.binding_descriptions = get_bindings_descriptions()

	// Create graphics pipeline 
	vk_ctx.graphics_pipeline = create_graphics_pipeline(DEFAULT_VERT_SHADER, DEFAULT_FRAG_SHADER, &pipeline_config)

	// Load image
	{
		width, height, tex_channels: i32
		pixels := stbi.load("assets/textures/entity.png", &width, &height, &tex_channels, 4)
		if pixels == nil {
			log.panic("unable to load image")
		}

		image_size: vk.DeviceSize = vk.DeviceSize(width * height * 4)
		vk_create_image(vk.Extent2D{u32(width), u32(height)}, .R8G8B8A8_UNORM, {.TRANSFER_DST, .SAMPLED})
	}
	// Staging buffer
	{
		vk_ctx.staging_buffer = create_buffer(1 * MB, {.TRANSFER_SRC}, .CPU_TO_GPU)
	}

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
