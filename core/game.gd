extends RefCounted
## 游戏总控（纯逻辑，不依赖任何节点/窗口）。表现层每帧调用 tick()，按返回的事件做动画。
##
## 三种模式：
##   专注(FOCUS)  小猫正常速度钓鱼，鱼进"番茄渔获"，完成番茄后加成结算
##   休息(BREAK)  小猫打盹，不钓鱼
##   自由(IDLE)   小猫慢速钓鱼，鱼进鱼篓（容量有限，满了就停，需要手动卖）

const GameState := preload("res://core/game_state.gd")
const Economy := preload("res://core/economy.gd")
const FishingSystem := preload("res://core/fishing_system.gd")
const Pomodoro := preload("res://core/pomodoro.gd")

var state: GameState
var economy: Economy
var fishing: FishingSystem
var pomodoro: Pomodoro
var fish_by_id: Dictionary = {}
var dirty: bool = false     # 有需要落盘的变化

var _clock
var _cfg: Dictionary

func _init(balance: Dictionary, fish_table: Array, game_state: GameState, clock, rng: RandomNumberGenerator) -> void:
	_cfg = balance
	_clock = clock
	state = game_state
	state.basket_capacity = int(balance.get("basket_capacity", state.basket_capacity))
	for f in fish_table:
		fish_by_id[f["id"]] = f
	economy = Economy.new(fish_table)
	fishing = FishingSystem.new(balance["fishing"], fish_table, rng)
	pomodoro = Pomodoro.new(state.pomodoro, balance["pomodoro"])

func now_ms() -> int:
	return _clock.now_ms()

func in_focus() -> bool:
	return pomodoro.phase() == Pomodoro.Phase.FOCUS

func tick() -> Array:
	var now: int = _clock.now_ms()
	var events: Array = []

	var p := pomodoro.tick(now)
	if p == "focus_done" or p == "focus_done_long":
		events.append(_finish_focus(p == "focus_done_long"))
	elif p == "break_done":
		events.append({"type": "break_done"})
		dirty = true

	_sync_fishing(now, events)

	var fish_id := fishing.advance(now)
	if fish_id != "":
		if economy.add_catch(state, state.new_id("c"), fish_id, in_focus()):
			events.append({"type": "catch", "fish_id": fish_id})
			dirty = true
	return events

func start_focus() -> bool:
	var now: int = _clock.now_ms()
	if not pomodoro.start_focus(now):
		return false
	fishing.stop(now)   # 重新抛竿，让专注从干净的一竿开始
	dirty = true
	return true

## 放弃专注：已钓的鱼按原价结算，没有完成奖励。
func abandon_focus() -> int:
	if not pomodoro.abandon(_clock.now_ms()):
		return -1
	dirty = true
	return economy.settle_haul(state, state.new_id("s"), 1.0, 0)

func skip_break() -> bool:
	if pomodoro.skip_break():
		dirty = true
		return true
	return false

func sell_basket() -> int:
	var gold := economy.sell_basket(state, state.new_id("s"))
	if gold > 0:
		dirty = true
	return gold

func _finish_focus(is_long: bool) -> Dictionary:
	var pc: Dictionary = _cfg["pomodoro"]
	var count := state.session_haul.size()
	var bonus := int(pc["focus_flat_bonus"]) + (int(pc["long_break_bonus"]) if is_long else 0)
	var gold := economy.settle_haul(state, state.new_id("s"), float(pc["focus_gold_multiplier"]), bonus)
	state.stats["total_pomodoros"] = int(state.stats["total_pomodoros"]) + 1
	var daily: Dictionary = state.stats["daily"]
	var key: String = _clock.today_key()
	daily[key] = int(daily.get(key, 0)) + 1
	dirty = true
	return {"type": "focus_done", "gold": gold, "fish_count": count, "long": is_long}

func _sync_fishing(now: int, events: Array) -> void:
	var should_fish := true
	if pomodoro.is_break():
		should_fish = false
	elif not in_focus() and economy.basket_full(state):
		should_fish = false
	fishing.wait_multiplier = 1.0 if in_focus() else float(_cfg["fishing"]["free_wait_multiplier"])
	if should_fish and not fishing.is_active():
		fishing.start(now)
	elif not should_fish and fishing.is_active():
		# 鱼篓满时让当前这一竿的结算动画播完再停
		if pomodoro.is_break() or fishing.state != FishingSystem.State.SETTLEMENT:
			fishing.stop(now)
			if not pomodoro.is_break():
				events.append({"type": "basket_full"})
