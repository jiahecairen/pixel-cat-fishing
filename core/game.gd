extends RefCounted
## 游戏总控（纯逻辑，不依赖任何节点/窗口）。表现层每帧调用 tick()，按返回的事件做动画。
##
## 小猫的活动循环：钓鱼 → 鱼篓满 → 划船去小镇 → 摆摊一条条卖 → 划船回来 → 继续钓。
## 番茄钟与活动循环的关系：
##   专注中   在海上：正常速度钓鱼，鱼进不限量的"木箱"（番茄渔获），完成番茄时 1.5 倍结算；
##            在摊位：每条鱼按 1.5 倍价格卖出。去不去小镇始终由玩家决定，不会自己出发
##   自由挂机 钓鱼减速，鱼进鱼篓；满篓后要玩家点气泡才出发，否则小猫原地睡觉/玩掌机，偶尔偷吃一条
##   休息中   整个循环暂停，小猫原地打盹

const GameState := preload("res://core/game_state.gd")
const Economy := preload("res://core/economy.gd")
const FishingSystem := preload("res://core/fishing_system.gd")
const Pomodoro := preload("res://core/pomodoro.gd")
const Upgrades := preload("res://core/upgrades.gd")
const Journey := preload("res://core/journey.gd")
const Inventory := preload("res://core/inventory.gd")

const DURATION_KEYS := ["focus_min", "short_break_min", "long_break_min"]

var state: GameState
var economy: Economy
var fishing: FishingSystem
var pomodoro: Pomodoro
var upgrades: Upgrades
var journey: Journey
var inventory: Inventory
var fish_list: Array = []
var fish_by_id: Dictionary = {}
var _water: Dictionary = {}
var _birds: Dictionary = {}
var _bird_kind: String = ""      # 正在来访的鸟："gift" 送礼 / "steal" 偷鱼（只在内存里，重启后这次来访作废）
var _bird_item: String = ""
var _anger_until_ms: int = 0     # 被鸟偷了鱼以后生气到这个时刻（只在内存里）
var dirty: bool = false     # 有需要落盘的变化

var _clock
var _cfg: Dictionary
var _pomo_cfg: Dictionary
var _base_capacity: float = 10.0
var _free_multiplier: float = 2.0
var _last_cp_state: int = 0
var _rng: RandomNumberGenerator
var _chest_cfg: Dictionary = {}
var _base_chest: float = 0.0     # 宝箱基础概率（幸运鱼饵生效时翻倍）
var lat: float = 53.35            # 所在位置（按时区推算，由 main 在启动时设置）
var lon: float = -6.26
var city: String = ""
var real_rain: bool = false       # 真实天气（由 io/weather_fetcher 写入）
var real_cloudy: bool = false
var real_at_ms: int = -1          # 最近一次拿到真实天气的时刻，-1 = 还没拿到
var _sky_key: int = -1
var _sky: Dictionary = {}
var _day_key: int = -1
var _day: Dictionary = {}
var weather_override: int = -1    # 调试/测试：-1 按真实时间，0 强制晴，1 强制下雨
var day_shift: int = 0              # 调试：日期往后挪几天
var hour_override: float = -1.0   # 调试：>=0 时把"现在"当成这个钟点（0..24）
var _raining: bool = false
var _base_rarity: float = 0.0    # 装备升级不再提高稀有度，恒为 0（幸运鱼饵生效时才加）

func _init(balance: Dictionary, fish_table: Array, game_state: GameState, clock, rng: RandomNumberGenerator) -> void:
	_cfg = balance
	_clock = clock
	state = game_state
	_base_capacity = float(balance.get("basket_capacity", 10))
	fish_list = fish_table
	for f in fish_table:
		fish_by_id[f["id"]] = f
	economy = Economy.new(fish_table)
	fishing = FishingSystem.new(balance["fishing"], fish_table, rng)
	_rng = rng
	_chest_cfg = balance.get("chest", {})
	_base_chest = float(_chest_cfg.get("chance", 0.0)) if not _chest_cfg.get("tiers", []).is_empty() else 0.0
	fishing.chest_chance = _base_chest
	fishing.junk_roller = Callable(self, "_roll_junk")
	fishing.gate = Callable(self, "_fish_gate")
	inventory = Inventory.new(balance.get("items", []))
	inventory.stack_default = int(balance.get("bag", {}).get("stack", 10))
	_init_gear()
	journey = Journey.new(state.journey, balance["town"], rng)
	_water = balance.get("water", {})
	_birds = balance.get("birds", {})
	# 番茄钟用一份"生效配置"：默认值来自 balance.json，玩家在设置里改过的时长覆盖它
	_pomo_cfg = balance["pomodoro"].duplicate(true)
	for k in DURATION_KEYS:
		if int(state.settings.get(k, 0)) > 0:
			_pomo_cfg[k] = _clamp_setting(k, int(state.settings[k]))
	pomodoro = Pomodoro.new(state.pomodoro, _pomo_cfg)
	upgrades = Upgrades.new(balance.get("upgrades", {}))
	_apply_upgrades()
	# 接着上次没钓完的那一竿
	if journey.activity() == Journey.Activity.FISHING and not pomodoro.is_break():
		fishing.restore(state.fishing_checkpoint)
	_last_cp_state = fishing.state

func now_ms() -> int:
	return _clock.now_ms()

func in_focus() -> bool:
	return pomodoro.phase() == Pomodoro.Phase.FOCUS

func tick() -> Array:
	var events := _tick()
	_clamp_wallet()
	# 钓鱼状态一变就更新断点（状态切换不频繁，不会造成频繁写盘）
	if fishing.state != _last_cp_state:
		_last_cp_state = fishing.state
		state.fishing_checkpoint = fishing.checkpoint()
		dirty = true
	return events

## 本地时间秒数（调试时可以指定钟点，日期仍是今天）。
func local_s() -> int:
	if hour_override >= 0.0:
		var day0 := floori(float(_clock.local_s()) / 86400.0) * 86400
		return day0 + int(hour_override * 3600.0) + day_shift * 86400
	return _clock.local_s() + day_shift * 86400

func utc_s() -> int:
	return local_s() - _clock.bias_s()

func set_location(la: float, lo: float, name: String) -> void:
	lat = la
	lon = lo
	city = name
	_sky_key = -1
	_day_key = -1

## 拿到一次真实天气（io 层调用）。
func set_real_weather(raining: bool, cloudy: bool) -> void:
	real_rain = raining
	real_cloudy = cloudy
	real_at_ms = _clock.now_ms()

func real_weather_on() -> bool:
	return int(state.settings.get("real_weather", 0)) == 1

## 真实天气可用：开关开着、拿到过数据、且不超过 3 小时（断网太久就退回模拟）。
func _real_valid() -> bool:
	return real_weather_on() and real_at_ms >= 0 and _clock.now_ms() - real_at_ms < 3 * 3600 * 1000

## 天空状态：天色（暗度/暖色）、太阳和月亮的位置、月相、是否阴天。每 20 秒才重算一次。
func sky() -> Dictionary:
	var u := utc_s()
	var key := u / 20
	if key == _sky_key and not _sky.is_empty():
		return _sky
	_sky_key = key
	var alt := Astro.sun_altitude(lat, lon, float(u))
	var dk := int(Astro.solar_day_start(lon, float(u)))
	if dk != _day_key:
		_day_key = dk
		_day = Astro.sun_day(lat, lon, float(dk))
	var dawn := Astro.solar_hour(lon, float(u)) < 12.0
	var out := Weather.light(alt, dawn)
	var rise := float(_day["rise"])
	var sset := float(_day["set"])
	var sun_u := -9.0
	if rise >= 0.0 and sset > rise:
		sun_u = (float(u) - rise) / (sset - rise)
	elif alt > 0.0:
		sun_u = 0.5
	out["sun_u"] = sun_u
	out["sun_alt"] = alt
	out["sun_peak"] = float(_day["peak"])
	out["moon_u"] = Astro.moon_u(lon, float(u))
	out["moon_phase"] = Astro.moon_phase(float(u))
	out["cloudy"] = _real_valid() and real_cloudy
	_sky = out
	return out

func is_raining() -> bool:
	return _raining

func _rain_cfg(key: String, fallback: float) -> float:
	return float(_cfg.get("weather", {}).get(key, fallback))

func _compute_raining() -> bool:
	if weather_override >= 0:
		return weather_override == 1
	if _real_valid():
		return real_rain
	return Weather.is_raining(local_s(), _rain_cfg("rain_block_chance", 0.0))

