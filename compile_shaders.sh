# Install glslang
# Mac: brew install glslang
# Arch: yay -Sy glslang
mkdir -p ./assets/shaders/compiled
glslang ./assets/shaders/simple.frag.glsl -V -o ./assets/shaders/compiled/simple.frag.spv
glslang ./assets/shaders/simple.vert.glsl -V -o ./assets/shaders/compiled/simple.vert.spv
