package chordvk

import "core:log"
import "core:slice"
import "engine:core"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"


Swapchain :: struct {
	handle:       vk.SwapchainKHR,
	capabilities: vk.SurfaceCapabilitiesKHR,
	format:       vk.SurfaceFormatKHR,
	present_mode: vk.PresentModeKHR,
	images:       []SwapchainImage,
	image_count:  u32,
	image_index:  u32,
	extent:       vk.Extent2D,
}

SwapchainImage :: struct {
	image:       vk.Image,
	view:        vk.ImageView,
	framebuffer: vk.Framebuffer,
}


@(private)
create_swapchain :: proc(old_swapchain: ^Swapchain = nil) -> (swapchain: Swapchain) {
	pixel_width, pixel_height: i32
	sdl.Vulkan_GetDrawableSize(core.window_get_instance().handle, &pixel_width, &pixel_height)

	swapchain.capabilities, swapchain.format, swapchain.present_mode = query_swap_chain_support(vk_ctx.device.physical_handle)
	swapchain.extent = choose_swap_extent(swapchain.capabilities, pixel_width, pixel_height)

	log.debugf("Swapchain Format: %v", swapchain.format.format)
	log.debugf("Surface Color: %v", swapchain.format.colorSpace)
	log.debugf("PresentMode: %v", swapchain.present_mode)
	log.debugf("Swapchain Extent: %v", swapchain.extent)

	swapchain.handle = vk_create_swapchain(
		swapchain.capabilities,
		swapchain.format,
		swapchain.present_mode,
		swapchain.extent,
		old_swapchain,
	)

	swapchain_images := vk_get_swapchain_images(swapchain.handle)
	swapchain.image_count = u32(len(swapchain_images))

	swapchain.images = make([]SwapchainImage, swapchain.image_count)
	for &image, i in swapchain.images {
		image.image = swapchain_images[i]
		image.view = vk_create_image_view(
			image.image,
			swapchain.format.format,
			{layerCount = 1, levelCount = 1, baseArrayLayer = 0, baseMipLevel = 0, aspectMask = {.COLOR}},
		)
	}

	return swapchain
}

create_swapchain_frame_buffers :: proc() {
	for &image in vk_ctx.swapchain.images {
		image.framebuffer = vk_create_frame_buffer(vk_ctx.renderpass, {image.view}, vk_ctx.swapchain.extent)
	}
}

get_swapchain_framebuffer :: proc() -> vk.Framebuffer {
	return vk_ctx.swapchain.images[vk_ctx.swapchain.image_index].framebuffer
}


destroy_swapchain :: proc() {
	for image in vk_ctx.swapchain.images {
		vk.DestroyImageView(vk_ctx.device.handle, image.view, nil)
		vk.DestroyFramebuffer(vk_ctx.device.handle, image.framebuffer, nil)
	}

	vk.DestroySwapchainKHR(vk_ctx.device.handle, vk_ctx.swapchain.handle, nil)
	delete(vk_ctx.swapchain.images)
}

vk_acquire_next_image :: proc(swapchain: vk.SwapchainKHR, semaphore: vk.Semaphore) -> (u32, vk.Result) {
	index: u32
	result := vk.AcquireNextImageKHR(vk_ctx.device.handle, vk_ctx.swapchain.handle, max(u64), semaphore, 0, &index)
	return index, result
}

compare_swapchain_formats :: proc(old, new: Swapchain) -> bool {
	return old.format.format == new.format.format
}


@(private)
choose_swap_extent :: proc(capabilities: vk.SurfaceCapabilitiesKHR, width, height: i32) -> vk.Extent2D {
	if capabilities.currentExtent.width != 0 && capabilities.currentExtent.width != max(u32) {
		return capabilities.currentExtent
	}

	cwidth := clamp(u32(width), capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
	cheight := clamp(u32(height), capabilities.minImageExtent.height, capabilities.maxImageExtent.height)

	return vk.Extent2D{cwidth, cheight}
}

@(private)
find_depth_format :: proc() -> vk.Format {
	format := find_supported_format(
		vk_ctx.device.physical_handle,
		{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		.OPTIMAL,
		.DEPTH_STENCIL_ATTACHMENT,
	)
	return format
}

find_supported_format :: proc(
	device: vk.PhysicalDevice,
	candidates: []vk.Format,
	tiling: vk.ImageTiling,
	features: vk.FormatFeatureFlag,
) -> vk.Format {
	for format in candidates {
		props: vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(device, format, &props)
		if tiling == .LINEAR && features in (props.linearTilingFeatures & vk.FormatFeatureFlags{features}) {
			return format
		}

		if tiling == .OPTIMAL && features in (props.optimalTilingFeatures & vk.FormatFeatureFlags{features}) {
			return format
		}
	}
	log.panic("unable to find supported image format")
}

@(private)
query_swap_chain_support :: proc(device: vk.PhysicalDevice) -> (vk.SurfaceCapabilitiesKHR, vk.SurfaceFormatKHR, vk.PresentModeKHR) {

	capabilities := vk_get_physical_device_surface_capabilities(device)

	format := vk.SurfaceFormatKHR{.B8G8R8A8_SRGB, .COLORSPACE_SRGB_NONLINEAR}
	supported_formats := vk_get_physical_device_surface_formats(device)
	if slice.none_of(supported_formats, format) {
		format = supported_formats[0]
	}

	present_mode: vk.PresentModeKHR = .MAILBOX
	supported_present_modes := vk_get_physical_device_surface_present_modes(device)
	if slice.none_of(supported_present_modes, present_mode) {
		present_mode = supported_present_modes[0]
	}

	return capabilities, format, present_mode
}


@(private)
create_image_with_info :: proc(
	image_info: ^vk.ImageCreateInfo,
	properties: vk.MemoryPropertyFlags,
) -> (
	image: vk.Image,
	image_memory: vk.DeviceMemory,
) {

	if vk.CreateImage(vk_ctx.device.handle, image_info, nil, &image) != .SUCCESS {
		log.panic("unable to create image")
	}

	mem_requirements := vk.MemoryRequirements{}
	vk.GetImageMemoryRequirements(vk_ctx.device.handle, image, &mem_requirements)

	alloc_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = mem_requirements.size,
		memoryTypeIndex = find_memory_type(mem_requirements.memoryTypeBits, properties),
	}

	if vk.AllocateMemory(vk_ctx.device.handle, &alloc_info, nil, &image_memory) != .SUCCESS {
		log.panic("unable to allocate memory for image")
	}

	if vk.BindImageMemory(vk_ctx.device.handle, image, image_memory, 0) != .SUCCESS {
		log.panic("unable to bind image memory")
	}
	return image, image_memory
}