func _tick() -> Array:
	var now: int = _clock.now_ms()
	var events: Array = []
	var rain := _compute_raining()
	if rain != _raining:
		_raining = rain
		events.append({"type": "weather", "raining": rain})
	_refresh_modifiers(now)
	_check_island(events)

	var p := pomodoro.tick(now)
	if p == "focus_done" or p == "focus_done_long":
		events.append(_finish_focus(p == "focus_done_long"))
	elif p == "break_done":
		events.append({"type": "break_done"})
		dirty = true

	# 休息：整个循环暂停，记下暂停时刻，恢复时把截止时间顺延
	if pomodoro.is_break():
		if int(state.journey["paused_at_ms"]) == 0:
			state.journey["paused_at_ms"] = now
			fishing.stop(now)
			dirty = true
		return events
	if int(state.journey["paused_at_ms"]) != 0:
		var paused_for := maxi(0, now - int(state.journey["paused_at_ms"]))
		journey.shift(paused_for)
		for k in ["bird_next_ms", "bird_act_ms"]:       # 鸟的计时也跟着顺延
			if int(state.effects[k]) > 0:
				state.effects[k] = int(state.effects[k]) + paused_for
		if int(state.effects["lucky_until_ms"]) > 0:      # 休息不消耗幸运鱼饵的时间
			state.effects["lucky_until_ms"] = int(state.effects["lucky_until_ms"]) + paused_for
		state.journey["paused_at_ms"] = 0
		dirty = true

	match journey.activity():
		Journey.Activity.FISHING:
			_tick_fishing(now, events)
			_tick_birds(now, events)
		Journey.Activity.IDLE_FULL:
			_tick_idle_full(now, events)
			_tick_birds(now, events)
		Journey.Activity.ISLAND:
			if line_out() and not at_lake_spot():
				reel_in()
			_tick_fishing(now, events)
		_:
			_tick_trip(now, events)
	return events

func start_focus() -> bool:
	var now: int = _clock.now_ms()
	if not pomodoro.start_focus(now):
		return false
	if journey.activity() == Journey.Activity.FISHING:
		fishing.stop(now)   # 重新抛竿，让专注从干净的一竿开始
	dirty = true
	return true

## 放弃专注：木箱里的鱼按原价结算，没有完成奖励，也不计入番茄数。返回结算金币，未在专注返回 -1。
func abandon_focus() -> int:
	if not pomodoro.abandon(_clock.now_ms()):
		return -1
	dirty = true
	return economy.settle_haul(state, state.new_id("s"), 1.0, 0)

func focus_multiplier() -> float:
	return float(_pomo_cfg.get("focus_gold_multiplier", 1.0)) if in_focus() else 1.0

## 完整窗口里玩家接管小猫（x 为当前世界坐标）。
func begin_roam(x: float) -> bool:
	if journey.begin_roam(x, _clock.now_ms()):
		dirty = true
		return true
	return false

## 松手后交还给自动流程：有鱼就走去摊位，没鱼就回码头。fraction 为剩余路程比例。
## 迷你窗自动挂机的规则（数值在 balance.auto）。
func auto_cfg() -> Dictionary:
	return _cfg.get("auto", {})

## 小镇一侧的近水域里随机挑一处能钓鱼的位置（避开浪区和码头浅滩）。
func pick_water_x() -> int:
	var lo := int(_water.get("wave_x", 92)) + 30
	var hi := int(journey.cfg_dock_x()) - int(_cfg.get("town", {}).get("dock_no_fish", 70)) - 30
	return _rng.randi_range(lo, maxi(lo, hi))

## 船现在停的地方钓不了鱼时，自动挑一处附近能钓的水域（岛边浅滩就挑岛外的深水，镇边浅滩就挑镇外的水）。
func auto_fish_x() -> float:
	if at_island_shoal():
		var x0 := island_x() + float(island_info().get("no_fish", 70)) + 60.0
		return x0 + float(_rng.randi_range(0, 340))
	return float(pick_water_x())

## 雾灯岛上：从 x 走到最近的钓位，要不要超过 reach_s 秒（默认 10 秒）。
func island_spot_reachable(cat_x: float) -> bool:
	var secs := absf(nearest_spot_x(cat_x) - cat_x) / (float(auto_cfg().get("walk_px_s", 70)) * move_speed())
	return secs <= float(auto_cfg().get("reach_s", 10))

## 回镇后自动安排：鱼篓超过 30% 去摊位卖鱼，不超过（含 30%）就随机挑近处水域去钓鱼。
func end_roam(fraction_to_stall: float, fraction_to_boat: float, by_policy: bool = false) -> void:
	var to_stall := not state.basket.is_empty()
	if by_policy and to_stall and economy.basket_percent(state) <= int(auto_cfg().get("sell_pct", 30)):
		to_stall = false
	if by_policy and not to_stall:
		journey.set_fish_spot(pick_water_x())
	if journey.end_roam(to_stall, fraction_to_stall if to_stall else fraction_to_boat, _clock.now_ms()):
		dirty = true

## 玩家在码头按互动键：不管还有没有鱼，直接上船返航。
func roam_board(fraction_to_boat: float) -> void:
	if journey.end_roam(false, fraction_to_boat, _clock.now_ms()):
		dirty = true

func skip_break() -> bool:
	if pomodoro.skip_break():
		dirty = true
		return true
	return false

func can_go_to_town() -> bool:
	return journey.can_depart() and not pomodoro.is_break()

## 让小猫出发去小镇（随时可以，鱼篓空着也行；休息时整个循环暂停，所以休息时不行）。
func go_to_town(stop_at_dock: bool = false) -> bool:
	if not can_go_to_town():
		return false
	state.journey["dock_stop"] = 1 if stop_at_dock else 0
	var now: int = _clock.now_ms()
	fishing.stop(now)
	state.journey["line_out"] = 1
	journey.depart(now)
	if journey.activity() == Journey.Activity.WALK_TO_STALL and (state.basket.is_empty() or stop_at_dock):
		state.journey["dock_stop"] = 0
		journey.begin_roam(journey.dock_roam_x(), now)      # 空篓子（或从目的地面板回小镇）贴着码头上岸：直接让玩家自己逛
	_cancel_bird()
	dirty = true
	return true

## 自动航行（去小镇 / 回钓点）随时能打断：船停在当前位置，竿收着，按互动键再甩。休息时不行。
func can_halt_sail() -> bool:
	return (journey.activity() == Journey.Activity.SAIL_OUT or journey.activity() == Journey.Activity.SAIL_BACK) and not pomodoro.is_break()

func halt_sail() -> bool:
	if not can_halt_sail():
		return false
	if not journey.halt_sail(_clock.now_ms()):
		return false
	state.journey["line_out"] = 0
	fishing.stop(_clock.now_ms())
	_cancel_bird()
	dirty = true
	return true

const MOVE_SPEEDS := [1.0, 2.0, 4.0, 8.0, 16.0]
var time_scale: float = 1.0            # 全局加速倍数（测试用，不存档）
var _ff_rest: float = 0.0              # 加速时不足 1 毫秒的零头

## 测试用：整个游戏加速（钓鱼、航行、走路、番茄钟、鸟全部一起快）。direction 为 +1 / -1，到头不循环。
func move_speed() -> float:
	return time_scale

func change_move_speed(direction: int) -> float:
	var i := MOVE_SPEEDS.find(time_scale)
	if i < 0:
		i = 0
	i = clampi(i + direction, 0, MOVE_SPEEDS.size() - 1)
	time_scale = MOVE_SPEEDS[i]
	return time_scale

## 每帧由表现层调用，传入这一帧真实经过的毫秒数。加速时把所有"截止时刻"往前挪，
## 效果等同于时间流得更快，但存档里记的仍是真实墙上时间，退出后不会留下错位。
func fast_forward(real_dt_ms: float) -> void:
	if time_scale <= 1.0:
		return
	_ff_rest += real_dt_ms * (time_scale - 1.0)
	var delta := int(_ff_rest)
	if delta <= 0:
		return
	_ff_rest -= float(delta)
	_advance_deadlines(-delta)

## 把所有按墙上时间记的截止时刻平移 delta_ms（正数往后推、负数往前拉）。
func _advance_deadlines(delta_ms: int) -> void:
	if int(state.pomodoro["phase_end_ms"]) > 0:
		state.pomodoro["phase_end_ms"] = int(state.pomodoro["phase_end_ms"]) + delta_ms
	if int(state.journey["paused_at_ms"]) != 0:
		return                                   # 休息中：旅程和钓鱼整体暂停，不跟着走
	journey.shift(delta_ms)
	fishing.shift(delta_ms)
	for k in ["bird_next_ms", "bird_act_ms", "lucky_until_ms"]:
		if int(state.effects[k]) > 0:
			state.effects[k] = int(state.effects[k]) + delta_ms
	if _anger_until_ms > 0:
		_anger_until_ms += delta_ms

## 刚被鸟偷了鱼，小猫还在生气。
func angry() -> bool:
	return _anger_until_ms > 0 and _clock.now_ms() < _anger_until_ms

## 装备栏里某一格显示的名字（鱼竿随升级等级变，鱼线、鱼钩暂时只有一档）。
func equipment_name(slot: String) -> String:
	var names: Array = _cfg.get("equipment", {}).get(slot, [])
	if names.is_empty():
		return "-"
	return String(names[clampi(int(state.gear.get(slot, 0)), 0, names.size() - 1)])

## 幸运鱼饵生效中（鱼饵格显示用）。
func bait_active() -> bool:
	return int(state.effects["lucky_until_ms"]) > _clock.now_ms()

## 船所在位置属于哪片水域（"deep" / "normal" / "shallow"）。
## 鸟飞来后停多久才送礼/偷鱼（画面里鸟停留的时间也按它）。
func bird_act_after_ms() -> int:
	return int(_birds.get("act_after_ms", 6000))

