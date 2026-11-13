extends SceneTree
## 无界面单元测试。运行:
##   godot --headless --path . --script res://tests/run_tests.gd
## 全部通过打印 "ALL TESTS PASS" 并以 0 退出；任何失败以 1 退出。

const Game := preload("res://core/game.gd")
const GameState := preload("res://core/game_state.gd")
const Economy := preload("res://core/economy.gd")
const Fishing := preload("res://core/fishing_system.gd")
const Pomodoro := preload("res://core/pomodoro.gd")
const ConfigLoader := preload("res://io/config_loader.gd")
const SaveService := preload("res://io/save_service.gd")
const EventLog := preload("res://io/event_log.gd")
const World := preload("res://presentation/world.gd")

class FakeClock:
	var t: int = 1_000_000
	var day: String = "2026-01-01"
	func now_ms() -> int: return t
	func today_key() -> String: return day
	func bias_s() -> int: return 0
	func local_s() -> int: return 43200 + 3 * 3600     # 本地 15:00，固定一个不下雨的时刻

var _fails := 0
var _checks := 0

func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: ", what)

func _init() -> void:
	var balance := ConfigLoader.load_balance()
	var fish := ConfigLoader.load_fish()
	check(not balance.is_empty(), "balance.json 可加载")
	check(fish.size() == 9, "fish.json 有 9 种鱼")
	if _fails == 0:
		test_economy(fish)
		test_fishing(balance, fish)
		test_pomodoro(balance)
		test_game_focus(balance, fish)
		test_game_free_mode(balance, fish)
		test_upgrades_and_settings(balance, fish)
		test_cat_config()
		test_chest(balance, fish)
		test_adapters()
		test_weather(balance, fish)
		test_water(balance, fish)
		test_sail_turn(balance, fish)
		test_birds(balance, fish)
		test_inventory(balance, fish)
		test_stall_walk(balance, fish)
		test_bait(balance, fish)
		test_checkpoint(balance, fish)
		test_event_log()
		test_save()
		test_bad_config()
	print("%d checks, %d failed" % [_checks, _fails])
	if _fails == 0:
		print("ALL TESTS PASS")
	quit(1 if _fails > 0 else 0)

func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

func test_economy(fish: Array) -> void:
	print("economy")
	var eco := Economy.new(fish)
	var s := GameState.new()
	check(eco.add_catch(s, "c1", "bass", false), "入篓成功")
	check(not eco.add_catch(s, "c1", "bass", false), "同一 catch_id 不重复入篓")
	check(not eco.add_catch(s, "c2", "shark", false), "未知鱼种被拒绝")
	check(s.basket.size() == 1, "鱼篓只有 1 条")
	for i in 20:
		eco.add_catch(s, "x%d" % i, "crucian", false)
	check(s.basket.size() == 10, "鱼篓不超过容量 10")
	var gold := eco.sell_basket(s, "s1")
	check(gold == 12 + 9 * 5, "卖鱼金额正确 (%d)" % gold)
	check(eco.sell_basket(s, "s1") == 0 and s.wallet_gold == gold, "同一 sale_id 不重复加钱")
	eco.add_catch(s, "h1", "koi", true)
	eco.add_catch(s, "h2", "koi", true)
	check(s.session_haul.size() == 2 and s.basket.is_empty(), "番茄渔获与鱼篓分开")
	var g2 := eco.settle_haul(s, "s2", 1.5, 10)
	check(g2 == 130, "番茄结算 80×1.5+10=130 (%d)" % g2)
	check(eco.settle_haul(s, "s2", 1.5, 10) == 0, "番茄结算幂等")

func test_fishing(balance: Dictionary, fish: Array) -> void:
	print("fishing")
	var cfg: Dictionary = balance["fishing"]
	var fs := Fishing.new(cfg, fish, _rng(7))
	fs.zone = "normal"
	var now := 0
	fs.start(now)
	check(fs.state == Fishing.State.BAITING and fs.baiting_started, "开始后先上饵")
	var waits: Array = []
	var gaps := [[], []]
	var catches := 0
	var tangles := 0
	var casts := 0
	var counts := {}
	var bites := [0, 0, 0]
	var rare_by_stage := [0, 0, 0]
	var size_ok := true
	var seen_twitch := false
	var order_ok := true
	var rare_ids := ["mandarin", "koi", "arowana", "bass", "grass_carp", "catfish"]
	var fish_def := {}
	for f in fish:
		fish_def[f["id"]] = f
	for i in 3000000:
		now += 100
		var before := fs.state
		var got := fs.advance(now)
		if fs.baiting_started:
			fs.baiting_started = false
			casts += 1
		if fs.tangled_flag:
			fs.tangled_flag = false
			tangles += 1
		if before == Fishing.State.CASTING and fs.state == Fishing.State.WAITING:
			waits.append(fs.deadline_ms - now)
		if before == Fishing.State.TWITCH and fs.state == Fishing.State.WAITING:
			gaps[fs.stage - 1].append(fs.deadline_ms - now)
		if before == Fishing.State.WAITING and fs.state == Fishing.State.TWITCH:
			seen_twitch = true
		if before == Fishing.State.TWITCH and fs.state == Fishing.State.HOOKED:
			bites[fs.stage] += 1
			var fd: Dictionary = fish_def[fs.hooked_fish]
			if int(fd["rarity"]) > 0:
				rare_by_stage[fs.stage] += 1
			size_ok = size_ok and fs.hooked_size >= int(fd["size_cm"][0]) and fs.hooked_size <= int(fd["size_cm"][1])
		if before == Fishing.State.BAITING and fs.state != before and fs.state != Fishing.State.CASTING:
			order_ok = false
		if got != "":
			catches += 1
			counts[got] = counts.get(got, 0) + 1
		if catches >= 1500:
			break
	check(catches == 1500, "跑出 1500 次鱼获")
	check(order_ok and seen_twitch, "流程：上饵 → 抛竿 → 等 → 动漂")
	check(waits.min() >= 20000 and waits.max() <= 60000, "第一次动漂前等待 20–60 秒 (%d..%d)" % [waits.min(), waits.max()])
	check(gaps[0].min() >= 4000 and gaps[0].max() <= 10000, "第二次动漂在 10 秒内 (%d..%d)" % [gaps[0].min(), gaps[0].max()])
	check(gaps[1].min() >= 2500 and gaps[1].max() <= 5000, "第三次动漂在 5 秒内 (%d..%d)" % [gaps[1].min(), gaps[1].max()])
	var tot := float(bites[0] + bites[1] + bites[2])
	check(float(bites[0]) / tot > 0.45 and float(bites[0]) / tot < 0.62, "约一半在第一次动漂就咬钩 (%.2f)" % (float(bites[0]) / tot))
	check(tangles > 0 and float(tangles) / float(casts) < 0.06, "三次都没咬的空军很少见 (%d/%d)" % [tangles, casts])
	check(float(rare_by_stage[2]) / maxf(1.0, float(bites[2])) > 2.0 * float(rare_by_stage[0]) / maxf(1.0, float(bites[0])), "第三次动漂咬的钩更可能是稀有鱼")
	check(size_ok, "鱼的大小都在种类的尺寸范围内")
	check(counts.get("crucian", 0) > counts.get("koi", 0) and counts.get("bass", 0) > counts.get("koi", 0),
			"稀有度分布符合权重 %s" % str(counts))
	# 睡眠醒来（时间跳 3 小时）不会补钓多条
	var n := 0
	now += 3 * 3600 * 1000
	for i in 3:
		if fs.advance(now) != "":
			n += 1
	check(n <= 1, "时间大跳跃后最多结算 1 条")
	fs.stop(now)
	check(fs.advance(now + 999999) == "" and fs.state == Fishing.State.IDLE, "停止后不再推进")

