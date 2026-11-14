extends RefCounted
## 自动钓鱼状态机。只靠传入的时间戳推进，不看帧数。
## 每次 advance 最多走一步，所以电脑睡眠醒来不会"补钓"一大堆鱼。

## 一竿的流程：上饵 → 抛竿 → 等（第一次动漂）→ 动漂 → [没咬：再等 → 动漂] ×最多 3 次 → 咬钩/收线/结算；
## 三次都没咬就是空军（收杆，线缠成一团，饵丢了）。新增状态都追加在末尾，旧存档里的数值含义不变。
enum State { IDLE, CASTING, WAITING, HOOKED, REELING, SETTLEMENT, PAUSED, BAITING, TWITCH, TANGLED }

var state: int = State.IDLE
var state_start_ms: int = 0
var deadline_ms: int = 0
var wait_multiplier: float = 1.0
const JUNK_PREFIX := "junk:"       # 钓上来的是杂物（漂流瓶、旧靴子…）时，hooked_fish 是 "junk:物品id"：这次咬钩只有杂物，没有鱼
var _pending: Dictionary = {}       # 这次等待结束时要咬钩的东西（鱼/杂物/宝箱和大小），等待开始时就定下，好让小鱼咬得快
var junk_roller: Callable = Callable()   # 咬钩时问一次：返回杂物物品 id 或 ""（由 Game 设置）
const CHEST := "chest"            # 钓上来的不是鱼而是宝箱时，hooked_fish 取这个值

var hooked_fish: String = ""
var hooked_size: int = 0            # 这条鱼的大小（厘米），咬钩时在种类的尺寸范围里随机
var stage: int = 0                  # 这一竿已经动过几次漂（0..2），决定下一次咬钩的概率和鱼的档次
var baiting_started: bool = false   # 刚开始上饵：Game 读到后扣一个饵并清掉这个标记
var tangled_flag: bool = false      # 刚空军：Game 读到后记一笔并清掉
var bait_bonus: float = 0.0         # 本竿所用鱼饵带来的稀有鱼加成（Game 在上饵时设置）
var chest_chance: float = 0.0     # 每一竿钓到宝箱的概率（来自 balance.json 的 chest.chance）
var zone: String = ""               # 当前水域 id；鱼表里有 zone_weights 的鱼按它取权重
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
	return {"state": state, "state_start_ms": state_start_ms, "deadline_ms": deadline_ms, "hooked_fish": hooked_fish, "stage": stage, "hooked_size": hooked_size}

## 从断点恢复。数据不合法（未知状态、未知鱼种）时返回 false 并保持空闲。
func restore(cp: Dictionary) -> bool:
	var s := int(cp.get("state", State.IDLE))
	var fish := str(cp.get("hooked_fish", ""))
	var known := fish == "" or fish == CHEST or fish.begins_with(JUNK_PREFIX)
	for f in _fish:
		if f["id"] == fish:
			known = true
	if s <= State.IDLE or s == State.PAUSED or s > State.TANGLED or not known:
		return false
	if s in [State.HOOKED, State.REELING, State.SETTLEMENT] and fish == "":
		return false
	state = s
	state_start_ms = int(cp.get("state_start_ms", 0))
	deadline_ms = int(cp.get("deadline_ms", 0))
	hooked_fish = fish
	stage = clampi(int(cp.get("stage", 0)), 0, 2)
	hooked_size = int(cp.get("hooked_size", 0))
	return true

func is_active() -> bool:
	return state != State.IDLE and state != State.PAUSED

func start(now_ms: int) -> void:
	if not is_active():
		_begin_baiting(now_ms)

func stop(now_ms: int) -> void:
	hooked_fish = ""
	_pending = {}
	_enter(State.IDLE, now_ms, 0)

## 0..1，当前状态的进度，给动画用。
func progress(now_ms: int) -> float:
	var span := deadline_ms - state_start_ms
	if span <= 0:
		return 0.0
	return clampf(float(now_ms - state_start_ms) / float(span), 0.0, 1.0)

## 推进状态机。返回本次产生的鱼 id（没有则为空字符串）。
## 平移所有截止时刻（休息暂停、全局加速用）。
func shift(delta_ms: int) -> void:
	if state_start_ms > 0:
		state_start_ms += delta_ms
	if deadline_ms > 0:
		deadline_ms += delta_ms

