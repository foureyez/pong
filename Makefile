build:
	odin build . -debug -collection:deps=deps -collection:engine=engine -o:none

run:
	odin run . -collection:deps=deps -collection:engine=engine

shaders:
	./compile_shaders.sh

update_deps:
	git subtree pull --prefix deps/imgui https://gitlab.com/L-4/odin-imgui.git main --squash 
	git subtree pull --prefix deps/vma https://github.com/DanielGavin/odin-vma.git master --squash 
