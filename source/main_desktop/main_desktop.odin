package main_desktop

import "core:c"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"
import game ".."

main :: proc() {
	game.init()
	defer game.shutdown()

	if len(os.args) > 1 {
		rom_path := os.args[1]
		if data, err := os.read_entire_file(rom_path, context.allocator); err == nil {
			defer delete(data)
			game.load_user_file_data(raw_data(data), c.int(len(data)), fmt.ctprintf("%s", rom_path))
		} else {
			fmt.eprintfln("Error: Could not read ROM file '%s': %v", rom_path, err)
		}
	}

	for !rl.WindowShouldClose() {
		game.update()
		free_all(context.temp_allocator)
	}
}

