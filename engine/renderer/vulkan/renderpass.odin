package chordvk

import "core:log"
import vk "vendor:vulkan"


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
