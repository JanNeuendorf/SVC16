package game

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1000
SCREEN_HEIGHT :: 1000

UploadedData :: struct {
	buffer:      []u8,
	max_size_kb: int,
}

uploaded_data: UploadedData

TEXTURE_SIZE :: 256
TARGET_FPS :: 30.
e: Engine
has_uploaded_anything: bool = false
dp: DrawPipeline
sound_manager: SoundManager
debug_buffer: DebugBuffer = {}
gamepad_connected: bool = (ODIN_OS != .JS)

paused := false
error := false
reload := false
cursor := false
mute := false
zoomed := false
frame := 0
pick: i32 = 0
edit := false
input := [2]u16{0, 0}
i_count := 0
event: EngineEvent = nil

LOGO_PNG :: #load("../assets/logo_alpha.png")
EXAMPLE :: #load("../examples/spikeavoider.svc16")
CRT_SHADER_SRC :: #load("../assets/crt.fs", string)
logo_texture: rl.Texture2D
crt_shader: rl.Shader


Mode :: enum {
	Normal        = 0,
	CRT           = 1,
	Overdraw      = 2,
	SoundAsScreen = 3,
	MemoryView    = 4,
	Debug         = 5,
}


@(export)
load_user_file_data :: proc "c" (data: [^]u8, size: c.int, name: cstring) {
	context = runtime.default_context()

	if size <= 0 || data == nil do return

	mem.zero_slice(uploaded_data.buffer)
	copy_len := min(int(size), len(uploaded_data.buffer))
	mem.copy(raw_data(uploaded_data.buffer), data, copy_len)
	AddRomFromBufferAndReset(&e, uploaded_data.buffer)
	ResetSoundManager(&sound_manager)
	has_uploaded_anything = true
	reload = false
	paused = false
	error = false
	frame = 0
	set_loaded_file_path(name)
	when ODIN_OS != .JS {
		if name != nil {
			rl.SetWindowTitle(fmt.ctprintf("SVC16 - %s", name))
		}
	}
}


init :: proc() {
	rl.SetTraceLogLevel(.NONE)
	rl.InitAudioDevice()
	when ODIN_OS != .JS {
		rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
		rl.SetTargetFPS(i32(TARGET_FPS))
	} else {
		rl.SetConfigFlags({.VSYNC_HINT})
	}
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "SVC16")
	e = CreateEngine()

	logo_img := rl.LoadImageFromMemory(".png", raw_data(LOGO_PNG), i32(len(LOGO_PNG)))
	when ODIN_OS != .JS {
		rl.SetWindowIcon(logo_img)
		MAPPINGS: string : "03000000d62000000128000000000000,BDA Xbox ONE Enhanced Controller,platform:Linux,a:b0,b:b1,x:b2,y:b3,back:b6,start:b7,guide:b8,leftstick:b9,rightstick:b10,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,\n03000000d62000000128000000010000,BDA Xbox ONE Enhanced Controller,platform:Linux,a:b0,b:b1,x:b2,y:b3,back:b6,start:b7,guide:b8,leftstick:b9,rightstick:b10,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,\n03000000d62000000128000001010000,BDA Xbox ONE Enhanced Controller,platform:Linux,a:b0,b:b1,x:b2,y:b3,back:b6,start:b7,guide:b8,leftstick:b9,rightstick:b10,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,\n03000000d62000000128000010010000,BDA Xbox ONE Enhanced Controller,platform:Linux,a:b0,b:b1,x:b2,y:b3,back:b6,start:b7,guide:b8,leftstick:b9,rightstick:b10,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,\n03000000d62000000128000011010000,BDA Xbox ONE Enhanced Controller,platform:Linux,a:b0,b:b1,x:b2,y:b3,back:b6,start:b7,guide:b8,leftstick:b9,rightstick:b10,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,\n\x00"
		rl.SetGamepadMappings(cstring(raw_data(MAPPINGS)))
	}
	logo_texture = rl.LoadTextureFromImage(logo_img)
	rl.UnloadImage(logo_img)

	uploaded_data.max_size_kb = 256 // Safety margin if different formats might be supported
	uploaded_data.buffer = make([]u8, uploaded_data.max_size_kb * 1024)

	sound_manager = InitSoundManager()
	dp = InitDrawPipeline()
	crt_shader = rl.LoadShaderFromMemory(nil, fmt.ctprintf("%s\x00", CRT_SHADER_SRC))
	SetGuiProps()
}

last_frame_timestamp: f64 = 0
measured_fps: i32 = 0

