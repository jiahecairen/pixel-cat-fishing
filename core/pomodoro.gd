extends RefCounted
## 番茄钟。状态存在 GameState.pomodoro 里（阶段、结束时刻、本轮已完成数），
## 用墙上时间的"结束时刻"而不是倒数计数器，所以不受帧率、睡眠、重启影响。

enum Phase { IDLE, FOCUS, SHORT_BREAK, LONG_BREAK }

var _p: Dictionary      # 指向 GameState.pomodoro
var _cfg: Dictionary

func _init(pomodoro_state: Dictionary, cfg: Dictionary) -> void:
	_p = pomodoro_state
	_cfg = cfg

func phase() -> int:
	return int(_p["phase"])

func cycle_done() -> int:
	return int(_p["cycle_done"])

func cycle_length() -> int:
	return int(_cfg["cycle_length"])

func is_break() -> bool:
	return phase() == Phase.SHORT_BREAK or phase() == Phase.LONG_BREAK

func remaining_ms(now_ms: int) -> int:
	if phase() == Phase.IDLE:
		return int(_cfg["focus_min"]) * 60000
	return max(0, int(_p["phase_end_ms"]) - now_ms)

func start_focus(now_ms: int) -> bool:
	if phase() == Phase.FOCUS:
		return false
	_go(Phase.FOCUS, now_ms + int(_cfg["focus_min"]) * 60000)
	return true

## 放弃当前专注，不计入完成数。
func abandon(now_ms: int) -> bool:
	if phase() != Phase.FOCUS:
		return false
	_go(Phase.IDLE, 0)
	return true

func skip_break() -> bool:
	if not is_break():
		return false
	_go(Phase.IDLE, 0)
	return true

## 推进。返回 "" / "focus_done" / "focus_done_long" / "break_done"。
func tick(now_ms: int) -> String:
	if phase() == Phase.IDLE or now_ms < int(_p["phase_end_ms"]):
		return ""
	if phase() == Phase.FOCUS:
		var done := cycle_done() + 1
		if done >= cycle_length():
			_p["cycle_done"] = 0
			_go(Phase.LONG_BREAK, now_ms + int(_cfg["long_break_min"]) * 60000)
			return "focus_done_long"
		_p["cycle_done"] = done
		_go(Phase.SHORT_BREAK, now_ms + int(_cfg["short_break_min"]) * 60000)
		return "focus_done"
	_go(Phase.IDLE, 0)
	return "break_done"

func _go(ph: int, end_ms: int) -> void:
	_p["phase"] = ph
	_p["phase_end_ms"] = end_ms
