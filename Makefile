build:
	odin build examples -collection:deps=deps -collection:engine=engine

check:
	odin strip-semicolon . -collection:deps=deps -collection:engine=engine
	odin check examples -collection:deps=deps -collection:engine=engine

doc:
	odin doc examples -collection:deps=deps -collection:engine=engine

run:
	odin run examples -debug -collection:deps=deps -collection:engine=engine

shaders:
	./compile_shaders.sh

update_deps:
	git subtree pull --prefix deps/imgui https://gitlab.com/L-4/odin-imgui.git main --squash 
	git subtree pull --prefix deps/vma https://github.com/DanielGavin/odin-vma.git master --squash 
