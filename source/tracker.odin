package game

import "core:fmt"
import rl "vendor:raylib"

PERF_HISTORY_LEN :: 120 // 4 seconds at 30 FPS

PerformanceTracker :: struct {
	instructions:    [PERF_HISTORY_LEN]int,
	zero_mem:        [PERF_HISTORY_LEN]int,
	used_mem:        [PERF_HISTORY_LEN]int,
	total_prints:    [PERF_HISTORY_LEN]int,
	pixels_drawn:    [PERF_HISTORY_LEN]int,
	max_overdraw:    [PERF_HISTORY_LEN]int,
	history_index:   int,
	history_count:   int,

	// Current snapshot values
	cur_instructions: int,
	cur_zero_mem:     int,
	cur_used_mem:     int,
	cur_prints:       int,
	cur_pixels_drawn: int,
	cur_max_overdraw: int,
}

InitPerformanceTracker :: proc() -> PerformanceTracker {
	return PerformanceTracker{}
}

// Strictly allocation-free frame recording
RecordPerformanceFrame :: proc(
	tracker: ^PerformanceTracker,
	i_count: int,
	main_buf: ^Buffer,
	overdraw_buf: ^Buffer,
) {
	if tracker == nil do return

	// 1. Memory scan (zeros vs active words)
	zero_count := 0
	if main_buf != nil {
		for i in 0 ..< MAXMEM {
			if main_buf[i] == 0 {
				zero_count += 1
			}
		}
	}
	used_count := MAXMEM - zero_count

	// 2. Overdraw buffer scan (draw calls)
	prints_sum := 0
	drawn_count := 0
	max_od := 0
	if overdraw_buf != nil {
		for i in 0 ..< MAXMEM {
			v := int(overdraw_buf[i])
			if v > 0 {
				prints_sum += v
				drawn_count += 1
				if v > max_od {
					max_od = v
				}
			}
		}
	}

	// 3. Update snapshot
	tracker.cur_instructions = i_count
	tracker.cur_zero_mem = zero_count
	tracker.cur_used_mem = used_count
	tracker.cur_prints = prints_sum
	tracker.cur_pixels_drawn = drawn_count
	tracker.cur_max_overdraw = max_od

	// 4. Update rolling history ring buffer
	idx := tracker.history_index
	tracker.instructions[idx] = i_count
	tracker.zero_mem[idx] = zero_count
	tracker.used_mem[idx] = used_count
	tracker.total_prints[idx] = prints_sum
	tracker.pixels_drawn[idx] = drawn_count
	tracker.max_overdraw[idx] = max_od

	tracker.history_index = (idx + 1) % PERF_HISTORY_LEN
	if tracker.history_count < PERF_HISTORY_LEN {
		tracker.history_count += 1
	}
}

// Statistical calculation over preallocated history
get_history_stats :: proc(data: ^[PERF_HISTORY_LEN]int, count: int, head_idx: int) -> (min_val: int, max_val: int, avg_val: int) {
	if count <= 0 do return 0, 0, 0
	min_val = max(int)
	max_val = min(int)
	sum := 0
	for i in 0 ..< count {
		val := data[i]
		if val < min_val do min_val = val
		if val > max_val do max_val = val
		sum += val
	}
	avg_val = sum / count
	return
}

// Zero-allocation stack buffer formatting helpers
fmt_compact_buf :: proc(buf: []u8, val: int) -> cstring {
	if val >= 1_000_000 {
		str := fmt.bprintf(buf, "%.1fM", f32(val) / 1_000_000.0)
		buf[len(str)] = 0
		return cstring(raw_data(buf))
	} else if val >= 1_000 {
		str := fmt.bprintf(buf, "%.1fk", f32(val) / 1_000.0)
		buf[len(str)] = 0
		return cstring(raw_data(buf))
	}
	str := fmt.bprintf(buf, "%d", val)
	buf[len(str)] = 0
	return cstring(raw_data(buf))
}