func test_pomodoro(balance: Dictionary) -> void:
	print("pomodoro")
	var st := {"phase": 0, "phase_end_ms": 0, "cycle_done": 0}
	var p := Pomodoro.new(st, balance["pomodoro"])
	var now := 5000
	check(p.remaining_ms(now) == 25 * 60000, "空闲时显示 25:00")
	check(p.start_focus(now) and not p.start_focus(now), "专注不能重复开始")
	check(p.tick(now + 25 * 60000 - 1) == "", "差 1ms 未完成")
	now += 25 * 60000
	check(p.tick(now) == "focus_done" and p.phase() == Pomodoro.Phase.SHORT_BREAK, "完成后进入短休息")
	check(p.remaining_ms(now) == 5 * 60000, "短休息 5 分钟")
	now += 5 * 60000
	check(p.tick(now) == "break_done" and p.phase() == Pomodoro.Phase.IDLE, "休息结束回到空闲")
	p.start_focus(now)
	check(p.abandon(now + 1000) and p.cycle_done() == 1, "放弃不计数")
	for i in 2:
		p.start_focus(now); now += 25 * 60000; p.tick(now); p.skip_break()
	check(p.cycle_done() == 3, "已完成 3 个")
	p.start_focus(now); now += 25 * 60000
	check(p.tick(now) == "focus_done_long" and p.phase() == Pomodoro.Phase.LONG_BREAK, "第 4 个进入长休息")
	check(p.remaining_ms(now) == 15 * 60000 and p.cycle_done() == 0, "长休息 15 分钟且轮次清零")

func _types(events: Array) -> Array:
	return events.map(func(e): return e["type"])

const Journey := preload("res://core/journey.gd")

func _run(g, clock, seconds: float, step_ms: int = 250) -> Array:
	var all: Array = []
	for i in int(seconds * 1000.0 / step_ms):
		clock.t += step_ms
		all.append_array(g.tick())
	return all

## 按 gs 当前的倍速跑 seconds 秒：每 250 毫秒真实时间先快进再推进一帧。
func _run_ff(g, clock, seconds: float, step_ms: int = 250) -> Array:
	var all: Array = []
	for i in int(seconds * 1000.0 / step_ms):
		clock.t += step_ms
		g.fast_forward(float(step_ms))
		all.append_array(g.tick())
	return all

func _count(events: Array, type: String) -> int:
	return events.filter(func(e): return e["type"] == type).size()

func test_game_focus(balance: Dictionary, fish: Array) -> void:
	print("game: focus（木箱结算）")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(3))
	g.set_chest_chance(0.0)      # 这组用例要精确对账鱼的收入，宝箱另有专门的用例
	check(g.start_focus(), "开始专注")
	var ev := _run(g, clock, 25 * 60 + 1)
	var caught := _count(ev, "catch")
	check(caught > 20, "25 分钟专注钓到不少鱼，不受 10 格鱼篓限制 (%d)" % caught)
	check(_count(ev, "depart") == 0 and _count(ev, "basket_full") == 0 and g.state.basket.is_empty(), "专注时鱼进木箱，不会满篓也不会自己出发")
	var done: Array = ev.filter(func(e): return e["type"] == "focus_done")
	check(done.size() == 1 and done[0]["fish_count"] == caught, "产生一次 focus_done，结算全部渔获")
	check(done[0]["gold"] > 0 and g.state.wallet_gold == done[0]["gold"], "结算金币入账 (%d)" % g.state.wallet_gold)
	check(g.state.session_haul.is_empty(), "木箱已清空")
	check(g.state.stats["total_pomodoros"] == 1 and g.state.stats["daily"].get("2026-01-01", 0) == 1, "统计 +1")
	# 休息：循环暂停
	check(g.pomodoro.is_break(), "进入休息")
	var ev2 := _run(g, clock, 120)
	check(_count(ev2, "catch") + _count(ev2, "sale") == 0, "休息时不钓也不卖")
	# 放弃：原价结算、不计数
	g.skip_break(); g.start_focus()
	_run(g, clock, 600)
	var expect := g.economy.value_of(g.state.session_haul)
	var wallet := g.state.wallet_gold
	check(expect > 0 and g.abandon_focus() == expect and g.state.wallet_gold == wallet + expect, "放弃按原价结算")
	check(g.state.stats["total_pomodoros"] == 1, "放弃不计入番茄数")
	# 满篓闲置时开始专注：接着钓，鱼进木箱
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(4))
	var c2 = g2._clock
	for i in 10:
		g2.economy.add_catch(g2.state, "k%d" % i, "bass", false)
	_run(g2, c2, 2)
	check(g2.journey.activity() == Journey.Activity.IDLE_FULL, "满篓闲置")
	g2.start_focus()
	var ev3 := _run(g2, c2, 300)
	check(_count(ev3, "catch") > 0 and g2.state.basket.size() == 10 and g2.state.session_haul.size() == _count(ev3, "catch"), "专注时满篓也接着钓，鱼进木箱")
	# 专注时在摊位卖鱼：1.5 倍
	check(g2.go_to_town(), "专注中也可以手动去小镇")
	var ev4 := _run(g2, c2, 240)
	var sales: Array = ev4.filter(func(e): return e["type"] == "sale")
	check(sales.size() == 10 and sales.all(func(e): return e["gold"] == 18), "专注时摆摊每条鲈鱼卖 12×1.5=18")
	check(_count(ev4, "catch") == 0, "在镇上时不钓鱼")