update :: proc() {
	start_time := rl.GetTime()
	if last_frame_timestamp > 0 {
		delta := start_time - last_frame_timestamp
		if delta > 0 {
			measured_fps = i32(math.round(1.0 / delta))
		}
	}
	last_frame_timestamp = start_time

	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.BLACK)
	if !has_uploaded_anything {
		start_triggered := rl.IsMouseButtonPressed(.LEFT) || rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER)
		when ODIN_OS != .JS {
			for pad in i32(0) ..< 4 {
				if rl.IsGamepadAvailable(pad) {
					if rl.IsGamepadButtonPressed(pad, .RIGHT_FACE_DOWN) ||
					   rl.IsGamepadButtonPressed(pad, .RIGHT_FACE_RIGHT) ||
					   rl.IsGamepadButtonPressed(pad, .MIDDLE_RIGHT) {
						start_triggered = true
						break
					}
				}
			}
		}
		if start_triggered {
			AddRomFromBufferAndReset(&e, EXAMPLE)
			copy(uploaded_data.buffer, EXAMPLE)
			has_uploaded_anything = true
			when ODIN_OS != .JS {
				rl.SetWindowTitle("SVC16 - spikeavoider.svc16")
			}
		}
		DrawStartupAnimation()
		return
	}
	// Now the real loop
	if rl.IsKeyPressed(.Z) || rl.IsKeyPressed(.Y) {
		zoomed = !zoomed
	}
	layout := GetGlobalLayout(zoomed)
	if reload {
		reload_rom_from_disk_if_available()
		AddRomFromBufferAndReset(&e, uploaded_data.buffer)
		reload = false
		paused = false
		error = false
		// FreeSoundManager(sound_manager)
		// sound_manager = InitSoundManager()
		ResetSoundManager(&sound_manager)
		frame = 0
	}

	if !cursor &&
	   (Mode(pick) == .Normal || Mode(pick) == .CRT) &&
	   MouseInMainScreen(layout) &&
	   !paused &&
	   !edit {
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

	if error {
		rl.ClearBackground(rl.RED)
	} else {
		rl.ClearBackground(rl.Color{140, 150, 150, 255})
	}

	switch Mode(pick) {
	case .Normal:
		UpdateDrawPipeline(&dp, e.screen_buffer)
		DrawMainTexture(dp, layout)
	case .CRT:
		UpdateDrawPipeline(&dp, e.screen_buffer)
		rl.SetTextureFilter(dp.texture, .BILINEAR)
		DrawMainTexture(dp, layout, crt_shader)
		rl.SetTextureFilter(dp.texture, .POINT)
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
		"Normal;Normal (CRT);Overdraw;Sound as Screen;Memory View;Debug",
		&pick,
		edit,
	) {
		edit = !edit
	}
	// This is very fragile. When zoomed is true, the buttons have no size
	HandleButtons(layout, &paused, &reload, &cursor, &sound_manager, &mute)

	if !layout.zoomed {
		DrawBarLine(layout, event, input, i_count)
		fps_color: rl.Color = measured_fps > 27 ? rl.LIME : rl.RED
		fps_text := fmt.ctprintf("%d FPS", measured_fps)
		rl.DrawText(fps_text, 5, 5, 20, fps_color)
	}

	when ODIN_OS == .JS {
		for (rl.GetTime() - start_time) < (1.0 / TARGET_FPS - 0.0005) {}
	}
}

shutdown :: proc() {
	cleanup_loaded_file_path()
	rl.UnloadShader(crt_shader)
	delete(uploaded_data.buffer)
	rl.CloseAudioDevice()
	rl.CloseWindow()
}

DrawStartupAnimation :: proc() {
	anim_speed: f32 = 0.5
	time := f32(rl.GetTime()) * anim_speed
	t := min(1.0, time)
	scale := 0.7 * (1.0 - (1.0 - t) * (1.0 - t))
	pos := rl.Vector2 {
		200 + f32(logo_texture.width) * (0.7 - scale) * 0.5,
		200 + f32(logo_texture.height) * (0.7 - scale) * 0.5,
	}
	tint := rl.WHITE
	text_color := rl.LIGHTGRAY
	if t < 1.0 {
		tint = rl.ColorFromHSV(t * 40.0, 0.4 * (1.0 - t), 1.0)
	} else {
		s1 := math.sin(f32(rl.GetTime()) * 2.7)
		s2 := math.sin(f32(rl.GetTime()) * 7.3)
		flicker := f32(0.92 + (s1 * 0.05 + s2 * 0.03))
		tint = rl.ColorAlpha(rl.WHITE, flicker)
		text_color = rl.ColorAlpha(rl.LIGHTGRAY, flicker)
	}
	rl.DrawTextureEx(logo_texture, pos, 0.0, scale, tint)
	if time > 0.7 {
		rl.DrawText("Nothing uploaded...", 80, 880, 30, text_color)
	}
	if time > 1.4 {
		rl.DrawText("Click to play example", 80, 920, 30, text_color)
	}
}