## 小岛一侧的浅水区：从小岛到 island.shallow_to（距小岛的距离）；和小镇一侧对称，中间是深水区。
func _island_shallow_end() -> float:
	if island_info().is_empty():
		return -1.0e9
	return island_x() + float(island_info().get("shallow_to", 386))

func zone_id(x: float) -> String:
	if x < _island_shallow_end():
		return "shallow"
	for z in _water.get("zones", []):
		if x < float(z["max_x"]):
			return z["id"]
	return "shallow"

## 各水域的范围：[{id, x0, x1}]，从左到右；最后一片的右端用 sea_end 截断。
## 画面和钓鱼的水域都靠它：小岛一侧是浅水区，中间深水区，小镇一侧又是浅水区。
func zone_bounds(sea_end: float) -> Array:
	var out: Array = []
	var x0 := -100000.0
	if not island_info().is_empty():
		var ie := island_x() + float(island_info().get("shallow_to", 386))
		out.append({"id": "shallow", "x0": x0, "x1": ie})
		x0 = ie
	for z in _water.get("zones", []):
		var x1 := minf(float(z["max_x"]), sea_end)
		out.append({"id": z["id"], "x0": x0, "x1": x1})
		x0 = x1
	return out

## 船能划到的左右边界（船左端的世界坐标）。
func boat_limits() -> Vector2:
	var lo := float(_water.get("boat_min_x", 30))
	if boat_passes_waves() and not island_info().is_empty():
		lo = float(island_info()["x"])       # 能穿过浪区的船，可以一直划到小岛
	return Vector2(lo, float(_water.get("boat_max_x", 440)))

## ---- 小猫的名字（最多 6 个字，空的用默认名）----
const NAME_MAX := 6
const DEFAULT_NAMES := ["小橘", "团子", "年糕", "麻薯", "布丁", "汤圆", "豆沙", "芝麻"]

func set_cat_name(n: String) -> String:
	var v := n.strip_edges().substr(0, NAME_MAX)
	if v == "":
		v = DEFAULT_NAMES[0]
	state.cat_name = v
	state.revision += 1
	dirty = true
	return v

func town_name() -> String:
	return str(_cfg.get("town", {}).get("name", "小镇"))

## ---- 小岛 ----
func island_info() -> Dictionary:
	return _water.get("island", {})

func island_x() -> float:
	return float(island_info().get("x", -3900))

func island_visited() -> bool:
	return str(island_info().get("id", "")) in state.islands

## 船在小岛岸边的浅水里，不能钓鱼。
func at_island_shoal() -> bool:
	return not island_info().is_empty() and float(journey.boat_x()) <= island_x() + float(island_info().get("no_fish", 70))

## 船贴着小岛的码头。
func at_island_dock() -> bool:
	return not island_info().is_empty() and float(journey.boat_x()) <= island_x() + 14.0

## 小岛上的位置（世界坐标）：登岛时站在码头尽头，往西走进岛里；灯塔、看守人、岛心湖都以岛的坐标为准。
func island_land_x() -> float:
	return island_x() - 34.0

## 湖东岸的钓位（小猫站在这里朝西钓鱼）。
func lake_spot_x() -> float:
	return island_lake().y + 2.0

func bridge_built() -> bool:
	return int(state.effects.get("bridge", 0)) == 1

## 岛上能走的最西处：没修桥时是湖东岸（湖挡着路）；修好桥后能一直走到岛的西边。
func island_walk_min() -> float:
	if bridge_built():
		return island_x() - float(island_info().get("walk_west", 760))
	return lake_spot_x()

## 修好的拱桥正中间的钓位（小猫站在桥顶，正对着画面钓鱼）。
func bridge_spot_x() -> float:
	var lk := island_lake()
	return (lk.x + lk.y) / 2.0 - 16.0

func at_bridge_spot() -> bool:
	return bridge_built() and journey.on_island() and absf(float(journey.roam_x()) - bridge_spot_x()) <= 3.0

## 离小猫（左端 x）最近的钓位：在桥上就是桥顶，否则是湖东岸。
func nearest_spot_x(cat_x: float) -> float:
	if bridge_built() and absf(cat_x - bridge_spot_x()) < absf(cat_x - lake_spot_x()):
		return bridge_spot_x()
	return lake_spot_x()

## 小猫是不是站在能钓鱼的位置（湖东岸或桥顶）。
func at_lake_spot() -> bool:
	return journey.on_island() and (absf(float(journey.roam_x()) - lake_spot_x()) <= 3.0 or at_bridge_spot())

func island_keeper_x() -> float:
	return island_x() - float(island_info().get("keeper_off", 196))

## 湖的范围（世界坐标 x0, x1）。
func island_lake() -> Vector2:
	var shore := island_x() - 64.0
	return Vector2(shore - 420.0, shore - 270.0)

func can_land() -> bool:
	return at_island_dock() and journey.can_depart() and not pomodoro.is_break()

## 在岛的码头按互动键：小猫上岸（先收竿）。
func land_on_island() -> bool:
	if not can_land():
		return false
	var now: int = _clock.now_ms()
	fishing.stop(now)
	state.journey["line_out"] = 0
	_cancel_bird()
	if not journey.land_on_island(island_land_x(), now):
		return false
	dirty = true
	return true

## 回到船上，接着钓鱼。
func leave_island() -> bool:
	var now: int = _clock.now_ms()
	fishing.stop(now)
	if not journey.leave_island(now):
		return false
	state.journey["line_out"] = 1
	dirty = true
	return true

## 带 gate 的鱼什么时候出现："lamp" = 灯塔修好了，而且是夜里。
func _fish_gate(gate_id: String) -> bool:
	match gate_id:
		"lamp":
			return lighthouse_lit() and float(sky()["dark"]) > 0.45
	return true

## 灯塔修好了没（第二个看守任务交付）。
func lighthouse_lit() -> bool:
	return quest_state("lighthouse2") == "done"

# ------------------------------------------------------------------ 岛上拾取
func drift_x(i: int) -> float:
	var offs: Array = _cfg.get("drift", {}).get("offsets", [])
	return island_x() + float(offs[i]) if i < offs.size() else INF

func drift_count() -> int:
	var n: int = _cfg.get("drift", {}).get("offsets", []).size()
	return n if bridge_built() else mini(n, int(_cfg.get("drift", {}).get("west_from", n)))

func drift_ready(i: int) -> bool:
	return i < drift_count() and _clock.now_ms() >= int(state.effects.get("drift_%d" % i, 0))

## 小猫（中心 x）脚边有没有能拾的东西：返回格子序号，没有返回 -1。
func drift_near(x: float) -> int:
	var reach := float(_cfg.get("drift", {}).get("reach", 20))
	for i in drift_count():
		if drift_ready(i) and absf(x - drift_x(i)) <= reach:
			return i
	return -1

## 拾起来：随机一样东西（或几个铜币），这一格过一会儿才再有。返回 {"item","gold"}，不能拾返回空。
func pick_drift(i: int) -> Dictionary:
	if not journey.on_island() or not drift_ready(i) or pomodoro.is_break():
		return {}
	var cfg: Dictionary = _cfg.get("drift", {})
	var pick := _pick_pool(cfg.get("pool", []))
	if pick == "":
		pick = "gold"
	var out := {"item": "", "gold": 0}
	if pick == "gold":
		var gr: Array = cfg.get("gold", [10, 30])
		out["gold"] = _rng.randi_range(int(gr[0]), int(gr[1]))
		economy.grant_gold(state, state.new_id("d"), int(out["gold"]))
	else:
		out["item"] = pick
		give(pick, 1)
	state.effects["drift_%d" % i] = _clock.now_ms() + int(cfg.get("refill_min", 8)) * 60000
	dirty = true
	return out

# ------------------------------------------------------------------ 工作台与蟹笼
func pots_cfg() -> Dictionary:
	return _cfg.get("pots", {})

func bench_x() -> float:
	return island_keeper_x() + float(pots_cfg().get("bench_off", -66))

func pot_count() -> int:
	var n := 0
	for i in int(pots_cfg().get("max", 3)):
		if int(state.effects.get("pot_%d" % i, 0)) > 0:
			n += 1
	return n

func has_pot_recipe() -> bool:
	return inventory.count(state, "crab_recipe") > 0

func pot_materials_ok() -> bool:
	for c in pots_cfg().get("cost", []):
		if inventory.count(state, str(c[0])) < int(c[1]):
			return false
	return true

## 在工作台做一个蟹笼（要配方和材料），自动放进岛心湖。成功返回 true。
func craft_pot() -> bool:
	if not journey.on_island() or not has_pot_recipe() or not pot_materials_ok():
		return false
	if pot_count() >= int(pots_cfg().get("max", 3)):
		return false
	for c in pots_cfg().get("cost", []):
		inventory.remove(state, str(c[0]), int(c[1]))
	for i in int(pots_cfg().get("max", 3)):
		if int(state.effects.get("pot_%d" % i, 0)) == 0:
			state.effects["pot_%d" % i] = _clock.now_ms() + int(pots_cfg().get("ready_min", 25)) * 60000
			break
	dirty = true
	return true

func pot_ready(i: int) -> bool:
	var v := int(state.effects.get("pot_%d" % i, 0))
	return v > 0 and _clock.now_ms() >= v