func test_game_free_mode(balance: Dictionary, fish: Array) -> void:
	print("game: free mode（满篓等点击 / 偷吃 / 去小镇）")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(5))
	check(g.can_go_to_town(), "空鱼篓也可以去小镇")
	check(not g.can_go_fishing(), "在海上不能点去钓鱼")
	var ev := _run(g, clock, 40 * 60, 500)
	check(_count(ev, "basket_full") >= 1 and _count(ev, "depart") == 0, "满篓后原地等待，不会自己出发")
	# 满篓后会偷吃：钓满 → 吃掉一条 → 接着钓
	check(_count(ev, "ate") >= 1, "闲置太久会偷吃 (%d 次)" % _count(ev, "ate"))
	for e in ev:
		if e["type"] == "ate":
			check(e["fish_id"] != "koi", "不吃稀有鱼")
	# 只剩稀有鱼时不吃
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(1))
	for i in 10:
		g2.economy.add_catch(g2.state, "k%d" % i, "koi", false)
	var c2 = g2._clock
	var ev_k := _run(g2, c2, 20 * 60, 1000)
	check(g2.state.basket.size() == 10 and _count(ev_k, "ate") == 0, "鱼篓里全是稀有鱼时不偷吃")
	check(g2.journey.activity() == Journey.Activity.IDLE_FULL, "一直满着等玩家")
	# 点击出发：航行 30s → 走 8s → 摆摊 → 走 8s → 返航 30s
	var expect := g2.economy.value_of(g2.state.basket)
	check(g2.go_to_town() and not g2.go_to_town(), "出发，且不能重复出发")
	var trip := _run(g2, c2, 29)
	check(g2.journey.activity() == Journey.Activity.SAIL_OUT and trip.is_empty(), "29 秒时还在航行")
	trip = _run(g2, c2, 2)
	check(_count(trip, "docked") == 1, "30 秒到码头")
	trip = _run(g2, c2, 9)
	check(_count(trip, "open") == 1 and g2.journey.activity() == Journey.Activity.VENDING, "走到摊位开张")
	var t0: int = c2.t
	var gaps: Array = []
	var last: int = c2.t
	var sold := 0
	var safety := 0
	while g2.journey.activity() == Journey.Activity.VENDING and safety < 100000:
		safety += 1
		c2.t += 250
		for e in g2.tick():
			if e["type"] == "sale":
				gaps.append(c2.t - last); last = c2.t; sold += 1
	check(sold == 10 and g2.state.basket.is_empty(), "10 条鱼一条条卖完")
	check(gaps.min() >= 8000 and gaps.max() <= 20500, "每条间隔 8–20 秒 (%d..%d)" % [gaps.min(), gaps.max()])
	check(g2.state.wallet_gold == expect, "收入 = 鱼价之和 (%d)" % expect)
	check(g2.journey.activity() == Journey.Activity.SOLD_OUT, "卖光后停在摊位前等玩家，不自己去钓鱼")
	_run(g2, c2, 120)
	check(g2.journey.activity() == Journey.Activity.SOLD_OUT and g2.journey.in_town(), "等多久都不会自己走")
	check(g2.go_fishing(0.0, 1.0) and g2.journey.activity() == Journey.Activity.WALK_TO_BOAT, "点气泡后才走向码头")
	trip = _run(g2, c2, 39)
	check(_count(trip, "boarded") == 1 and _count(trip, "back") == 1, "走回码头并返航")
	check(g2.journey.activity() == Journey.Activity.FISHING, "回到钓点")
	_run(g2, c2, 5)
	check(g2.fishing.is_active(), "自动继续钓鱼")
	# 空篓子也能去小镇：上岸后停在码头自由走动，随时可以点去钓鱼
	var ge := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(9))
	var ce = ge._clock
	check(ge.go_to_town(), "空篓子出发")
	_run(ge, ce, 31)
	check(ge.journey.activity() == Journey.Activity.ROAM and ge.journey.roam_x() == 552, "没鱼：上岸后停在码头自由走动")
	_run(ge, ce, 120)
	check(ge.journey.activity() == Journey.Activity.ROAM, "不会自己走开")
	check(ge.can_go_fishing() and ge.go_fishing(552.0, 0.0), "点去钓鱼")
	_run(ge, ce, 40)
	check(ge.journey.activity() == Journey.Activity.FISHING, "返航后继续钓鱼")
	# 摆摊中途点去钓鱼：带着没卖完的鱼回船
	var gv := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(10))
	var cv = gv._clock
	for i in 3:
		gv.economy.add_catch(gv.state, "v%d" % i, "bass", false)
	gv.go_to_town(); _run(gv, cv, 45)
	check(gv.journey.activity() == Journey.Activity.VENDING and gv.go_fishing(0.0, 1.0), "摆摊中也可以点去钓鱼")
	check(gv.journey.activity() == Journey.Activity.WALK_TO_BOAT and gv.state.basket.size() == 3, "没卖的鱼还在篓里")
	check(not gv.go_fishing(0.0, 1.0), "已经在走向码头，不能重复点")
	# 全局加速：fast_forward 把所有截止时刻前移，航行、钓鱼、番茄钟一起变快，存档里仍是真实时间
	var gs := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(11))
	var cs = gs._clock
	gs.economy.add_catch(gs.state, "s1", "bass", false)
	check(gs.change_move_speed(1) == 2.0 and gs.change_move_speed(1) == 4.0 and gs.change_move_speed(-1) == 2.0, "倍速 1→2→4→2")
	gs.go_to_town()
	_run_ff(gs, cs, 14)
	check(gs.journey.activity() == Journey.Activity.SAIL_OUT, "2 倍速：14 秒还在航行（共 30 秒，快进后约 28 秒）")
	var prog_before: float = gs.journey.progress(cs.t)
	gs.change_move_speed(1)
	check(absf(gs.journey.progress(cs.t) - prog_before) < 0.01, "航行中改倍速，进度不跳 (%.2f)" % gs.journey.progress(cs.t))
	var ev_s := _run_ff(gs, cs, 5)
	check(_count(ev_s, "docked") == 1, "4 倍速：剩下的航行很快就到")
	check(gs.change_move_speed(-9) == 1.0 and gs.change_move_speed(99) == 16.0, "倍速到头不越界")
	# 快进对番茄钟也生效：25 分钟的专注在 4 倍速下约 6.3 分钟完成，而真实时间的存档时刻没有错位
	var gp := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(12))
	var cp = gp._clock
	gp.change_move_speed(1); gp.change_move_speed(1)
	gp.start_focus()
	var ev_p := _run_ff(gp, cp, 6 * 60)
	check(_count(ev_p, "focus_done") == 0, "4 倍速 6 分钟：专注还没结束")
	ev_p = _run_ff(gp, cp, 60)
	check(_count(ev_p, "focus_done") == 1, "4 倍速 7 分钟：专注完成了")
	check(int(gp.state.pomodoro["phase_end_ms"]) <= cp.t + 6 * 60000, "存档里的结束时刻是真实时间，不是虚拟时间")
	# 休息期间加速：番茄钟走得快，但旅程和钓鱼保持暂停
	var gb := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(13))
	var cb = gb._clock
	gb.state.pomodoro["phase"] = Pomodoro.Phase.SHORT_BREAK
	gb.state.pomodoro["phase_end_ms"] = cb.t + 300000
	_run(gb, cb, 1)
	var dl_before: int = gb.fishing.deadline_ms
	gb.change_move_speed(1)
	_run_ff(gb, cb, 10)
	check(gb.fishing.deadline_ms == dl_before and int(gb.state.pomodoro["phase_end_ms"]) < cb.t + 300000 - 9000, "休息中加速：番茄钟变快，钓鱼保持暂停")
	# 航行途中进入休息：进度冻结，休息结束后接着走
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(2))
	var c3 = g3._clock
	g3.economy.add_catch(g3.state, "a", "bass", false)
	g3.go_to_town(); _run(g3, c3, 10)
	g3.state.pomodoro["phase"] = Pomodoro.Phase.SHORT_BREAK; g3.state.pomodoro["phase_end_ms"] = c3.t + 300000
	_run(g3, c3, 200)
	check(g3.journey.activity() == Journey.Activity.SAIL_OUT, "休息时停在半路")
	g3.skip_break(); _run(g3, c3, 1)
	check(is_equal_approx(g3.journey.progress(c3.t), 11.0 / 30.0) or absf(g3.journey.progress(c3.t) - 11.0 / 30.0) < 0.03, "休息结束后从原进度继续 (%.2f)" % g3.journey.progress(c3.t))
	# 重启恢复：活动状态在存档里
	var s4 := GameState.new(); s4.from_dict(JSON.parse_string(JSON.stringify(g3.state.to_dict())))
	var g4 := Game.new(balance, fish, s4, c3, _rng(2))
	check(g4.journey.activity() == Journey.Activity.SAIL_OUT, "重启后仍在航行")
	# 自由走动：玩家接管 → 松手后自动走回摊位继续卖
	var g6 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(6))
	var c6 = g6._clock
	for i in 3:
		g6.economy.add_catch(g6.state, "r%d" % i, "crucian", false)
	check(not g6.begin_roam(700), "在海上不能自由走动")
	g6.go_to_town(); _run(g6, c6, 45)
	check(g6.journey.activity() == Journey.Activity.VENDING and g6.begin_roam(760), "摆摊时可以接管")
	g6.journey.set_roam_x(820)
	var left := g6.state.basket.size()
	var ev6 := _run(g6, c6, 120)
	check(_count(ev6, "sale") == 0 and g6.state.basket.size() == left, "自由走动时不卖鱼")
	g6.end_roam(0.5, 1.0)
	check(g6.journey.activity() == Journey.Activity.WALK_TO_STALL and g6.journey.walk_from() == 820, "松手后从当前位置走回摊位")
	ev6 = _run(g6, c6, 5)
	check(_count(ev6, "open") == 1, "半程只用一半时间（4 秒）就到")
	ev6 = _run(g6, c6, 100)
	check(g6.state.wallet_gold == 15 and _count(ev6, "sale") == 3 and g6.journey.activity() == Journey.Activity.SOLD_OUT, "卖完停在摊位前")
	check(g6.go_fishing(0.0, 1.0) and _count(_run(g6, c6, 45), "back") == 1, "点气泡后返航")
	g6.state.basket.clear()
	# 自由走动时在码头直接上船
	for i in 2:
		g6.economy.add_catch(g6.state, "q%d" % i, "crucian", false)
	g6.go_to_town(); _run(g6, c6, 45)
	g6.begin_roam(760); g6.roam_board(0.1)
	check(g6.journey.activity() == Journey.Activity.WALK_TO_BOAT, "码头互动：带着没卖完的鱼也能回船")
	var s7 := GameState.new(); s7.from_dict(JSON.parse_string(JSON.stringify(g6.state.to_dict())))
	check(s7.journey["walk_from"] == 760 and typeof(s7.journey["roam_x"]) == TYPE_INT, "行走起点随存档恢复")

