package chordvk

import "core:log"
import vk "vendor:vulkan"

vk_get_physical_device_surface_capabilities :: proc(device: vk.PhysicalDevice) -> vk.SurfaceCapabilitiesKHR {
	surface_capabilities: vk.SurfaceCapabilitiesKHR
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, vk_ctx.surface, &surface_capabilities)
	return surface_capabilities
}

vk_get_physical_device_surface_formats :: proc(device: vk.PhysicalDevice) -> []vk.SurfaceFormatKHR {
	format_count: u32
	supported_formats: []vk.SurfaceFormatKHR
	vk.GetPhysicalDeviceSurfaceFormatsKHR(device, vk_ctx.surface, &format_count, nil)
	if format_count != 0 {
		supported_formats = make([]vk.SurfaceFormatKHR, format_count, context.temp_allocator)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, vk_ctx.surface, &format_count, raw_data(supported_formats))
	}
	return supported_formats
}

vk_get_physical_device_surface_present_modes :: proc(device: vk.PhysicalDevice) -> []vk.PresentModeKHR {
	present_mode_count: u32
	supported_present_modes: []vk.PresentModeKHR
	vk.GetPhysicalDeviceSurfacePresentModesKHR(device, vk_ctx.surface, &present_mode_count, nil)
	if present_mode_count != 0 {
		supported_present_modes = make([]vk.PresentModeKHR, present_mode_count, context.temp_allocator)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, vk_ctx.surface, &present_mode_count, raw_data(supported_present_modes))
	}
	return supported_present_modes
}


vk_create_image :: proc(extent: vk.Extent2D, format: vk.Format, usage: vk.ImageUsageFlags) -> (image: vk.Image, mem: vk.DeviceMemory) {
	create_info := vk.ImageCreateInfo {
		sType = .IMAGE_CREATE_INFO,
		format = format,
		imageType = .D2,
		extent = vk.Extent3D{width = extent.width, height = extent.height, depth = 1},
		mipLevels = 1,
		arrayLayers = 1,
		initialLayout = .UNDEFINED,
		samples = {._1},
		tiling = .LINEAR,
		usage = usage,
	}

	vk.CreateImage(vk_ctx.device.handle, &create_info, nil, &image)

	mem_requirements: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(vk_ctx.device.handle, image, &mem_requirements)

	mem_alloc_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = mem_requirements.size,
		memoryTypeIndex = find_memory_type(mem_requirements.memoryTypeBits, {.HOST_VISIBLE, .HOST_COHERENT}),
	}

	vk.AllocateMemory(vk_ctx.device.handle, &mem_alloc_info, nil, &mem)
	vk.BindImageMemory(vk_ctx.device.handle, image, mem, 0)

	return image, mem
}


vk_create_image_view :: proc(image: vk.Image, format: vk.Format, sub_resource_range: vk.ImageSubresourceRange) -> (view: vk.ImageView) {
	vk.CreateImageView(
		vk_ctx.device.handle,
		&vk.ImageViewCreateInfo {
			sType = .IMAGE_VIEW_CREATE_INFO,
			image = image,
			format = format,
			viewType = .D2,
			subresourceRange = sub_resource_range,
		},
		nil,
		&view,
	)
	return view
}

vk_create_semaphore :: proc(flags: vk.SemaphoreCreateFlags) -> (semaphore: vk.Semaphore) {
	vk.CreateSemaphore(vk_ctx.device.handle, &vk.SemaphoreCreateInfo{sType = .SEMAPHORE_CREATE_INFO}, nil, &semaphore)
	return semaphore
}

vk_create_fence :: proc(flags: vk.FenceCreateFlags) -> (fence: vk.Fence) {
	vk.CreateFence(vk_ctx.device.handle, &vk.FenceCreateInfo{sType = .FENCE_CREATE_INFO, flags = flags}, nil, &fence)
	return fence
}

vk_get_swapchain_images :: proc(swapchain: vk.SwapchainKHR) -> []vk.Image {
	image_count: u32
	vk.GetSwapchainImagesKHR(vk_ctx.device.handle, swapchain, &image_count, nil)

	vk_images := make([]vk.Image, image_count)
	vk.GetSwapchainImagesKHR(vk_ctx.device.handle, swapchain, &image_count, raw_data(vk_images))
	return vk_images
}


