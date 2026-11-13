extends SceneTree
## 长时间稳定性模拟（原需求里的"8 小时"）。运行:
##   godot --headless --path . --script res://tests/sim_long_run.gd
## 用假时钟快进 8 小时游戏时间，期间随机做玩家会做的各种操作，
## 每一步检查不变量，并定期做一次"存档 → 读档 → 用读出来的状态继续"。
## 这验证的是逻辑层不会跑偏；真实窗口连续开 8 小时的验收仍需在 Mac 上人工进行。

const Game := preload("res://core/game.gd")
const GameState := preload("res://core/game_state.gd")
const Journey := preload("res://core/journey.gd")
const Fishing := preload("res://core/fishing_system.gd")
const ConfigLoader := preload("res://io/config_loader.gd")
const SaveService := preload("res://io/save_service.gd")

const HOURS := 8.0
const STEP_MS := 200

class FakeClock:
	var t: int = 1_700_000_000_000
	func now_ms() -> int: return t
	func today_key() -> String: return "2026-01-0%d" % (1 + int((t - 1_700_000_000_000) / 14_400_000))

var fails: Array = []

func require(cond: bool, what: String, tick: int) -> void:
	if not cond and fails.size() < 10:
		fails.append("tick %d: %s" % [tick, what])

func _init() -> void:
	var balance := ConfigLoader.load_balance()
	var fish := ConfigLoader.load_fish()
	var clock := FakeClock.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 20261112
	var act := RandomNumberGenerator.new(); act.seed = 7
	var saver := SaveService.new("user://sim_save.json")
	var g := Game.new(balance, fish, GameState.new(), clock, rng)
	var counts := {}
	var gold_in := 0          # 所有事件里报告的收入
	var spent := 0
	var reloads := 0
	var max_jump_catch := 0
	var ticks := int(HOURS * 3600.0 * 1000.0 / STEP_MS)
	for i in ticks:
		clock.t += STEP_MS
		# ---- 随机操作 ----
		var r := act.randf()
		if r < 0.0004:
			g.start_focus()
		elif r < 0.00045:
			var got := g.abandon_focus()
			if got > 0: gold_in += got
		elif r < 0.0006:
			g.skip_break()
		elif r < 0.0007:
			g.go_to_town()
		elif r < 0.0023:
			var id: String = ["rod", "bait", "basket"][act.randi() % 3]
			var cost: int = g.upgrades.next_cost(g.state, id)
			if g.buy_upgrade(id): spent += cost
		elif r < 0.0026:
			g.adjust_duration(["focus_min", "short_break_min", "long_break_min"][act.randi() % 3], 1 if act.randf() < 0.5 else -1)
		elif r < 0.003:
			if g.begin_roam(760): g.journey.set_roam_x(act.randi_range(548, 1000))
		elif r < 0.0045:
			g.end_roam(act.randf(), act.randf())
		elif r < 0.0047:
			g.roam_board(act.randf())
		elif r < 0.00475:
			clock.t += act.randi_range(60_000, 3 * 3600_000)    # 电脑睡了一觉
		# ---- 推进 ----
		var before_fish: int = int(g.state.stats["total_fish"])
		for e in g.tick():
			counts[e["type"]] = counts.get(e["type"], 0) + 1
			if e["type"] in ["sale", "focus_done", "chest"]:
				gold_in += int(e["gold"])
		max_jump_catch = maxi(max_jump_catch, int(g.state.stats["total_fish"]) - before_fish)
		# ---- 不变量 ----
		var s := g.state
		require(s.wallet_gold >= 0, "金币为负", i)
		require(s.wallet_gold == gold_in - spent, "金币对不上账: 钱包 %d, 收入 %d, 支出 %d" % [s.wallet_gold, gold_in, spent], i)
		require(s.basket.size() <= s.basket_capacity, "鱼篓超容量 %d/%d" % [s.basket.size(), s.basket_capacity], i)
		require(s.processed_catch_ids.size() <= GameState.MAX_PROCESSED_IDS and s.processed_sale_ids.size() <= GameState.MAX_PROCESSED_IDS, "幂等记录无限增长", i)
		require(g.journey.activity() >= 0 and g.journey.activity() <= Journey.Activity.ROAM, "未知活动状态", i)
		require(g.journey.on_boat() or not g.fishing.is_active(), "人在镇上却在钓鱼", i)
		require(not (g.pomodoro.is_break() and g.fishing.is_active()), "休息时还在钓鱼", i)
		require(g.in_focus() or s.session_haul.is_empty(), "不在专注但木箱里有鱼", i)
		if i % 5000 == 0:
			var sum := 0
			for k in s.stats["fish_counts"]:
				sum += int(s.stats["fish_counts"][k])
			require(sum == int(s.stats["total_fish"]), "图鉴计数与总数不一致", i)
		# ---- 定期存读档，用读回来的状态接着跑 ----
		if i % 9973 == 0:
			require(saver.save(s.to_dict()), "存档失败", i)
			var s2 := GameState.new()
			require(s2.from_dict(saver.load_data()), "读档失败", i)
			require(JSON.stringify(s2.to_dict()) == JSON.stringify(JSON.parse_string(JSON.stringify(s.to_dict()))) or s2.wallet_gold == s.wallet_gold, "读档后状态不一致", i)
			g = Game.new(balance, fish, s2, clock, rng)
			reloads += 1
	require(max_jump_catch <= 1, "单步出现多条鱼（时间跳跃后补钓）", ticks)
	var dir := DirAccess.open("user://")
	for p in ["sim_save.json", "sim_save.json.bak"]:
		dir.remove(p)
	print("模拟 %.0f 小时游戏时间, %d 步, 存读档 %d 次" % [HOURS, ticks, reloads])
	print("事件统计: ", counts)
	print("结束时: 金币 %d, 累计钓鱼 %d, 番茄 %d, 升级 %s" % [g.state.wallet_gold, g.state.stats["total_fish"], g.state.stats["total_pomodoros"], str(g.state.upgrades)])
	for f in fails:
		print("  FAIL ", f)
	if fails.is_empty():
		print("SIM PASS")
	quit(0 if fails.is_empty() else 1)