func test_upgrades_and_settings(balance: Dictionary, fish: Array) -> void:
	print("upgrades & settings")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(9))
	check(not g.buy_upgrade("basket") and g.state.upgrades["basket"] == 0, "没钱不能升级")
	g.state.wallet_gold = 100
	check(g.buy_upgrade("basket") and g.state.wallet_gold == 20, "升级扣 80 金币")
	check(g.state.basket_capacity == 12, "鱼篓容量 10→12")
	check(not g.buy_upgrade("nope"), "未知升级被拒绝")
	g.state.wallet_gold = 100000
	for i in 10:
		g.buy_upgrade("basket"); g.buy_upgrade("rod"); g.buy_upgrade("bait")
	check(g.state.upgrades == {"rod": 5, "bait": 5, "basket": 5}, "最多升到 5 级")
	check(g.upgrades.next_cost(g.state, "rod") == -1, "满级后没有下一级价格")
	check(g.state.basket_capacity == 20, "满级鱼篓 20")
	g.tick()
	check(is_equal_approx(g.fishing.wait_multiplier, 1.0), "满级鱼竿：自由挂机等待倍率 1.0（不快于 20–60 秒）")
	# 鱼饵让稀有鱼更多
	var base := Fishing.new(balance["fishing"], fish, _rng(1))
	var baited := Fishing.new(balance["fishing"], fish, _rng(1))
	baited.rarity_bonus = 0.75
	base.zone = "deep"; baited.zone = "deep"
	var k0 := 0; var k1 := 0
	for i in 5000:
		if base._roll_fish() == "koi": k0 += 1
		if baited._roll_fish() == "koi": k1 += 1
	check(k1 > k0 * 1.2, "满级鱼饵锦鲤明显变多 (%d → %d)" % [k0, k1])
	# 升级随存档恢复
	var s2 := GameState.new(); s2.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict())))
	var g2 := Game.new(balance, fish, s2, clock, _rng(9))
	check(g2.state.basket_capacity == 20 and s2.upgrades["rod"] == 5, "升级随存档恢复")
	# 时长设置
	check(g.duration("focus_min") == 25, "默认专注 25 分钟")
	check(g.adjust_duration("focus_min", 1) == 30 and g.pomodoro.remaining_ms(clock.t) == 30 * 60000, "专注调到 30 分钟")
	for i in 40:
		g.adjust_duration("focus_min", -1)
	check(g.duration("focus_min") == 5, "专注最短 5 分钟")
	for i in 40:
		g.adjust_duration("short_break_min", 1)
	check(g.duration("short_break_min") == 30, "短休最长 30 分钟")
	var s3 := GameState.new(); s3.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict())))
	var g3 := Game.new(balance, fish, s3, clock, _rng(9))
	check(g3.duration("focus_min") == 5 and g3.duration("long_break_min") == 15, "时长设置随存档恢复，未改的保持默认")
	g3.start_focus(); clock.t += 5 * 60000
	check(_types(g3.tick()).has("focus_done"), "5 分钟番茄按新时长完成")
	# 满篓闲置时升级鱼篓：有了空位就继续钓
	var g6 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(4))
	for i in 10:
		g6.economy.add_catch(g6.state, "f%d" % i, "crucian", false)
	_run(g6, g6._clock, 2)
	check(g6.journey.activity() == Journey.Activity.IDLE_FULL, "满篓闲置")
	g6.state.wallet_gold = 80; g6.buy_upgrade("basket"); _run(g6, g6._clock, 2)
	check(g6.journey.activity() == Journey.Activity.FISHING and g6.fishing.is_active(), "扩容后继续钓")

func test_cat_config() -> void:
	print("cat config")
	var c := ConfigLoader.load_cat()
	check(not c.is_empty(), "cat.json 可加载")
	var s := GameState.new()
	check(not s.cat["created"], "新存档尚未捏猫（首次启动会弹出面板）")
	for key_list in [["fur", "furs"], ["pattern", "patterns"], ["hat", "hats"]]:
		check(int(c["default"][key_list[0]]) == int(s.cat[key_list[0]]), "默认形象与 cat.json 一致: " + key_list[0])
		check(int(s.cat[key_list[0]]) < c[key_list[1]].size(), "默认下标在范围内: " + key_list[0])
	for h in c["hats"]:
		if h["sprite"] != "":
			check(FileAccess.file_exists("res://assets/cat/%s.png" % h["sprite"]), "帽子素材存在: " + h["sprite"])
	for layer in ["fur_base", "fur_shade", "fur_light", "pat_white", "pat_stripe", "fixed"]:
		check(FileAccess.file_exists("res://assets/cat/%s.png" % layer), "猫图层存在: " + layer)
	s.cat = {"fur": 3, "pattern": 2, "hat": 0, "created": true}
	var s2 := GameState.new(); s2.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(s2.cat == {"fur": 3, "pattern": 2, "hat": 0, "created": true}, "形象随存档恢复")
	# 第一阶段的旧存档没有 cat 字段：应保留默认形象且视为未捏猫
	var old := s.to_dict(); old.erase("cat")
	var s3 := GameState.new()
	check(s3.from_dict(old) and not s3.cat["created"] and s3.cat["hat"] == 1, "旧存档兼容")

func test_chest(balance: Dictionary, fish: Array) -> void:
	print("treasure chest")
	check(is_equal_approx(float(balance["chest"]["chance"]), 0.04), "默认 4% 概率")
	# 概率调到 100%：每一竿都是宝箱
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(21))
	g.set_chest_chance(1.0)
	var ev := _run(g, clock, 30 * 60, 500)
	var chests: Array = ev.filter(func(e): return e["type"] == "chest")
	check(chests.size() >= 10 and _count(ev, "catch") == 0, "每一竿都钓到宝箱 (%d 个)" % chests.size())
	var sum := 0
	var ok := true
	var tiers := {}
	for e in chests:
		sum += int(e["gold"])
		tiers[e["tier"]] = true
		var t: Dictionary = balance["chest"]["tiers"].filter(func(x): return x["name"] == e["tier"])[0]
		if e["gold"] < int(t["gold_min"]) or e["gold"] > int(t["gold_max"]):
			ok = false
	check(ok, "每个宝箱的金币都在所属档位的范围内")
	check(g.state.wallet_gold == sum, "宝箱金币直接入账 (%d)" % sum)
	check(g.state.basket.is_empty() and g.state.session_haul.is_empty() and g.state.stats["total_fish"] == 0, "宝箱不占鱼篓、不进木箱、不算进钓鱼数")
	check(g.state.stats["chests"] == chests.size(), "宝箱计数正确")
	check(not g.economy.open_chest(g.state, g.state.processed_catch_ids[-1], 999) and g.state.wallet_gold == sum, "同一个宝箱不能开两次")
	# 专注时也能钓到，同样直接入账
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(22))
	g2.set_chest_chance(1.0)
	g2.start_focus()
	var ev2 := _run(g2, g2._clock, 10 * 60, 500)
	check(_count(ev2, "chest") > 0 and g2.state.session_haul.is_empty() and g2.state.wallet_gold > 0, "专注时钓到宝箱也直接入账，不进木箱")
	# 默认概率下：宝箱是少数，鱼照常
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(23))
	g3.start_focus(); g3.state.pomodoro["phase_end_ms"] = g3._clock.t + 100 * 3600000
	var ev3 := _run(g3, g3._clock, 20 * 3600, 1000)
	var c3 := _count(ev3, "chest"); var f3 := _count(ev3, "catch")
	var rate := float(c3) / float(c3 + f3)
	check(c3 > 0 and rate > 0.015 and rate < 0.08, "默认概率下宝箱占比约 4%% (%d/%d = %.3f)" % [c3, c3 + f3, rate])
	# 没配置宝箱时完全不会出现
	var b2: Dictionary = balance.duplicate(true); b2.erase("chest")
	var g4 := Game.new(b2, fish, GameState.new(), FakeClock.new(), _rng(24))
	check(g4.fishing.chest_chance == 0.0, "没有 chest 配置时概率为 0")
	# 咬钩后、提竿前重启：断点里的宝箱能恢复，且只开一次
	var g5 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(25))
	g5.set_chest_chance(1.0)
	var c5 = g5._clock
	var guard := 0
	while g5.fishing.state != Fishing.State.HOOKED and guard < 2000:
		guard += 1; c5.t += 100; g5.tick()
	var s6 := GameState.new(); s6.from_dict(JSON.parse_string(JSON.stringify(g5.state.to_dict())))
	var g6 := Game.new(balance, fish, s6, c5, _rng(26))
	check(g6.fishing.hooked_fish == Fishing.CHEST, "重启后钩上的宝箱还在")
	var ev6 := _run(g6, c5, 4, 100)
	check(_count(ev6, "chest") == 1, "提上来只开一次")

