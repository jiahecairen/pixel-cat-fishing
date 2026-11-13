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
var dirty: bool = false     # 有需要落盘的变化

var _clock
var _cfg: Dictionary
var _pomo_cfg: Dictionary
var _base_capacity: int = 10
var _free_multiplier: float = 2.0
var _last_cp_state: int = 0
var _rng: RandomNumberGenerator
var _chest_cfg: Dictionary = {}
var _base_chest: float = 0.0     # 宝箱基础概率（幸运鱼饵生效时翻倍）
var _base_rarity: float = 0.0    # 鱼饵升级带来的稀有度加成（幸运鱼饵生效时再加）

func _init(balance: Dictionary, fish_table: Array, game_state: GameState, clock, rng: RandomNumberGenerator) -> void:
	_cfg = balance
	_clock = clock
	state = game_state
	_base_capacity = int(balance.get("basket_capacity", 10))
	fish_list = fish_table
	for f in fish_table:
		fish_by_id[f["id"]] = f
	economy = Economy.new(fish_table)
	fishing = FishingSystem.new(balance["fishing"], fish_table, rng)
	_rng = rng
	_chest_cfg = balance.get("chest", {})
	_base_chest = float(_chest_cfg.get("chance", 0.0)) if not _chest_cfg.get("tiers", []).is_empty() else 0.0
	fishing.chest_chance = _base_chest
	inventory = Inventory.new(balance.get("items", []))
	journey = Journey.new(state.journey, balance["town"], rng)
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
	# 钓鱼状态一变就更新断点（状态切换不频繁，不会造成频繁写盘）
	if fishing.state != _last_cp_state:
		_last_cp_state = fishing.state
		state.fishing_checkpoint = fishing.checkpoint()
		dirty = true
	return events

func _tick() -> Array:
	var now: int = _clock.now_ms()
	var events: Array = []
	_refresh_modifiers(now)

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
		if int(state.effects["lucky_until_ms"]) > 0:      # 休息不消耗幸运鱼饵的时间
			state.effects["lucky_until_ms"] = int(state.effects["lucky_until_ms"]) + paused_for
		state.journey["paused_at_ms"] = 0
		dirty = true

	match journey.activity():
		Journey.Activity.FISHING:
			_tick_fishing(now, events)
		Journey.Activity.IDLE_FULL:
			_tick_idle_full(now, events)
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
func end_roam(fraction_to_stall: float, fraction_to_boat: float) -> void:
	var to_stall := not state.basket.is_empty()
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
	return journey.can_depart() and not state.basket.is_empty() and not pomodoro.is_break()

## 让小猫出发去小镇卖鱼（鱼篓没满也可以提前去）。
func go_to_town() -> bool:
	if not can_go_to_town():
		return false
	var now: int = _clock.now_ms()
	fishing.stop(now)
	journey.depart(now)
	dirty = true
	return true

func buy_upgrade(id: String) -> bool:
	if not upgrades.buy(state, id):
		return false
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
	fishing.wait_multiplier = 1.0 if focus else _free_multiplier
	if not focus and economy.basket_full(state):
		# 让最后一条鱼的结算动画播完再收竿
		if fishing.is_active() and fishing.state == FishingSystem.State.SETTLEMENT:
			fishing.advance(now)
			return
		fishing.stop(now)
		journey.set_full(now)
		events.append({"type": "basket_full"})
		dirty = true
		return
	if not fishing.is_active():
		fishing.start(now)
	var fish_id := fishing.advance(now)
	if fish_id == FishingSystem.CHEST:
		var loot := _roll_chest()
		if economy.open_chest(state, state.new_id("c"), int(loot["gold"])):
			if loot["item"] != "":
				inventory.add(state, loot["item"])
			events.append({"type": "chest", "gold": loot["gold"], "tier": loot["tier"], "item": loot["item"]})
			dirty = true
	elif fish_id != "" and economy.add_catch(state, state.new_id("c"), fish_id, focus):
		events.append({"type": "catch", "fish_id": fish_id})
		dirty = true

func _tick_idle_full(now: int, events: Array) -> void:
	if in_focus() or not economy.basket_full(state):   # 专注：鱼进木箱，满篓也接着钓
		journey.resume_fishing(now)   # 例如刚升级了鱼篓容量
		dirty = true
	elif journey.advance(now) == "eat":
		var eaten := economy.eat_cheapest(state)
		if eaten != "":
			events.append({"type": "ate", "fish_id": eaten})
			journey.resume_fishing(now)
		dirty = true

func _tick_trip(now: int, events: Array) -> void:
	var r := journey.advance(now)
	if r == "":
		return
	dirty = true
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
				journey.leave_stall(now)
				events.append({"type": "sold_out"})
			else:
				journey.schedule_next_sale(now)
		"open":
			if state.basket.is_empty():
				journey.leave_stall(now)
			events.append({"type": "open"})
		_:
			events.append({"type": r})

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
		item = inventory.roll(_rng)
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

## 使用一个物品。返回 {"ok": 是否用成, "use": 效果类型, "gold": 得到的金币（没有则为 0）}。
func use_item(id: String) -> Dictionary:
	if not inventory.can_use(state, id):
		return {"ok": false, "use": "", "gold": 0}
	var d: Dictionary = inventory.by_id[id]
	var now: int = _clock.now_ms()
	inventory.consume(state, id)
	var gold := 0
	match str(d["use"]):
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
	return {"ok": true, "use": str(d["use"]), "gold": gold}

## 幸运鱼饵生效期间：稀有鱼权重更高、宝箱概率翻倍。
func _refresh_modifiers(now: int) -> void:
	var lucky := now < int(state.effects["lucky_until_ms"])
	var d: Dictionary = inventory.by_id.get("lucky_bait", {})
	fishing.rarity_bonus = _base_rarity + (float(d.get("rarity_bonus", 0.0)) if lucky else 0.0)
	fishing.chest_chance = minf(1.0, _base_chest * (float(d.get("chest_mult", 1.0)) if lucky else 1.0))

func _finish_focus(is_long: bool) -> Dictionary:
	var pc: Dictionary = _pomo_cfg
	var count := state.session_haul.size()
	var bonus := int(pc["focus_flat_bonus"]) + (int(pc["long_break_bonus"]) if is_long else 0)
	var gold := economy.settle_haul(state, state.new_id("s"), float(pc["focus_gold_multiplier"]), bonus)
	state.stats["total_pomodoros"] = int(state.stats["total_pomodoros"]) + 1
	var daily: Dictionary = state.stats["daily"]
	var key: String = _clock.today_key()
	daily[key] = int(daily.get(key, 0)) + 1
	dirty = true
	return {"type": "focus_done", "gold": gold, "fish_count": count, "long": is_long}

func _clamp_setting(key: String, v: int) -> int:
	var lim: Array = _cfg.get("settings_limits", {}).get(key, [1, 120, 1])
	return clampi(v, int(lim[0]), int(lim[1]))

func _apply_upgrades() -> void:
	state.basket_capacity = _base_capacity + upgrades.level(state, "basket") * int(upgrades.param("basket", "capacity_per_level", 0))
	_base_rarity = upgrades.level(state, "bait") * upgrades.param("bait", "rarity_bonus_per_level", 0.0)
	fishing.rarity_bonus = _base_rarity
	_free_multiplier = float(_cfg["fishing"]["free_wait_multiplier"])
	if upgrades.has("rod"):
		var table: Array = _cfg["upgrades"]["rod"].get("free_wait_multipliers", [])
		var lv := upgrades.level(state, "rod")
		if lv < table.size():
			_free_multiplier = float(table[lv])
