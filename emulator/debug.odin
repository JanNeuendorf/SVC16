package main
import "core:fmt"
import rl "vendor:raylib"

DEBUG_LEN :: 22

DebugBuffer :: struct {
	len:       int,
	content:   [DEBUG_LEN][3]u16,
	limit_hit: bool,
}

AddDebugMessage :: proc(db: ^DebugBuffer, msg: [3]u16) {
	if db.len >= DEBUG_LEN {
		db.limit_hit = true
		return
	}
	db.content[db.len] = msg
	db.len += 1
}

DrawDebugMode :: proc(db: ^DebugBuffer, layout: GlobalLayout, frame: int) {
	spacing: i32 = 10
	fontsize: i32 = 20
	color := rl.GREEN
	x: i32 = i32(layout.screen.x) + spacing
	rl.DrawRectangleRec(layout.screen, rl.BLACK)
	line := fmt.ctprintf("-- Frame: %d --", frame)
	rl.DrawText(line, x, i32(layout.screen.y) + spacing, fontsize, color)
	for i in i32(0) ..< i32(db.len) {
		msg := db.content[i]
		y: i32 = i32(layout.screen.y) + (i + 1) * (spacing + fontsize) + spacing
		line := fmt.ctprintf("code: %d  values: %d , %d", msg[0], msg[1], msg[2])
		rl.DrawText(line, x, y, fontsize, color)

	}
	if db.limit_hit {
		y: i32 = i32(layout.screen.y) + (DEBUG_LEN + 1) * (spacing + fontsize) + spacing
		rl.DrawText("...", x, y, fontsize, color)

	}

}