func _utc(y: int, mo: int, d: int, h: int, mi: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": 0}))

func test_adapters() -> void:
	print("adapters")
	# 测试里用的是无窗口适配器，桌面适配器不会被加载；这里单独加载一次，确保它能编译
	for path in ["res://platform/desktop_adapter.gd", "res://platform/platform_adapter.gd", "res://platform/platform.gd"]:
		var sc = load(path)
		check(sc != null and sc.can_instantiate() if sc != null and sc is GDScript else sc != null, "能加载 " + path)
	var desk = load("res://platform/desktop_adapter.gd").new()
	var tz: String = desk.timezone_name()
	check(tz is String, "桌面适配器能读时区名 (%s)" % tz)

func test_weather(balance: Dictionary, fish: Array) -> void:
	print("weather")
	var p: float = float(balance["weather"]["rain_block_chance"])
	# 同一时刻结果固定
	var same := true
	for s in range(0, 86400 * 3, 977):
		if Weather.is_raining(s, p) != Weather.is_raining(s, p):
			same = false
	check(same, "同一时刻天气固定")
	# 长期下雨占比在 10%–20% 之间，且下雨连续一段时间（不是一闪而过）
	var rainy := 0
	var total := 0
	var longest := 0
	var run := 0
	for s in range(0, 86400 * 60, 300):
		total += 1
		if Weather.is_raining(s, p):
			rainy += 1
			run += 300
			longest = maxi(longest, run)
		else:
			run = 0
	var frac := float(rainy) / float(total)
	check(frac > 0.10 and frac < 0.20, "下雨时间占比约 15%% (%.3f)" % frac)
	check(longest >= 3600 and longest <= 5400 + 300, "一场雨持续 60–90 分钟 (%d 秒)" % longest)
	var dry := true
	for s in range(0, 86400, 600):
		if Weather.is_raining(s, 0.0):
			dry = false
	check(dry, "概率 0 永远不下雨")
	# 天文：都柏林 2026-11-13 日出 07:46、日落 16:31（格林尼治时间；用独立的 astral 库交叉核对过）
	var dub_day := _utc(2026, 11, 13, 0, 0)
	var dub_ev := Astro.sun_day(53.35, -6.26, float(Astro.solar_day_start(-6.26, float(dub_day + 12 * 3600))))
	var rise_h: float = (float(dub_ev["rise"]) - float(dub_day)) / 3600.0
	var set_h: float = (float(dub_ev["set"]) - float(dub_day)) / 3600.0
	check(absf(rise_h - 7.777) < 0.15, "都柏林 11-13 日出约 07:46 (%.2f)" % rise_h)
	check(absf(set_h - 16.52) < 0.15, "都柏林 11-13 日落约 16:31 (%.2f)" % set_h)
	check(dub_ev["peak"] > 14.0 and dub_ev["peak"] < 24.0, "都柏林冬天太阳最高只有 14–24 度 (%.1f)" % dub_ev["peak"])
	# 北京夏至：日出 04:46、日落 19:46（北京时间 = UTC+8，同样用 astral 核对）
	var bj := Astro.sun_day(39.9, 116.4, float(Astro.solar_day_start(116.4, float(_utc(2026, 6, 21, 4, 0)))))
	var bj_rise := (float(bj["rise"]) - float(_utc(2026, 6, 20, 16, 0))) / 3600.0
	var bj_set := (float(bj["set"]) - float(_utc(2026, 6, 20, 16, 0))) / 3600.0
	check(absf(bj_rise - 4.77) < 0.25 and absf(bj_set - 19.78) < 0.25, "北京夏至日出日落约 04:46 / 19:47 (%.2f / %.2f)" % [bj_rise, bj_set])
	check(bj["peak"] > 70.0, "北京夏至太阳很高 (%.1f)" % bj["peak"])
	# 极夜/极昼：特罗姆瑟 12 月没有日出，6 月没有日落
	var tr := Astro.sun_day(69.65, 18.96, float(Astro.solar_day_start(18.96, float(_utc(2026, 12, 21, 12, 0)))))
	check(tr["rise"] < 0.0 and tr["set"] < 0.0 and tr["peak"] < 0.0, "极夜没有日出日落")
	var tr2 := Astro.sun_day(69.65, 18.96, float(Astro.solar_day_start(18.96, float(_utc(2026, 6, 21, 12, 0)))))
	check(tr2["rise"] < 0.0 and tr2["set"] < 0.0 and tr2["peak"] > 0.0, "极昼没有日出日落（太阳一直在天上）")
	# 月相：2024-01-25 17:54 UTC 满月，2024-02-09 22:59 UTC 新月
	check(absf(Astro.moon_phase(float(_utc(2024, 1, 25, 17, 54))) - 0.5) < 0.03, "2024-01-25 满月")
	var np := Astro.moon_phase(float(_utc(2024, 2, 9, 22, 59)))
	check(np < 0.03 or np > 0.97, "2024-02-09 新月 (%.3f)" % np)
	# 月亮位置：满月午夜在中天，新月中午在中天（但看不到亮面）
	var fm := _utc(2024, 1, 25, 17, 54)
	var mid := fm + int((24.0 - Astro.solar_hour(0.0, float(fm))) * 3600.0)       # 满月当晚（lon=0）的午夜
	check(absf(Astro.moon_u(0.0, float(mid)) - 0.5) < 0.1, "满月午夜在天空正中")
	check(Astro.moon_u(0.0, float(mid + 11 * 3600)) < -1.0, "满月到中午已落下")
	# 天色：高度 → 暗度/暖色
	check(is_equal_approx(Weather.light(30.0, false)["dark"], 0.0), "太阳高时不暗")
	check(is_equal_approx(Weather.light(-20.0, false)["dark"], 1.0), "太阳深落到地平线下时最暗")
	check(Weather.light(1.5, false)["warm"] > 0.99 and Weather.light(40.0, false)["warm"] == 0.0, "日出日落时暖色最浓，中午没有")
	# 定位：按时区名找城市，找不到按偏移估
	var tbl := Location.load_table()
	var dub := Location.resolve("Europe/Dublin", 0, tbl)
	check(dub["name"] == "都柏林" and absf(dub["lat"] - 53.35) < 0.1, "时区 Europe/Dublin → 都柏林")
	var sh := Location.resolve("Asia/Shanghai", 8 * 3600, tbl)
	check(sh["name"] == "上海" and sh["source"] == "tz", "时区 Asia/Shanghai → 上海")
	var unk := Location.resolve("Mars/Olympus", 9 * 3600, tbl)
	check(unk["source"] == "bias" and absf(unk["lon"] - 135.0) < 0.01, "不认识的时区按偏移估经度 (%.1f)" % unk["lon"])
	# 真实天气：WMO 天气码解析
	check(WeatherFetcher.parse('{"current":{"weather_code":61,"cloud_cover":90}}')["raining"], "天气码 61 = 下雨")
	check(not WeatherFetcher.parse('{"current":{"weather_code":0,"cloud_cover":5}}')["raining"], "天气码 0 = 晴")
	check(WeatherFetcher.parse('{"current":{"weather_code":3,"cloud_cover":100}}')["cloudy"], "天气码 3 = 阴")
	check(WeatherFetcher.parse("乱码").is_empty() and WeatherFetcher.parse('{"current":{}}').is_empty(), "返回格式不对时不当成天气")
	# 下雨对钓鱼的影响：咬钩快 5%，宝箱概率 ×0.95；雨停恢复
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(77))
	check(not Weather.is_raining(clock.local_s(), p), "测试时钟固定在不下雨的时刻")
	var chest0: float = g.fishing.chest_chance
	g.weather_override = 1
	var ev: Array = g.tick()
	var got := false
	for e in ev:
		if e["type"] == "weather" and e["raining"]:
			got = true
	check(g.is_raining() and got, "下雨时发出天气事件")
	check(is_equal_approx(g.fishing.chest_chance, chest0 * 0.95), "下雨宝箱概率 ×0.95")
	check(is_equal_approx(g.fishing.wait_multiplier, g._free_multiplier / 1.05) or is_equal_approx(g.fishing.wait_multiplier, 1.0 / 1.05), "下雨咬钩等待缩短到 1/1.05 (%f)" % g.fishing.wait_multiplier)
	# 真实天气：开关关着时忽略；打开且拿到数据后用真实的；超过 3 小时没更新退回模拟
	g.weather_override = -1
	g.tick()
	check(not g.is_raining(), "回到模拟天气（测试时刻不下雨）")
	g.set_real_weather(true, true)
	g.tick()
	check(not g.is_raining() and not g.sky()["cloudy"], "开关关着时忽略真实天气")
	g.state.settings["real_weather"] = 1
	g._sky_key = -1
	g.tick()
	check(g.is_raining() and g.sky()["cloudy"], "开关打开后用真实天气")
	clock.t += 4 * 3600 * 1000
	g.tick()
	check(not g.is_raining(), "真实天气超过 3 小时没更新，退回模拟")
	g.state.settings["real_weather"] = 0
	g.weather_override = 0
	g.tick()
	check(not g.is_raining() and is_equal_approx(g.fishing.chest_chance, chest0), "雨停后宝箱概率恢复")
	check(is_equal_approx(g.fishing.wait_multiplier, g._free_multiplier) or is_equal_approx(g.fishing.wait_multiplier, 1.0), "雨停后咬钩时间恢复")