vk_create_swapchain :: proc(
	capabilities: vk.SurfaceCapabilitiesKHR,
	format: vk.SurfaceFormatKHR,
	present_mode: vk.PresentModeKHR,
	extent: vk.Extent2D,
	old_swapchain: ^Swapchain = nil,
) -> (
	handle: vk.SwapchainKHR,
) {

	image_count := capabilities.minImageCount + 1
	if capabilities.maxImageCount > 0 && image_count > capabilities.maxImageCount {
		image_count = capabilities.maxImageCount
	}

	create_info: vk.SwapchainCreateInfoKHR = {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = vk_ctx.surface,
		minImageCount    = image_count,
		imageFormat      = format.format,
		imageColorSpace  = format.colorSpace,
		imageExtent      = extent,
		imageArrayLayers = 1,
		imageUsage       = {.COLOR_ATTACHMENT},
		preTransform     = capabilities.currentTransform,
		compositeAlpha   = {.OPAQUE},
		presentMode      = present_mode,
		clipped          = true,
		oldSwapchain     = old_swapchain != nil ? old_swapchain.handle : 0,
	}

	queue_family_incides := []u32{vk_ctx.device.graphics_queue.family_index, vk_ctx.device.present_queue.family_index}
	if vk_ctx.device.graphics_queue.family_index != vk_ctx.device.present_queue.family_index {
		create_info.imageSharingMode = .CONCURRENT
		create_info.queueFamilyIndexCount = 2
		create_info.pQueueFamilyIndices = raw_data(queue_family_incides)
	} else {
		create_info.imageSharingMode = .EXCLUSIVE
		create_info.queueFamilyIndexCount = 0
		create_info.pQueueFamilyIndices = nil
	}

	if vk.CreateSwapchainKHR(vk_ctx.device.handle, &create_info, nil, &handle) != .SUCCESS {
		log.panicf("Unable to create swapchain")
	}

	return handle
}

vk_create_frame_buffer :: proc(renderpass: vk.RenderPass, views: []vk.ImageView, extent: vk.Extent2D) -> (frame_buffer: vk.Framebuffer) {
	frame_buffer_info := vk.FramebufferCreateInfo {
		sType           = .FRAMEBUFFER_CREATE_INFO,
		renderPass      = renderpass,
		attachmentCount = u32(len(views)),
		pAttachments    = raw_data(views),
		width           = extent.width,
		height          = extent.height,
		layers          = 1,
	}

	if vk.CreateFramebuffer(vk_ctx.device.handle, &frame_buffer_info, nil, &frame_buffer) != .SUCCESS {
		log.panic("unable to create framebuffers")
	}
	return frame_buffer
}

vk_create_renderpass :: proc(format: vk.Format, final_layout: vk.ImageLayout) -> (render_pass: vk.RenderPass) {

	attachments := []vk.AttachmentDescription {
		{format = format, samples = {._1}, loadOp = .CLEAR, storeOp = .STORE, initialLayout = .UNDEFINED, finalLayout = final_layout},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = u32(len(attachments)),
		pAttachments    = raw_data(attachments),
		subpassCount    = 1,
		pSubpasses      = &vk.SubpassDescription {
			pipelineBindPoint = .GRAPHICS,
			colorAttachmentCount = 1,
			pColorAttachments = raw_data([]vk.AttachmentReference{{attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL}}),
			pDepthStencilAttachment = nil,
		},
		dependencyCount = 1,
		pDependencies   = &vk.SubpassDependency {
			dstSubpass = 0,
			dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
			dstStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
			srcSubpass = vk.SUBPASS_EXTERNAL,
			srcAccessMask = {},
			srcStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		},
	}

	if vk.CreateRenderPass(vk_ctx.device.handle, &render_pass_info, nil, &render_pass) != .SUCCESS {
		log.panic("unable to create swapchain render pass")
	}

	return render_pass
}

vk_create_command_buffers :: proc(count: u32) -> []vk.CommandBuffer {
	command_buffers := make([]vk.CommandBuffer, count)
	alloc_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		level              = .PRIMARY,
		commandPool        = vk_ctx.device.command_pool,
		commandBufferCount = u32(len(command_buffers)),
	}

	assert(
		vk.AllocateCommandBuffers(vk_ctx.device.handle, &alloc_info, raw_data(command_buffers)) == .SUCCESS,
		"unable to allocate command buffers",
	)
	return command_buffers
}