func pots_ready() -> int:
	var n := 0
	for i in int(pots_cfg().get("max", 3)):
		if pot_ready(i):
			n += 1
	return n

## 在湖边收蟹笼：每个好了的笼子给一点铜币，有机会带出别的东西；笼子自动重新下好。返回 {"gold","items":{id:n}}。
func collect_pots() -> Dictionary:
	var out := {"gold": 0, "items": {}}
	if not at_lake_spot() or pomodoro.is_break():
		return out
	var cfg := pots_cfg()
	for i in int(cfg.get("max", 3)):
		if not pot_ready(i):
			continue
		var gr: Array = cfg.get("gold", [10, 30])
		var gold := _rng.randi_range(int(gr[0]), int(gr[1]))
		economy.grant_gold(state, state.new_id("p"), gold)
		out["gold"] = int(out["gold"]) + gold
		if _rng.randf() < float(cfg.get("item_chance", 0.4)):
			var got := _pick_pool(cfg.get("pool", []))
			if got != "":
				give(got, 1)
				out["items"][got] = int(out["items"].get(got, 0)) + 1
		state.effects["pot_%d" % i] = _clock.now_ms() + int(cfg.get("ready_min", 25)) * 60000
	if int(out["gold"]) > 0:
		dirty = true
	return out

# ------------------------------------------------------------------ 西岸旧营地的木箱
func west_chest_x() -> float:
	return island_x() + float(_cfg.get("west_chest", {}).get("off", -690))

func west_chest_open() -> bool:
	return int(state.effects.get("west_chest", 0)) == 1

func open_west_chest() -> Dictionary:
	if not bridge_built() or west_chest_open() or not journey.on_island():
		return {}
	var cfg: Dictionary = _cfg.get("west_chest", {})
	state.effects["west_chest"] = 1
	economy.open_chest(state, "island_west_chest", int(cfg.get("gold", 0)))
	var items := {}
	for e in cfg.get("give", []):
		give(str(e[0]), int(e[1]))
		items[str(e[0])] = int(e[1])
	dirty = true
	return {"gold": int(cfg.get("gold", 0)), "items": items}

# ------------------------------------------------------------------ 信号台小游戏
func signal_cfg() -> Dictionary:
	return _cfg.get("signal", {})

func signal_ready() -> bool:
	return lighthouse_lit() and _clock.now_ms() >= int(state.effects.get("signal_ready_ms", 0)) and not pomodoro.is_break()

func signal_wait_s() -> int:
	return maxi(0, (int(state.effects.get("signal_ready_ms", 0)) - _clock.now_ms()) / 1000)

func signal_x() -> float:
	return island_keeper_x() - float(signal_cfg().get("console_off", 36))

## 一局结束：good = 命中次数，perfect = 正中次数。发铜币，命中够多再送一枚雾灯贝，开始冷却。
func signal_finish(good: int, perfect: int) -> Dictionary:
	var cfg := signal_cfg()
	var gold := good * int(cfg.get("gold_good", 6)) + perfect * int(cfg.get("gold_perfect", 14))
	var shell := good >= int(cfg.get("shell_hits", 4))
	if gold > 0:
		economy.grant_gold(state, state.new_id("g"), gold)
	if shell:
		give("lamp_shell", 1)
	state.effects["signal_ready_ms"] = _clock.now_ms() + int(cfg.get("cooldown_min", 20)) * 60000
	state.stats["signal_plays"] = int(state.stats.get("signal_plays", 0)) + 1
	dirty = true
	return {"gold": gold, "shell": shell}

## 第一次靠近小岛：记下来并给界面一个"发现小岛"事件。
func _check_island(events: Array) -> void:
	if not ("town" in state.islands) and journey.in_town():        # 第一次踏上小镇：也弹一次标题
		state.islands.append("town")
		state.revision += 1
		dirty = true
		events.append({"type": "island_found", "id": "town", "name": town_name()})
	if island_info().is_empty() or island_visited() or not journey.on_boat():
		return
	if float(journey.boat_x()) <= island_x() + 120.0:
		state.islands.append(str(island_info()["id"]))
		state.revision += 1
		dirty = true
		events.append({"type": "island_found", "id": island_info()["id"], "name": island_info().get("name", "")})

## 水域最左侧的浪区：x 在 wave_x 以内浪越来越大把船往回推，最远只能划到 wave_stop 附近
## （以后升级船只才能出得更远）。返回 Vector2(wave_x, wave_stop)。
func wave_zone() -> Vector2:
	return Vector2(float(_water.get("wave_x", 92)), float(_water.get("wave_stop", 56)))

## 海流：浪区往西一直到小岛附近都有向东（回小镇方向）的海流。顺流划船加速 20%，逆流减速 20%。
## 返回船在 x 处朝 dir（-1 向西 / +1 向东）划时的速度倍率；浪区以外是 1。
func current_mult(x: float, dir: float) -> float:
	var s := current_strength(x)
	if s <= 0.0 or dir == 0.0:
		return 1.0
	var amt := float(_water.get("current_amount", 0.2))
	return 1.0 + (amt if dir > 0.0 else -amt) * s

func current_strength(x: float) -> float:
	var wz := wave_zone()
	var s := clampf((wz.x - x) / 30.0, 0.0, 1.0)          # 浪区入口处从 0 慢慢加到 1
	if not island_info().is_empty():
		var tail := island_x() + float(island_info().get("current_end", 160))
		s = minf(s, clampf((x - tail) / 150.0, 0.0, 1.0))   # 靠近小岛慢慢消失
	return s

## 当前的船能不能穿过浪区（升级后浪还在，只是船不再被推回来；以后更大的浪要更高级的船）。
func boat_passes_waves() -> bool:
	return state.boat_level >= int(_water.get("wave_need", 1))

## ---- 船坞：船的等级 ----
func boat_levels() -> Array:
	return _water.get("boat_levels", [])

func boat_info(level: int) -> Dictionary:
	var l := boat_levels()
	return l[level] if level >= 0 and level < l.size() else {}

func boat_price(level: int) -> int:
	return int(boat_info(level).get("price", 0))

## 买下第 level 级的船。只能一级一级买（level 必须正好是当前级别 + 1），所以重复提交不会重复扣钱。
func buy_boat_upgrade(level: int) -> bool:
	if level != state.boat_level + 1 or level >= boat_levels().size():
		return false
	var price := boat_price(level)
	if state.wallet_gold < price:
		return false
	state.wallet_gold -= price
	state.boat_level = level
	dirty = true
	return true

## 船在 x 处受到的向右推力占比：浪区入口 0，到 wave_stop 为 1。
func wave_push(x: float) -> float:
	if boat_passes_waves():
		return 0.0
	var w := wave_zone()
	return clampf((w.x - x) / maxf(1.0, w.x - w.y), 0.0, 1.0)

func can_steer() -> bool:
	if fishing.state in [FishingSystem.State.HOOKED, FishingSystem.State.REELING, FishingSystem.State.SETTLEMENT]:
		return false          # 正在收鱼，先让这条鱼收完
	return (journey.activity() == Journey.Activity.FISHING or journey.activity() == Journey.Activity.IDLE_FULL) and not pomodoro.is_break()

## 钓竿是不是甩出去了。划船会把竿收起来，停船后要按互动键重新甩竿。
func line_out() -> bool:
	return int(state.journey["line_out"]) == 1

## 收杆：停掉这一竿（饵已经上了，没钓到就算丢了）。
func reel_in() -> bool:
	if not line_out():
		return false
	state.journey["line_out"] = 0
	fishing.stop(_clock.now_ms())
	dirty = true
	return true

## 船停在码头边上（离码头太近，不能钓鱼）。
func at_dock() -> bool:
	return journey.boat_at_dock()

## 离码头一定距离内水太浅，不能钓鱼。
func fishing_blocked() -> bool:
	if journey.on_island():
		return not at_lake_spot()
	return journey.boat_in_shoal() or at_island_shoal()

## 停船后重新开始钓鱼。
func cast_line() -> bool:
	var act_ok: bool = journey.activity() == Journey.Activity.FISHING or journey.on_island()
	if fishing_blocked() or line_out() or not act_ok or pomodoro.is_break():
		return false
	state.journey["line_out"] = 1
	dirty = true
	return true

## 划船：把船挪到 x（夹在可划范围内）。钓鱼不会被打断，咬钩时按船此刻所在的水域抽鱼。
func steer_to(x: float) -> bool:
	if not can_steer():
		return false
	reel_in()                  # 划船要先收杆
	var lim := boat_limits()
	var nx := clampf(x, lim.x, lim.y)
	if int(round(nx)) != journey.boat_x():
		journey.set_boat_x(nx)
		_cancel_bird()                 # 船在开，鸟停不住
		dirty = true
	return true

func can_go_fishing() -> bool:
	return journey.in_town() and journey.activity() != Journey.Activity.WALK_TO_BOAT and not pomodoro.is_break()

