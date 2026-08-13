package game

import rl "vendor:raylib"


SOUND_BUFFERS :: 123
SoundBuffer :: [MAXMEM]i16

SoundManager :: struct {
	sounds: ^[SOUND_BUFFERS]rl.Sound,
}

InitSoundManager :: proc() -> SoundManager {
	sounds := new([SOUND_BUFFERS]rl.Sound)
	return SoundManager{sounds}
}

FreeSoundManager :: proc(sm: SoundManager) {
	for b in 0 ..< SOUND_BUFFERS {
		if sm.sounds[b].frameCount > 0 {
			rl.UnloadSound(sm.sounds[b])
		}
	}
	free(sm.sounds)
}

ResetSoundManager :: proc(sm: ^SoundManager) {
	if sm == nil || sm.sounds == nil do return
	for b in 0 ..< SOUND_BUFFERS {
		if sm.sounds[b].frameCount > 0 {
			rl.StopSound(sm.sounds[b])
			rl.UnloadSound(sm.sounds[b])
			sm.sounds[b] = {}
		}
	}
}

TriggerSound :: proc(sm: ^SoundManager, soundbuf: ^Buffer, frame: int) {
	if SoundBufferEmpty(soundbuf) {
		return
	}
	idx := frame % SOUND_BUFFERS
	if sm.sounds[idx].frameCount > 0 {
		rl.UnloadSound(sm.sounds[idx])
	}

	wave := rl.Wave {
		frameCount = u32(MAXMEM),
		sampleRate = 16000,
		sampleSize = 16,
		channels   = 1,
		data       = raw_data(soundbuf),
	}

	sm.sounds[idx] = rl.LoadSoundFromWave(wave)
	rl.SetSoundVolume(sm.sounds[idx], 1.0)
	rl.PlaySound(sm.sounds[idx])
}

PauseSound :: proc(sm: ^SoundManager) {
	for s in sm.sounds {
		if s.frameCount > 0 {
			rl.PauseSound(s)
		}
	}
}

ResumeSound :: proc(sm: ^SoundManager) {
	for s in sm.sounds {
		if s.frameCount > 0 {
			rl.ResumeSound(s)
		}
	}
}

SetVolume :: proc(sm: ^SoundManager, m: bool) {
	for s in sm.sounds {
		if s.frameCount > 0 {
			if m {
				rl.SetSoundVolume(s, 0.0)
			} else {
				rl.SetSoundVolume(s, 1.0)
			}
		}
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
