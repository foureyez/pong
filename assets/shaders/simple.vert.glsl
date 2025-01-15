#version 450

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
layout(location = 2) in vec3 normal;
layout(location = 3) in vec3 uv;
//
// layout(location = 0) out vec3 fragColor;
//
layout(set = 0, binding = 0) uniform GlobalUbo {
    mat4 projectionViewMatrix;
    vec3 directionToLight;
} ubo;

layout(location = 0) out vec3 texuv;

layout(push_constant) uniform Push {
    // mat4 transform; // projection * view * model matrix
    mat4 modelMatrix;
} push;

// const vec3 DIR_TO_LIGHT = normalize(vec3(1.0, -3.0, -1.0));
// const float AMBIENT = 0.1;

vec4 vertices[6] = {
        // Bottom left
        vec4(-0.5, 0.5, 0.0, 1.0),
        // Top left
        vec4(-0.5, -0.5, 0.0, 0.0),
        // Top right
        vec4(0.5, -0.5, 1.0, 0.0),

        // Top right
        vec4(0.5, -0.5, 1.0, 0.0),
        // Bottom right
        vec4(0.5, 0.5, 1.0, 1.0),
        // Bottom left
        vec4(-0.5, 0.5, 0.0, 1.0),
    };

void main() {
    // gl_Position = vec4(vertices[gl_VertexIndex].xy, 0.0, 1.0);
    gl_Position = push.modelMatrix * vec4(position, 1.0);
    texuv = uv;
    // gl_Position = ubo.projectionViewMatrix * vec4(position, 1.0);
    // vec3 normalWorldSpace = normalize(normal);
    // float lightIntensity = max(dot(normalWorldSpace, DIR_TO_LIGHT), 0);
    // fragColor = AMBIENT + lightIntensity * vec3(1, 1, 1);
}
