package renderer

import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:strings"

compile_shaders :: proc(root_dir: string) {
	defer free_all(context.temp_allocator)

	files, err := os.read_directory_by_path(root_dir, 100, context.temp_allocator)
	if err != nil {
		log.errorf("Unable to list shaders for compilation, err: %v", err)
		return
	}

	for f, i in files {
		// Skip compiled shaders folder
		if os.is_dir(f.fullpath) {
			continue
		}

		compiled_path := fmt.tprintf("%s/compiled/%s.spv", filepath.dir(f.fullpath), f.name)
		compile_cmd := os.Process_Desc {
			command = []string{"glslang", f.fullpath, "-V", "-o", compiled_path},
		}
		state, sout, serr, err := os.process_exec(compile_cmd, context.temp_allocator)
		if err != nil {
			log.fatalf("Unable to compile shaderfile: %s, err : %s", f.name, string(serr))
		}
		log.debugf("Shader Compiled, out: %s", compiled_path)
	}
}
