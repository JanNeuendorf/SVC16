package game

import "core:fmt"
import "core:slice"
import rl "vendor:raylib"

PERF_HISTORY_LEN :: 120 // 4 seconds

COLOR_SCRIM :: rl.Color{16, 16, 16, 215}
COLOR_CHART_BG :: rl.Color{24, 24, 24, 235}
COLOR_BORDER :: rl.Color{80, 80, 80, 255}
COLOR_GRID :: rl.Color{55, 55, 55, 200}
COLOR_PINK :: rl.Color{210, 70, 190, 255}
COLOR_RED_LIMIT :: rl.Color{220, 60, 60, 220}

Metric :: enum {
	Instructions,
	Memory,
	DrawCalls,
}

MetricProps :: struct {
	title:     string,
	red_limit: f64,
}

METRIC_PROPS := [Metric]MetricProps {
	.Instructions = {"INSTRUCTIONS", MAXINST},
	.Memory       = {"MEMORY", 0},
	.DrawCalls    = {"DRAW CALLS", 0},
}

PerformanceTracker :: struct {
	history:      [Metric][PERF_HISTORY_LEN]int,
	timed_out:    [PERF_HISTORY_LEN]bool,
	history_idx:  int,
	history_len:  int,
	cur:          [Metric]int,
	pixels_drawn: int,
	debug_buf:    DebugBuffer,
	debug_frame:  int,
}

RecordPerformanceFrame :: proc(
	t: ^PerformanceTracker,
	i_count: int,
	main_buf, overdraw_buf: ^Buffer,
	debug: ^DebugBuffer = nil,
	frame: int = 0,
	timed_out: bool = false,
) {
	used, prints, drawn := 0, 0, 0
	for w in main_buf do if w != 0 do used += 1
	for v in overdraw_buf do if v > 0 {
		prints += int(v)
		drawn += 1
	}

	t.cur = {
		.Instructions = i_count,
		.Memory       = used,
		.DrawCalls    = prints,
	}
	t.pixels_drawn = drawn
	t.timed_out[t.history_idx] = timed_out

	if debug != nil && debug.len > 0 {
		t.debug_buf = debug^
		t.debug_frame = frame
	}

	for m in Metric do t.history[m][t.history_idx] = t.cur[m]
	t.history_idx = (t.history_idx + 1) % PERF_HISTORY_LEN
	t.history_len = min(t.history_len + 1, PERF_HISTORY_LEN)
}

compact_num :: proc(buf: []u8, val: int) -> string {
	if val >= 1_000_000 do return fmt.bprintf(buf, "%.1fM", f32(val) / 1_000_000.0)
	if val >= 1_000 do return fmt.bprintf(buf, "%.1fk", f32(val) / 1_000.0)
	return fmt.bprintf(buf, "%d", val)
}

get_metric_stat :: proc(m: Metric, t: ^PerformanceTracker) -> (stat: string, scale: f64) {
	max_val := slice.max(t.history[m][:t.history_len])
	b1, b2: [16]u8
	cur := compact_num(b1[:], t.cur[m])
	peak := compact_num(b2[:], max_val)

	#partial switch m {
	case .Instructions:
		last_idx := (t.history_idx - 1 + PERF_HISTORY_LEN) % PERF_HISTORY_LEN
		cur_label := (t.history_len > 0 && t.timed_out[last_idx]) ? "TIMEOUT" : cur
		return fmt.tprintf(
			"%s (peak %s)",
			cur_label,
			peak,
		), f64(max(MAXINST / 100, max_val * 11 / 10))
	case .Memory:
		zero_pct := (f32(MAXMEM - t.cur[m]) / f32(MAXMEM)) * 100.0
		return fmt.tprintf("%s (%.0f%% zero)", cur, zero_pct), f64(MAXMEM)
	case .DrawCalls:
		avg_od := t.pixels_drawn > 0 ? f32(t.cur[m]) / f32(t.pixels_drawn) : 0
		return fmt.tprintf("%s (%.1fx od)", cur, avg_od), f64(max(100, max_val * 11 / 10))
	}
	return "", 1.0
}

draw_text :: proc(
	font: rl.Font,
	x, y, size: f32,
	format: string,
	args: ..any,
	right_align := false,
) {
	b: [128]u8
	s := format
	if len(args) > 0 {
		s = fmt.bprintf(b[:], format, ..args)
	} else {
		copy_len := min(len(format), len(b) - 1)
		copy(b[:copy_len], format[:copy_len])
		b[copy_len] = 0
		s = string(b[:copy_len])
	}
	pos_x := right_align ? x - f32(len(s)) * (size * 0.6 + 1.0) : x
	rl.DrawTextEx(font, cstring(raw_data(b[:])), {pos_x, y}, size, 1.0, COLOR_PINK)
}

