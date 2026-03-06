package main
import "core:fmt"
import "core:mem"
import "core:os"
import rl "vendor:raylib"


paused := false
error := false
reload := false
cursor := false
mute := false
frame := 0
pick: i32 = 0
edit := false
input := [2]u16{0, 0}
i_count := 0
event: EngineEvent = nil


Mode :: enum {
	Normal        = 0,
	Overdraw      = 1,
	SoundAsScreen = 2,
	MemoryView    = 3,
	Debug         = 4,
}


main :: proc() {
	flag := rl.ConfigFlag.WINDOW_RESIZABLE
	rl.SetConfigFlags(rl.ConfigFlags{flag})
	rl.InitWindow(1000, 1000, "SVC16")
	SetGuiProps()
	defer rl.CloseWindow()
	rl.SetTargetFPS(30)

	filename: string
	if len(os.args) > 1 {
		filename = os.args[1]

	} else {
		for {
			rl.BeginDrawing()
			rl.ClearBackground(rl.LIGHTGRAY)
			rl.DrawText("Drop ROM Here!", 150, 150, 80, rl.BLACK)

			if rl.IsFileDropped() {
				filename = string(rl.LoadDroppedFiles().paths[0])
				break
			}
			if rl.WindowShouldClose() {
				rl.CloseWindow()
				os.exit(0)
			}
			rl.EndDrawing()
		}
	}

	e := CreateEngine()
	defer DestroyEngine(&e)
	AddRomFromFileAndReset(&e, filename)
	debug_buffer := DebugBuffer{}
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	sound_manager := InitSoundManager()
	defer FreeSoundManager(sound_manager)
	dp := InitDrawPipeline()
	defer FreeDrawPipeline(&dp)

	for !rl.WindowShouldClose() {
		layout := GetGlobalLayout()
		if reload {
			AddRomFromFileAndReset(&e, filename)
			reload = false
			paused = false
			error = false
			FreeSoundManager(sound_manager)
			sound_manager = InitSoundManager()
			frame = 0
		}
		if !cursor && Mode(pick) == .Normal && MouseInMainScreen(layout) && !paused && !edit {
			rl.HideCursor()
		} else {
			rl.ShowCursor()
		}

		if !paused && !error {
			debug_buffer = DebugBuffer{}
			input = GetInputCode(layout.screen.x, layout.screen.y, layout.screen.width)
			event, i_count = StepEngineFrame(&e, input, &debug_buffer)
			frame += 1
		}

		if event == .DivByZero || event == .InvalidOpCode {
			error = true
			paused = true

		}
		if event == .SyncSound {
			TriggerSound(&sound_manager, e.sound_buffer, frame)
			mem.zero(e.sound_buffer, 2 * MAXMEM)

		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		if error {
			rl.ClearBackground(rl.RED)
		} else {
			rl.ClearBackground(rl.Color{140, 150, 150, 255})
		}

		switch Mode(pick) {
		case .Normal:
			UpdateDrawPipeline(&dp, e.screen_buffer)
			DrawMainTexture(dp, layout)
		case .Overdraw:
			UpdateDrawPipeline(&dp, e.overdraw_buffer, heatmap)
			DrawMainTexture(dp, layout)
		case .SoundAsScreen:
			UpdateDrawPipeline(&dp, e.sound_buffer)
			DrawMainTexture(dp, layout)
		case .MemoryView:
			UpdateDrawPipeline(&dp, e.main_buffer, hash_u16)
			DrawMainTexture(dp, layout)
		case .Debug:
			DrawDebugMode(&debug_buffer, layout, frame)
		}

		if error {
			DrawError(layout, event, frame)
		}

		rl.DrawRectangleRec(layout.bar, rl.Color{50, 50, 50, 255})
		if rl.GuiDropdownBox(
			layout.picker,
			"Normal;Overdraw;Sound as Screen;Memory View;Debug",
			&pick,
			edit,
		) {
			edit = !edit
		}

		HandleButtons(layout, &paused, &reload, &cursor, &sound_manager, &mute)

		DrawBarLine(layout, event, input, i_count)

		if rl.GetFPS() != 30 {
			rl.DrawFPS(5, 5)
		}


	}

}

