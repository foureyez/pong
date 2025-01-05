package chordvk

import "core:fmt"
import "core:log"
import vk "vendor:vulkan"

free_command_buffers :: proc() {
	vk.FreeCommandBuffers(
		vk_ctx.device.handle,
		vk_ctx.device.command_pool,
		u32(len(vk_ctx.command_buffers)),
		raw_data(vk_ctx.command_buffers),
	)
}

begin_command_buffer :: proc(command_buffer: vk.CommandBuffer) {
	begin_info := vk.CommandBufferBeginInfo{}
	begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO
	assert(vk.BeginCommandBuffer(command_buffer, &begin_info) == .SUCCESS, "unable to begin command buffers")
}

end_command_buffer :: proc(command_buffer: vk.CommandBuffer) {
	assert(vk.EndCommandBuffer(command_buffer) == .SUCCESS, "Unable to end command buffer")
}

submit_command_buffers :: proc(frame_info: FrameInfo) -> vk.Result {
	signal_semaphores := []vk.Semaphore{vk_ctx.render_finished[vk_ctx.frame_index]}
	submit_info := vk.SubmitInfo {
		sType                = .SUBMIT_INFO,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = raw_data([]vk.Semaphore{vk_ctx.image_available[vk_ctx.frame_index]}),
		pWaitDstStageMask    = raw_data([]vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}),
		commandBufferCount   = 1,
		pCommandBuffers      = raw_data([]vk.CommandBuffer{frame_info.command_buffer}),
		signalSemaphoreCount = 1,
		pSignalSemaphores    = raw_data(signal_semaphores),
	}

	result := vk.QueueSubmit(vk_ctx.device.graphics_queue.vk_queue, 1, &submit_info, vk_ctx.inflight_fence[vk_ctx.frame_index])
	if result != .SUCCESS {
		log.info("here")
		return result
	}

	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = raw_data(signal_semaphores),
		swapchainCount     = 1,
		pSwapchains        = raw_data([]vk.SwapchainKHR{vk_ctx.swapchain.handle}),
		pImageIndices      = &vk_ctx.swapchain.image_index,
	}

	result = vk.QueuePresentKHR(vk_ctx.device.present_queue.vk_queue, &present_info)
	return result
}