## 在镇上点"去钓鱼"：不管在哪（摊位前、卖光后、自由走动），都走回码头上船。
## x 是小猫当前世界坐标，fraction_to_boat 是剩余路程占全程的比例。
func go_fishing(x: float, fraction_to_boat: float) -> bool:
	if not can_go_fishing():
		return false
	var now: int = _clock.now_ms()
	var ok := false
	match journey.activity():
		Journey.Activity.SOLD_OUT:
			ok = journey.leave_stall(now)
		Journey.Activity.WALK_TO_STALL, Journey.Activity.VENDING:
			ok = journey.begin_roam(x, now) and journey.end_roam(false, fraction_to_boat, now)
		Journey.Activity.ROAM:
			ok = journey.end_roam(false, fraction_to_boat, now)
	if ok:
		dirty = true
	return ok

func buy_upgrade(id: String) -> bool:
	if not upgrades.buy(state, id):
		return false
	if id == "rod":
		grant_gear("rod_%d" % upgrades.level(state, "rod"))     # 买到手的新鱼竿自动装上，换下来的进物品栏
	_apply_upgrades()
	dirty = true
	return true

## 当前生效的时长（分钟）。
func duration(key: String) -> int:
	return int(_pomo_cfg[key])

## 调整番茄时长，direction 为 +1 / -1。对正在进行的阶段不生效，下一个阶段起生效。
func adjust_duration(key: String, direction: int) -> int:
	if not key in DURATION_KEYS:
		return 0
	var lim: Array = _cfg.get("settings_limits", {}).get(key, [1, 120, 1])
	var v := _clamp_setting(key, duration(key) + direction * int(lim[2]))
	_pomo_cfg[key] = v
	state.settings[key] = v
	dirty = true
	return v

# ------------------------------------------------------------------ 内部
func _tick_fishing(now: int, events: Array) -> void:
	var focus := in_focus()
	if fishing_blocked():               # 浅滩：不能钓鱼，收着竿
		state.journey["line_out"] = 0
	if not line_out():                  # 钓竿收着（刚划过船）：等玩家按互动键再甩
		if fishing.is_active():
			fishing.stop(now)
		return
	# 下雨：鱼咬钩更快（等待时间缩短到 1/1.05）
	var rain_speed := _rain_cfg("rain_bite_speed", 1.0) if _raining else 1.0
	fishing.wait_multiplier = (1.0 if focus else _free_multiplier) / rain_speed
	if not focus and economy.basket_full(state):
		# 让最后一条鱼的结算动画播完再收竿
		if fishing.is_active() and fishing.state == FishingSystem.State.SETTLEMENT:
			fishing.advance(now)
			return
		fishing.stop(now)
		if journey.on_island():          # 在岛上：只收竿，不会被带去小镇
			state.journey["line_out"] = 0
		else:
			journey.set_full(now)
		events.append({"type": "basket_full"})
		dirty = true
		return
	if not fishing.is_active():
		fishing.start(now)
	fishing.zone = "lake" if journey.on_island() else zone_id(float(journey.boat_x()))
	if fishing.baiting_started:         # 每次甩钩前上饵：装上的饵扣 1 个，没有了就用面团
		fishing.baiting_started = false
		events.append(_use_bait())
	var fish_id := fishing.advance(now)
	if fishing.tangled_flag:            # 三次动漂都没咬钩：空军
		fishing.tangled_flag = false
		state.stats["empty_casts"] = int(state.stats.get("empty_casts", 0)) + 1
		events.append({"type": "tangle"})
		dirty = true
	if fish_id == FishingSystem.CHEST:
		var loot := _roll_chest()
		if economy.open_chest(state, state.new_id("c"), int(loot["gold"])):
			if loot["item"] != "":
				give(loot["item"], 1, events)
			events.append({"type": "chest", "gold": loot["gold"], "tier": loot["tier"], "item": loot["item"]})
			dirty = true
	elif fish_id.begins_with(FishingSystem.JUNK_PREFIX):
		var junk := fish_id.substr(FishingSystem.JUNK_PREFIX.length())
		give(junk, 1, events)
		events.append({"type": "junk", "item": junk})
		dirty = true
	elif fish_id != "" and economy.add_catch(state, state.new_id("c"), fish_id, focus, fishing.hooked_size):
		var size := fishing.hooked_size
		var drop_item := str(fish_by_id.get(fish_id, {}).get("drop_item", ""))
		if drop_item != "":
			give(drop_item, 1, events)
		var best: Dictionary = state.stats["fish_best"]
		if size > int(best.get(fish_id, 0)):
			best[fish_id] = size
		events.append({"type": "catch", "fish_id": fish_id, "size": size})
		dirty = true
	if fish_id != "":
		journey.remember_fish_spot()      # 钓到东西的地方记下来：靠岸再回来时开回这里

## 上饵：扣掉装上的饵 1 个（用完自动换回面团），并把它的稀有鱼加成交给钓鱼系统。
func _use_bait() -> Dictionary:
	var id := state.equipped_bait
	var bonus := 0.0
	if id != "":
		if inventory.count(state, id) > 0 and inventory.by_id.has(id):
			inventory.consume(state, id)
			bonus = float(inventory.by_id[id].get("rarity_bonus", 0.0))
		if inventory.count(state, id) <= 0:
			state.equipped_bait = ""
	fishing.bait_bonus = bonus
	dirty = true
	return {"type": "bait", "bait": id, "left": inventory.count(state, id) if id != "" else -1}

## 鸟：每隔几分钟飞来一次落在船上。送礼（带来物品）或偷鱼（叼走篓里最便宜的非稀有鱼，
## 只在小猫盯着浮漂等咬钩、没留意身后的时候来偷）。来访开始时定好种类，到 act_after_ms 后才真正生效，让画面里的鸟先飞到。
func _tick_birds(now: int, events: Array) -> void:
	if _birds.is_empty():
		return
	var e := state.effects
	if int(e["bird_act_ms"]) > 0:
		if now < int(e["bird_act_ms"]):
			return
		e["bird_act_ms"] = 0
		e["bird_next_ms"] = now + _rng.randi_range(int(_birds["min_ms"]), int(_birds["max_ms"]))
		if _bird_kind == "gift" and _bird_item != "":
			give(_bird_item, 1, events)
			events.append({"type": "bird_gift", "item": _bird_item})
		elif _bird_kind == "steal":
			var gone := economy.eat_cheapest(state)
			_anger_until_ms = now + int(_birds.get("anger_ms", 1500))   # 气得冒红色💢，过一会儿才接着钓
			events.append({"type": "bird_steal", "fish_id": gone, "size": economy.last_removed_size})
		_bird_kind = ""
		_bird_item = ""
		dirty = true
		return
	if int(e["bird_next_ms"]) <= 0:
		e["bird_next_ms"] = now + _rng.randi_range(int(_birds["min_ms"]), int(_birds["max_ms"]))
		dirty = true
		return
	if now < int(e["bird_next_ms"]):
		return
	var watching_float: bool = journey.activity() == Journey.Activity.IDLE_FULL or (fishing.state == FishingSystem.State.WAITING or fishing.state == FishingSystem.State.TWITCH)
	var loot := economy.cheapest_common(state)
	var roll := _rng.randf()
	if loot != "" and watching_float and roll < float(_birds["steal_chance"]):
		_bird_kind = "steal"
		_bird_item = loot
	elif _rng.randf() < float(_birds.get("idle_chance", 0.0)):
		_bird_kind = "none"          # 只是来歇歇脚，什么也不发生（最后停在船尾小猫面前）
		_bird_item = ""
	else:
		_bird_kind = "gift"
		_bird_item = "bottle" if _rng.randf() < float(_birds["bottle_chance"]) and inventory.by_id.has("bottle") and item_wanted("bottle") else ""
		var tries := 0
		while _bird_item == "" and tries < 12:
			tries += 1
			var cand := inventory.roll(_rng)
			if cand != "" and item_wanted(cand):
				_bird_item = cand
		if _bird_item == "":
			_bird_kind = "none"
	e["bird_act_ms"] = now + int(_birds["act_after_ms"])
	events.append({"type": "bird_visit", "kind": _bird_kind, "item": _bird_item})
	dirty = true

func _cancel_bird() -> void:
	_anger_until_ms = 0
	_bird_kind = ""
	_bird_item = ""
	state.effects["bird_act_ms"] = 0
	state.effects["bird_next_ms"] = 0

func _tick_idle_full(now: int, events: Array) -> void:
	if now < _anger_until_ms:          # 刚被鸟偷了鱼：先生气，不马上接着钓
		return
	if in_focus() or not economy.basket_full(state):   # 专注：鱼进木箱，满篓也接着钓
		journey.resume_fishing(now)   # 例如刚升级了鱼篓容量
		dirty = true
	elif journey.advance(now) == "eat":
		var eaten := economy.eat_cheapest(state)
		if eaten != "":
			events.append({"type": "ate", "fish_id": eaten, "size": economy.last_removed_size})
			journey.resume_fishing(now)
		dirty = true