func advance(now_ms: int) -> String:
	if not is_active() or now_ms < deadline_ms:
		return ""
	match state:
		State.BAITING:
			_enter(State.CASTING, now_ms, int(_cfg["cast_ms"]))
		State.CASTING:
			stage = 0
			var lo := float(_cfg["bite_min_ms"])
			var hi := float(_cfg["bite_max_ms"])
			_plan_bite()
			_enter(State.WAITING, now_ms, int(_rng.randf_range(lo, hi) * _bite_scale() * wait_multiplier))
		State.WAITING:
			_enter(State.TWITCH, now_ms, int(_cfg.get("twitch_ms", 1400)))
		State.TWITCH:
			_after_twitch(now_ms)
		State.TANGLED:
			hooked_fish = ""
			_begin_baiting(now_ms)
		State.HOOKED:
			_enter(State.REELING, now_ms, int(_cfg["reel_ms"]))
		State.REELING:
			_enter(State.SETTLEMENT, now_ms, int(_cfg["settle_ms"]))
			return hooked_fish
		State.SETTLEMENT:
			hooked_fish = ""
			_begin_baiting(now_ms)
	return ""

func _begin_baiting(now_ms: int) -> void:
	baiting_started = true
	_enter(State.BAITING, now_ms, int(_cfg.get("bait_ms", 1100)))

## 一次动漂结束：按这是第几次决定咬不咬。咬了就按档次抽鱼（或宝箱）；没咬就接着等，三次都没咬则空军。
func _after_twitch(now_ms: int) -> void:
	var chances: Array = _cfg.get("bite_chance", [1.0, 1.0, 1.0])
	if _rng.randf() < float(chances[clampi(stage, 0, chances.size() - 1)]):
		if _pending.is_empty():
			_plan_bite()                 # 从存档断点接着等时没有预先定好，现在补定
		hooked_fish = str(_pending["id"])
		hooked_size = int(_pending["size"])
		_pending = {}
		_enter(State.HOOKED, now_ms, int(_cfg["hooked_ms"]))
		return
	stage += 1
	if stage >= 3:
		tangled_flag = true
		_enter(State.TANGLED, now_ms, int(_cfg.get("tangle_ms", 3600)))
		return
	var gaps: Array = _cfg.get("gap_ms", [[4000, 10000], [2500, 5000]])
	var g: Array = gaps[clampi(stage - 1, 0, gaps.size() - 1)]
	_plan_bite()
	_enter(State.WAITING, now_ms, int(_rng.randf_range(float(g[0]), float(g[1])) * _bite_scale()))

## 决定这次咬钩的是什么：宝箱 / 杂物 / 鱼（和大小）。
func _plan_bite() -> void:
	var id := ""
	var size := 0
	# chest_chance 为 0 时不消耗随机数，保持没有宝箱时的随机序列不变
	if chest_chance > 0.0 and _rng.randf() < chest_chance:
		id = CHEST
	else:
		var junk: String = str(junk_roller.call()) if junk_roller.is_valid() else ""
		if junk != "":
			id = JUNK_PREFIX + junk
		else:
			id = _roll_fish()
			size = _roll_size(id)
	_pending = {"id": id, "size": size}

## 等待时长的缩放：鱼越小越快咬钩（占的单位越少倍率越低），最小鱼约 0.4 倍、最大鱼 1 倍；宝箱和杂物 1 倍。
func _bite_scale() -> float:
	var id := str(_pending.get("id", ""))
	var u := 1.8
	for f in _fish:
		if f["id"] == id:
			u = float(f.get("units", 1.0))
	var max_u: float = float(_cfg.get("bite_units_max", 1.8))
	return lerpf(float(_cfg.get("bite_small_scale", 0.4)), 1.0, clampf(u / max_u, 0.0, 1.0))

func _enter(s: int, now_ms: int, duration_ms: int) -> void:
	state = s
	state_start_ms = now_ms
	deadline_ms = now_ms + duration_ms

func _weight(f: Dictionary) -> float:
	var base := float(f["weight"])
	if f.has("zone_weights"):          # 这种鱼只在列出的水域出现
		base = float(f["zone_weights"].get(zone, 0.0))
	var w := base * (1.0 + (rarity_bonus + bait_bonus) * float(f.get("rarity", 0)))
	if int(f.get("rarity", 0)) > 0:      # 第几次动漂咬的钩：一次就中多是普通鱼，第三次更可能是稀有的
		var mults: Array = _cfg.get("stage_rare_mult", [1.0, 1.0, 1.0])
		w *= float(mults[clampi(stage, 0, mults.size() - 1)])
	return w

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

## 鱼的大小（厘米）：在这个种类的尺寸范围里取一个随机值；档次越高（动漂次数越多）越偏大。
func _roll_size(fish_id: String) -> int:
	for f in _fish:
		if f["id"] == fish_id and f.has("size_cm"):
			var us: Array = _cfg.get("size_u", [[0.0, 1.0]])
			var u: Array = us[clampi(stage, 0, us.size() - 1)]
			var r: Array = f["size_cm"]
			return int(round(lerpf(float(r[0]), float(r[1]), _rng.randf_range(float(u[0]), float(u[1])))))
	return 0
