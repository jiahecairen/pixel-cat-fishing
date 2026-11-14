extends RefCounted
## 雾灯信号小游戏（纯逻辑）：光点在 0~1 的横条上来回扫，玩家在它进入光斑时按键。
## 一共几轮，越往后越快、光斑越窄。时间全部由调用方传入（毫秒时间戳）。

var cfg: Dictionary
var round_i: int = 0           # 当前第几轮（0 开始）
var good: int = 0              # 命中（含正中）
var perfect: int = 0           # 正中
var last_grade: int = -1       # 上一次按键的结果：0 没中、1 命中、2 正中；-1 还没按
var finished: bool = false
var t0_ms: int = 0             # 这一轮开始的时刻
var target: float = 0.5        # 光斑中心（0~1）

func _init(config: Dictionary) -> void:
	cfg = config

func rounds() -> int:
	return int(cfg.get("rounds", 5))

func start(now_ms: int, rng: RandomNumberGenerator) -> void:
	round_i = 0
	good = 0
	perfect = 0
	last_grade = -1
	finished = false
	_begin_round(now_ms, rng)

func _begin_round(now_ms: int, rng: RandomNumberGenerator) -> void:
	t0_ms = now_ms
	var w := target_w()
	target = rng.randf_range(w / 2.0 + 0.05, 1.0 - w / 2.0 - 0.05)

func _pick(key: String, i: int) -> float:
	var a: Array = cfg.get(key, [1.0])
	return float(a[clampi(i, 0, a.size() - 1)])

func period_ms() -> float:
	return _pick("period_ms", round_i)

func target_w() -> float:
	return _pick("target_w", round_i)

## 光点此刻的位置（0~1，来回扫的三角波，从左端出发）。
func marker(now_ms: int) -> float:
	var p := period_ms()
	var k := fposmod(float(now_ms - t0_ms) / p, 1.0)
	return k * 2.0 if k < 0.5 else (1.0 - k) * 2.0

## 玩家按键：返回 0 没中 / 1 命中 / 2 正中，并进入下一轮；已经结束返回 -1。
func press(now_ms: int, rng: RandomNumberGenerator) -> int:
	if finished:
		return -1
	var d := absf(marker(now_ms) - target)
	var grade := 0
	if d <= float(cfg.get("perfect_w", 0.06)) / 2.0:
		grade = 2
	elif d <= target_w() / 2.0:
		grade = 1
	if grade >= 1:
		good += 1
	if grade == 2:
		perfect += 1
	last_grade = grade
	round_i += 1
	if round_i >= rounds():
		finished = true
	else:
		_begin_round(now_ms, rng)
	return grade
