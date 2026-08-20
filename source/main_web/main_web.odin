// Adapted from Karl Zylinski's odin-raylib-web template (https://github.com/karl-zylinski/odin-raylib-web).
// Web entry point - these procs are called from index_template.html via JavaScript.

package main_web

import "base:runtime"
import "core:mem"
import game ".."

@(private = "file")
web_context: runtime.Context

@(export)
main_start :: proc "c" () {
	context = runtime.default_context()

	// The WASM allocator doesn't work properly with emscripten.
	// Use emscripten's malloc instead.
	context.allocator = emscripten_allocator()
	runtime.init_global_temporary_allocator(1 * mem.Megabyte)

	context.logger = create_emscripten_logger()

	web_context = context

	game.init()
}

@(export)
main_update :: proc "c" () -> bool {
	context = web_context
	game.update()
	free_all(context.temp_allocator)
	return true
}

@(export)
main_end :: proc "c" () {
	context = web_context
	game.shutdown()
}

@(export)
set_gamepad_connected :: proc "c" (connected: bool) {
	game.gamepad_connected = connected
}
