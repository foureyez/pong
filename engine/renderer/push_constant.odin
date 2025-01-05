package renderer

import glm "core:math/linalg/glsl"

SimplePushConstantData :: struct {
	model_matrix:  glm.mat4,
	// _:            [2]f32, // TOOD: since vec3 push_constant requrires padding(from start of struct) which is multiple of 4 * sizeof(f32) => 4 * 4 = 16 i.e.(16,32,48...), added an empty 8 byte field 
	normal_matrix: glm.mat4,
}
