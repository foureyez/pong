package renderer

import "core:log"
import glm "core:math/linalg/glsl"
import "engine:core"
import "engine:renderer/vulkan"

Camera2D :: struct {
	transform:         core.Transform,
	near, far:         f32,
	top, bottom:       f32,
	aspect:            f32,
	projection_matrix: glm.mat4,
	view_matrix:       glm.mat4,
}

new_camera_2d :: proc(near, far: f32, position: core.vec3) -> Camera2D {
	camera := Camera2D {
		near = near,
		far = far,
		transform = {position = position},
	}

	vertical_bound: f32 = 1
	extent := vulkan.get_swapchain_extent()
	aspect_ratio := f32(extent.width) / f32(extent.height)
	camera.view_matrix = camera_view_yxz_matrix(position, {0, 0, 0})
	camera.projection_matrix = camera_orthographic_projection_matrix(
		-aspect_ratio,
		aspect_ratio,
		-vertical_bound,
		vertical_bound,
		near,
		far,
	)
	// camera.projection_matrix = camera_perspective_projection_matrix(glm.radians_f32(50.0), aspect_ratio, 0, 10)
	return camera
}

camera_view_target_matrix :: proc(position, target: glm.vec3, up: glm.vec3 = {0, -1, 0}) -> glm.mat4 {
	return camera_view_direction_matrix(position, target - position, up)
}

camera_view_yxz_matrix :: proc(position, rotation: glm.vec3) -> (view_matrix: glm.mat4) {
	c3 := glm.cos(rotation.z)
	s3 := glm.sin(rotation.z)
	c2 := glm.cos(rotation.x)
	s2 := glm.sin(rotation.x)
	c1 := glm.cos(rotation.y)
	s1 := glm.sin(rotation.y)
	u: glm.vec3 = {(c1 * c3 + s1 * s2 * s3), (c2 * s3), (c1 * s2 * s3 - c3 * s1)}
	v: glm.vec3 = {(c3 * s1 * s2 - c1 * s3), (c2 * c3), (c1 * c3 * s2 + s1 * s3)}
	w: glm.vec3 = {(c2 * s1), (-s2), (c1 * c2)}
	view_matrix = 1
	view_matrix[0][0] = u.x
	view_matrix[1][0] = u.y
	view_matrix[2][0] = u.z
	view_matrix[0][1] = v.x
	view_matrix[1][1] = v.y
	view_matrix[2][1] = v.z
	view_matrix[0][2] = w.x
	view_matrix[1][2] = w.y
	view_matrix[2][2] = w.z
	view_matrix[3][0] = -glm.dot(u, position)
	view_matrix[3][1] = -glm.dot(v, position)
	view_matrix[3][2] = -glm.dot(w, position)
	return view_matrix
}

camera_view_direction_matrix :: proc(position, direction: glm.vec3, up: glm.vec3 = {0, -1, 0}) -> (view_matrix: glm.mat4) {
	w: glm.vec3 = glm.normalize(direction)
	u: glm.vec3 = glm.normalize(glm.cross(w, up))
	v: glm.vec3 = glm.cross(w, u)

	view_matrix = 1
	view_matrix[0][0] = u.x
	view_matrix[1][0] = u.y
	view_matrix[2][0] = u.z
	view_matrix[0][1] = v.x
	view_matrix[1][1] = v.y
	view_matrix[2][1] = v.z
	view_matrix[0][2] = w.x
	view_matrix[1][2] = w.y
	view_matrix[2][2] = w.z
	view_matrix[3][0] = -glm.dot(u, position)
	view_matrix[3][1] = -glm.dot(v, position)
	view_matrix[3][2] = -glm.dot(w, position)
	return view_matrix
}

camera_orthographic_projection_matrix :: proc(left, right, top, bottom, near, far: f32) -> (projection_matrix: glm.mat4) {
	projection_matrix = 1
	projection_matrix[0][0] = 2.0 / (right - left)
	projection_matrix[1][1] = 2.0 / (bottom - top)
	projection_matrix[2][2] = 1.0 / (far - near)
	projection_matrix[3][0] = -(right + left) / (right - left)
	projection_matrix[3][1] = -(bottom + top) / (bottom - top)
	projection_matrix[3][2] = -near / (far - near)
	return projection_matrix
}

camera_perspective_projection_matrix :: proc(fovy, aspect, near, far: f32) -> (projection_matrix: glm.mat4) {
	// glm.mat4Perspective() glm perspective matrix method
	// GLM was originally designed for OpenGL, where the Y coordinate of the clip coordinates is inverted
	// The easiest way to compensate for that is to flip the sign on the scaling factor of the Y axis in the projection matrix. 
	// If you don't do this, then the image will be rendered upside down.
	// ubo.proj[1][1] *= -1;

	tan_half_fovy := glm.tan(fovy / 2.0)
	projection_matrix = 1
	projection_matrix[0][0] = 1.0 / (aspect * tan_half_fovy)
	projection_matrix[1][1] = 1.0 / (tan_half_fovy)
	projection_matrix[2][2] = far / (far - near)
	projection_matrix[2][3] = 1.0
	projection_matrix[3][2] = -(far * near) / (far - near)
	return projection_matrix
}

//camera_refresh_projection_matrix :: proc() {
//	extent := vulkan.get_swapchain_extent()
//	aspect_ratio := f32(extent.width) / f32(extent.height)
//	if ectx.camera.type == .PERSPECTIVE {
//		ectx.camera.projection_matrix = camera_perspective_projection_matrix(ectx.camera.fov, aspect, ectx.camera.near, ectx.camera.far)
//	} else {
//		ectx.camera.projection_matrix = camera_orthographic_projection_matrix(
//			-aspect,
//			aspect,
//			ectx.camera.top,
//			ectx.camera.bottom,
//			ectx.camera.near,
//			ectx.camera.far,
//		)
//	}
//}
