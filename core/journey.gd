extends RefCounted
## 小猫的"活动循环"状态机：钓鱼 → (满篓) → 划船去小镇 → 走到摊位 → 摆摊 → 走回码头 → 划船回来。
## 状态存在 GameState.journey 里，用墙上时间的截止时刻推进，重启后能接着走。
## 每次 advance 最多走一步，时间大跳跃（电脑睡眠）不会一口气卖光或吃光。

## SOLD_OUT：鱼卖光了，小猫在摊位前等玩家点气泡再去钓鱼
## ROAM：完整窗口里玩家用方向键亲自带着小猫在镇上走（只追加在末尾，保持旧存档里的数值含义不变）
enum Activity { FISHING, IDLE_FULL, SAIL_OUT, WALK_TO_STALL, VENDING, WALK_TO_BOAT, SAIL_BACK, ROAM, SOLD_OUT }

var _j: Dictionary     # 指向 GameState.journey
var _cfg: Dictionary
var _rng: RandomNumberGenerator

func _init(journey_state: Dictionary, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	_j = journey_state
	_cfg = cfg
	_rng = rng

func activity() -> int:
	return int(_j["activity"])

func on_boat() -> bool:
	return activity() in [Activity.FISHING, Activity.IDLE_FULL, Activity.SAIL_OUT, Activity.SAIL_BACK]

func can_depart() -> bool:
	return activity() == Activity.FISHING or activity() == Activity.IDLE_FULL

## 当前阶段的进度 0..1（钓鱼/满篓阶段没有进度，返回 0）。
func progress(now_ms: int) -> float:
	var span := int(_j["phase_end_ms"]) - int(_j["phase_start_ms"])
	if span <= 0:
		return 0.0
	return clampf(float(now_ms - int(_j["phase_start_ms"])) / float(span), 0.0, 1.0)

func in_town() -> bool:
	return activity() in [Activity.WALK_TO_STALL, Activity.VENDING, Activity.WALK_TO_BOAT, Activity.ROAM, Activity.SOLD_OUT]

## 自由走动时小猫的位置（世界坐标，由表现层写入）。
func roam_x() -> int:
	return int(_j["roam_x"])

func set_roam_x(x: float) -> void:
	_j["roam_x"] = int(round(x))

## 自动行走的起点；-1 表示默认起点（码头或摊位）。
func walk_from() -> int:
	return int(_j["walk_from"])

## 玩家接管：从自动行走/摆摊切到自由走动。
func begin_roam(x: float, now_ms: int) -> bool:
	if not in_town() or activity() == Activity.ROAM:
		return false
	_enter(Activity.ROAM, now_ms, 0)
	set_roam_x(x)
	return true

## 结束自由走动，从当前位置自动走向摊位或码头。fraction 是剩余路程占全程的比例（0..1）。
func end_roam(to_stall: bool, fraction: float, now_ms: int) -> bool:
	if activity() != Activity.ROAM:
		return false
	var from := roam_x()
	_enter(Activity.WALK_TO_STALL if to_stall else Activity.WALK_TO_BOAT, now_ms,
			int(float(_cfg["walk_ms"]) * clampf(fraction, 0.0, 1.5)))
	_j["walk_from"] = from
	return true

func sales_made() -> int:
	return int(_j["sales"])

## 鱼篓满了、玩家还没让它出发：原地打发时间，并安排下一次偷吃。
func set_full(now_ms: int) -> void:
	_enter(Activity.IDLE_FULL, now_ms, 0)
	_j["next_eat_ms"] = now_ms + _rand_ms("eat_min_ms", "eat_max_ms")

func resume_fishing(now_ms: int) -> void:
	_enter(Activity.FISHING, now_ms, 0)

func depart(now_ms: int) -> bool:
	if not can_depart():
		return false
	_enter(Activity.SAIL_OUT, now_ms, int(_cfg["sail_ms"]))
	return true

## 鱼卖完了：停在摊位前，等玩家点"鱼卖光了"气泡。
func sold_out(now_ms: int) -> void:
	if activity() == Activity.VENDING:
		_enter(Activity.SOLD_OUT, now_ms, 0)

## 收摊回船（摆摊中或卖光后）。
func leave_stall(now_ms: int) -> bool:
	if activity() == Activity.VENDING or activity() == Activity.SOLD_OUT:
		_enter(Activity.WALK_TO_BOAT, now_ms, int(_cfg["walk_ms"]))
		return true
	return false

## 空篓子上岸：不去摊位，直接停在码头，让玩家自己逛。
func dock_roam_x() -> int:
	return int(_cfg.get("dock_roam_x", 552))

func schedule_next_sale(now_ms: int) -> void:
	_j["phase_start_ms"] = now_ms
	_j["phase_end_ms"] = now_ms + _rand_ms("sale_min_ms", "sale_max_ms")

## 暂停了 delta_ms（番茄休息期间），把所有截止时刻往后推。
func shift(delta_ms: int) -> void:
	for k in ["phase_start_ms", "phase_end_ms", "next_eat_ms"]:
		if int(_j[k]) > 0:
			_j[k] = int(_j[k]) + delta_ms

## 推进一步。返回发生的事：
##   ""        无事
##   "docked"  船到码头，开始往摊位走
##   "open"    到摊位，开始摆摊
##   "sale"    该卖出一条鱼了（由调用方真正执行买卖，然后 schedule_next_sale 或 leave_stall）
##   "boarded" 回到船上，开始返航
##   "back"    回到钓点，恢复钓鱼
##   "eat"     满篓闲置太久，小猫要偷吃一条
func advance(now_ms: int) -> String:
	match activity():
		Activity.IDLE_FULL:
			if now_ms >= int(_j["next_eat_ms"]):
				_j["next_eat_ms"] = now_ms + _rand_ms("eat_min_ms", "eat_max_ms")
				return "eat"
		Activity.SAIL_OUT:
			if now_ms >= int(_j["phase_end_ms"]):
				_enter(Activity.WALK_TO_STALL, now_ms, int(_cfg["walk_ms"]))
				return "docked"
		Activity.WALK_TO_STALL:
			if now_ms >= int(_j["phase_end_ms"]):
				_enter(Activity.VENDING, now_ms, 0)
				_j["sales"] = 0
				schedule_next_sale(now_ms)
				return "open"
		Activity.VENDING:
			if now_ms >= int(_j["phase_end_ms"]):
				_j["sales"] = int(_j["sales"]) + 1
				return "sale"
		Activity.WALK_TO_BOAT:
			if now_ms >= int(_j["phase_end_ms"]):
				_enter(Activity.SAIL_BACK, now_ms, int(_cfg["sail_ms"]))
				return "boarded"
		Activity.SAIL_BACK:
			if now_ms >= int(_j["phase_end_ms"]):
				_enter(Activity.FISHING, now_ms, 0)
				return "back"
	return ""

func _enter(a: int, now_ms: int, duration_ms: int) -> void:
	_j["activity"] = a
	_j["walk_from"] = -1
	_j["phase_start_ms"] = now_ms
	_j["phase_end_ms"] = now_ms + duration_ms

func _rand_ms(lo_key: String, hi_key: String) -> int:
	return int(_rng.randf_range(float(_cfg[lo_key]), float(_cfg[hi_key])))
