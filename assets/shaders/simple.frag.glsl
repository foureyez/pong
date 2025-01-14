# version 450

layout(location = 0) in vec3 texuv;
// layout(location = 0) in vec3 fragColor;

// layout(push_constant) uniform Push {
//     mat4 modeMatrix;
//     mat4 normaMatrix;
// } push;
layout(set = 0, binding = 1) uniform sampler2D sprite;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 color = texture(sprite, texuv.xy);
    if (color.a == 0) {
        discard;
    }
    outColor = color;
    // outColor = vec4(1.0, 0.0, 0.0, 1.0);
}
