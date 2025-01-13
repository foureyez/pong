# version 450

// layout(location = 0) in vec3 fragColor;

// layout(push_constant) uniform Push {
//     mat4 modeMatrix;
//     mat4 normaMatrix;
// } push;
layout(location = 0) in vec2 uv;
layout(set = 0, binding = 1) uniform sampler2D sprite;

layout(location = 0) out vec4 outColor;

void main() {
    // outColor = vec4(1.0, 0.0, 0.0, 1.0);
    outColor = texture(sprite, uv);
}
