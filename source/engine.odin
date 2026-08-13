package game

import "core:mem"
MAXINST :: 3000000
MAXMEM :: 65536
Buffer :: [MAXMEM]u16


OpCode :: enum (u16) {
	Set   = 0,
	GoTo  = 1,
	Skip  = 2,
	Add   = 3,
	Sub   = 4,
	Mul   = 5,
	Div   = 6,
	Cmp   = 7,
	Deref = 8,
	Ref   = 9,
	Debug = 10,
	Print = 11,
	Read  = 12,
	Band  = 13,
	Xor   = 14,
	Sync  = 15,
}

EngineEvent :: enum {
	nil,
	DivByZero,
	InvalidOpCode,
	SyncBare,
	SyncSound,
	Debug,
	SyncTimeout,
}


Engine :: struct {
	i_pointer:       u16,
	main_buffer:     ^Buffer,
	screen_buffer:   ^Buffer,
	sound_buffer:    ^Buffer,
	overdraw_buffer: ^Buffer,
	debug_output:    [3]u16,
	input:           [2]u16,
}

CreateEngine :: proc() -> Engine {
	return Engine {
		i_pointer = 0,
		main_buffer = new(Buffer),
		screen_buffer = new(Buffer),
		sound_buffer = new(Buffer),
		overdraw_buffer = new(Buffer),
		debug_output = {0, 0, 0},
		input = {0, 0},
	}


}
DestroyEngine :: proc(e: ^Engine) {
	free(e.screen_buffer)
	free(e.main_buffer)
	free(e.sound_buffer)
	free(e.overdraw_buffer)
}

AddRomFromBufferAndReset :: proc(engine: ^Engine, data: []u8) {
	mem.zero(engine.main_buffer, size_of(Buffer))

	bytes_to_read := min(len(data), MAXMEM * 2)
	words_to_read := bytes_to_read / 2

	for i in 0 ..< words_to_read {
		a := data[2 * i]
		b := data[2 * i + 1]
		engine.main_buffer[i] = u16(a) | (u16(b) << 8)
	}

	if bytes_to_read < MAXMEM * 2 && len(data) % 2 != 0 {
		a := data[2 * words_to_read]
		engine.main_buffer[words_to_read] = u16(a)
	}

	mem.zero(engine.screen_buffer, size_of(Buffer))
	mem.zero(engine.sound_buffer, size_of(Buffer))
	mem.zero(engine.overdraw_buffer, size_of(Buffer))
	engine.input = {0, 0}
	engine.i_pointer = 0
}


StepEngineFrame :: proc(
	engine: ^Engine,
	input: [2]u16,
	debug_buffer: ^DebugBuffer,
) -> (
	EngineEvent,
	int,
) {
	i_counter: int = 0
	engine.input = input
	for i := 0; i < MAXMEM; i += 1 {
		engine.overdraw_buffer[i] = 0
	}
	for {
		i_counter += 1
		switch StepEngine(engine) {
		case .nil:
			{}
		case .DivByZero:
			return .DivByZero, i_counter
		case .InvalidOpCode:
			return .InvalidOpCode, i_counter
		case .Debug:
			AddDebugMessage(debug_buffer, engine.debug_output)
		case .SyncBare:
			return .SyncBare, i_counter
		case .SyncSound:
			return .SyncSound, i_counter
		case .SyncTimeout:
			unreachable()

		}
		if i_counter == MAXINST {
			return .SyncTimeout, i_counter

		}

	}


}


StepEngine :: proc(engine: ^Engine) -> EngineEvent {
	if engine.main_buffer[engine.i_pointer] > 15 {
		return EngineEvent.InvalidOpCode

	}
	mb := engine.main_buffer
	opcode := OpCode(engine.main_buffer[engine.i_pointer])
	arg1 := mb[engine.i_pointer + u16(1)]
	arg2 := mb[engine.i_pointer + u16(2)]
	arg3 := mb[engine.i_pointer + u16(3)]
	switch opcode {
	case .Set:
		{
			if arg3 != 0 {
				mb[arg1] = engine.i_pointer
			} else {
				mb[arg1] = arg2
			}
			engine.i_pointer += 4

		}
	case .GoTo:
		{
			if mb[arg3] == 0 {
				engine.i_pointer = mb[arg1] + arg2
			} else {
				engine.i_pointer += 4
			}
		}
	case .Skip:
		{
			if mb[arg3] == 0 {
				engine.i_pointer += 4 * arg1 - 4 * arg2
			} else {
				engine.i_pointer += 4
			}

		}
	case .Add:
		{
			mb[arg3] = mb[arg1] + mb[arg2]
			engine.i_pointer += 4
		}
	case .Sub:
		{
			mb[arg3] = mb[arg1] - mb[arg2]
			engine.i_pointer += 4
		}
	case .Mul:
		{
			mb[arg3] = mb[arg1] * mb[arg2]
			engine.i_pointer += 4
		}
	case .Div:
		{
			if mb[arg2] == 0 {
				return EngineEvent.DivByZero
			}
			mb[arg3] = mb[arg1] / mb[arg2]
			engine.i_pointer += 4
		}
	case .Cmp:
		{
			if mb[arg1] < mb[arg2] {
				mb[arg3] = 1

			} else {
				mb[arg3] = 0
			}
			engine.i_pointer += 4
		}
	case .Deref:
		{
			mb[arg2] = mb[mb[arg1] + arg3]
			engine.i_pointer += 4
		}
	case .Ref:
		{
			mb[mb[arg1] + arg3] = mb[arg2]
			engine.i_pointer += 4

		}
	case .Debug:
		{
			engine.debug_output = [3]u16{arg1, mb[arg2], mb[arg3]}
			engine.i_pointer += 4
			return EngineEvent.Debug

		}
	case .Print:
		{
			b: ^Buffer = nil
			if arg3 == 0 {
				b = engine.screen_buffer
				b[mb[arg2]] = mb[arg1]
				engine.overdraw_buffer[mb[arg2]] += 1
			} else {
				b = engine.sound_buffer
				b[mb[arg2]] = mb[arg1]
			}
			engine.i_pointer += 4

		}
	case .Read:
		{
			b: ^Buffer = nil
			if arg3 == 0 {
				b = engine.screen_buffer
			} else {
				b = engine.sound_buffer
			}
			mb[arg2] = b[mb[arg1]]
			engine.i_pointer += 4

		}
	case .Band:
		{
			mb[arg3] = mb[arg1] & mb[arg2]
			engine.i_pointer += 4
		}
	case .Xor:
		{
			mb[arg3] = mb[arg1] ~ mb[arg2]
			engine.i_pointer += 4
		}
	case .Sync:
		{
			mb[arg1] = engine.input[0]
			mb[arg2] = engine.input[1]
			engine.i_pointer += 4

			if arg3 > 0 {
				return EngineEvent.SyncSound
			} else {

				return EngineEvent.SyncBare
			}
		}}


	return nil


}