// Unified high-contrast dashboard: Persistent frame_nr: msg debug scroll on left, Performance telemetry on right
DrawDebugAndPerfMode :: proc(
	debug_log: ^DebugLog,
	tracker: ^PerformanceTracker,
	layout: GlobalLayout,
	frame: int,
	fps: i32,
	font: rl.Font,
) {
	if tracker == nil do return

	bounds := layout.screen
	margin: f32 = max(6.0, bounds.width * 0.015)
	pad: f32 = max(6.0, bounds.width * 0.014)

	// Sleek translucent theme: ~65% opacity cards for a glassy look with high legibility
	canvas_scrim := rl.Color{16, 16, 16, 145}    // ~57% opacity outer background
	card_bg := rl.Color{24, 24, 24, 165}         // ~65% opacity card background
	card_border := rl.Color{75, 75, 75, 190}     // subtle border
	chart_bg := rl.Color{18, 18, 18, 165}        // chart inner backing
	grid_color := rl.Color{55, 55, 55, 140}      // chart grid line

	magenta_accent := rl.Color{210, 70, 190, 255} // #d246be signature plum
	cyan_accent := rl.Color{95, 200, 230, 255}    // #5fc8e6 ice cyan
	amber_accent := rl.Color{245, 185, 65, 255}   // #f5b941 warm gold
	green_accent := rl.Color{74, 222, 128, 255}   // #4ade80 mint green for debug scroll
	text_bright := rl.Color{243, 244, 246, 255}   // crisp white
	text_dim := rl.Color{140, 140, 140, 255}

	// 1. Draw outer screen scrim
	rl.DrawRectangleRec(bounds, canvas_scrim)
	rl.DrawRectangleLinesEx(bounds, 1.5, card_border)

	// Font sizes
	label_size: f32 = max(11.0, min(17.0, bounds.width * 0.021))
	msg_font_size: f32 = max(11.0, min(15.5, bounds.width * 0.019))

	// Stack buffers for string formatting
	text_buf: [64]u8
	c_buf1: [32]u8
	c_buf2: [32]u8

	// =========================================================================
	// LEFT COLUMN: Debug Scroll (frame nr: msg) (37% width)
	// =========================================================================
	left_w := (bounds.width - 3 * margin) * 0.37
	left_h := bounds.height - 2 * margin
	left_rect := rl.Rectangle{bounds.x + margin, bounds.y + margin, left_w, left_h}

	rl.DrawRectangleRec(left_rect, card_bg)
	rl.DrawRectangleLinesEx(left_rect, 1.0, card_border)

	// Debug Log Title & Current Frame
	rl.DrawTextEx(font, "DEBUG LOG", rl.Vector2{left_rect.x + pad, left_rect.y + pad}, label_size, 1.0, text_bright)

	f_str := fmt.bprintf(text_buf[:], "F:%d", frame)
	text_buf[len(f_str)] = 0
	f_cstring := cstring(raw_data(text_buf[:]))
	f_dim := rl.MeasureTextEx(font, f_cstring, label_size, 1.0)
	rl.DrawTextEx(font, f_cstring, rl.Vector2{left_rect.x + left_rect.width - f_dim.x - pad, left_rect.y + pad}, label_size, 1.0, text_dim)

	// Debug Messages List (scrolling newest at bottom)
	log_y_start := left_rect.y + label_size + pad * 1.5
	line_spacing: f32 = msg_font_size + pad * 0.4
	max_visible_lines := int((left_h - (label_size + pad * 2.0)) / line_spacing)

	if debug_log != nil && debug_log.count > 0 {
		visible_count := min(debug_log.count, max_visible_lines)
		start_offset := debug_log.count - visible_count
		for i in 0 ..< visible_count {
			entry_idx := (debug_log.head - debug_log.count + start_offset + i + DEBUG_LOG_MAX) % DEBUG_LOG_MAX
			entry := debug_log.entries[entry_idx]
			
			// Format: "frame nr: msg"
			msg_str := fmt.bprintf(text_buf[:], "frame %d: %d, %d, %d", entry.frame, entry.msg[0], entry.msg[1], entry.msg[2])
			text_buf[len(msg_str)] = 0
			pos_y := log_y_start + f32(i) * line_spacing
			rl.DrawTextEx(font, cstring(raw_data(text_buf[:])), rl.Vector2{left_rect.x + pad, pos_y}, msg_font_size, 1.0, green_accent)
		}
	} else {
		rl.DrawTextEx(font, "(no debug events)", rl.Vector2{left_rect.x + pad, log_y_start}, msg_font_size, 1.0, text_dim)
	}

	// =========================================================================
	// RIGHT COLUMN: 3 Performance Telemetry Cards (63% width)
	// =========================================================================
	right_x := left_rect.x + left_rect.width + margin
	right_w := bounds.width - 3 * margin - left_w
	card_gap: f32 = margin * 0.7
	card_h := (left_h - 2 * card_gap) / 3.0

	// -------------------------------------------------------------------------
	// Card 1: Instructions Per Frame
	// -------------------------------------------------------------------------
	c1_rect := rl.Rectangle{right_x, bounds.y + margin, right_w, card_h}
	rl.DrawRectangleRec(c1_rect, card_bg)
	rl.DrawRectangleLinesEx(c1_rect, 1.0, card_border)

	rl.DrawTextEx(font, "INSTRUCTIONS", rl.Vector2{c1_rect.x + pad, c1_rect.y + pad}, label_size, 1.0, text_bright)

	_, max_inst, _ := get_history_stats(&tracker.instructions, tracker.history_count, tracker.history_index)
	cur_str := fmt_compact_buf(c_buf1[:], tracker.cur_instructions)
	peak_str := fmt_compact_buf(c_buf2[:], max_inst)
	c1_str := fmt.bprintf(text_buf[:], "%s  (peak %s)", cur_str, peak_str)
	text_buf[len(c1_str)] = 0
	c1_cstring := cstring(raw_data(text_buf[:]))

	c1_dim := rl.MeasureTextEx(font, c1_cstring, label_size, 1.0)
	rl.DrawTextEx(font, c1_cstring, rl.Vector2{c1_rect.x + c1_rect.width - c1_dim.x - pad, c1_rect.y + pad}, label_size, 1.0, magenta_accent)

	c1_graph_y := c1_rect.y + label_size + pad * 1.3
	c1_graph_h := (c1_rect.y + c1_rect.height - pad) - c1_graph_y
	c1_graph := rl.Rectangle{c1_rect.x + pad, c1_graph_y, c1_rect.width - 2 * pad, c1_graph_h}
	draw_timeseries_graph(
		c1_graph,
		&tracker.instructions,
		tracker.history_count,
		tracker.history_index,
		f64(max(MAXINST / 100, max_inst * 11 / 10)),
		magenta_accent,
		chart_bg,
		grid_color,
		true,
	)

	// -------------------------------------------------------------------------
	// Card 2: Memory (65,536 Units)
	// -------------------------------------------------------------------------
	c2_y := c1_rect.y + card_h + card_gap
	c2_rect := rl.Rectangle{right_x, c2_y, right_w, card_h}
	rl.DrawRectangleRec(c2_rect, card_bg)
	rl.DrawRectangleLinesEx(c2_rect, 1.0, card_border)

	rl.DrawTextEx(font, "MEMORY", rl.Vector2{c2_rect.x + pad, c2_rect.y + pad}, label_size, 1.0, text_bright)

	zero_pct := (f32(tracker.cur_zero_mem) / f32(MAXMEM)) * 100.0
	cur_mem_str := fmt_compact_buf(c_buf1[:], tracker.cur_used_mem)
	c2_str := fmt.bprintf(text_buf[:], "%s USED  (%.0f%% zero)", cur_mem_str, zero_pct)
	text_buf[len(c2_str)] = 0
	c2_cstring := cstring(raw_data(text_buf[:]))

	c2_dim := rl.MeasureTextEx(font, c2_cstring, label_size, 1.0)
	rl.DrawTextEx(font, c2_cstring, rl.Vector2{c2_rect.x + c2_rect.width - c2_dim.x - pad, c2_rect.y + pad}, label_size, 1.0, cyan_accent)

	// Thin gauge bar
	bar_y := c2_rect.y + label_size + pad * 1.1
	bar_h: f32 = max(3.5, card_h * 0.045)
	bar_rect := rl.Rectangle{c2_rect.x + pad, bar_y, c2_rect.width - 2 * pad, bar_h}
	rl.DrawRectangleRec(bar_rect, rl.Color{36, 36, 36, 255})
	active_bar_w := bar_rect.width * (f32(tracker.cur_used_mem) / f32(MAXMEM))
	rl.DrawRectangleRec(rl.Rectangle{bar_rect.x, bar_rect.y, active_bar_w, bar_rect.height}, cyan_accent)

	c2_graph_y := bar_rect.y + bar_rect.height + pad * 0.5
	c2_graph_h := (c2_rect.y + c2_rect.height - pad) - c2_graph_y
	c2_graph := rl.Rectangle{c2_rect.x + pad, c2_graph_y, c2_rect.width - 2 * pad, c2_graph_h}
	draw_timeseries_graph(
		c2_graph,
		&tracker.used_mem,
		tracker.history_count,
		tracker.history_index,
		f64(MAXMEM),
		cyan_accent,
		chart_bg,
		grid_color,
		false,
	)

	// -------------------------------------------------------------------------
	// Card 3: Draw Calls (Print)
	// -------------------------------------------------------------------------
	c3_y := c2_y + card_h + card_gap
	c3_rect := rl.Rectangle{right_x, c3_y, right_w, card_h}
	rl.DrawRectangleRec(c3_rect, card_bg)
	rl.DrawRectangleLinesEx(c3_rect, 1.0, card_border)

	rl.DrawTextEx(font, "DRAW CALLS", rl.Vector2{c3_rect.x + pad, c3_rect.y + pad}, label_size, 1.0, text_bright)

	avg_od: f32 = 0.0
	if tracker.cur_pixels_drawn > 0 {
		avg_od = f32(tracker.cur_prints) / f32(tracker.cur_pixels_drawn)
	}
	prints_str := fmt_compact_buf(c_buf1[:], tracker.cur_prints)
	c3_str := fmt.bprintf(text_buf[:], "%s  (%.1fx od)", prints_str, avg_od)
	text_buf[len(c3_str)] = 0
	c3_cstring := cstring(raw_data(text_buf[:]))

	c3_dim := rl.MeasureTextEx(font, c3_cstring, label_size, 1.0)
	rl.DrawTextEx(font, c3_cstring, rl.Vector2{c3_rect.x + c3_rect.width - c3_dim.x - pad, c3_rect.y + pad}, label_size, 1.0, amber_accent)

	c3_graph_y := c3_rect.y + label_size + pad * 1.3
	c3_graph_h := (c3_rect.y + c3_rect.height - pad) - c3_graph_y
	c3_graph := rl.Rectangle{c3_rect.x + pad, c3_graph_y, c3_rect.width - 2 * pad, c3_graph_h}

	_, max_prints, _ := get_history_stats(&tracker.total_prints, tracker.history_count, tracker.history_index)
	draw_timeseries_graph(
		c3_graph,
		&tracker.total_prints,
		tracker.history_count,
		tracker.history_index,
		f64(max(100, max_prints * 11 / 10)),
		amber_accent,
		chart_bg,
		grid_color,
		false,
	)
}

