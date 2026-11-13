extends RefCounted
## 自动钓鱼状态机。只靠传入的时间戳推进，不看帧数。
## 每次 advance 最多走一步，所以电脑睡眠醒来不会"补钓"一大堆鱼。

enum State { IDLE, CASTING, WAITING, HOOKED, REELING, SETTLEMENT, PAUSED }

var state: int = State.IDLE
var state_start_ms: int = 0
var deadline_ms: int = 0
var wait_multiplier: float = 1.0
const CHEST := "chest"            # 钓上来的不是鱼而是宝箱时，hooked_fish 取这个值

var hooked_fish: String = ""
var chest_chance: float = 0.0     # 每一竿钓到宝箱的概率（来自 balance.json 的 chest.chance）
var rarity_bonus: float = 0.0     # 鱼饵升级：稀有鱼权重 ×(1 + rarity_bonus × rarity)

var _cfg: Dictionary
var _fish: Array
var _rng: RandomNumberGenerator

func _init(cfg: Dictionary, fish_table: Array, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_fish = fish_table
	_rng = rng

## 断点：把当前这一竿的进度存下来，重启后接着等，而不是重新抛竿。
func checkpoint() -> Dictionary:
	return {"state": state, "state_start_ms": state_start_ms, "deadline_ms": deadline_ms, "hooked_fish": hooked_fish}

## 从断点恢复。数据不合法（未知状态、未知鱼种）时返回 false 并保持空闲。
func restore(cp: Dictionary) -> bool:
	var s := int(cp.get("state", State.IDLE))
	var fish := str(cp.get("hooked_fish", ""))
	var known := fish == "" or fish == CHEST
	for f in _fish:
		if f["id"] == fish:
			known = true
	if s <= State.IDLE or s >= State.PAUSED or not known:
		return false
	if s in [State.HOOKED, State.REELING, State.SETTLEMENT] and fish == "":
		return false
	state = s
	state_start_ms = int(cp.get("state_start_ms", 0))
	deadline_ms = int(cp.get("deadline_ms", 0))
	hooked_fish = fish
	return true

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
			# chest_chance 为 0 时不消耗随机数，保持没有宝箱时的随机序列不变
			if chest_chance > 0.0 and _rng.randf() < chest_chance:
				hooked_fish = CHEST
			else:
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

func _weight(f: Dictionary) -> float:
	return float(f["weight"]) * (1.0 + rarity_bonus * float(f.get("rarity", 0)))

func _roll_fish() -> String:
	var total := 0.0
	for f in _fish:
		total += _weight(f)
	var r := _rng.randf() * total
	for f in _fish:
		r -= _weight(f)
		if r < 0.0:
			return f["id"]
	return _fish[-1]["id"]
