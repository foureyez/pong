package renderer

import "core:log"
import "engine:renderer/vulkan"

Mesh :: struct {
	vk_mesh: vulkan.Mesh,
}

mesh_create_quad :: proc() -> (mesh: Mesh) {
	mesh.vk_mesh = vulkan.mesh_create(vulkan.MESH_DATA_QUAD)
	return mesh
}