// High-contrast timeseries graph with opaque inner backing
draw_timeseries_graph :: proc(
	rect: rl.Rectangle,
	history: ^[PERF_HISTORY_LEN]int,
	count: int,
	head_idx: int,
	max_y: f64,
	line_color: rl.Color,
	bg_color: rl.Color,
	grid_color: rl.Color,
	draw_budget_line: bool,
) {
	if count < 2 || max_y <= 0.0 do return

	// Chart dark inner backing
	rl.DrawRectangleRec(rect, bg_color)
	rl.DrawRectangleLinesEx(rect, 1.0, grid_color)

	// Subtle horizontal grid line (50%)
	mid_y := rect.y + rect.height * 0.5
	rl.DrawLineEx(rl.Vector2{rect.x, mid_y}, rl.Vector2{rect.x + rect.width, mid_y}, 1.0, grid_color)

	// 3M limit line (if relevant)
	if draw_budget_line && max_y >= f64(MAXINST) {
		limit_y := rect.y + rect.height * (1.0 - f32(f64(MAXINST) / max_y))
		rl.DrawLineEx(rl.Vector2{rect.x, limit_y}, rl.Vector2{rect.x + rect.width, limit_y}, 1.0, rl.Color{220, 60, 60, 200})
	}

	start_idx := (head_idx - count + PERF_HISTORY_LEN) % PERF_HISTORY_LEN
	dx := rect.width / f32(max(1, count - 1))

	fill_color := rl.ColorAlpha(line_color, 0.22)

	for i in 0 ..< count - 1 {
		idx1 := (start_idx + i) % PERF_HISTORY_LEN
		idx2 := (start_idx + i + 1) % PERF_HISTORY_LEN

		v1 := f64(history[idx1])
		v2 := f64(history[idx2])

		x1 := rect.x + f32(i) * dx
		x2 := rect.x + f32(i + 1) * dx

		y1 := rect.y + rect.height * (1.0 - f32(min(1.0, v1 / max_y)))
		y2 := rect.y + rect.height * (1.0 - f32(min(1.0, v2 / max_y)))

		// Filled area
		p1 := rl.Vector2{x1, y1}
		p2 := rl.Vector2{x2, y2}
		p3 := rl.Vector2{x2, rect.y + rect.height}
		p4 := rl.Vector2{x1, rect.y + rect.height}

		rl.DrawTriangle(p1, p4, p3, fill_color)
		rl.DrawTriangle(p1, p3, p2, fill_color)

		// Line stroke
		rl.DrawLineEx(p1, p2, 1.8, line_color)
	}
}