draw_box :: proc(rect: rl.Rectangle) {
	rl.DrawRectangleRec(rect, COLOR_CHART_BG)
	rl.DrawRectangleLinesEx(rect, 1.0, COLOR_BORDER)
}

draw_graph :: proc(
	rect: rl.Rectangle,
	history: []int,
	head_idx: int,
	max_y, red_limit: f64,
	timeouts: []bool = nil,
) {
	draw_box(rect)

	mid_y := rect.y + rect.height * 0.5
	rl.DrawLineEx({rect.x, mid_y}, {rect.x + rect.width, mid_y}, 1.0, COLOR_GRID)

	if red_limit > 0 && max_y >= red_limit {
		limit_y := rect.y + rect.height * (1.0 - f32(red_limit / max_y))
		rl.DrawLineEx({rect.x, limit_y}, {rect.x + rect.width, limit_y}, 1.0, COLOR_RED_LIMIT)
	}

	count := len(history)
	if count < 2 || max_y <= 0 do return

	start_idx := (head_idx - count + PERF_HISTORY_LEN) % PERF_HISTORY_LEN
	dx := rect.width / f32(count - 1)

	get_p :: proc(rect: rl.Rectangle, i: int, dx: f32, val, max_y: f64) -> rl.Vector2 {
		return {rect.x + f32(i) * dx, rect.y + rect.height * (1.0 - f32(min(1.0, val / max_y)))}
	}

	for i in 0 ..< count - 1 {
		idx1 := (start_idx + i) % PERF_HISTORY_LEN
		idx2 := (start_idx + i + 1) % PERF_HISTORY_LEN
		col := (timeouts != nil && timeouts[idx2]) ? COLOR_RED_LIMIT : COLOR_PINK
		rl.DrawLineEx(
			get_p(rect, i, dx, f64(history[idx1]), max_y),
			get_p(rect, i + 1, dx, f64(history[idx2]), max_y),
			1.8,
			col,
		)
	}
}

DrawDebugAndPerfMode :: proc(
	t: ^PerformanceTracker,
	layout: GlobalLayout,
	current_frame: int,
	font: rl.Font,
) {
	bounds := layout.screen
	S := bounds.width

	margin := S * 0.02
	pad := S * 0.012
	label_size := S * 0.02

	rl.DrawRectangleRec(bounds, COLOR_SCRIM)

	left_w := S * 0.36
	left_x := bounds.x + margin
	left_y := bounds.y + margin

	draw_text(font, left_x, left_y, label_size, "DEBUG LOG")
	draw_text(font, left_x + left_w, left_y, label_size, "F:%d", current_frame, right_align = true)

	log_bg_y := left_y + label_size + pad * 1.0
	log_bg_h := (bounds.y + S - margin) - log_bg_y
	draw_box({left_x, log_bg_y, left_w, log_bg_h})

	log_y := log_bg_y + pad * 0.6
	line_step := label_size + pad * 0.4
	if t.debug_buf.len > 0 {
		for i in 0 ..< t.debug_buf.len {
			msg := t.debug_buf.content[i]
			draw_text(
				font,
				left_x + pad * 0.5,
				log_y + f32(i) * line_step,
				label_size,
				"frame %d: %d, %d, %d",
				t.debug_frame,
				msg[0],
				msg[1],
				msg[2],
			)
		}
		if t.debug_buf.limit_hit {
			draw_text(
				font,
				left_x + pad * 0.5,
				log_y + f32(t.debug_buf.len) * line_step,
				label_size,
				"...",
			)
		}
	} else {
		draw_text(font, left_x + pad * 0.5, log_y, label_size, "(no debug events)")
	}

	right_x := left_x + left_w + margin
	right_w := S - 3 * margin - left_w
	card_gap := S * 0.016
	card_h := (S - 2 * margin - 2 * card_gap) / 3.0

	for m in Metric {
		card_y := bounds.y + margin + f32(int(m)) * (card_h + card_gap)
		props := METRIC_PROPS[m]
		stat_str, scale := get_metric_stat(m, t)

		draw_text(font, right_x, card_y, label_size, props.title)
		draw_text(font, right_x + right_w, card_y, label_size, stat_str, right_align = true)

		gy := card_y + label_size + pad * 1.3
		gh := (card_y + card_h) - gy
		timeouts := (m == .Instructions) ? t.timed_out[:t.history_len] : nil
		draw_graph(
			{right_x, gy, right_w, gh},
			t.history[m][:t.history_len],
			t.history_idx,
			scale,
			props.red_limit,
			timeouts,
		)
	}
}
