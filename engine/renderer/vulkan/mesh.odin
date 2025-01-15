package chordvk

import "core:log"
import glm "core:math/linalg/glsl"
import "deps:vma"
import "engine:core"
import vk "vendor:vulkan"

Mesh :: struct {
	vertex_buffer: Buffer,
	index_buffer:  Buffer,
	vertex_count:  u32,
	index_count:   u32,
}

Vertex :: struct {
	position: core.vec3,
	color:    core.vec3,
	normal:   core.vec3,
	uv:       core.vec3,
}

TransformPushConstantData :: struct {
	model_matrix: glm.mat4,
}

MeshData :: struct {
	vertices: []Vertex,
	indices:  []u32,
}

MESH_DATA_QUAD :: MeshData {
	vertices = []Vertex {
		{position = {-0.5, -0.5, 0}, uv = {0, 0, 0}}, // Top left
		{position = {-0.5, 0.5, 0}, uv = {0, 1, 0}}, // Bottom left
		{position = {0.5, 0.5, 0}, uv = {1, 1, 0}}, // Bottom right
		{position = {0.5, -0.5, 0}, uv = {1, 0, 0}}, // Top right
	},
	indices  = []u32{0, 1, 2, 0, 3, 2},
}

mesh_create :: proc(data: MeshData) -> (mesh: Mesh) {
	log.debugf("creating mesh from data, vertices: %v, indices: %v", len(data.vertices), len(data.indices))
	mesh.vertex_buffer = create_vertex_buffer(data.vertices)
	mesh.vertex_count = u32(len(data.vertices))
	if data.indices != nil {
		mesh.index_buffer = create_index_buffer(data.indices)
		mesh.index_count = u32(len(data.indices))
	}
	return mesh
}

mesh_bind :: proc(mesh: Mesh, command_buffer: vk.CommandBuffer) {
	buffer: []vk.Buffer = {mesh.vertex_buffer.vk_buffer}
	offset: []vk.DeviceSize = {0}
	vk.CmdBindVertexBuffers(command_buffer, 0, 1, raw_data(buffer), raw_data(offset))
	if mesh.index_count > 0 {
		vk.CmdBindIndexBuffer(command_buffer, mesh.index_buffer.vk_buffer, 0, .UINT32)
	}
}

mesh_draw :: proc(mesh: Mesh, command_buffer: vk.CommandBuffer) {
	if mesh.index_count > 0 {
		vk.CmdDrawIndexed(command_buffer, mesh.index_count, 1, 0, 0, 0)
	} else {
		vk.CmdDraw(command_buffer, mesh.vertex_count, 1, 0, 0)
	}
}


@(private)
create_vertex_buffer :: proc(vertices: []Vertex) -> Buffer {
	vertex_count := u32(len(vertices))
	assert(vertex_count >= 3, "Verties must be greater than 3")

	buffer_size := u64(size_of(vertices[0]) * vertex_count)
	vertex_size := u64(size_of(vertices[0]))
	staging_buffer := create_buffer(buffer_size, {.TRANSFER_SRC}, .CPU_TO_GPU)
	defer delete_buffer(&staging_buffer)
	write_to_buffer(staging_buffer, raw_data(vertices))

	vertex_buffer := create_buffer(buffer_size, {.VERTEX_BUFFER, .TRANSFER_DST}, .GPU_ONLY)
	copy_buffer(staging_buffer.vk_buffer, vertex_buffer.vk_buffer, buffer_size)
	return vertex_buffer
}

@(private)
create_index_buffer :: proc(indices: []u32) -> Buffer {
	index_count := u32(len(indices))
	has_index_buffer := index_count > 0

	buffer_size := cast(u64)(size_of(indices[0]) * index_count)
	index_size := u64(size_of(indices[0]))

	staging_buffer := create_buffer(buffer_size, {.TRANSFER_SRC}, .CPU_TO_GPU)
	defer delete_buffer(&staging_buffer)
	write_to_buffer(staging_buffer, raw_data(indices))

	index_buffer := create_buffer(buffer_size, {.INDEX_BUFFER, .TRANSFER_DST}, .GPU_ONLY)
	copy_buffer(staging_buffer.vk_buffer, index_buffer.vk_buffer, buffer_size)
	return index_buffer
}

get_bindings_descriptions :: proc() -> []vk.VertexInputBindingDescription {
	bindingDescriptions := make([]vk.VertexInputBindingDescription, 1)
	bindingDescriptions[0] = {0, size_of(Vertex), .VERTEX}
	return bindingDescriptions
}

get_attribute_descriptions :: proc() -> []vk.VertexInputAttributeDescription {
	attributeDescriptions := make([]vk.VertexInputAttributeDescription, 4)
	attributeDescriptions[0] = {0, 0, .R32G32B32_SFLOAT, u32(offset_of(Vertex, position))}
	attributeDescriptions[1] = {1, 0, .R32G32B32_SFLOAT, u32(offset_of(Vertex, color))}
	attributeDescriptions[2] = {2, 0, .R32G32B32_SFLOAT, u32(offset_of(Vertex, normal))}
	attributeDescriptions[3] = {3, 0, .R32G32_SFLOAT, u32(offset_of(Vertex, uv))}
	return attributeDescriptions
}