func _tick_trip(now: int, events: Array) -> void:
	var r := journey.advance(now)
	if r == "":
		return
	dirty = true
	if r == "back":
		state.journey["line_out"] = 1      # 回到钓点：自动甩竿
	elif r == "moored":
		state.journey["line_out"] = 0      # 船贴着码头：不能钓鱼
	match r:
		"sale":
			var mult := focus_multiplier()
			var belled := int(state.effects["bell_sales"]) > 0     # 招财铃：这一单翻倍
			if belled:
				mult *= float(inventory.by_id.get("bell", {}).get("price_mult", 1.0))
			var sale := economy.sell_one(state, state.new_id("s"), mult)
			if belled and not sale.is_empty():
				state.effects["bell_sales"] = int(state.effects["bell_sales"]) - 1
			if not sale.is_empty():
				events.append({"type": "sale", "fish_id": sale["fish_id"], "gold": sale["gold"]})
			if state.basket.is_empty():
				journey.sold_out(now)
				events.append({"type": "sold_out"})
			else:
				journey.schedule_next_sale(now)
		"docked":
			if state.basket.is_empty() or int(state.journey.get("dock_stop", 0)) == 1:       # 没鱼可卖 / 从目的地面板回来：停在码头，让玩家自己逛
				state.journey["dock_stop"] = 0
				journey.begin_roam(journey.dock_roam_x(), now)
			events.append({"type": "docked"})
		"open":
			if state.basket.is_empty():
				journey.sold_out(now)
			events.append({"type": "open"})
		_:
			events.append({"type": r})

## 钓上来的不是鱼而是杂物（漂流瓶、旧靴子）：这次咬钩算不算。算的话物品 id 记在 _last_junk。
var _last_junk: String = ""

func _roll_junk() -> String:
	_last_junk = ""
	var cfg: Dictionary = _cfg.get("lake_junk" if journey.on_island() else "junk", {})
	if cfg.is_empty() or _rng.randf() >= float(cfg.get("chance", 0.0)):
		return ""
	_last_junk = _pick_pool(cfg.get("pool", []))
	if _last_junk == "":
		return ""
	if not inventory.by_id.has(_last_junk):
		_last_junk = ""
	return _last_junk

## 决定宝箱里有什么。现在只有金币，按档位权重抽；以后有了物品栏，在这里加物品。
func _roll_chest() -> Dictionary:
	var tiers: Array = _chest_cfg.get("tiers", [])
	var total := 0.0
	for t in tiers:
		total += float(t["weight"])
	var r := _rng.randf() * total
	var pick: Dictionary = tiers[-1]
	for t in tiers:
		r -= float(t["weight"])
		if r < 0.0:
			pick = t
			break
	var gold := _rng.randi_range(int(pick["gold_min"]), int(pick["gold_max"]))
	var item := ""
	var item_chance := float(_chest_cfg.get("item_chance", 0.0))
	if item_chance > 0.0 and not inventory.defs.is_empty() and _rng.randf() < item_chance:
		item = inventory.roll(_rng, "chest")
	return {"tier": pick.get("name", ""), "gold": gold, "item": item}

## 覆盖宝箱的基础概率（测试和调试用）。
func set_chest_chance(p: float) -> void:
	_base_chest = clampf(p, 0.0, 1.0)
	_refresh_modifiers(_clock.now_ms())

## 小猫的床：休息时睡一觉（每段休息一次），睡醒后几分钟内更走运。
## 0 = 现在不是休息时间，1 = 可以睡，2 = 这段休息已经睡过了。
func nap_status() -> int:
	if not pomodoro.is_break():
		return 0
	return 2 if int(state.effects["napped_end_ms"]) == int(state.pomodoro["phase_end_ms"]) else 1

func nap() -> bool:
	if nap_status() != 1:
		return false
	var now: int = _clock.now_ms()
	var minutes := int(_cfg.get("nap", {}).get("lucky_minutes", 5))
	state.effects["napped_end_ms"] = int(state.pomodoro["phase_end_ms"])
	state.effects["lucky_until_ms"] = maxi(now, int(state.effects["lucky_until_ms"])) + minutes * 60000
	_refresh_modifiers(now)
	state.revision += 1
	dirty = true
	return true

func lucky_active() -> bool:
	return _clock.now_ms() < int(state.effects["lucky_until_ms"])

func lucky_remaining_ms() -> int:
	return maxi(0, int(state.effects["lucky_until_ms"]) - _clock.now_ms())

## 在家里把物品存进仓库 / 从仓库取出。all 为真时整堆搬。返回实际搬了几个。
func stash_item(id: String, all: bool = false) -> int:
	var n := inventory.stash(state, id, inventory.count(state, id) if all else 1)
	if n > 0:
		dirty = true
	return n

func fetch_item(id: String, all: bool = false) -> int:
	var n := inventory.fetch(state, id, inventory.count_w(state, id) if all else 1)
	if n > 0:
		dirty = true
	return n

## 使用一个物品。返回 {"ok": 是否用成, "use": 效果类型, "gold": 得到的金币（没有则为 0）}。
func use_item(id: String) -> Dictionary:
	if not inventory.can_use(state, id):
		return {"ok": false, "use": "", "gold": 0}
	var d: Dictionary = inventory.by_id[id]
	var now: int = _clock.now_ms()
	if str(d["use"]) == "bait":          # 鱼饵：装到钩上（下一竿起生效），不消耗
		state.equipped_bait = id
		state.revision += 1
		dirty = true
		return {"ok": true, "use": "bait", "gold": 0}
	if str(d["use"]) == "gear":          # 装备：装上，换下来的进物品栏
		var ok := equip_gear(id)
		return {"ok": ok, "use": "gear", "gold": 0, "quest": ""}
	inventory.consume(state, id)
	var gold := 0
	var quest := ""
	match str(d["use"]):
		"letter":
			# 漂流瓶：里面是任务的信；没有新任务就是空瓶，不再给钱（也不会再出现新的瓶子）
			quest = next_quest_letter()
			if quest != "":
				state.quests[quest] = "active"
		"gold":
			gold = _rng.randi_range(int(d["gold_min"]), int(d["gold_max"]))
			state.wallet_gold += gold
		"lucky":
			# 连着用会把时间接上去，而不是从现在重新算
			state.effects["lucky_until_ms"] = maxi(now, int(state.effects["lucky_until_ms"])) + int(d["minutes"]) * 60000
		"bell":
			state.effects["bell_sales"] = int(state.effects["bell_sales"]) + int(d["sales"])
	_refresh_modifiers(now)
	state.revision += 1
	dirty = true
	return {"ok": true, "use": str(d["use"]), "gold": gold, "quest": quest}

## 直接用仓库里的物品（不用先取出来，所以身上满了也能用）。装备：装上，换下来的进物品栏（放不下就进仓库）；
## 鱼饵：尽量取到身上再装上；其它：用掉一份。返回和 use_item 一样的字典。
func use_item_w(id: String) -> Dictionary:
	var d: Dictionary = inventory.by_id.get(id, {})
	var need := inventory.need(id)
	if d.is_empty() or str(d.get("use", "")) == "" or inventory.count_w(state, id) < need:
		return {"ok": false, "use": "", "gold": 0}
	if str(d["use"]) == "bait":
		if inventory.fetch(state, id, inventory.count_w(state, id)) <= 0:
			return {"ok": false, "use": "", "gold": 0}
		return use_item(id)
	# 先把要用的几份挪到身上（直接写，不受格子限制），用完马上就没了；用不成再原样放回去
	var left := inventory.count_w(state, id) - need
	if left > 0:
		state.warehouse[id] = left
	else:
		state.warehouse.erase(id)
	state.inventory[id] = inventory.count(state, id) + need
	var res := use_item(id)
	if not res["ok"]:
		state.inventory[id] = inventory.count(state, id) - need
		if int(state.inventory[id]) <= 0:
			state.inventory.erase(id)
		state.warehouse[id] = inventory.count_w(state, id) + need
	state.revision += 1
	dirty = true
	return res

## ---- 放进物品栏（放不下就扔掉，重要物品换掉不重要的）----
## 返回 "bag"（放进去了）/ "replaced"（重要物品顶掉了一件普通物品）/ "dropped"（放不下，扔掉了）/ "warehouse"
## （只有重要物品放不下、又没有普通物品可换时才会送仓库）。东西不会凭空传送进仓库。
## 重要物品：装备、以及 balance.json 里标了 "important": true 的任务物品。
func is_important(id: String) -> bool:
	var d: Dictionary = inventory.by_id.get(id, {})
	return str(d.get("use", "")) == "gear" or bool(d.get("important", false))

func give(id: String, n: int = 1, events: Array = []) -> String:
	var moved := inventory.room_for(state, id, n)
	if moved > 0:
		inventory.add(state, id, moved)
	if moved >= n:
		return "bag"
	var left := n - moved
	if is_important(id):
		# 格子满了：顶掉最普通的一种非重要物品（整格）
		var victim := ""
		var best := -1.0
		for k in state.inventory:
			if int(state.inventory[k]) > 0 and not is_important(str(k)):
				var w := float(inventory.by_id.get(k, {}).get("weight", 0))
				if w > best:
					best = w
					victim = str(k)
		if victim != "":
			# 只腾出刚好够用的格子：从被顶掉的那种物品里拿走最后几格，而不是整堆都扔
			var need := maxi(1, inventory.slots_of(id, inventory.count(state, id) + left) - inventory.slots_of(id, inventory.count(state, id)))
			var vleft := int(state.inventory[victim]) - need * inventory.stack_cap(victim)
			if vleft > 0:
				state.inventory[victim] = vleft
			else:
				state.inventory.erase(victim)
			inventory.add(state, id, left)
			state.revision += 1
			events.append({"type": "replaced", "item": id, "dropped": victim})
			_overflow_pending = "replaced"
			return "replaced"
		state.warehouse[id] = inventory.count_w(state, id) + left
		state.revision += 1
		events.append({"type": "overflow", "item": id})
		_overflow_pending = "warehouse"
		return "warehouse"
	state.revision += 1
	events.append({"type": "dropped", "item": id})
	_overflow_pending = "dropped"
	return "dropped"

