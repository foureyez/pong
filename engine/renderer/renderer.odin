package renderer

import "core:fmt"
import "core:log"
import glm "core:math/linalg/glsl"
import "deps:imgui"
import "engine:renderer/vulkan"
import vk "vendor:vulkan"

clear_color: [4]f32
frame_info: vulkan.FrameInfo
MAX_FRAMES_IN_FLIGHT :: 2

GlobalUboData :: struct {
	projection_view: glm.mat4,
	light_dir:       glm.vec3,
}

DEFAULT_GLOBAL_UBO := GlobalUboData {
	projection_view = 1.0,
	light_dir       = glm.normalize(glm.vec3{1, -3, -1}),
}

init :: proc(name: string) {
	vulkan.init(name, MAX_FRAMES_IN_FLIGHT)
	vulkan.init_graphics_pipeline(GlobalUboData)
}

/**
1. Get the next image from swapchain
2. Begin renderpass  and bind graphics pipeline
3. Bind mesh and issue draw calls to command buffer
**/
render_begin :: proc() {
	frame_info = vulkan.get_next_frame()

	ubo := DEFAULT_GLOBAL_UBO
	// ubo.projection_view = ectx.camera.projection_matrix * ectx.camera.view_matrix
	frame_info.clear_color = clear_color

	vulkan.write_to_buffer_index(&ubo)
	vulkan.begin_command_buffer(frame_info.command_buffer)
	vulkan.begin_renderpass(&frame_info)
}


/**
* End the renderpass and submit command buffer
**/
render_end :: proc() {
	vulkan.end_renderpass(frame_info.command_buffer)
	vulkan.end_command_buffer(frame_info.command_buffer)

	result := vulkan.submit_command_buffers(frame_info)
	if result == .ERROR_OUT_OF_DATE_KHR {
		vulkan.recreate_swap_chain()
		// camera_refresh_projection_matrix(ectx)
	} else {
		assert(result == .SUCCESS, fmt.tprintf("unable to submit command buffers: %v", result))
	}
}

handle_window_resize :: proc() {
	vulkan.recreate_swap_chain()
	// vulkan.create_viewport_resources()
}

clear_background :: proc(color: [4]f32) {
	clear_color = color
}

draw_quad :: proc(size: [2]f32, pos: [2]f32) {
	vulkan.bind_pipeline(frame_info.command_buffer)
	vulkan.draw_simple(frame_info.command_buffer)
}

destroy :: proc() {
	vulkan.cleanup()
}

// @(private)
// draw_mesh :: proc(curr_frame: ^FrameInfo) {
// 	vk.CmdBindPipeline(curr_frame.command_buffer, .GRAPHICS, ectx.graphics_pipeline.vk_pipeline)
// 	vk.CmdBindDescriptorSets(
// 		curr_frame.command_buffer,
// 		.GRAPHICS,
// 		ectx.graphics_pipeline.layout,
// 		0,
// 		1,
// 		&curr_frame.global_ubo_descriptor_set,
// 		0,
// 		nil,
// 	)
// 	for _, object in registered_gameobjects {
// 		mesh.bind(object.mesh, curr_frame.command_buffer)
// 		push := SimplePushConstantData {
// 			model_matrix  = transform_matrix(object.transform),
// 			normal_matrix = normal_matrix(object.transform),
// 		}
//
// 		vk.CmdPushConstants(
// 			curr_frame.command_buffer,
// 			ectx.graphics_pipeline.layout,
// 			{.FRAGMENT, .VERTEX}, // NOT {.FRAGMENT|.VERTEX} 
// 			0,
// 			size_of(SimplePushConstantData),
// 			&push,
// 		)
// 		mesh.draw(object.mesh, curr_frame.command_buffer)
// 	}
// }
