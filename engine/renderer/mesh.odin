package renderer

import "core:log"
import glm "core:math/linalg/glsl"
import "engine:core"
import "engine:renderer/vulkan"

Mesh :: struct {
	vk_mesh: vulkan.Mesh,
}


mesh_create_quad :: proc() -> (mesh: Mesh) {
	mesh.vk_mesh = vulkan.mesh_create(vulkan.MESH_DATA_QUAD)
	return mesh
}

transform_matrix :: proc(t: core.Transform) -> glm.mat4 {
	// Slower approach instead expand the matrix multiplication for fewer calculations
	// TODO: Read more on this
	// transform := glm.mat4Translate(t.translate)
	// transform *= glm.mat4Rotate({0.0, 1.0, 0.0}, t.rotation.y)
	// transform *= glm.mat4Rotate({1.0, 0.0, 0.0}, t.rotation.x)
	// transform *= glm.mat4Rotate({0.0, 0.0, 1.0}, t.rotation.z)
	// transform *= glm.mat4Scale(t.scale)

	c3 := glm.cos(t.rotation.z)
	s3 := glm.sin(t.rotation.z)
	c2 := glm.cos(t.rotation.x)
	s2 := glm.sin(t.rotation.x)
	c1 := glm.cos(t.rotation.y)
	s1 := glm.sin(t.rotation.y)

	// https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix
	return glm.mat4 {
		t.scale.x * (c1 * c3 + s1 * s2 * s3),
		t.scale.y * (c3 * s1 * s2 - c1 * s3),
		t.scale.z * (c2 * s1),
		t.position.x,
		t.scale.x * (c2 * s3),
		t.scale.y * (c2 * c3),
		t.scale.z * (-s2),
		t.position.y,
		t.scale.x * (c1 * s2 * s3 - c3 * s1),
		t.scale.y * (c1 * c3 * s2 + s1 * s3),
		t.scale.z * (c1 * c2),
		t.position.z,
		0,
		0,
		0,
		1.0,
	}
}