var _overflow_pending: String = ""

## 钱包最多 999 金：超出的部分自动放进家里的存钱罐，并让界面提示"钱包满了"。
func _clamp_wallet() -> void:
	if state.wallet_gold > Money.WALLET_CAP:
		state.piggy += state.wallet_gold - Money.WALLET_CAP
		state.wallet_gold = Money.WALLET_CAP
		_wallet_full_pending = true
		state.revision += 1
		dirty = true

var _wallet_full_pending: bool = false

func take_wallet_full() -> bool:
	var r := _wallet_full_pending
	_wallet_full_pending = false
	return r

func wallet_is_full() -> bool:
	return state.wallet_gold >= Money.WALLET_CAP

## 存钱罐：钱包里有钱就全存进去；钱包空了就取出（取到钱包封顶为止）。返回 "deposit" / "withdraw" / ""。
func piggy_use() -> String:
	if state.wallet_gold > 0:
		state.piggy += state.wallet_gold
		state.wallet_gold = 0
		state.revision += 1
		dirty = true
		return "deposit"
	if state.piggy > 0:
		var n := mini(state.piggy, Money.WALLET_CAP)
		state.piggy -= n
		state.wallet_gold += n
		state.revision += 1
		dirty = true
		return "withdraw"
	return ""

## 界面每帧问一次：刚才有没有东西因为行李满了被送去仓库（问完清零，用来弹提示）。
func take_overflow() -> String:
	var r := _overflow_pending
	_overflow_pending = ""
	return r

## ---- 装备（鱼竿 / 鱼线 / 鱼钩都是物品，身上装一件，其余放物品栏或仓库）----
func _init_gear() -> void:
	for slot in ["rod", "line", "hook"]:
		if int(state.gear.get(slot, -1)) < 0:
			state.gear[slot] = int(state.upgrades.get(slot, 0)) if slot != "line" else 0

func _gear_def(id: String) -> Dictionary:
	var d: Dictionary = inventory.by_id.get(id, {})
	return d if str(d.get("use", "")) == "gear" else {}

## 得到一件新装备：比身上的好就直接装上（旧的进物品栏），否则放进物品栏。
func grant_gear(id: String) -> void:
	var d := _gear_def(id)
	if d.is_empty():
		return
	var slot := str(d["slot"])
	if int(d["level"]) > int(state.gear.get(slot, 0)):
		var old := "%s_%d" % [slot, int(state.gear.get(slot, 0))]
		state.gear[slot] = int(d["level"])
		give(old)
	else:
		give(id)
	state.revision += 1
	dirty = true

## 装上物品栏里的一件装备，身上原来的那件换回物品栏。
func equip_gear(id: String) -> bool:
	var d := _gear_def(id)
	if d.is_empty() or inventory.count(state, id) <= 0:
		return false
	var slot := str(d["slot"])
	var old := "%s_%d" % [slot, int(state.gear.get(slot, 0))]
	inventory.remove(state, id, 1)
	state.gear[slot] = int(d["level"])
	give(old)
	_apply_upgrades()
	state.revision += 1
	dirty = true
	return true

## 装备的属性：返回 [属性名, 数值文字]；不是装备或没有属性返回 []。
## 鱼竿：自由挂机时的等待倍率（越小越快）；鱼钩：稀有鱼加成；鱼线：暂时没有属性。
func gear_stat(id: String) -> Array:
	var d: Dictionary = inventory.by_id.get(id, {})
	if str(d.get("use", "")) != "gear":
		return []
	var lv := int(d.get("level", 0))
	match str(d.get("slot", "")):
		"rod":
			var table: Array = _cfg.get("upgrades", {}).get("rod", {}).get("free_wait_multipliers", [])
			if lv >= 0 and lv < table.size():
				return ["挂机速度", "+%d％" % int(round((float(table[0]) / float(table[lv]) - 1.0) * 100.0))]      # 比最差的鱼竿快多少
		"hook":
			var hb: Array = _cfg.get("hook_wait_mult", [])
			if lv >= 0 and lv < hb.size():
				return ["咬钩速度", "+%d％" % int(round((1.0 / float(hb[lv]) - 1.0) * 100.0))]
		"line":
			return ["暂无加成", ""]
	return []

## 卖一个物品（背包里的普通物品；关键物品、装备不能卖）。返回得到的铜币，卖不了返回 0。
func sell_price(id: String) -> int:
	var d: Dictionary = inventory.by_id.get(id, {})
	if d.is_empty() or bool(d.get("important", false)) or str(d.get("use", "")) == "gear":
		return 0
	return int(d.get("sell", 0))

func sell_item(id: String) -> int:
	var price := sell_price(id)
	if price <= 0 or inventory.count(state, id) <= 0:
		return 0
	if not inventory.remove(state, id, 1):
		return 0
	economy.grant_gold(state, state.new_id("s"), price)
	_clamp_wallet()
	dirty = true
	return price

## 一次性的礼物（balance.gift）：每个礼物 id 只发一次，存档里用 effects["gift_<id>"] 记着。返回是否发了。
func apply_gift() -> bool:
	var g: Dictionary = _cfg.get("gift", {})
	var key := "gift_%s" % str(g.get("id", ""))
	if g.is_empty() or not state.effects.has(key) or int(state.effects[key]) != 0:
		return false
	state.effects[key] = 1
	economy.grant_gold(state, "gift_%s" % str(g["id"]), int(g.get("copper", 0)))
	_clamp_wallet()
	for id in g.get("items", {}):
		var n := int(g["items"][id])
		if give(str(id), n) == "":
			pass
	state.revision += 1
	dirty = true
	return true

## 只在有任务需要时才会出现的物品：没有任务要它，就不会捡到、钓到、收到。
const QUEST_ONLY := ["bottle", "diary_page"]

func item_wanted(id: String) -> bool:
	if not QUEST_ONLY.has(id):
		return true
	if id == "bottle" and next_quest_letter() != "":
		return true
	for q in _quest_cfg_list():
		var qid := str(q["id"])
		if quest_state(qid) != "active":
			continue
		for n in quest_needs(qid):
			if str(n[0]) == id and int(n[1]) < int(n[2]):
				return true
	return false

## 按权重从 [[id, 权重], ...] 里抽一个；任务才用得到的物品没人要时跳过。池子空了返回 ""。
func _pick_pool(pool: Array) -> String:
	var total := 0.0
	for e in pool:
		if item_wanted(str(e[0])):
			total += float(e[1])
	if total <= 0.0:
		return ""
	var r := _rng.randf() * total
	var last := ""
	for e in pool:
		if not item_wanted(str(e[0])):
			continue
		last = str(e[0])
		r -= float(e[1])
		if r < 0.0:
			return last
	return last

## 下一封漂流瓶里的信是哪个任务（前置任务没完成的不出，没有了返回 ""）。
func next_quest_letter() -> String:
	for q in _quest_cfg_list():
		var id := str(q["id"])
		if quest_state(id) != "":
			continue
		if bool(q.get("start_on_talk", false)):      # 当面接的任务（灯塔看守），漂流瓶里不会出现
			continue
		var req := str(q.get("requires", ""))
		if req != "" and quest_state(req) != "done":
			continue
		return id
	return ""

## 这间屋子里的店主该和玩家说哪个任务：进行中的 > 最近完成的 > 还没开始的。
func room_quest(kind: String) -> String:
	var started := ""
	var idle := ""
	var done := ""
	for q in _quest_cfg_list():
		if str(q.get("npc", "")) != kind:
			continue
		var id := str(q["id"])
		match quest_state(id):
			"active":
				started = id
			"done":
				done = id
			_:
				if idle == "":
					idle = id
	return started if started != "" else (idle if idle != "" else done)

## 店主平常说的话（没有进行中的任务、任务也都交付完了的时候）。
func shop_chat(npc: String) -> Array:
	return _cfg.get("shop_chat", {}).get(npc, [])

## ---- 支线任务（数据在 balance.json 的 quests） ----
func _quest_cfg_list() -> Array:
	return _cfg.get("quests", [])

func quest_cfg(id: String) -> Dictionary:
	for q in _quest_cfg_list():
		if str(q["id"]) == id:
			return q
	return {}

## "" = 还没开始，"active" = 进行中，"done" = 完成。
func quest_state(id: String) -> String:
	return str(state.quests.get(id, ""))

## 每项要求的 [物品 id, 手里有几个, 需要几个]。
func quest_needs(id: String) -> Array:
	var out: Array = []
	for w in quest_cfg(id).get("wants", []):
		out.append([str(w["item"]), inventory.count(state, str(w["item"])), int(w["n"])])
	return out

## 和 NPC 当面聊起一个"当面接"的任务：还没开始就接下来。
func begin_talk_quest(id: String) -> void:
	var q := quest_cfg(id)
	if q.is_empty() or not bool(q.get("start_on_talk", false)) or quest_state(id) != "":
		return
	state.quests[id] = "active"
	state.revision += 1
	dirty = true

