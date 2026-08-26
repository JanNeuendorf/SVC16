#+build !js
package game

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

@(private = "file")
loaded_file_path: string

set_loaded_file_path :: proc(name: cstring) {
	if name != nil {
		delete(loaded_file_path)
		loaded_file_path = strings.clone_from_cstring(name)
	}
}

reload_rom_from_disk_if_available :: proc() {
	if len(loaded_file_path) > 0 {
		if file_data, err := os.read_entire_file(loaded_file_path, context.allocator); err == nil {
			defer delete(file_data)
			mem.zero_slice(uploaded_data.buffer)
			copy_len := min(len(file_data), len(uploaded_data.buffer))
			mem.copy(raw_data(uploaded_data.buffer), raw_data(file_data), copy_len)
		} else {
			fmt.eprintfln("Failed to reload file '%s': %v", loaded_file_path, err)
		}
	}
}

cleanup_loaded_file_path :: proc() {
	delete(loaded_file_path)
}
