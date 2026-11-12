extends RefCounted
## 自动钓鱼状态机。只靠传入的时间戳推进，不看帧数。
## 每次 advance 最多走一步，所以电脑睡眠醒来不会"补钓"一大堆鱼。

enum State { IDLE, CASTING, WAITING, HOOKED, REELING, SETTLEMENT, PAUSED }

var state: int = State.IDLE
var state_start_ms: int = 0
var deadline_ms: int = 0
var wait_multiplier: float = 1.0
var hooked_fish: String = ""

var _cfg: Dictionary
var _fish: Array
var _rng: RandomNumberGenerator
var _total_weight: float = 0.0

func _init(cfg: Dictionary, fish_table: Array, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_fish = fish_table
	_rng = rng
	for f in _fish:
		_total_weight += float(f["weight"])

func is_active() -> bool:
	return state != State.IDLE and state != State.PAUSED

func start(now_ms: int) -> void:
	if not is_active():
		_enter(State.CASTING, now_ms, int(_cfg["cast_ms"]))

func stop(now_ms: int) -> void:
	hooked_fish = ""
	_enter(State.IDLE, now_ms, 0)

## 0..1，当前状态的进度，给动画用。
func progress(now_ms: int) -> float:
	var span := deadline_ms - state_start_ms
	if span <= 0:
		return 0.0
	return clampf(float(now_ms - state_start_ms) / float(span), 0.0, 1.0)

## 推进状态机。返回本次产生的鱼 id（没有则为空字符串）。
func advance(now_ms: int) -> String:
	if not is_active() or now_ms < deadline_ms:
		return ""
	match state:
		State.CASTING:
			var lo := float(_cfg["bite_min_ms"])
			var hi := float(_cfg["bite_max_ms"])
			_enter(State.WAITING, now_ms, int(_rng.randf_range(lo, hi) * wait_multiplier))
		State.WAITING:
			hooked_fish = _roll_fish()
			_enter(State.HOOKED, now_ms, int(_cfg["hooked_ms"]))
		State.HOOKED:
			_enter(State.REELING, now_ms, int(_cfg["reel_ms"]))
		State.REELING:
			_enter(State.SETTLEMENT, now_ms, int(_cfg["settle_ms"]))
			return hooked_fish
		State.SETTLEMENT:
			hooked_fish = ""
			_enter(State.CASTING, now_ms, int(_cfg["cast_ms"]))
	return ""

func _enter(s: int, now_ms: int, duration_ms: int) -> void:
	state = s
	state_start_ms = now_ms
	deadline_ms = now_ms + duration_ms

func _roll_fish() -> String:
	var r := _rng.randf() * _total_weight
	for f in _fish:
		r -= float(f["weight"])
		if r < 0.0:
			return f["id"]
	return _fish[-1]["id"]