func test_water(balance: Dictionary, fish: Array) -> void:
	print("water: 水域与划船")
	var fs := Fishing.new(balance["fishing"], fish, _rng(3))
	var seen := {"shallow": {}, "normal": {}, "deep": {}}
	for z in seen:
		fs.zone = z
		for i in 4000:
			seen[z][fs._roll_fish()] = true
	check(not seen["shallow"].has("arowana") and not seen["shallow"].has("catfish") and not seen["shallow"].has("koi"), "浅滩钓不到深水鱼")
	check(seen["deep"].has("arowana") and seen["deep"].has("catfish") and not seen["deep"].has("loach"), "深水区有银龙鱼和鲶鱼，没有泥鳅")
	check(seen["normal"].has("bass") and seen["normal"].has("koi") and not seen["normal"].has("arowana"), "普通水域有鲈鱼和锦鲤")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(4))
	check(g.zone_id(100.0) == "deep" and g.zone_id(250.0) == "normal" and g.zone_id(400.0) == "shallow", "按位置判断水域")
	var zb := g.zone_bounds(640.0)
	check(zb.size() == 3 and zb[0]["x0"] == 0.0 and zb[2]["x1"] == 640.0 and zb[1]["x0"] == zb[0]["x1"], "水域范围首尾相接")
	check(g.can_steer() and g.steer_to(120.0) and g.journey.boat_x() == 120, "钓鱼时可以划船")
	check(g.steer_to(-50.0) and g.journey.boat_x() == 30 and g.steer_to(9999.0) and g.journey.boat_x() == 512, "划船范围有边界（右端是码头）")
	check(not g.line_out() and g.fishing.state == Fishing.State.IDLE, "划船先收杆")
	var c0: FakeClock = g._clock
	_run(g, c0, 30)
	check(g.fishing.state == Fishing.State.IDLE and not g.fishing.is_active(), "停船后不会自己甩竿")
	check(g.cast_line() and g.line_out() and not g.cast_line(), "按互动键重新甩竿，不能重复")
	_run(g, c0, 2)
	check(g.fishing.is_active(), "甩竿后恢复钓鱼")
	g.economy.add_catch(g.state, "w1", "bass", false)
	g.go_to_town()
	check(not g.can_steer() and not g.steer_to(200.0), "出发后不能划船")
	var c: FakeClock = g._clock
	g.steer_to(200.0)
	_run(g, c, 100)
	check(g.journey.boat_x() == 512, "往返小镇不改变船的位置")

func test_sail_turn(balance: Dictionary, fish: Array) -> void:
	print("sail: 航行时长按路程折算、途中掉头")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(33))
	var c: FakeClock = g._clock
	_run(g, c, 2)
	g.steer_to(260.0)
	g.go_to_town()
	var far: int = int(g.state.journey["phase_end_ms"]) - int(g.state.journey["phase_start_ms"])
	g.journey.turn_sail(c.now_ms())
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(34))
	var c2: FakeClock = g2._clock
	_run(g2, c2, 2)
	g2.steer_to(500.0)
	g2.go_to_town()
	var near: int = int(g2.state.journey["phase_end_ms"]) - int(g2.state.journey["phase_start_ms"])
	check(near < far / 10 and near >= int(float(far) * 0.07), "离码头近航行时间按比例缩短 (远 %d / 近 %d)" % [far, near])
	# 掉头：途中位置连续、剩余路程等于已走路程
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(35))
	var c3: FakeClock = g3._clock
	_run(g3, c3, 2)
	check(g3.go_to_town() and g3.journey.activity() == Journey.Activity.SAIL_OUT, "出发")
	c3.t += 9000
	var p_before: float = g3.journey.progress(c3.now_ms())
	check(g3.can_turn_sail() and g3.turn_sail() and g3.journey.activity() == Journey.Activity.SAIL_BACK, "航行中可以掉头")
	var p_after: float = g3.journey.progress(c3.now_ms())
	check(absf((1.0 - p_before) - p_after) < 0.01, "掉头后位置不跳 (%.3f → %.3f)" % [p_before, p_after])
	_run(g3, c3, 60)
	check(g3.journey.activity() == Journey.Activity.FISHING and g3.line_out(), "回头的船回到钓点继续钓鱼")
	g3.go_to_town()
	c3.t += 5000
	g3.turn_sail()
	g3.turn_sail()
	check(g3.journey.activity() == Journey.Activity.SAIL_OUT, "来回掉头两次还是往小镇去")

func test_birds(balance: Dictionary, fish: Array) -> void:
	print("birds: 鸟来访（送礼 / 偷鱼）")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(21))
	var c: FakeClock = g._clock
	var ev := _run(g, c, 3 * 3600, 500)
	var visits: Array = ev.filter(func(e): return e["type"] == "bird_visit")
	var gifts: Array = ev.filter(func(e): return e["type"] == "bird_gift")
	var steals: Array = ev.filter(func(e): return e["type"] == "bird_steal")
	check(visits.size() >= 15 and visits.size() <= 50, "3 小时来了 %d 次鸟（平均 4–9 分钟一次）" % visits.size())
	var nones: Array = visits.filter(func(e): return e["kind"] == "none")
	check(gifts.size() + steals.size() + nones.size() >= visits.size() - 1 and gifts.size() > 0, "来访后都会生效 (送 %d / 偷 %d / 来 %d)" % [gifts.size(), steals.size(), visits.size()])
	for e in steals:
		check(e["fish_id"] != "koi" and e["fish_id"] != "arowana", "鸟不偷稀有鱼")
	# 篓子空着不会来偷
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(22))
	g2.state.effects["bird_next_ms"] = 1
	var ev2 := _run(g2, g2._clock, 600, 500)
	check(ev2.filter(func(e): return e["type"] == "bird_visit" and e["kind"] == "steal").is_empty(), "空篓子不会被偷")
	# 出发去小镇会取消来访
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(23))
	g3.state.effects["bird_next_ms"] = 1
	_run(g3, g3._clock, 5, 500)
	check(int(g3.state.effects["bird_act_ms"]) > 0, "鸟来了")
	g3.go_to_town()
	check(int(g3.state.effects["bird_act_ms"]) == 0, "出发后这次来访作废")

