package game
import "core:slice"
import rl "vendor:raylib"

DrawPipeline :: struct {
	image:   rl.Image,
	texture: rl.Texture,
}

InitDrawPipeline :: proc() -> DrawPipeline {
	image := rl.GenImageColor(256, 256, rl.WHITE)
	pixels := slice.bytes_from_ptr(image.data, 256 * 256 * 4)
	for i in 0 ..< 256 * 256 {
		pixels[4 * i + 3] = 255
	}
	texture := rl.LoadTextureFromImage(image)
	return DrawPipeline{image, texture}
}

FreeDrawPipeline :: proc(dp: ^DrawPipeline) {
	rl.UnloadImage(dp.image)
	rl.UnloadTexture(dp.texture)
}

UpdateDrawPipeline :: proc(
	dp: ^DrawPipeline,
	screenbuffer: ^Buffer,
	converter: proc(u: u16) -> (u8, u8, u8) = rgb565_to_rgb,
) {
	pixels := slice.bytes_from_ptr(dp.image.data, 256 * 256 * 4)
	for i in 0 ..< 256 * 256 {
		r, g, b := converter(screenbuffer[i])
		pixels[4 * i] = r
		pixels[4 * i + 1] = g
		pixels[4 * i + 2] = b
	}
	rl.UpdateTexture(dp.texture, dp.image.data)

}

rgb565_to_rgb :: proc(rgb565: u16) -> (u8, u8, u8) {
	r := u8(((rgb565 >> 11) & 0x1F))
	g := u8(((rgb565 >> 5) & 0x3F))
	b := u8((rgb565 & 0x1F))
	r = (r << 3) | (r >> 2)
	g = (g << 2) | (g >> 4)
	b = (b << 3) | (b >> 2)
	return r, g, b


}

heatmap :: proc(count: u16) -> (u8, u8, u8) {
	cols := [7]rl.Color{rl.BLACK, rl.GREEN, rl.DARKGREEN, rl.YELLOW, rl.ORANGE, rl.RED, rl.VIOLET}
	c := min(count, 6)
	return cols[c].r, cols[c].g, cols[c].b


}

hash_u16 :: proc(u: u16) -> (u8, u8, u8) {
	if u == 0 {
		return 0, 0, 0
	}

	mul: u16 = 0x5B63
	xor: u16 = 0xACE1

	new := (u * mul) ~ xor
	return rgb565_to_rgb(new)
}
