# Install glslang
# Mac: brew install glslang
# Arch: yay -Sy glslang
mkdir -p ./shaders/compiled
glslang ./shaders/simple.frag.glsl -V -o ./shaders/compiled/simple.frag.spv
glslang ./shaders/simple.vert.glsl -V -o ./shaders/compiled/simple.vert.spv