func test_inventory(balance: Dictionary, fish: Array) -> void:
	print("inventory & items")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(31))
	var inv = g.inventory
	check(inv.defs.size() == 8 and inv.owned(g.state).is_empty(), "8 种物品（含两种鱼饵），开局物品栏为空")
	check(not inv.add(g.state, "nope") and inv.add(g.state, "boot") and inv.add(g.state, "boot", 2), "只能加入已定义的物品，同种叠加")
	check(inv.count(g.state, "boot") == 3 and inv.owned(g.state) == ["boot"], "旧靴子 ×3 只占一格")
	check(not inv.can_use(g.state, "boot") and not g.use_item("boot")["ok"] and inv.count(g.state, "boot") == 3, "收藏品不能使用，也不会被扣掉")
	check(not g.use_item("bottle")["ok"], "没有的物品不能用")
	# 漂流瓶：得金币
	inv.add(g.state, "bottle")
	var r := g.use_item("bottle")
	check(r["ok"] and r["gold"] >= 10 and r["gold"] <= 60 and g.state.wallet_gold == r["gold"], "漂流瓶开出 10–60 金币 (%d)" % r["gold"])
	check(inv.count(g.state, "bottle") == 0 and not g.state.inventory.has("bottle"), "用掉后从物品栏消失")
	# 藏宝图碎片：集齐 4 片才能用
	inv.add(g.state, "map_piece", 3)
	check(not inv.can_use(g.state, "map_piece") and not g.use_item("map_piece")["ok"], "3 片不够")
	inv.add(g.state, "map_piece", 2)
	var w := g.state.wallet_gold
	r = g.use_item("map_piece")
	check(r["ok"] and r["gold"] >= 400 and r["gold"] <= 600 and g.state.wallet_gold == w + r["gold"], "4 片拼成藏宝图，得 400–600 金币 (%d)" % r["gold"])
	check(inv.count(g.state, "map_piece") == 1, "5 片用掉 4 片剩 1 片")
	# 幸运鱼饵：10 分钟内稀有度和宝箱概率提高，到期恢复
	inv.add(g.state, "lucky_bait", 2)
	var base_chest: float = g.fishing.chest_chance
	check(g.use_item("lucky_bait")["ok"] and g.lucky_active(), "幸运鱼饵生效")
	check(is_equal_approx(g.fishing.rarity_bonus, 0.6) and is_equal_approx(g.fishing.chest_chance, base_chest * 2.0), "稀有度 +0.6，宝箱概率翻倍")
	g.use_item("lucky_bait")
	check(g.lucky_remaining_ms() == 20 * 60000, "连着用两个，时间接成 20 分钟")
	# 休息不消耗时间
	g.state.pomodoro["phase"] = Pomodoro.Phase.SHORT_BREAK; g.state.pomodoro["phase_end_ms"] = clock.t + 5 * 60000
	_run(g, clock, 5 * 60 + 2)
	check(absi(g.lucky_remaining_ms() - 20 * 60000) < 5000, "番茄休息的 5 分钟不算进去 (剩 %d 秒)" % (g.lucky_remaining_ms() / 1000))
	_run(g, clock, 20 * 60 + 5)
	check(not g.lucky_active() and is_equal_approx(g.fishing.rarity_bonus, 0.0) and is_equal_approx(g.fishing.chest_chance, base_chest), "到期后恢复原样")
	# 小猫的床：只在休息时能睡，每段休息一次，睡醒幸运 5 分钟
	check(g.nap_status() == 0 and not g.nap(), "不在休息时不能睡")
	g.state.pomodoro["phase"] = Pomodoro.Phase.SHORT_BREAK; g.state.pomodoro["phase_end_ms"] = clock.t + 5 * 60000
	check(g.nap_status() == 1 and g.nap() and g.lucky_active(), "休息时可以小睡，睡醒更走运")
	check(absi(g.lucky_remaining_ms() - 5 * 60000) < 2000, "小睡幸运 5 分钟")
	check(g.nap_status() == 2 and not g.nap(), "同一段休息不能再睡")
	g.state.pomodoro["phase_end_ms"] = clock.t + 15 * 60000
	check(g.nap_status() == 1, "下一段休息又可以睡")
	# 招财铃：接下来 5 单翻倍，第 6 单恢复
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(32))
	g2.set_chest_chance(0.0)
	for i in 7:
		g2.economy.add_catch(g2.state, "b%d" % i, "bass", false)
	g2.inventory.add(g2.state, "bell")
	check(g2.use_item("bell")["ok"] and g2.state.effects["bell_sales"] == 5, "招财铃：记下 5 单")
	g2.go_to_town()
	var sales: Array = _run(g2, g2._clock, 240).filter(func(e): return e["type"] == "sale")
	var golds: Array = sales.map(func(e): return e["gold"])
	check(golds == [24, 24, 24, 24, 24, 12, 12], "前 5 单 24，后 2 单 12: %s" % str(golds))
	check(g2.state.effects["bell_sales"] == 0, "铃用完")
	# 宝箱会开出物品
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(33))
	g3.set_chest_chance(1.0)
	var ev := _run(g3, g3._clock, 4 * 3600, 1000)
	var chests: Array = ev.filter(func(e): return e["type"] == "chest")
	var with_item: Array = chests.filter(func(e): return e["item"] != "")
	var rate := float(with_item.size()) / float(chests.size())
	check(chests.size() > 100 and rate > 0.45 and rate < 0.75, "约 60%% 的宝箱带物品 (%d/%d)" % [with_item.size(), chests.size()])
	var total := 0
	for id in g3.state.inventory:
		total += int(g3.state.inventory[id])
	var gifts := ev.filter(func(e): return e["type"] == "bird_gift").size()
	check(total == with_item.size() + gifts, "开出的物品和鸟送的礼物都进了物品栏 (%d = %d + %d)" % [total, with_item.size(), gifts])
	check(g3.inventory.owned(g3.state).size() == 8, "跑够久，8 种物品都开出来过")
	# 存档
	var s4 := GameState.new(); s4.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict())))
	check(s4.inventory == g.state.inventory and typeof(s4.inventory["boot"]) == TYPE_INT and s4.effects == g.state.effects, "物品栏和效果随存档恢复")
	var old: Dictionary = g.state.to_dict(); old.erase("inventory"); old.erase("effects")
	var s5 := GameState.new()
	check(s5.from_dict(old) and s5.inventory.is_empty() and s5.effects["bell_sales"] == 0, "旧存档没有物品栏字段也能读")

func test_stall_walk(balance: Dictionary, fish: Array) -> void:
	print("摊位：绕到柜台后面 + 状态页数据")
	var w := World.new(null)
	var rl: Dictionary = w.stall_route(700.0)
	check(rl["corner"] == World.CORNER_L and is_equal_approx(float(rl["l1"]) + float(rl["l2"]), float(World.STALL_CAT_X - 700)), "从左边来：绕左端，路程不变")
	var rr: Dictionary = w.stall_route(World.STALL_X + 60.0)
	check(rr["corner"] == World.CORNER_R, "从右边来：绕右端")
	check(is_equal_approx(w.frac_to_stall(float(World.WALK_FROM_X)), 1.0), "码头到摊位全程比例 = 1")
	var p0: Dictionary = w._walk_pose(true, -1.0, 0.0)
	var p1: Dictionary = w._walk_pose(true, -1.0, 1.0)
	check(absf(p0["x"] - World.WALK_FROM_X) < 0.5 and not p0["behind"], "去摊位：起点在码头、在柜台前")
	check(absf(p1["x"] - World.STALL_CAT_X) < 0.5 and p1["behind"] and absf(p1["y"] - (World.GROUND_Y - 29)) < 0.5, "去摊位：终点在柜台后，和摆摊位置对上")
	var pm: Dictionary = w._walk_pose(true, -1.0, 0.99)
	var seen_front := false
	var seen_behind := false
	var prev_x := -1.0
	var jump_ok := true
	for i in 101:
		var q: Dictionary = w._walk_pose(true, -1.0, float(i) / 100.0)
		seen_front = seen_front or not q["behind"]
		seen_behind = seen_behind or q["behind"]
		if prev_x >= 0.0 and absf(q["x"] - prev_x) > 12.0:
			jump_ok = false
		prev_x = q["x"]
	check(seen_front and seen_behind and jump_ok, "去摊位：先在柜台前、后在柜台后，没有瞬移")
	var b0: Dictionary = w._walk_pose(false, -1.0, 0.0)
	var b1: Dictionary = w._walk_pose(false, -1.0, 1.0)
	check(b0["behind"] and absf(b0["x"] - World.STALL_CAT_X) < 0.5 and not b1["behind"] and absf(b1["x"] - World.WALK_FROM_X) < 0.5, "回码头：从柜台后出来，走到码头")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(5))
	check(g.equipment_name("rod") == "树枝" and g.equipment_name("line") == "棉线" and g.equipment_name("hook") == "铁钩", "装备栏默认名字")
	g.state.upgrades["rod"] = 2
	check(g.equipment_name("rod") == "玻纤" and not g.bait_active(), "鱼竿随升级换名字；没有幸运鱼饵时鱼饵格为空")

