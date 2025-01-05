package engine

import glm "core:math/linalg/glsl"

Transform :: struct {
	translation: glm.vec3,
	scale:       glm.vec3,
	rotation:    glm.vec3,
}
