package game

DEBUG_LEN :: 22
DEBUG_LOG_MAX :: 128

DebugBuffer :: struct {
	len:       int,
	content:   [DEBUG_LEN][3]u16,
	limit_hit: bool,
}

DebugLogEntry :: struct {
	frame: int,
	msg:   [3]u16,
}

DebugLog :: struct {
	entries: [DEBUG_LOG_MAX]DebugLogEntry,
	head:    int,
	count:   int,
}

AddDebugMessage :: proc(db: ^DebugBuffer, msg: [3]u16) {
	if db == nil do return
	if db.len >= DEBUG_LEN {
		db.limit_hit = true
		return
	}
	db.content[db.len] = msg
	db.len += 1
}

AddDebugLogMessage :: proc(log: ^DebugLog, frame: int, msg: [3]u16) {
	if log == nil do return
	idx := log.head
	log.entries[idx] = DebugLogEntry{frame, msg}
	log.head = (idx + 1) % DEBUG_LOG_MAX
	if log.count < DEBUG_LOG_MAX {
		log.count += 1
	}
}

ResetDebugLog :: proc(log: ^DebugLog) {
	if log == nil do return
	log.head = 0
	log.count = 0
}
