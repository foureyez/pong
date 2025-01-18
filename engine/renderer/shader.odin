package renderer

import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:path/filepath"
import "core:strings"

compile_shaders :: proc() {
	files, err := os.read_directory_by_path("./assets/shaders", 100, context.allocator)
	if err != nil {
		log.errorf("unable to read shaders for compilation, err: %v", err)
		return
	}

	for f, i in files {
		if strings.contains(f.fullpath, ".spv") || os.is_dir(f.fullpath) {
			continue
		}

		shader_dir_path := filepath.dir(f.fullpath)
		compiled_path := fmt.tprintf("%s/compiled/%s.spv", shader_dir_path, f.name)
		compile_cmd := os.Process_Desc {
			command = []string{"glslang", f.fullpath, "-V", "-o", compiled_path},
		}
		state, sout, serr, err := os.process_exec(compile_cmd, context.allocator)
		if err != nil {
			log.errorf("Unable to compile shaderfile: %s, err : %s", f.name, string(serr))
		}
		log.debugf("Shader Compiled: %s, out: %s", f.fullpath, compiled_path)
	}
}
