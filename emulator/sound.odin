package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"


SOUND_BUFFERS :: 123
SoundBuffer :: [MAXMEM]i16

SoundManager :: struct {
	streams: ^[SOUND_BUFFERS]rl.AudioStream,
}

InitSoundManager :: proc() -> SoundManager {
	rl.SetAudioStreamBufferSizeDefault(2 * MAXMEM)
	buffers := new([SOUND_BUFFERS]rl.AudioStream)
	for b in 0 ..< SOUND_BUFFERS {
		buffers[b] = rl.LoadAudioStream(16000, 16, 1)
	}
	return SoundManager{buffers}
}
FreeSoundManager :: proc(sm: SoundManager) {
	for b in 0 ..< SOUND_BUFFERS {
		rl.UnloadAudioStream(sm.streams[b])
	}
	free(sm.streams)
}

TriggerSound :: proc(sm: ^SoundManager, soundbuf: ^Buffer, frame: int) {
	if SoundBufferEmpty(soundbuf) {
		return
	}
	stream := sm.streams[frame % SOUND_BUFFERS]
	rl.UpdateAudioStream(stream, soundbuf, MAXMEM * 1)
	rl.PlayAudioStream(stream)
	rl.SetAudioStreamVolume(stream, 1.0)
}

PauseSound :: proc(sm: ^SoundManager) {
	for s in sm.streams {
		rl.PauseAudioStream(s)
	}
}
ResumeSound :: proc(sm: ^SoundManager) {
	for s in sm.streams {
		rl.ResumeAudioStream(s)
	}
}
SetVolume :: proc(sm: ^SoundManager, m: bool) {
	for s in sm.streams {
		if m {
			rl.SetAudioStreamVolume(s, 0.0)
		} else {
			rl.SetAudioStreamVolume(s, 1.0)}
	}
}


SoundBufferEmpty :: proc(b: ^Buffer) -> bool {
	for i in 0 ..< MAXMEM {
		if b[i] != 0 {
			return false
		}
	}
	return true
}