func can_turn_in(id: String) -> bool:
	if quest_state(id) != "active":
		return false
	for n in quest_needs(id):
		if int(n[1]) < int(n[2]):
			return false
	return true

## 交付：扣物品、给奖励（新鱼钩）。只能成功一次。
func turn_in(id: String) -> bool:
	if not can_turn_in(id):
		return false
	for n in quest_needs(id):
		inventory.remove(state, str(n[0]), int(n[2]))
	state.quests[id] = "done"
	var qc: Dictionary = quest_cfg(id)
	if str(qc.get("reward_item", "")) != "":
		grant_gear(str(qc["reward_item"]))
	if str(qc.get("reward_give", "")) != "":
		give(str(qc["reward_give"]), 1)
	if int(qc.get("reward_slots", 0)) > 0:
		state.bag_slots += int(qc["reward_slots"])
	if int(qc.get("reward_gold", 0)) > 0:
		economy.grant_gold(state, "q_" + id, int(qc["reward_gold"]))
	if str(qc.get("reward_flag", "")) != "":
		state.effects[str(qc["reward_flag"])] = 1
	_apply_upgrades()
	state.revision += 1
	dirty = true
	return true

## 幸运鱼饵生效期间：稀有鱼权重更高、宝箱概率翻倍。
func _refresh_modifiers(now: int) -> void:
	var lucky := now < int(state.effects["lucky_until_ms"])
	var d: Dictionary = inventory.by_id.get("lucky_bait", {})
	fishing.rarity_bonus = _base_rarity + (float(d.get("rarity_bonus", 0.0)) if lucky else 0.0)
	var rain_chest := _rain_cfg("rain_chest_mult", 1.0) if _raining else 1.0
	var focus_luck := float(_cfg["fishing"].get("focus_luck_mult", 1.0)) if in_focus() else 1.0
	fishing.luck_mult = focus_luck
	fishing.chest_chance = minf(1.0, _base_chest * (float(d.get("chest_mult", 1.0)) if lucky else 1.0) * rain_chest * focus_luck)

func _finish_focus(is_long: bool) -> Dictionary:
	var pc: Dictionary = _pomo_cfg
	var count := state.session_haul.size()
	var bonus := int(pc["focus_flat_bonus"]) + (int(pc["long_break_bonus"]) if is_long else 0)
	var gold := economy.settle_haul(state, state.new_id("s"), float(pc["focus_gold_multiplier"]), bonus)
	state.stats["total_pomodoros"] = int(state.stats["total_pomodoros"]) + 1
	var daily: Dictionary = state.stats["daily"]
	var key: String = _clock.today_key()
	daily[key] = int(daily.get(key, 0)) + 1
	_record_focus_hours(key, duration("focus_min"))
	dirty = true
	return {"type": "focus_done", "gold": gold, "fish_count": count, "long": is_long}

## 把这次专注的时长按小时记下来（统计页的按小时柱状图用）。以现在为终点往前推 dur_min 分钟，只记当天的部分；单位是秒。
func _record_focus_hours(day_key: String, dur_min: int) -> void:
	var end_s: int = _clock.local_s() % 86400
	var start_s: int = maxi(0, end_s - dur_min * 60)
	var all: Dictionary = state.stats["focus_hours"]
	var hours: Array = all.get(day_key, [])
	if hours.size() != 24:
		hours = []
		for h in 24:
			hours.append(0)
	for h in 24:
		var o := mini(end_s, (h + 1) * 3600) - maxi(start_s, h * 3600)
		if o > 0:
			hours[h] = int(hours[h]) + o
	all[day_key] = hours
	while all.size() > 400:                  # 只留最近 400 天
		var oldest := ""
		for k in all:
			if oldest == "" or String(k) < oldest:
				oldest = String(k)
		all.erase(oldest)

## 某天每个小时的专注秒数（没有记录就全是 0）。
func focus_hours_of(day_key: String) -> Array:
	var hours: Array = state.stats["focus_hours"].get(day_key, [])
	var out: Array = []
	for h in 24:
		out.append(int(hours[h]) if hours.size() == 24 else 0)
	return out

## 同上，但当天正在进行的专注也算进去（只算到现在为止的那一段）。
func focus_hours_live(day_key: String) -> Array:
	var out: Array = focus_hours_of(day_key)
	if day_key != _clock.today_key() or not in_focus():
		return out
	var now: int = _clock.now_ms()
	var elapsed_s: int = maxi(0, duration("focus_min") * 60 - int(pomodoro.remaining_ms(now) / 1000))
	var end_s: int = _clock.local_s() % 86400
	var start_s: int = maxi(0, end_s - elapsed_s)
	for h in 24:
		var o := mini(end_s, (h + 1) * 3600) - maxi(start_s, h * 3600)
		if o > 0:
			out[h] = int(out[h]) + o
	return out

## ---- 帽子店 / 服装店 ----
## data/cat.json 的内容，由表现层交给 Game（价格在里面）。kind: "hat" 或 "outfit"。
var cat_cfg: Dictionary = {}

func set_cat_cfg(cfg: Dictionary) -> void:
	cat_cfg = cfg
	# 老存档：现在戴着的帽子、穿着的衣服一定算已拥有
	_own_add("hat", int(state.cat.get("hat", 0)))
	_own_add("outfit", int(state.cat.get("outfit", 0)))

func cat_items(kind: String) -> Array:
	return cat_cfg.get("hats" if kind == "hat" else "outfits", [])

func _own_key(kind: String) -> String:
	return "own_hats" if kind == "hat" else "own_outfits"

func _own_add(kind: String, idx: int) -> void:
	var own: Array = state.cat[_own_key(kind)]
	for v in own:
		if int(v) == idx:
			return
	own.append(idx)

func cat_price(kind: String, idx: int) -> int:
	var list := cat_items(kind)
	return int(list[idx].get("price", 0)) if idx >= 0 and idx < list.size() else 0

func cat_owns(kind: String, idx: int) -> bool:
	if idx < 0 or idx >= cat_items(kind).size():
		return false
	if cat_price(kind, idx) <= 0:
		return true
	for v in state.cat[_own_key(kind)]:
		if int(v) == idx:
			return true
	return false

func cat_wearing(kind: String, idx: int) -> bool:
	return int(state.cat.get(kind, 0)) == idx

## 买下。已经拥有或钱不够都不会扣钱（重复提交不会重复生效）。
func buy_cat_item(kind: String, idx: int) -> bool:
	if cat_owns(kind, idx) or idx < 0 or idx >= cat_items(kind).size():
		return false
	var price := cat_price(kind, idx)
	if state.wallet_gold < price:
		return false
	state.wallet_gold -= price
	_own_add(kind, idx)
	dirty = true
	return true

## 穿上 / 戴上（必须已经拥有）。
func wear_cat_item(kind: String, idx: int) -> bool:
	if not cat_owns(kind, idx):
		return false
	state.cat[kind] = idx
	dirty = true
	return true

## ---- 渔具店买鱼饵 ----
func shop_baits() -> Array:
	var out: Array = []
	for d in inventory.defs:
		if str(d.get("use", "")) == "bait" and int(d.get("price", 0)) > 0:
			out.append(d["id"])
	return out

func bait_unlocked(id: String) -> bool:
	var d: Dictionary = inventory.by_id.get(id, {})
	return int(state.stats["total_fish"]) >= int(d.get("unlock_fish", 0))

func can_buy_bait(id: String) -> bool:
	var d: Dictionary = inventory.by_id.get(id, {})
	return not d.is_empty() and bait_unlocked(id) and state.wallet_gold >= int(d.get("price", 0)) and int(d.get("price", 0)) > 0 \
			and inventory.room_for(state, id, 1) > 0

func buy_bait(id: String) -> bool:
	if not can_buy_bait(id):
		return false
	state.wallet_gold -= int(inventory.by_id[id]["price"])
	inventory.add(state, id)
	dirty = true
	return true

func _clamp_setting(key: String, v: int) -> int:
	var lim: Array = _cfg.get("settings_limits", {}).get(key, [1, 120, 1])
	return clampi(v, int(lim[0]), int(lim[1]))

func _apply_upgrades() -> void:
	state.basket_capacity = _base_capacity + float(upgrades.level(state, "basket")) * float(upgrades.param("basket", "capacity_per_level", 0))
	var hook_mult: Array = _cfg.get("hook_wait_mult", [])
	var hook_lv := int(state.gear.get("hook", 0))
	_base_rarity = 0.0
	fishing.rarity_bonus = _base_rarity
	fishing.gear_wait_mult = maxf(0.3, 1.0 - float(upgrades.level(state, "bait")) * float(upgrades.param("bait", "wait_mult_per_level", 0.0))) * (float(hook_mult[hook_lv]) if hook_lv >= 0 and hook_lv < hook_mult.size() else 1.0)
	_free_multiplier = float(_cfg["fishing"]["free_wait_multiplier"])
	if upgrades.has("rod"):
		var table: Array = _cfg["upgrades"]["rod"].get("free_wait_multipliers", [])
		var lv := int(state.gear.get("rod", 0))
		if lv >= 0 and lv < table.size():
			_free_multiplier = float(table[lv])
