package chordvk

import "core:log"
import vk "vendor:vulkan"

@(private)
create_renderpass :: proc(format: vk.Format, final_layout: vk.ImageLayout) -> (render_pass: vk.RenderPass) {

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

begin_renderpass :: proc(frame_info: ^FrameInfo) {
	clear_values: [1]vk.ClearValue
	clear_values[0].color = vk.ClearColorValue {
		float32 = frame_info.clear_color,
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