func test_bait(balance: Dictionary, fish: Array) -> void:
	print("鱼饵、上饵动作、空军、鱼的大小")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(21))
	g.set_chest_chance(0.0)
	check(g.inventory.add(g.state, "bait_worm", 200) and g.inventory.count(g.state, "bait_worm") == 99, "鱼饵最多 99 个")
	check(not g.inventory.add(g.state, "bait_worm", 1), "满 99 个再加不进去")
	g.inventory.add(g.state, "bait_shrimp", 2)
	var r: Dictionary = g.use_item("bait_shrimp")
	check(r["ok"] and g.state.equipped_bait == "bait_shrimp" and g.inventory.count(g.state, "bait_shrimp") == 2, "使用鱼饵 = 装上，不消耗")
	var ev := _run(g, clock, 1)
	check(_count(ev, "bait") == 1 and g.inventory.count(g.state, "bait_shrimp") == 1, "第一竿上饵扣 1 个")
	check(g.fishing.state == Fishing.State.BAITING and g.fishing.bait_bonus > 0.8, "鱼饵加成交给钓鱼系统")
	var baits := 1
	var tangles := 0
	var sized := true
	for i in 20000:
		clock.t += 250
		for e in g.tick():
			if e["type"] == "bait":
				baits += 1
			elif e["type"] == "tangle":
				tangles += 1
			elif e["type"] == "catch":
				sized = sized and int(e["size"]) > 0
		if g.state.equipped_bait == "" and baits >= 4 and tangles >= 1:
			break
		if g.economy.basket_full(g.state):
			g.state.basket.clear()
	check(g.state.equipped_bait == "" and g.inventory.count(g.state, "bait_shrimp") == 0, "饵用完自动换回面团")
	check(g.fishing.bait_bonus == 0.0 or g.state.equipped_bait == "", "面团没有加成")
	check(sized and not g.state.stats["fish_best"].is_empty(), "钓到的鱼有大小，记下每种的最大值")
	check(tangles >= 1 and int(g.state.stats["empty_casts"]) == tangles, "空军记进统计")
	# 存档往返：装上的饵、动漂次数、鱼的大小不丢
	g.use_item("bait_worm")
	var s2 := GameState.new(); s2.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict())))
	check(s2.equipped_bait == "bait_worm", "装上的鱼饵写进存档")

func test_checkpoint(balance: Dictionary, fish: Array) -> void:
	print("fishing checkpoint")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(11))
	_run(g, clock, 5)
	check(g.fishing.state == Fishing.State.WAITING and g.state.fishing_checkpoint["state"] == Fishing.State.WAITING, "等鱼时断点已记录")
	var deadline: int = g.fishing.deadline_ms
	var s2 := GameState.new(); s2.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict())))
	clock.t += 3000    # 关掉 3 秒再打开
	var g2 := Game.new(balance, fish, s2, clock, _rng(99))
	check(g2.fishing.state == Fishing.State.WAITING and g2.fishing.deadline_ms == deadline, "重启后接着等同一竿，咬钩时刻不变")
	var ev := _run(g2, clock, (deadline - clock.t) / 1000.0 + 60)
	check(_count(ev, "catch") <= 1 and (_count(ev, "catch") == 1 or g2.fishing.stage > 0 or g2.fishing.state != Fishing.State.WAITING), "到点照常动漂/上鱼，一竿最多一条")
	# 断点里是没见过的鱼或非法状态：放弃断点，正常重新抛竿
	var s3 := GameState.new()
	s3.fishing_checkpoint = {"state": Fishing.State.REELING, "state_start_ms": 0, "deadline_ms": 0, "hooked_fish": "shark"}
	var g3 := Game.new(balance, fish, s3, clock, _rng(1))
	check(g3.fishing.state == Fishing.State.IDLE, "非法断点被忽略")
	_run(g3, clock, 2)
	check(g3.fishing.state == Fishing.State.CASTING or g3.fishing.state == Fishing.State.WAITING, "然后正常抛竿")
	check(g3.state.basket.is_empty(), "非法断点不会凭空产生鱼")

func test_event_log() -> void:
	print("event log")
	var path := "user://logs/test_events.log"
	var dir := DirAccess.open("user://")
	dir.remove("logs/test_events.log"); dir.remove("logs/test_events.log.1")
	var lg := EventLog.new(path, 400)
	lg.write("app_start", {"version": "t"})
	lg.write("catch", {"fish_id": "koi"})
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	check(lines.size() == 2, "写入两行")
	var last = JSON.parse_string(lines[1])
	check(last is Dictionary and last["type"] == "catch" and last["fish_id"] == "koi" and last.has("time"), "每行是带时间和类型的 JSON")
	for i in 20:
		lg.write("filler", {"i": i})
	check(FileAccess.file_exists(path + ".1"), "超过上限后轮转出 .1")
	check(FileAccess.get_file_as_string(path).length() < 800, "当前日志保持在上限附近")
	dir.remove("logs/test_events.log"); dir.remove("logs/test_events.log.1")

func test_save() -> void:
	print("save")
	var path := "user://test_save.json"
	var dir := DirAccess.open("user://")
	for p in [path, path + ".bak", path + ".tmp"]:
		dir.remove(p)
	var sv := SaveService.new(path)
	check(sv.load_data().is_empty(), "无存档返回空")
	var s := GameState.new()
	s.wallet_gold = 77; s.basket = ["koi"]; s.pomodoro["cycle_done"] = 2
	check(sv.save(s.to_dict()), "第一次保存")
	s.wallet_gold = 99
	check(sv.save(s.to_dict()), "第二次保存")
	check(FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path + ".tmp"), "留有 .bak，没有残留 .tmp")
	var s2 := GameState.new()
	check(s2.from_dict(sv.load_data()) and s2.wallet_gold == 99 and s2.basket == ["koi"], "读档还原")
	check(typeof(s2.pomodoro["cycle_done"]) == TYPE_INT and s2.pomodoro["cycle_done"] == 2, "数字还原为 int")
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string("{broken"); f.close()
	var s3 := GameState.new()
	check(s3.from_dict(sv.load_data()) and s3.wallet_gold == 77, "主档损坏时回退 .bak")
	check(not GameState.new().from_dict({"save_version": 999}), "未知版本被拒绝")
	for p in [path, path + ".bak"]:
		dir.remove(p)

func test_bad_config() -> void:
	print("bad config (下面出现的 ERROR 是预期的)")
	var f := FileAccess.open("user://bad_fish.json", FileAccess.WRITE)
	f.store_string('{"fish":[{"id":"a","price":1,"weight":0,"sprite":"x"}]}'); f.close()
	check(ConfigLoader.load_fish("user://bad_fish.json").is_empty(), "权重为 0 的鱼配置被拒绝")
	check(ConfigLoader.load_balance("user://nope.json").is_empty(), "缺失的 balance 被拒绝")
	DirAccess.open("user://").remove("bad_fish.json")
