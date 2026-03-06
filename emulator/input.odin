package main
import "core:fmt"
import rl "vendor:raylib"

//ToDo Gamepad input
GetInputCode :: proc(posX, posY, wh: f32) -> [2]u16 {
	key_code: u16 = 0
	if rl.IsKeyDown(rl.KeyboardKey.SPACE) {
		key_code += 1
	}
	if rl.IsKeyDown(rl.KeyboardKey.B) {
		key_code += 2
	}
	if rl.IsKeyDown(rl.KeyboardKey.W) | rl.IsKeyDown(rl.KeyboardKey.UP) {
		key_code += 4
	}
	if rl.IsKeyDown(rl.KeyboardKey.S) | rl.IsKeyDown(rl.KeyboardKey.DOWN) {
		key_code += 8
	}
	if rl.IsKeyDown(rl.KeyboardKey.A) | rl.IsKeyDown(rl.KeyboardKey.LEFT) {
		key_code += 16
	}
	if rl.IsKeyDown(rl.KeyboardKey.D) | rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
		key_code += 32
	}
	if rl.IsKeyDown(rl.KeyboardKey.N) {
		key_code += 64
	}
	if rl.IsKeyDown(rl.KeyboardKey.M) {
		key_code += 128
	}

	mp := rl.GetMousePosition()

	mouse_code: u16 = 0
	if !(mp.x < posX || mp.x >= (posX + wh) || mp.y < posY || mp.y >= (posY + wh)) {
		mcx, mcy := u8(256. * (mp.x - posX) / wh), u8(256 * (mp.y - posY) / wh)
		mouse_code = u16(mcx) + 256 * u16(mcy)
		if rl.IsMouseButtonDown(rl.MouseButton.LEFT) && (1 & key_code == 0) {
			key_code += 1

		}
		if rl.IsMouseButtonDown(rl.MouseButton.RIGHT) && (2 & key_code == 0) {
			key_code += 2

		}

	}


	return {mouse_code, key_code}
}

