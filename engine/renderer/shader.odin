package renderer

import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"

compile_shaders :: proc(root_dir: string) {
	defer free_all(context.temp_allocator)

	// TODO: move to os2 package once read_directory_by_path is implemented for linux
	dir_handle, _ := os.open(root_dir)
	files, err := os.read_dir(dir_handle, -1, context.allocator)
	if err != nil {
		log.panicf("Unable to list shaders for compilation, err: %v", err)
	}

	for f, i in files {
		// Skip compiled shaders folder
		if os2.is_dir(f.fullpath) {
			continue
		}

		compiled_path := fmt.tprintf("%s/compiled/%s.spv", filepath.dir(f.fullpath), f.name)
		compile_cmd := os2.Process_Desc {
			command = []string{"glslang", f.fullpath, "-V", "-o", compiled_path},
		}
		state, sout, serr, err := os2.process_exec(compile_cmd, context.temp_allocator)
		if err != nil {
			log.fatalf("Unable to compile shaderfile: %s, err : %s", f.name, string(serr))
		}
		log.debugf("Shader Compiled, out: %s", compiled_path)
	}
}
