package main

import "core:fmt"
import rl "vendor:raylib"

GlobalLayout :: struct {
	screen:        rl.Rectangle,
	picker:        rl.Rectangle,
	bar:           rl.Rectangle,
	play_button:   rl.Rectangle,
	reload_button: rl.Rectangle,
	cursor_button: rl.Rectangle,
	mute_button:   rl.Rectangle,
	input_text:    rl.Rectangle,
}


GetGlobalLayout :: proc() -> GlobalLayout {
	width := f32(rl.GetScreenWidth())
	height := f32(rl.GetScreenHeight())
	bar_height: f32 = 50.
	dropper_height: f32 = 50.
	button_buffer: f32 = 5.
	button_width: f32 = 70.
	min_space := min(height - bar_height - dropper_height, width)
	main_wh := f32(256 * (int(min_space) / 256))


	main := rl.Rectangle {
		(width - main_wh) / 2,
		(height - bar_height - dropper_height - main_wh) / 2 + dropper_height,
		main_wh,
		main_wh,
	}
	side_picker := rl.Rectangle{0, 0, width, dropper_height}
	bar := rl.Rectangle{0, height - bar_height, width, bar_height}
	play := rl.Rectangle {
		bar.x + button_buffer,
		bar.y + button_buffer,
		button_width,
		bar.height - 2 * button_buffer,
	}
	reload := rl.Rectangle {
		play.x + play.width + 2 * button_buffer,
		play.y,
		button_width,
		play.height,
	}
	cursor := rl.Rectangle {
		reload.x + +play.width + 2 * button_buffer,
		play.y,
		button_width,
		play.height,
	}
	mute := rl.Rectangle {
		cursor.x + play.width + 2 * button_buffer,
		play.y,
		button_width,
		play.height,
	}
	input := rl.Rectangle {
		mute.x + play.width + 4 * button_buffer + width - 950,
		play.y,
		button_width * 3,
		play.height,
	}

	return GlobalLayout{main, side_picker, bar, play, reload, cursor, mute, input}

}

DrawMainTexture :: proc(dp: DrawPipeline, layout: GlobalLayout) {
	rl.DrawTextureEx(
		dp.texture,
		{layout.screen.x, layout.screen.y},
		0,
		layout.screen.width / 256,
		rl.WHITE,
	)
}

MouseInMainScreen :: proc(layout: GlobalLayout) -> bool {

	mp := rl.GetMousePosition()
	wh := layout.screen.width
	posX := layout.screen.x
	posY := layout.screen.y

	return !(mp.x < posX || mp.x >= (posX + wh) || mp.y < posY || mp.y >= (posY + wh))
}

HandleButtons :: proc(
	layout: GlobalLayout,
	pause: ^bool,
	reload: ^bool,
	cursor: ^bool,
	sm: ^SoundManager,
	mute: ^bool,
) {
	toggle_pause: bool = false
	if pause^ {
		toggle_pause = rl.GuiButton(layout.play_button, "play")
	} else {
		toggle_pause = rl.GuiButton(layout.play_button, "pause")
	}
	if toggle_pause || rl.IsKeyPressed(rl.KeyboardKey.P) {
		if pause^ {
			ResumeSound(sm)
		} else {
			PauseSound(sm)
		}
		pause^ = !pause^
	}
	if rl.GuiButton(layout.reload_button, "reload") || rl.IsKeyPressed(rl.KeyboardKey.R) {
		reload^ = true
	}
	_ = rl.GuiToggle(layout.cursor_button, "cursor", cursor)
	_ = rl.GuiToggle(layout.mute_button, "mute", mute)
	SetVolume(sm, mute^)

}

DrawBarLine :: proc(layout: GlobalLayout, event: EngineEvent, input: [2]u16, i_count: int) {

	i_text := cstring("")
	if event == .SyncTimeout {
		i_text = cstring("OVER")
	} else {
		i_text = fmt.ctprintf("%06d", i_count)
	}
	bartext := fmt.ctprintf(
		"mx: %03d my: %03d mc: %05d kc: %03d     instructions: %s",
		input[0] - (input[0] / 256) * 256,
		input[0] / 256,
		input[0],
		input[1],
		i_text,
	)
	rl.DrawText(
		bartext,
		i32(layout.input_text.x),
		i32(layout.input_text.y + layout.input_text.height / 4),
		20,
		rl.WHITE,
	)
}

SetGuiProps :: proc() {
	focused_bright := i32(rl.ColorToInt(rl.WHITE))
	focused_dark := i32(rl.ColorToInt(rl.Color{122, 10, 111, 255}))

	rl.GuiSetStyle(rl.GuiControl.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), 20)
	rl.GuiSetStyle(
		rl.GuiControl.DEFAULT,
		i32(rl.GuiControlProperty.BASE_COLOR_FOCUSED),
		focused_dark,
	)
	rl.GuiSetStyle(
		rl.GuiControl.DEFAULT,
		i32(rl.GuiControlProperty.BORDER_COLOR_FOCUSED),
		focused_dark,
	)
	rl.GuiSetStyle(
		rl.GuiControl.DEFAULT,
		i32(rl.GuiControlProperty.TEXT_COLOR_FOCUSED),
		focused_bright,
	)
	rl.GuiSetStyle(
		rl.GuiControl.DEFAULT,
		i32(rl.GuiControlProperty.TEXT_COLOR_PRESSED),
		focused_bright,
	)
	rl.GuiSetStyle(
		rl.GuiControl.DEFAULT,
		i32(rl.GuiControlProperty.BASE_COLOR_PRESSED),
		focused_dark,
	)
	rl.GuiSetStyle(
		rl.GuiControl.DEFAULT,
		i32(rl.GuiControlProperty.BORDER_COLOR_PRESSED),
		focused_dark,
	)
	rl.SetWindowMinSize(1000, 1000)
}

DrawError :: proc(layout: GlobalLayout, event: EngineEvent, frame: int) {
	rl.DrawRectangleRec(layout.screen, rl.RED)
	msg: cstring
	er: cstring
	if event == .DivByZero {
		er = "Division by zero"
	} else if event == .InvalidOpCode {

		er = "Invalid Instruction"
	}
	msg = fmt.ctprintf("Error\nOn frame: %d\n%s", frame, er)
	rl.DrawText(msg, 200, 250, 40, rl.WHITE)
}

