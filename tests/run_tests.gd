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
	check(fish.size() == 10, "fish.json 有 10 种鱼")
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
		test_dock_shoal(balance, fish)
		test_money_waves(balance, fish)
		test_v046(balance, fish)
		test_v047(balance, fish)
		test_v048(balance, fish)
		test_v050(balance, fish)
		test_v051(balance, fish)
		test_v052(balance, fish)
		test_v054(balance, fish)
		test_v055(balance, fish)
		test_v056(balance, fish)
		test_v059(balance, fish)
		test_v061(balance, fish)
		test_v062(balance, fish)
		test_v064(balance, fish)
		test_v067(balance, fish)
		test_v068_sell(balance, fish)
		test_v078(balance, fish)
		test_v082(balance, fish)
		test_v083(balance, fish)
		test_unstick(balance, fish)
		test_island_layout(balance, fish)
		test_mail(balance, fish)
		test_v088_ticket_and_locker(balance, fish)
		test_v093_open_shafts(balance, fish)
		test_v094_shaft_themes(balance, fish)
		test_v095_shaft_backdrop(balance, fish)
		test_v096_ore_dex(balance, fish)
		test_v097_no_helper_cycles()
		test_v098_perf_hygiene()
		test_v089_scripts_and_art()
		test_labels()
		test_warehouse(balance, fish)
		test_stats_and_bait_shop(balance, fish)
		test_outfit_shop_and_dock(balance, fish)
		test_quest(balance, fish)
		test_bag_gear_quests(balance, fish)
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
	for i in 40:
		eco.add_catch(s, "x%d" % i, "crucian", false)
	# 容量 10 单位：鲈鱼 1.0 + 小鲫鱼每条 0.4，装到第 23 条鲫鱼时 10.2 ≥ 10，满了就不再收
	check(s.basket.size() == 24 and eco.basket_full(s) and eco.basket_percent(s) == 100, "鱼篓按单位装满 (%d 条)" % s.basket.size())
	check(abs(eco.units_of("arowana") - 1.8) < 0.001 and abs(eco.units_of("loach") - 0.2) < 0.001, "大鱼占得多、小鱼占得少")
	var gold := eco.sell_basket(s, "s1")
	check(gold == 12 + 23 * 5, "卖鱼金额正确 (%d)" % gold)
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
	fs.zone = "shallow"
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
	check(waits.min() >= 8000 and waits.max() <= 60000, "第一次动漂前等待 8–60 秒（小鱼更快，最小 0.4 倍） (%d..%d)" % [waits.min(), waits.max()])
	check(gaps[0].min() >= 1600 and gaps[0].max() <= 10000, "第二次动漂在 10 秒内 (%d..%d)" % [gaps[0].min(), gaps[0].max()])
	check(gaps[1].min() >= 1000 and gaps[1].max() <= 5000, "第三次动漂在 5 秒内 (%d..%d)" % [gaps[1].min(), gaps[1].max()])
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
	check(g2.state.basket.size() == 9 and g2.economy.basket_full(g2.state) and _count(ev_k, "ate") == 0, "鱼篓里全是稀有鱼时不偷吃")
	check(g2.journey.activity() == Journey.Activity.IDLE_FULL, "一直满着等玩家")
	# 点击出发：航行 30s → 走 8s → 摆摊 → 走 8s → 返航 30s
	var expect := g2.economy.value_of(g2.state.basket)
	var n_before: int = g2.state.basket.size()
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
	check(sold == n_before and g2.state.basket.is_empty(), "%d 条鱼一条条卖完" % n_before)
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
	check(g.state.upgrades == {"rod": 5, "bait": 5, "basket": 5, "hook": 0}, "最多升到 5 级")
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
	for i in 25:
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
	for o in c["outfits"]:
		if o["sprite"] != "":
			check(FileAccess.file_exists("res://assets/cat/%s.png" % o["sprite"]), "衣服素材存在: " + o["sprite"])
	s.cat["fur"] = 3
	s.cat["pattern"] = 2
	s.cat["hat"] = 0
	s.cat["outfit"] = 2
	s.cat["created"] = true
	var s2 := GameState.new(); s2.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(int(s2.cat["fur"]) == 3 and int(s2.cat["pattern"]) == 2 and int(s2.cat["hat"]) == 0 and int(s2.cat["outfit"]) == 2 and s2.cat["created"], "形象随存档恢复")
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
	check(c3 > 0 and rate > 0.05 and rate < 0.15, "专注中宝箱占比约 8%% (基础 4%% 翻倍) (%d/%d = %.3f)" % [c3, c3 + f3, rate])
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
	var seen := {"shallow": {}, "deep": {}}
	for z in seen:
		fs.zone = z
		for i in 4000:
			seen[z][fs._roll_fish()] = true
	check(not seen["shallow"].has("arowana"), "浅水区钓不到银龙鱼")
	check(seen["deep"].has("arowana") and seen["deep"].has("catfish") and not seen["deep"].has("loach"), "深水区有银龙鱼和鲶鱼，没有泥鳅")
	check(seen["shallow"].has("bass") and seen["shallow"].has("koi"), "浅水区有鲈鱼和锦鲤（已取消普通水域）")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(4))
	check(g.zone_id(100.0) == "deep" and g.zone_id(250.0) == "shallow" and g.zone_id(400.0) == "shallow" and g.zone_id(-3000.0) == "deep", "按位置判断水域（远海也是深水区）")
	var zb := g.zone_bounds(640.0)
	check(zb.size() == 3 and zb[2]["x1"] == 640.0 and zb[2]["x0"] == zb[1]["x1"] and zb[1]["x0"] == zb[0]["x1"], "水域范围首尾相接（小岛浅水区 / 深水区 / 小镇浅水区）")
	check(g.zone_id(g.island_x() + 200.0) == "shallow" and g.zone_id(g.island_x() + 500.0) == "deep", "小岛附近是浅水区")
	check(g.can_steer() and g.steer_to(120.0) and g.journey.boat_x() == 120, "钓鱼时可以划船")
	check(g.steer_to(-50.0) and g.journey.boat_x() == 30 and g.steer_to(9999.0) and g.journey.boat_x() == 512, "划船范围有边界（右端是码头）")
	check(not g.line_out() and g.fishing.state == Fishing.State.IDLE, "划船先收杆")
	var c0: FakeClock = g._clock
	_run(g, c0, 30)
	check(g.fishing.state == Fishing.State.IDLE and not g.fishing.is_active(), "停船后不会自己甩竿")
	g.steer_to(300.0)
	check(g.cast_line() and g.line_out() and not g.cast_line(), "按互动键重新甩竿，不能重复")
	_run(g, c0, 2)
	check(g.fishing.is_active(), "甩竿后恢复钓鱼")
	g.economy.add_catch(g.state, "w1", "bass", false)
	g.go_to_town()
	check(not g.can_steer() and not g.steer_to(200.0), "出发后不能划船")
	var c: FakeClock = g._clock
	g.steer_to(200.0)
	_run(g, c, 100)
	check(g.journey.boat_x() == 300, "往返小镇不改变船的位置")

func test_sail_turn(balance: Dictionary, fish: Array) -> void:
	print("sail: 航行时长按路程折算、途中掉头")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(33))
	var c: FakeClock = g._clock
	_run(g, c, 2)
	g.steer_to(260.0)
	g.go_to_town()
	var far: int = int(g.state.journey["phase_end_ms"]) - int(g.state.journey["phase_start_ms"])
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(34))
	var c2: FakeClock = g2._clock
	_run(g2, c2, 2)
	g2.steer_to(480.0)
	g2.go_to_town()
	var near: int = int(g2.state.journey["phase_end_ms"]) - int(g2.state.journey["phase_start_ms"])
	check(near < far / 5 and near >= int(float(far) * 0.07), "离码头近航行时间按比例缩短 (远 %d / 近 %d)" % [far, near])
	# 打断：船停在当前位置
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(35))
	var c3: FakeClock = g3._clock
	_run(g3, c3, 2)
	g3.steer_to(260.0)
	check(g3.go_to_town() and g3.journey.activity() == Journey.Activity.SAIL_OUT, "出发")
	c3.t += 9000
	var px: float = g3.journey.sail_pos(c3.now_ms())
	check(px > 262.0 and px < 500.0, "航行中位置在路上 (%.1f)" % px)
	check(g3.can_halt_sail() and g3.halt_sail() and g3.journey.activity() == Journey.Activity.FISHING, "航行中可以打断")
	check(absi(g3.journey.boat_x() - int(round(px))) <= 1 and not g3.line_out(), "船停在原地，竿收着")
	check(g3.can_steer() and g3.cast_line(), "停下后可以再甩竿")
	var curve_ok := Journey.sail_curve(0.0) == 0.0 and absf(Journey.sail_curve(1.0) - 1.0) < 0.0001 and Journey.sail_curve(0.5) > 0.45 and Journey.sail_curve(0.9) < Journey.sail_curve(0.95)
	check(curve_ok, "速度曲线单调、首尾对")
	# 回钓点途中转向小镇
	g3.go_to_town()
	_run(g3, c3, 40)
	check(g3.journey.in_town() or g3.journey.activity() == Journey.Activity.WALK_TO_STALL, "能到小镇")

func test_warehouse(balance: Dictionary, fish: Array) -> void:
	print("warehouse: 家里仓库")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(41))
	g.inventory.add(g.state, "pearl", 3)
	g.inventory.add(g.state, "bait_worm", 50)
	g.use_item("bait_worm")
	check(g.state.equipped_bait == "bait_worm", "装上蚯蚓")
	check(g.stash_item("pearl") == 1 and g.inventory.count(g.state, "pearl") == 2 and g.inventory.count_w(g.state, "pearl") == 1, "存 1 个珍珠")
	check(g.stash_item("pearl", true) == 2 and g.inventory.count(g.state, "pearl") == 0 and g.inventory.owned(g.state).has("pearl") == false, "整堆存入后物品栏里没有")
	check(g.fetch_item("pearl", true) == 3 and g.inventory.count(g.state, "pearl") == 3 and g.inventory.count_w(g.state, "pearl") == 0, "整堆取回")
	check(g.stash_item("bait_worm", true) == 50 and g.state.equipped_bait == "", "鱼饵全存走后换回面团")
	g.inventory.add(g.state, "bait_worm", 60)
	check(g.fetch_item("bait_worm", true) == 50 and g.inventory.count(g.state, "bait_worm") == 110 and g.inventory.count_w(g.state, "bait_worm") == 0 and g.inventory.slots_of("bait_worm", 110) == 2, "叠过 99 个的占第二格，仓库的整堆取得回来")
	check(g.stash_item("nope") == 0 and g.fetch_item("pearl") == 0, "不存在或没有的不动")
	var st2 := GameState.new()
	check(st2.from_dict(g.state.to_dict()) and st2.warehouse == g.state.warehouse and st2.inventory == g.state.inventory, "仓库随存档保存和读取")
	var total_before: int = g.inventory.count(g.state, "bait_worm") + g.inventory.count_w(g.state, "bait_worm")
	for i in 50:
		g.stash_item("bait_worm", i % 2 == 0)
		g.fetch_item("bait_worm", i % 3 == 0)
	check(g.inventory.count(g.state, "bait_worm") + g.inventory.count_w(g.state, "bait_worm") == total_before, "来回搬不丢不多")

func test_stats_and_bait_shop(balance: Dictionary, fish: Array) -> void:
	print("stats: 按小时专注记录 / 买鱼饵")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(51))
	g._record_focus_hours("2026-01-01", 25)         # 假时钟固定 15:00，往前 25 分钟 = 14:35–15:00
	var h: Array = g.focus_hours_of("2026-01-01")
	check(h.size() == 24 and int(h[14]) + int(h[15]) == 25 * 60, "25 分钟的专注全部记进了某些小时里")
	check(int(h[14]) == 1500 and int(h[15]) == 0, "14:35–15:00 全在 14 点那一格")
	check(g.focus_hours_of("2026-01-02").size() == 24 and int(g.focus_hours_of("2026-01-02")[10]) == 0, "没记录的一天全是 0")
	g._record_focus_hours("2026-01-01", 25)
	check(int(g.focus_hours_of("2026-01-01")[14]) == 3000, "同一天累加")
	var st2 := GameState.new()
	check(st2.from_dict(g.state.to_dict()) and int(st2.stats["focus_hours"]["2026-01-01"][14]) == 3000, "按小时记录随存档保存")
	check(g.shop_baits().has("bait_worm") and g.shop_baits().has("bait_shrimp"), "商店里有蚯蚓和小虾")
	g.state.wallet_gold = 100
	check(g.bait_unlocked("bait_worm") and not g.bait_unlocked("bait_shrimp"), "小虾要钓够 20 条鱼才解锁")
	check(not g.buy_bait("bait_shrimp") and g.state.wallet_gold == 100, "没解锁不能买")
	check(g.buy_bait("bait_worm") and g.state.wallet_gold == 85 and g.inventory.count(g.state, "bait_worm") == 1, "买蚯蚓扣 15 金币")
	g.state.stats["total_fish"] = 20
	check(g.bait_unlocked("bait_shrimp") and g.buy_bait("bait_shrimp") and g.state.wallet_gold == 45, "解锁后能买小虾")
	g.state.wallet_gold = 0
	check(not g.can_buy_bait("bait_worm"), "钱不够不能买")
	g.state.wallet_gold = 9999
	g.inventory.add(g.state, "bait_worm", 98)
	g.state.inventory["gold_ore"] = g.inventory.stack_cap("gold_ore")
	g.state.bag_slots = g.inventory.slots_used(g.state)
	check(not g.buy_bait("bait_worm") and g.inventory.count(g.state, "bait_worm") == 99, "鱼饵叠满 99 个、又没有空格子就不能再买")

func test_outfit_shop_and_dock(balance: Dictionary, fish: Array) -> void:
	print("outfit: 买帽子 / 买衣服 / 码头不能钓鱼")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(52))
	g.set_cat_cfg(ConfigLoader.load_cat())
	check(g.cat_owns("hat", 1) and g.cat_owns("hat", 0) and not g.cat_owns("hat", 2), "草帽和无帽一开始就有，渔夫帽没有")
	check(g.cat_owns("outfit", 0) and not g.cat_owns("outfit", 1), "衣服一开始只有没穿")
	check(not g.wear_cat_item("outfit", 1), "没买不能穿")
	g.state.wallet_gold = 100
	check(not g.buy_cat_item("outfit", 1) and g.state.wallet_gold == 100, "钱不够不扣钱")
	g.state.wallet_gold = 500
	check(g.buy_cat_item("outfit", 1) and g.state.wallet_gold == 380, "红围巾 120 金币")
	check(not g.buy_cat_item("outfit", 1) and g.state.wallet_gold == 380, "重复买不会再扣钱")
	check(g.wear_cat_item("outfit", 1) and int(g.state.cat["outfit"]) == 1, "买下后可以穿上")
	check(g.buy_cat_item("hat", 2) and g.wear_cat_item("hat", 2) and int(g.state.cat["hat"]) == 2, "买渔夫帽并戴上")
	var st2 := GameState.new()
	var ok: bool = st2.from_dict(g.state.to_dict())
	var g2 := Game.new(balance, fish, st2, FakeClock.new(), _rng(53))
	g2.set_cat_cfg(ConfigLoader.load_cat())
	check(ok and g2.cat_owns("outfit", 1) and g2.cat_owns("hat", 2) and int(st2.cat["outfit"]) == 1, "买过的东西随存档保存")
	var old := GameState.new()
	old.cat = {"fur": 0, "pattern": 1, "hat": 3, "created": true}     # 老存档里没有 own_* 字段，戴着贝雷帽
	var g3 := Game.new(balance, fish, old, FakeClock.new(), _rng(54))
	g3.state.cat["own_hats"] = [0, 1]
	g3.state.cat["own_outfits"] = [0]
	g3.set_cat_cfg(ConfigLoader.load_cat())
	check(g3.cat_owns("hat", 3), "老存档里正戴着的帽子算已拥有")
	# 船停在码头边上不能钓鱼
	var g4 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(55))
	g4.journey.set_boat_x(float(balance["town"]["dock_x"]))
	check(g4.at_dock() and not g4.cast_line(), "靠着码头不能甩竿")
	g4.journey.set_boat_x(float(balance["town"]["dock_x"]) - 60.0)
	check(not g4.at_dock(), "离码头远了不算靠码头")

func test_quest(balance: Dictionary, fish: Array) -> void:
	print("quest: 漂流瓶、支线任务、宝箱只出宝物")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(61))
	var rng := _rng(62)
	var seen := {}
	for i in 400:
		seen[g.inventory.roll(rng, "chest")] = true
	check(not seen.has("bottle") and not seen.has("boot") and not seen.has("bait_worm") and seen.has("pearl") and seen.has("map_piece"), "宝箱里没有漂流瓶、旧靴子和鱼饵")
	check(g.quest_state("keeper") == "" and not g.can_turn_in("keeper"), "一开始没有任务")
	g.inventory.add(g.state, "bottle", 2)
	var r: Dictionary = g.use_item("bottle")
	check(r["ok"] and r["quest"] == "keeper" and g.quest_state("keeper") == "active" and g.inventory.count(g.state, "bottle") == 1, "第一个漂流瓶开启任务")
	var r2: Dictionary = g.use_item("bottle")
	check(r2["ok"] and r2["quest"] == "tailor" and g.quest_state("tailor") == "active" and g.quest_state("keeper2") == "", "第二个漂流瓶开服装店的任务；第三个任务要等老板的任务做完")
	check(not g.turn_in("keeper"), "东西不够不能交付")
	g.inventory.add(g.state, "pearl")
	check(not g.turn_in("keeper") and g.inventory.count(g.state, "pearl") == 1, "只有一样也不扣东西")
	g.inventory.add(g.state, "boot")
	var rb0: float = g.fishing.rarity_bonus
	check(g.can_turn_in("keeper") and g.turn_in("keeper"), "凑齐就能交付")
	check(g.quest_state("keeper") == "done" and g.inventory.count(g.state, "pearl") == 0 and g.inventory.count(g.state, "boot") == 0, "交付后扣掉物品，任务完成")
	check(g.equipment_name("hook") == "银钩" and is_equal_approx(g.fishing.rarity_bonus, rb0) and g.fishing.gear_wait_mult < 1.0, "奖励银钩：咬钩更快，稀有度不变")
	g.inventory.add(g.state, "pearl"); g.inventory.add(g.state, "boot")
	check(not g.turn_in("keeper") and g.inventory.count(g.state, "pearl") == 1, "不能重复交付")
	var st2 := GameState.new()
	check(st2.from_dict(g.state.to_dict()) and st2.quests.get("keeper", "") == "done" and int(st2.gear["hook"]) == 1, "任务状态和银钩随存档保存")
	# 钓到杂物：概率调到 1，必定钓到漂流瓶或旧靴子，且不进鱼篓
	var b2 := balance.duplicate(true)
	b2["junk"]["chance"] = 1.0
	var g2 := Game.new(b2, fish, GameState.new(), FakeClock.new(), _rng(63))
	var got := ""
	for i in 20:
		got = g2._roll_junk()
		if got != "":
			break
	check(got == "bottle" or got == "boot", "杂物只会是漂流瓶或旧靴子")

func test_bag_gear_quests(balance: Dictionary, fish: Array) -> void:
	print("bag: 容量 / 装备物品 / 更多支线")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(71))
	var inv = g.inventory
	check(g.state.bag_slots == 8 and g.equipment_name("rod") == "树枝" and int(g.state.gear["rod"]) == 0, "开局 8 格，身上装着树枝竿")
	# 每格最多叠 10 个
	check(inv.add(g.state, "pearl", 10) and inv.count(g.state, "pearl") == 10 and inv.slots_used(g.state) == 1, "珍珠一格 10 个")
	check(g.give("pearl") == "bag" and inv.count(g.state, "pearl") == 11 and inv.slots_used(g.state) == 2, "叠满了再来一个占下一格，不会被扔掉")
	check(inv.cells(g.state) == [["pearl", 10], ["pearl", 1]], "物品栏里分成两格显示")
	g.state.bag_slots = inv.slots_used(g.state)
	check(g.give("boot") == "dropped" and inv.count(g.state, "boot") == 0, "格子真的满了，普通物品只好扔掉")
	check(g.take_overflow() == "dropped" and g.take_overflow() == "", "扔掉会提示一次")
	# 8 种东西占满 8 格，第 9 种放不下
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(72))
	var kinds := ["bottle", "boot", "pearl", "bell", "lucky_bait", "map_piece", "bait_worm", "bait_shrimp"]
	for k in kinds:
		inv.add(g2.state, k)
	check(inv.slots_used(g2.state) == 8, "八种物品占满 8 格")
	check(not inv.add(g2.state, "rod_1") and g2.give("rod_1") == "replaced" and inv.count(g2.state, "rod_1") == 1 and inv.slots_used(g2.state) == 8 and inv.count_w(g2.state, "rod_1") == 0, "第 9 种是装备：顶掉一件普通物品，不进仓库")
	var g2b := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(73))
	g2b.state.bag_slots = 2
	inv.add(g2b.state, "bell"); inv.add(g2b.state, "pearl")
	check(g2b.give("boot") == "dropped" and inv.count(g2b.state, "boot") == 0 and inv.count_w(g2b.state, "boot") == 0, "普通物品放不下：直接扔掉，不进仓库")
	check(g2b.give("bottle") == "replaced" and inv.count(g2b.state, "bottle") == 1 and inv.count(g2b.state, "bell") == 0 and inv.count(g2b.state, "pearl") == 1, "重要物品顶掉普通物品，不动别的重要物品")
	var g2c := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(74))
	for k in ["bottle", "pearl", "map_piece", "rod_1", "rod_2", "rod_3", "rod_4", "rod_5"]:
		inv.add(g2c.state, k)
	check(g2c.give("hook_1") == "warehouse" and g2c.give("boot") == "dropped", "全是重要物品时：装备才进仓库，普通物品扔掉")
	g2.state.wallet_gold = 1000
	inv.remove(g2.state, "bait_worm", 1)
	inv.add(g2.state, "rod_2")                   # 把空出来的格子占上
	check(not g2.can_buy_bait("bait_worm") and not g2.buy_bait("bait_worm") and g2.state.wallet_gold == 1000, "格子满了不能买新鱼饵，不扣钱")
	g2.state.warehouse["rod_3"] = 1
	check(inv.fetch(g2.state, "rod_3", 1) == 0 and inv.count_w(g2.state, "rod_3") == 1, "身上满了取不出仓库里的新种类")
	# 装备：买鱼竿自动装上，旧的进物品栏；使用物品栏里的装备换回去
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(73))
	g3.state.wallet_gold = 100000
	var mult0: float = g3._free_multiplier
	check(g3.buy_upgrade("rod") and g3.equipment_name("rod") == "竹竿" and inv.count(g3.state, "rod_0") == 1, "买竹竿自动装上，树枝竿进物品栏")
	check(g3._free_multiplier < mult0, "新鱼竿让自由挂机等得更短")
	check(g3.use_item("rod_0")["ok"] and g3.equipment_name("rod") == "树枝" and inv.count(g3.state, "rod_1") == 1 and inv.count(g3.state, "rod_0") == 0, "装回树枝竿，竹竿换回物品栏")
	check(g3._free_multiplier == mult0 and int(g3.state.upgrades["rod"]) == 1, "鱼竿效果看身上装的，买竿进度不变")
	check(inv.stash(g3.state, "rod_1", 1) == 1 and inv.count_w(g3.state, "rod_1") == 1, "装备可以存进仓库")
	var st2 := GameState.new()
	check(st2.from_dict(g3.state.to_dict()) and int(st2.gear["rod"]) == 0 and st2.bag_slots == 8, "身上的装备和格子数随存档保存")
	# 老存档：没有 gear 字段，按升级档位补上
	var old := GameState.new()
	old.upgrades["rod"] = 3
	old.upgrades["hook"] = 1
	var g4 := Game.new(balance, fish, old, FakeClock.new(), _rng(74))
	check(g4.equipment_name("rod") == "碳素" and g4.equipment_name("hook") == "银钩", "老存档的装备按升级档位补上")
	# 支线：服装店老板 → 大口袋；老板第二个 → 金钩
	var g5 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(75))
	g5.state.quests["keeper"] = "done"
	check(g5.next_quest_letter() == "tailor", "老板的任务完成后，下一封信是服装店的")
	g5.state.quests["tailor"] = "active"
	check(g5.room_quest("tailor") == "tailor" and g5.room_quest("tackle") == "keeper2", "按屋子找到该说的任务（做完的不再占着，下一个没开始的任务先说）")
	g5.inventory.add(g5.state, "boot", 2); g5.inventory.add(g5.state, "bell")
	check(g5.turn_in("tailor") and g5.state.bag_slots == 12 and g5.quest_state("tailor") == "done", "交付后背包扩到 12 格")
	check(g5.next_quest_letter() == "keeper2", "两个都完成后，下一封信是老板的第二个任务")
	g5.state.quests["keeper2"] = "active"
	g5.inventory.add(g5.state, "pearl", 2); g5.inventory.add(g5.state, "lucky_bait")
	check(g5.turn_in("keeper2") and g5.equipment_name("hook") == "金钩" and g5.room_quest("tackle") == "keeper2", "交付得到金钩")
	check(g5.next_quest_letter() == "", "任务都做完了，没有新的信")

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
	check(inv.defs.filter(func(d): return d["use"] != "gear").size() == 56 and inv.defs.filter(func(d): return d["use"] == "gear").size() == 10 and inv.owned(g.state).is_empty(), "21 种普通物品 + 35 种新矿石（共 38 种矿石）+ 10 件装备，开局物品栏为空")
	check(not inv.add(g.state, "nope") and inv.add(g.state, "boot") and inv.add(g.state, "boot", 2), "只能加入已定义的物品，同种叠加")
	check(inv.count(g.state, "boot") == 3 and inv.owned(g.state) == ["boot"], "旧靴子 ×3 只占一格")
	check(not inv.can_use(g.state, "boot") and not g.use_item("boot")["ok"] and inv.count(g.state, "boot") == 3, "收藏品不能使用，也不会被扣掉")
	check(not g.use_item("bottle")["ok"], "没有的物品不能用")
	# 漂流瓶：得金币
	for q in balance["quests"]:
		g.state.quests[q["id"]] = "done"      # 任务都完成后，漂流瓶里只有零钱
	inv.add(g.state, "bottle")
	var r := g.use_item("bottle")
	check(r["ok"] and r["gold"] == 0 and g.state.wallet_gold == 0, "没有新任务的漂流瓶是空的，不给钱")
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
	g3.state.bag_slots = 40                  # 格子和叠加上限放大，这里只看"开出多少 = 收到多少"
	g3.inventory.stack_default = 100000
	var ev := _run(g3, g3._clock, 8 * 3600, 1000)
	var chests: Array = ev.filter(func(e): return e["type"] == "chest")
	var with_item: Array = chests.filter(func(e): return e["item"] != "")
	var rate := float(with_item.size()) / float(chests.size())
	check(chests.size() > 100 and rate > 0.45 and rate < 0.75, "约 60%% 的宝箱带物品 (%d/%d)" % [with_item.size(), chests.size()])
	var total := 0
	var kinds := {}
	for id in g3.state.inventory:
		total += int(g3.state.inventory[id])
		kinds[id] = true
	for id in g3.state.warehouse:          # 行李满了会送去仓库，也算
		total += int(g3.state.warehouse[id])
		kinds[id] = true
	var gifts := ev.filter(func(e): return e["type"] == "bird_gift").size()
	check(total == with_item.size() + gifts, "开出的物品和鸟送的礼物都进了物品栏 (%d = %d + %d)" % [total, with_item.size(), gifts])
	check(kinds.size() == 8, "跑够久，8 种物品都开出来过 (%d)" % kinds.size())
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
	g.state.gear["rod"] = 2
	check(g.equipment_name("rod") == "玻纤" and not g.bait_active(), "鱼竿随升级换名字；没有幸运鱼饵时鱼饵格为空")

func test_bait(balance: Dictionary, fish: Array) -> void:
	print("鱼饵、上饵动作、空军、鱼的大小")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(21))
	g.set_chest_chance(0.0)
	check(g.inventory.add(g.state, "bait_worm", 200) and g.inventory.count(g.state, "bait_worm") == 200 and g.inventory.slots_used(g.state) == 3, "鱼饵每格 99 个，200 个占三格")
	g.state.bag_slots = 3
	check(g.inventory.add(g.state, "bait_worm", 1000) and g.inventory.count(g.state, "bait_worm") == 297, "格子满了只放得下剩下的空位")
	check(not g.inventory.add(g.state, "bait_worm", 1), "没有空位再加不进去")
	g.state.bag_slots = 8
	g.inventory.remove(g.state, "bait_worm", 198)
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


func test_dock_shoal(balance: Dictionary, fish: Array) -> void:
	print("dock: 贴码头直接上岸/登船不划桨，浅滩不能钓鱼")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(61))
	var c: FakeClock = g._clock
	_run(g, c, 2)
	var dx: float = g.journey.cfg_dock_x()
	g.steer_to(dx)
	check(g.at_dock(), "贴着码头 at_dock")
	check(g.fishing_blocked(), "码头边不能钓鱼")
	g.go_to_town()
	check(int(g.state.journey["activity"]) != Journey.Activity.SAIL_OUT, "在码头直接上岸，不划船")
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(62))
	var c2: FakeClock = g2._clock
	_run(g2, c2, 2)
	g2.steer_to(dx - float(balance["town"]["dock_no_fish"]) - 20.0)
	check(not g2.fishing_blocked(), "浅滩外可以钓鱼")
	g2.steer_to(dx - 30.0)
	check(g2.fishing_blocked() and not g2.at_dock(), "浅滩内不能钓鱼但不算靠岸")

	# 装备属性文字
	check(g.gear_stat("rod_0") == ["挂机速度", "+0％"], "树枝竿属性 +0％")
	check(str(g.gear_stat("rod_3")[0]) == "挂机速度" and str(g.gear_stat("rod_3")[1]).begins_with("+"), "鱼竿有速度属性")
	check(g.gear_stat("hook_1") == ["咬钩速度", "+5％"], "银钩咬钩速度 +5％")
	check(g.gear_stat("bell").is_empty(), "非装备没有属性")


func test_money_waves(balance: Dictionary, fish: Array) -> void:
	print("money: 金银铜换算、去尾显示、钱包封顶与存钱罐；浪区推力")
	check(Money.tier(0) == ["copper", 0] and Money.tier(8) == ["copper", 8], "8 铜显示铜")
	check(Money.tier(19) == ["silver", 1], "19 铜去尾显示 1 银")
	check(Money.tier(100) == ["gold", 1] and Money.tier(189) == ["gold", 1], "189 铜只显示 1 金")
	check(Money.icon(9) == "coin_copper" and Money.icon(10) == "coin_silver" and Money.icon(100) == "coin", "图标按档位")
	var g := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(71))
	g.state.wallet_gold = Money.WALLET_CAP + 250
	g.tick()
	check(g.state.wallet_gold == Money.WALLET_CAP and g.state.piggy == 250, "超过 999 金的部分进存钱罐")
	check(g.take_wallet_full() and not g.take_wallet_full(), "钱包满了只提示一次")
	check(g.wallet_is_full(), "钱包满")
	check(g.piggy_use() == "deposit" and g.state.wallet_gold == 0 and g.state.piggy == Money.WALLET_CAP + 250, "钱包有钱：全存进去")
	check(g.piggy_use() == "withdraw" and g.state.wallet_gold == Money.WALLET_CAP and g.state.piggy == 250, "钱包空了：取出到封顶")
	var s2 := GameState.new()
	s2.piggy = 77
	var s3 := GameState.new()
	s3.from_dict(s2.to_dict())
	check(s3.piggy == 77, "存钱罐存档往返")
	var w := g.wave_zone()
	check(g.wave_push(w.x + 5.0) == 0.0 and g.wave_push(w.y) == 1.0 and g.wave_push((w.x + w.y) / 2.0) > 0.0, "浪区推力：入口 0，最深处 1")


func test_v047(balance: Dictionary, fish: Array) -> void:
	print("v047: 船坞——船只等级、浪区范围、幂等购买")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(91))
	var levels: Array = g.boat_levels()
	check(levels.size() >= 3, "至少有三级以上的船 (%d)" % levels.size())
	var z0 := g.wave_zone()
	check(g.state.boat_level == 0 and not g.boat_passes_waves() and g.wave_push(z0.y) == 1.0, "初始是 0 级船，过不了浪区")
	# 钱不够不能买；不能跳级；不能买已有的
	check(not g.buy_boat_upgrade(1), "没钱买不了")
	g.state.wallet_gold = 90000
	check(not g.buy_boat_upgrade(2), "不能跳级购买")
	check(not g.buy_boat_upgrade(0), "不能重复买 0 级")
	var before: int = g.state.wallet_gold
	check(g.buy_boat_upgrade(1), "买 1 级成功")
	check(g.state.wallet_gold == before - g.boat_price(1), "只扣一次 1 级的价钱")
	check(not g.buy_boat_upgrade(1) and g.state.wallet_gold == before - g.boat_price(1), "重复提交 1 级不会再扣钱")
	check(g.wave_zone() == z0 and g.boat_passes_waves() and g.wave_push(z0.y) == 0.0, "升级后浪区还在，但船能过去")
	check(g.wave_push(70.0) < GameState.new().boat_level + 1.0 and g.wave_push(70.0) < Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(92)).wave_push(70.0), "升级后同一位置受到的浪推力更小")
	# 逐级买到顶，最高级没有浪
	while g.state.boat_level < levels.size() - 1:
		g.state.wallet_gold = 90000
		check(g.buy_boat_upgrade(g.state.boat_level + 1), "逐级购买")
	check(g.boat_passes_waves() and g.wave_push(31.0) == 0.0, "最高级的船也能过浪区")
	check(not g.buy_boat_upgrade(levels.size()), "超过最高级不能买")
	# 存档往返
	var st2 := GameState.new()
	check(st2.from_dict(g.state.to_dict()) and st2.boat_level == g.state.boat_level, "船的等级存进存档再读回来")
	check(GameState.new().from_dict({"save_version": GameState.new().save_version}) , "旧存档没有 boat_level 也能读") 

func test_v048(balance: Dictionary, fish: Array) -> void:
	print("v048: 装备升级不影响稀有度/宝箱，专注时翻倍")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(95))
	var base_chest: float = g.fishing.chest_chance
	g.state.wallet_gold = 90000
	for k in ["bait", "rod", "basket"]:
		for n in 5:
			g.buy_upgrade(k)
	check(is_equal_approx(g.fishing.rarity_bonus, 0.0), "升满装备，稀有度加成仍为 0")
	check(g.fishing.gear_wait_mult < 1.0, "鱼饵升级只缩短咬钩等待 (%.2f)" % g.fishing.gear_wait_mult)
	var c: FakeClock = g._clock
	_run(g, c, 5.0)
	var focus: bool = g.in_focus()
	var expect: float = base_chest * (2.0 if focus else 1.0)
	check(is_equal_approx(g.fishing.chest_chance, expect) and is_equal_approx(g.fishing.luck_mult, 2.0 if focus else 1.0), "宝箱概率只随专注翻倍，不随装备变化 (focus=%s)" % str(focus))

func test_v050(balance: Dictionary, fish: Array) -> void:
	print("v050: 小岛、被偷播报尺寸、普通水域取消")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(97))
	var ix: float = g.island_x()
	check(g.boat_limits().x == 30.0, "小木船只能划到浪区边上")
	g.state.wallet_gold = 90000
	g.buy_boat_upgrade(1)
	check(g.boat_limits().x == ix, "能穿过浪区的船可以划到小岛 (%.0f)" % ix)
	check(g.steer_to(ix) and g.journey.boat_x() == int(ix), "能划到小岛的码头")
	check(g.at_island_dock() and g.fishing_blocked(), "小岛码头边水太浅，不能钓鱼")
	var ev: Array = []
	g._check_island(ev)
	check(ev.size() == 1 and ev[0]["type"] == "island_found" and g.island_visited(), "第一次到小岛：发现事件")
	var ev2: Array = []
	g._check_island(ev2)
	check(ev2.is_empty(), "只发现一次")
	var st2 := GameState.new()
	check(st2.from_dict(g.state.to_dict()) and st2.islands == g.state.islands, "已探索的岛随存档保存")
	g.steer_to(-2000.0)
	check(g.zone_id(float(g.journey.boat_x())) == "deep" and not g.fishing_blocked(), "远海是深水区，可以钓鱼")
	# 被偷 / 被吃的鱼带尺寸
	var g2 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(98))
	check(g2.economy.add_catch(g2.state, "z1", "bass", false, 41) and g2.state.basket_sizes == [41], "鱼篓记着每条鱼的尺寸")
	check(g2.economy.add_catch(g2.state, "z2", "crucian", false, 17), "再放一条")
	check(g2.economy.eat_cheapest(g2.state) == "crucian" and g2.economy.last_removed_size == 17 and g2.state.basket_sizes == [41], "被吃的鱼报出尺寸")
	var st3 := GameState.new()
	check(st3.from_dict(g2.state.to_dict()) and st3.basket_sizes == [41], "尺寸随存档保存；旧存档没有尺寸也能读")
	var old := g2.state.to_dict()
	old.erase("basket_sizes")
	var st4 := GameState.new()
	check(st4.from_dict(old) and st4.basket_sizes.size() == st4.basket.size(), "旧存档补齐尺寸")

func test_v051(balance: Dictionary, fish: Array) -> void:
	print("v051: 海流、起名、回小镇停在码头")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(101))
	check(g.current_mult(300.0, -1.0) == 1.0 and g.current_mult(300.0, 1.0) == 1.0, "浪区外没有海流")
	check(is_equal_approx(g.current_mult(0.0, -1.0), 0.8) and is_equal_approx(g.current_mult(0.0, 1.0), 1.2), "海流：逆流 ×0.8，顺流 ×1.2")
	check(is_equal_approx(g.current_mult(-2000.0, -1.0), 0.8), "海流一直延伸到远海")
	check(g.current_mult(g.island_x() + 40.0, -1.0) > 0.95, "靠近小岛海流消失")
	check(g.set_cat_name("  小花小花小花小花  ") == "小花小花小花小" .substr(0, 6) and g.state.cat_name.length() == 6, "名字最多 6 个字")
	check(g.set_cat_name("   ") == Game.DEFAULT_NAMES[0], "空名字用默认名")
	var st := GameState.new()
	check(st.from_dict(g.state.to_dict()) and st.cat_name == g.state.cat_name, "名字随存档保存")
	check(g.town_name() == "潮声镇", "小镇有名字")
	# 回小镇（目的地面板）：到码头后停下自己逛，不去摊位卖鱼
	var g2 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(102))
	g2.economy.add_catch(g2.state, "q1", "bass", false, 30)
	g2.steer_to(300.0)
	check(g2.go_to_town(true), "出发回小镇")
	var c2: FakeClock = g2._clock
	_run(g2, c2, 120.0)
	check(g2.journey.activity() == Journey.Activity.ROAM and not g2.state.basket.is_empty(), "到了码头：停下来自己逛，鱼还在篓里")
	var g3 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(103))
	g3.economy.add_catch(g3.state, "q1", "bass", false, 30)
	g3.steer_to(300.0)
	g3.go_to_town(false)
	_run(g3, g3._clock, 120.0)
	check(g3.journey.activity() != Journey.Activity.ROAM, "普通回小镇仍然自动去摊位")

func test_v052(balance: Dictionary, fish: Array) -> void:
	print("v052: 登岛、灯塔看守的任务、物品叠格")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(111))
	g.state.boat_level = 1
	g.steer_to(g.island_x())
	check(g.at_island_dock() and g.can_land(), "船贴着岛的码头可以登岛")
	check(g.land_on_island() and g.journey.on_island() and g.journey.roam_x() == int(g.island_land_x()), "登岛：小猫站在码头尽头")
	check(not g.journey.on_boat() and not g.journey.in_town(), "在岛上既不算在船上也不算在镇上")
	_run(g, g._clock, 60.0)
	check(g.journey.on_island() and g.state.basket.is_empty(), "岛上不会自己走开，也不钓鱼")
	check(g.leave_island() and g.journey.activity() == Journey.Activity.FISHING, "回船接着钓鱼")
	check(not g.leave_island(), "不在岛上不能回船")
	check(g.room_quest("lighthouse") == "lighthouse" and g.quest_state("lighthouse") == "" and g.next_quest_letter() != "lighthouse", "看守的任务当面接，不会出现在漂流瓶里")
	g.begin_talk_quest("lighthouse")
	check(g.quest_state("lighthouse") == "active" and not g.can_turn_in("lighthouse"), "聊一次就接下任务")
	g.inventory.add(g.state, "bottle", 2)
	g.inventory.add(g.state, "pearl", 1)
	var gold_q := g.state.wallet_gold
	check(g.turn_in("lighthouse") and g.state.wallet_gold == gold_q + 100 and g.inventory.count(g.state, "bottle") == 0, "交付后拿到酬劳")
	check(not g.turn_in("lighthouse") and g.state.wallet_gold == gold_q + 100, "任务只能交一次")
	check(g.zone_id(g.island_x() + 100.0) == "shallow" and g.zone_id(g.island_x() + 800.0) == "deep", "岛边是浅水区")

func test_v054(balance: Dictionary, fish: Array) -> void:
	print("v054: 岛心湖钓鱼")
	var b2 := balance.duplicate(true)
	b2["lake_junk"]["chance"] = 1.0
	var g := Game.new(b2, fish, GameState.new(), FakeClock.new(), _rng(121))
	var c: FakeClock = g._clock
	g.state.boat_level = 1
	g.steer_to(g.island_x())
	g.land_on_island()
	check(g.fishing_blocked() and not g.cast_line(), "不在湖边不能钓鱼")
	g.journey.set_roam_x(g.lake_spot_x())
	check(g.at_lake_spot() and not g.fishing_blocked() and g.cast_line() and g.line_out(), "站到湖边可以甩竿")
	var junk := {}
	var fish_seen := {}
	g.state.quests["lighthouse"] = "done"
	g.state.quests["lighthouse2"] = "active"        # 任务要雾灯贝，湖里才会钓到
	for e in _run(g, c, 900.0):
		if e["type"] == "junk":
			junk[e["item"]] = true
		elif e["type"] == "catch":
			fish_seen[e["fish_id"]] = true
	check(g.fishing.zone == "lake" and not junk.is_empty() and junk.has("lamp_shell"), "湖里钓到的杂物来自湖区杂物表（有雾灯贝）")
	check(g.inventory.count(g.state, "lamp_shell") > 0, "雾灯贝进了物品栏")
	check(g.journey.on_island(), "钓鱼时小猫一直在岛上")
	g.journey.set_roam_x(g.lake_spot_x() + 80.0)
	_run(g, c, 3.0)
	check(not g.line_out(), "走开后自动收竿")
	g.journey.set_roam_x(g.lake_spot_x())
	g.cast_line()
	g.leave_island()
	check(g.journey.activity() == Journey.Activity.FISHING and not g.journey.on_island(), "回船后回到海上")
	var b3 := balance.duplicate(true)
	b3["lake_junk"]["chance"] = 0.0
	var g2 := Game.new(b3, fish, GameState.new(), FakeClock.new(), _rng(122))
	g2.state.boat_level = 1
	g2.steer_to(g2.island_x()); g2.land_on_island()
	g2.journey.set_roam_x(g2.lake_spot_x()); g2.cast_line()
	for e in _run(g2, g2._clock, 1500.0):
		if e["type"] == "catch":
			fish_seen[e["fish_id"]] = true
	check(not fish_seen.is_empty() and not fish_seen.has("arowana") and not fish_seen.has("catfish"), "湖里只有小鱼，没有深水大鱼")

func test_v055(balance: Dictionary, fish: Array) -> void:
	print("v055: 拾取、信号台、日记任务、雾灯鱼")
	var SG = preload("res://core/signal_game.gd")
	var rng := _rng(131)
	var sg = SG.new(balance["signal"])
	sg.start(1000, rng)
	check(sg.marker(1000) == 0.0 and absf(sg.marker(1000 + int(sg.period_ms() / 2.0)) - 1.0) < 0.01, "光点从左端出发，半个周期到右端")
	var t := 1000 + int(sg.period_ms() * (sg.target + 0.0) / 2.0)   # 光点第一次经过光斑中心的时刻
	check(sg.press(t, rng) == 2 and sg.good == 1 and sg.perfect == 1, "正中光斑中心 = 正中")
	var miss_t: int = sg.t0_ms + int(sg.period_ms() * (1.0 if sg.target < 0.5 else 0.0) * 0.0)
	check(sg.press(sg.t0_ms, rng) in [0, 1], "按键会进入下一轮")
	for i in 10:
		sg.press(sg.t0_ms, rng)
	check(sg.finished and sg.press(0, rng) == -1 and sg.round_i == sg.rounds(), "打完几轮就结束，再按无效")
	# 游戏：灯没修好不能玩；修好后结算、冷却
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(132))
	check(not g.signal_ready() and not g._fish_gate("lamp"), "灯塔没修好：信号台关着、没有雾灯鱼")
	g.state.quests["lighthouse2"] = "done"
	check(g.lighthouse_lit() and g.signal_ready(), "灯塔修好后信号台可用")
	var before := g.state.wallet_gold
	var r := g.signal_finish(5, 2)
	check(r["gold"] == 5 * 6 + 2 * 14 and not r["shell"] and g.state.wallet_gold == before + 58 and g.inventory.count(g.state, "lamp_shell") == 0, "结算：铜币到账；任务不要雾灯贝就不再给（不超额）")
	g.state.quests["lighthouse2"] = "active"
	g._clock.t += 21 * 60000
	var r2 := g.signal_finish(5, 2)
	check(r2["shell"] and g.inventory.count(g.state, "lamp_shell") == 1, "任务正要雾灯贝时命中够多才送")
	g.state.quests["lighthouse2"] = "done"
	g.inventory.remove(g.state, "lamp_shell", 1)
	check(not g.signal_ready() and g.signal_wait_s() > 0, "结算后冷却")
	g._clock.t += 21 * 60000
	check(g.signal_ready(), "冷却结束可再玩")
	# 拾取
	g.state.boat_level = 1
	g.steer_to(g.island_x()); g.land_on_island()
	check(g.drift_count() == 3 and g.drift_ready(0) and g.drift_near(g.drift_x(0)) == 0 and g.drift_near(g.drift_x(0) + 900.0) == -1, "岛上有三处可拾，离远了拾不到")
	var got := g.pick_drift(0)
	check(not got.is_empty() and not g.drift_ready(0) and g.pick_drift(0).is_empty(), "拾一次后这一格要等一会儿")
	g._clock.t += 9 * 60000
	check(g.drift_ready(0), "过一阵又有了")
	# 日记任务链和奖励
	g.state.quests["lighthouse"] = "done"
	g.begin_talk_quest("lighthouse3")
	g.inventory.add(g.state, "diary_page", 3)
	var gold0 := g.state.wallet_gold
	check(g.turn_in("lighthouse3") and g.state.wallet_gold == gold0 + 300, "交日记残页得 300 铜币")
	g.begin_talk_quest("lighthouse4")
	g.inventory.add(g.state, "lamp_scale", 1)
	var slots0 := g.state.bag_slots
	check(g.turn_in("lighthouse4") and g.state.bag_slots == slots0 + 2, "交雾灯鳞得背包格子")

func test_v056(balance: Dictionary, fish: Array) -> void:
	print("v056: 工作台蟹笼、修桥、西岸木箱")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(141))
	var c: FakeClock = g._clock
	g.state.boat_level = 1
	g.steer_to(g.island_x()); g.land_on_island()
	check(not g.bridge_built() and g.island_walk_min() == g.lake_spot_x() and g.drift_count() == 3, "没修桥：最西到湖边，只有 3 处可拾")
	# 修桥：酒馆雇一位工人 -> 修理厂投 12 块木板开工 -> 到点完工
	g.state.quests["lighthouse"] = "done"; g.state.quests["lighthouse2"] = "done"; g.state.quests["lighthouse3"] = "done"; g.state.quests["lighthouse4"] = "done"
	check(g.open_west_chest().is_empty(), "没修桥前西岸木箱打不开")
	check(not g.works.can_start("bridge"), "没有工人、没有木板：开不了工")
	g.state.wallet_gold = 1000
	check(g.works.hire() and g.works.workers() == 1 and g.state.wallet_gold == 700, "雇了第一位工人，花 300 铜")
	check(not g.works.can_start("bridge"), "有工人但木板不够")
	g.inventory.add(g.state, "plank", 12)
	check(g.works.start("bridge", g.now_ms()) and g.works.status("bridge") == "building" and g.inventory.count(g.state, "plank") == 0, "开工：扣木板")
	check(not g.works.start("bridge", g.now_ms()), "已经在修了，不能再开")
	c.t += 10 * 60000
	g.tick()
	check(g.works.status("bridge") == "building", "一个工人要 20/1.5≈13.3 分钟，10 分钟还没完")
	c.t += 5 * 60000
	var evs := g.tick()
	check(g.bridge_built() and g.works.status("bridge") == "done" and int(g.state.story.get("done_bridge", 0)) == 1, "到点桥修好了，剧情标记也记上")
	check(g.island_walk_min() < g.lake_spot_x() - 300.0 and g.drift_count() == 6, "修桥后能走到西边，多出 3 处可拾")
	g.journey.set_roam_x(g.west_chest_x())
	var gold1 := g.state.wallet_gold
	var cr := g.open_west_chest()
	check(not cr.is_empty() and g.state.wallet_gold == gold1 + 600 and g.west_chest_open() and g.open_west_chest().is_empty(), "西岸木箱只能开一次")
	check(not g.at_lake_spot(), "走到西边就不再是钓位")

func test_v059(balance: Dictionary, fish: Array) -> void:
	print("v059: 迷你窗自动挂机规则、顶掉物品只腾够格子")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(151))
	for i in 30:
		var x := g.pick_water_x()
		check(x >= 122 and x <= 412, "随机近水域在能钓鱼的范围内")
		if x < 122 or x > 412:
			break
	# 回镇后：鱼篓不够 30% 就去钓鱼（随机水域），够了才去摊位
	g.journey.set_fish_spot(-1)
	g.economy.add_catch(g.state, "c1", "bass", false)
	check(g.economy.basket_percent(g.state) < 30, "一条鱼低于 30%")
	g.journey._enter(Journey.Activity.ROAM, 0, 0)
	g.end_roam(0.5, 0.5, true)
	check(g.journey.activity() == Journey.Activity.WALK_TO_BOAT and g.journey.fish_spot() >= 122, "鱼篓低于 30%：直接回船去随机水域钓鱼")
	var g2 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(152))
	for i in 5:
		g2.economy.add_catch(g2.state, "c%d" % i, "bass", false)
	check(g2.economy.basket_percent(g2.state) >= 30, "五条鱼不低于 30%")
	g2.journey._enter(Journey.Activity.ROAM, 0, 0)
	g2.end_roam(0.5, 0.5, true)
	check(g2.journey.activity() == Journey.Activity.WALK_TO_STALL, "鱼篓不低于 30%：继续去摊位卖鱼")
	# 顶掉物品：只拿走刚好够用的格子
	var g3 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(153))
	g3.state.bag_slots = 3
	g3.state.inventory = {"bell": 20, "pearl": 1}
	var used := g3.inventory.slots_used(g3.state)
	check(used == 3, "先把格子占满：铃铛 20 个占 2 格 + 珍珠 1 格")
	check(g3.give("plank") == "replaced" and g3.inventory.count(g3.state, "bell") == 10 and g3.inventory.count(g3.state, "plank") == 1, "木板顶掉一格铃铛（10 个），不是整堆 20 个")

func test_v061(balance: Dictionary, fish: Array) -> void:
	print("v061: 拱桥桥顶钓位、蟹笼、自动规则（雾灯岛 80%、10 秒）")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(161))
	g.state.effects["bridge"] = 1
	g.journey._enter(Journey.Activity.ISLAND, 0, 0)
	var bx := g.bridge_spot_x()
	var lx := g.lake_spot_x()
	check(bx < lx - 20.0, "桥顶钓位在湖东岸钓位西侧")
	g.journey.set_roam_x(int(bx))
	check(g.at_bridge_spot() and g.at_lake_spot(), "站在桥顶算在钓位上")
	check(g.nearest_spot_x(bx + 5.0) == bx and g.nearest_spot_x(lx - 3.0) == lx, "最近的钓位：桥顶或东岸")
	g.journey.set_roam_x(int(lx))
	check(g.at_lake_spot() and not g.at_bridge_spot(), "东岸钓位不是桥顶")
	g.state.effects["bridge"] = 0
	g.journey.set_roam_x(int(bx))
	check(not g.at_lake_spot(), "没建桥时桥顶不是钓位")
	# 10 秒内能不能走到钓位
	g.state.effects["bridge"] = 1
	g.journey.set_roam_x(int(g.island_land_x()))
	var far := absf(g.nearest_spot_x(g.island_land_x()) - g.island_land_x())
	check(g.island_spot_reachable(g.island_land_x()) == (far / 70.0 <= 10.0), "走到钓位的时间按 10 秒判断")
	g.journey.set_roam_x(int(lx))
	check(g.island_spot_reachable(lx), "已经在钓位：当然够得着")
	# 回镇后：鱼篓正好 30% 也去钓鱼，不再卖
	var g2 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(162))
	var n := 0
	while g2.economy.basket_percent(g2.state) < 30:
		g2.economy.add_catch(g2.state, "e%d" % n, "bass", false)
		n += 1
	var pct := g2.economy.basket_percent(g2.state)
	var want_fish := pct <= 30
	g2.journey._enter(Journey.Activity.ROAM, 0, 0)
	g2.end_roam(0.5, 0.5, true)
	check((g2.journey.activity() == Journey.Activity.WALK_TO_BOAT) == want_fish, "鱼篓 %d%%：不超过 30%% 去钓鱼，超过去卖" % pct)
	# 酒馆雇人、工程时间
	var g3 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(163))
	check(g3.works.duration_min("bridge") == 20.0, "没有工人：20 分钟")
	g3.state.wallet_gold = 5000
	g3.inventory.add(g3.state, "stone", 3)
	check(g3.works.hire() and g3.works.hire() == true and g3.works.workers() == 2, "第二位要 800 铜 + 3 石头")
	check(absf(g3.works.duration_min("bridge") - 10.0) < 0.01, "两位工人：10 分钟")
	check(g3.works.status("lamp") == "locked", "桥没修好，加固灯室还没解锁")
	var dlg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogs.json"))
	check(dlg is Dictionary and dlg.has("keeper_menu") and dlg.has("tavern_menu") and dlg.has("island_arrive"), "对话数据在")
	var ok_nodes := true
	for did in dlg:
		for nid in dlg[did]["nodes"]:
			var nd: Dictionary = dlg[did]["nodes"][nid]
			if str(nd.get("next", "")) != "" and not dlg[did]["nodes"].has(str(nd["next"])):
				ok_nodes = false
			for ch in nd.get("choices", []):
				if str(ch.get("next", "")) != "" and not dlg[did]["nodes"].has(str(ch["next"])):
					ok_nodes = false
	check(ok_nodes, "对话里每个 next 都指向真实的节点")

func test_v062(balance: Dictionary, fish: Array) -> void:
	print("v062: 漂流瓶/日记残页只在有任务需要时出现")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(171))
	g.state.quests = {}
	for q in g._quest_cfg_list():
		g.state.quests[str(q["id"])] = "done"
	check(not g.item_wanted("bottle") and not g.item_wanted("diary_page"), "没有任务需要：瓶子和日记残页都不要")
	check(g.item_wanted("pearl"), "普通物品不受影响")
	for i in 80:
		check(g._pick_pool([["bottle", 50], ["diary_page", 10]]) == "", "池子里只有任务物品时抽不出东西")
		if g._pick_pool([["bottle", 50], ["diary_page", 10]]) != "":
			break
	check(g.shop_chat("workshop").size() >= 2, "工坊师傅有话说")
	var g2 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(172))
	check(g2.item_wanted("bottle"), "还有信没收：瓶子会出现")
	g2.state.quests = {}
	for q in g2._quest_cfg_list():
		g2.state.quests[str(q["id"])] = "done"
	g2.state.quests["lighthouse3"] = "active"
	check(g2.item_wanted("diary_page"), "日记任务进行中：残页会出现")
	g2.inventory.add(g2.state, "diary_page", 3)
	check(not g2.item_wanted("diary_page"), "收够了就不再出现")
	g2.state.quests["lighthouse3"] = "done"
	check(not g2.item_wanted("diary_page"), "任务结束后不再出现")
	g2.state.inventory["bottle"] = 1
	var r: Dictionary = g2.use_item("bottle")
	check(int(r["gold"]) == 0, "没有新任务的空瓶不给钱")

func test_v064(balance: Dictionary, fish: Array) -> void:
	print("v064: 卖道具、一次性礼物")
	var g := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(181))
	g.inventory.add(g.state, "boot", 2)
	g.inventory.add(g.state, "pearl", 1)
	g.inventory.add(g.state, "rod_1", 1)
	check(g.sell_item("pearl") == 0 and g.inventory.count(g.state, "pearl") == 1, "关键物品不能卖")
	check(g.sell_item("rod_1") == 0, "装备不能卖")
	check(g.sell_item("bell") == 0, "没有的物品卖不了")
	var w0 := g.state.wallet_gold
	var got := g.sell_item("boot")
	check(got == g.sell_price("boot") and got > 0 and g.state.wallet_gold == w0 + got and g.inventory.count(g.state, "boot") == 1, "卖一个旧靴子：少一个、多了钱")
	var g2 := Game.new(balance.duplicate(true), fish, GameState.new(), FakeClock.new(), _rng(182))
	check(g2.apply_gift(), "礼物发了")
	check(g2.state.wallet_gold == 80000 and g2.inventory.count(g2.state, "lamp_scale") == 1, "800 金 + 雾灯鳞")
	check(not g2.apply_gift() and g2.state.wallet_gold == 80000, "礼物只发一次")
	var d: Dictionary = g2.state.to_dict()
	var s2 := GameState.new()
	s2.from_dict(d)
	var g3 := Game.new(balance.duplicate(true), fish, s2, FakeClock.new(), _rng(183))
	check(not g3.apply_gift(), "存档读回来也不会再发")

func test_v046(balance: Dictionary, fish: Array) -> void:
	print("v046: 杂物和鱼不同时出现、仓库直接用、上次钓鱼点、店主默认的话")
	# 杂物概率 1：每次咬钩都只有杂物，没有鱼
	var b2 := balance.duplicate(true)
	b2["junk"]["chance"] = 1.0
	var g := Game.new(b2, fish, GameState.new(), FakeClock.new(), _rng(81))
	var c: FakeClock = g._clock
	var fish_events := 0
	var junk_events := 0
	for e in _run(g, c, 400.0):
		if e["type"] == "catch":
			fish_events += 1
		elif e["type"] == "junk":
			junk_events += 1
	check(junk_events > 0 and fish_events == 0, "杂物概率 1：只有杂物没有鱼 (%d / %d)" % [junk_events, fish_events])
	check(g.fishing.hooked_fish == "" or g.fishing.hooked_fish.begins_with(Fishing.JUNK_PREFIX) or g.fishing.hooked_fish == Fishing.CHEST, "咬钩的东西从一开始就是杂物")
	# 仓库里直接使用：装备、一次性物品
	var g2 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(82))
	g2.state.warehouse["rod_2"] = 1
	g2.state.warehouse["bell"] = 2
	var res := g2.use_item_w("rod_2")
	check(res["ok"] and int(g2.state.gear["rod"]) == 2 and g2.inventory.count_w(g2.state, "rod_2") == 0, "仓库里的鱼竿直接装上")
	check(g2.inventory.count(g2.state, "rod_0") == 1 or g2.inventory.count_w(g2.state, "rod_0") == 1, "换下来的鱼竿放进物品栏（或仓库）")
	check(g2.use_item_w("bell")["ok"] and g2.inventory.count_w(g2.state, "bell") == 1 and int(g2.state.effects["bell_sales"]) > 0, "仓库里的招财铃直接用掉一个")
	check(not g2.use_item_w("pearl")["ok"], "仓库里没有的东西不能用")
	# 上次钓到鱼的地方
	var g3 := Game.new(balance, fish, GameState.new(), FakeClock.new(), _rng(83))
	var c3: FakeClock = g3._clock
	g3.steer_to(300.0)
	g3.state.journey["fish_x"] = 300
	g3.steer_to(g3.journey.cfg_dock_x())
	g3.go_to_town()
	_run(g3, c3, 40.0)
	g3.begin_roam(580.0)
	g3.roam_board(0.5)
	_run(g3, c3, 60.0)
	check(g3.journey.boat_x() == 300, "手动靠岸后回船，船开回上次钓到鱼的地方 (%d)" % g3.journey.boat_x())
	# 店主默认的话
	check(not g3.shop_chat("tackle").is_empty() and not g3.shop_chat("tailor").is_empty(), "店主有默认的话")

	# 小鱼咬钩更快：第一次等待结束就咬钩的鱼，按占的单位分组比平均等待
	var fs3 := Fishing.new(balance["fishing"], fish, _rng(91))
	fs3.zone = "shallow"
	var t3 := 0
	fs3.start(t3)
	var sums := {"small": 0.0, "big": 0.0}
	var ns := {"small": 0, "big": 0}
	var last_wait := 0
	var fdefs := {}
	for f in fish:
		fdefs[f["id"]] = f
	for i in 3000000:
		t3 += 100
		var bf := fs3.state
		fs3.advance(t3)
		fs3.baiting_started = false
		fs3.tangled_flag = false
		if bf == Fishing.State.CASTING and fs3.state == Fishing.State.WAITING:
			last_wait = fs3.deadline_ms - t3
		if bf == Fishing.State.TWITCH and fs3.state == Fishing.State.HOOKED and fs3.stage == 0 and fdefs.has(fs3.hooked_fish):
			var u: float = float(fdefs[fs3.hooked_fish]["units"])
			var key := "small" if u <= 0.4 else ("big" if u >= 1.4 else "")
			if key != "":
				sums[key] += last_wait
				ns[key] += 1
		if int(ns["small"]) >= 150 and int(ns["big"]) >= 150:
			break
	var ms: float = float(sums["small"]) / maxf(1.0, float(ns["small"]))
	var mb: float = float(sums["big"]) / maxf(1.0, float(ns["big"]))
	check(ns["small"] >= 100 and ns["big"] >= 100 and ms < mb * 0.8, "小鱼上钩更快：平均等待 小 %d ms / 大 %d ms" % [int(ms), int(mb)])


func test_v078(balance: Dictionary, fish: Array) -> void:
	print("v0.78: 连续耗体力、面朝就能挖、黑洞下楼、补给木箱、体力跨局、旅店和回家休息")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(78))
	var mn = g.mine
	mn.ensure(clock.t)
	mn.give_first_pick()
	check(mn.begin_run(1, clock.t) and mn.stamina_f() == float(mn.stamina_max()), "第一次下井体力是满的")
	# 找一块石头站在它旁边，不对齐也能挖
	var nb := _stand_next_to_rock(mn)
	check(nb != Vector2i.ZERO, "找到一块能挖的石头")
	var cellp: Vector2i = mn.pos()
	var tg: Vector2i = cellp + nb
	g.state.mine["run"]["fx"] = float(cellp.x) + 0.5 + (0.2 if nb.y != 0 else 0.0)
	g.state.mine["run"]["fy"] = float(cellp.y) + 0.5 + (0.2 if nb.x != 0 else 0.0)
	check(mn.target(nb.x, nb.y) == tg, "没对齐（偏了 0.2 格）也能够到面前那块石头")
	var f0: float = mn.fpos().x + mn.fpos().y
	mn.walk(0.0, 0.0)
	check(absf(mn.fpos().x + mn.fpos().y - f0) < 0.0001, "不会自动对齐到格子中间")
	# 体力按时间连续消耗：挖到一半，已经扣了一半
	g.state.mine["sta"] = 50.0
	var ms: int = mn.dig_ms(tg.x, tg.y)
	var cost: float = float(mn.dig_cost(tg.x, tg.y))
	check(mn.start_dig(nb.x, nb.y, clock.t) == "", "开始挖")
	clock.t += ms / 2
	mn.update(clock.t)
	var used: float = 50.0 - mn.stamina_f()
	check(absf(used - cost * 0.5) < 0.05 and not mn.is_dug(tg.x, tg.y), "挖到一半：体力已经扣了一半（%.2f），石头还在" % used)
	mn.stop_dig(clock.t)
	var keep: float = mn.stamina_f()
	clock.t += 5000
	mn.update(clock.t)
	check(mn.stamina_f() == keep, "松手后不再扣")
	# 体力耗尽：挖到一半就停下，发出 tired
	g.state.mine["sta"] = 0.1
	mn.start_dig(nb.x, nb.y, clock.t)
	clock.t += ms
	var tev: Array = mn.update(clock.t)
	var tired := false
	for te in tev:
		if te["type"] == "tired":
			tired = true
	check(tired and mn.stamina_f() == 0.0 and not mn.digging() and not mn.is_dug(tg.x, tg.y), "体力用完：挖到一半停手，石头没碎")
	check(mn.dig_block_reason(nb.x, nb.y) == "tired", "没体力挖不动")
	# 矿里不会自己恢复
	clock.t += 600000
	mn.update(clock.t)
	check(mn.stamina_f() == 0.0, "在矿里体力不会自己恢复")
	mn.end_run()
	# 体力跨局
	check(mn.begin_run(1, clock.t) and mn.stamina_f() == 0.0, "体力跨局保存：下一局还是 0")
	mn.end_run()
	# 钓鱼和买东西：非常缓慢地恢复，不会超过上限
	var mx: float = float(mn.stamina_max())
	g.state.mine["sta"] = 10.0
	g.state.wallet_gold = 100000
	g.buy_bait("bait_worm")
	var after_buy: float = mn.stamina_f()
	check(after_buy > 10.0 and after_buy < 11.5, "买东西只恢复一点点（+%.2f）" % (after_buy - 10.0))
	mn.recover(1000.0)
	check(mn.stamina_f() == mx, "缓慢恢复不会超过上限")
	# 补给木箱
	mn.begin_run(1, clock.t)
	var crate := Vector2i(-1, -1)
	var crate_floors := 0
	var crate_floor := 1
	for ff in range(1, 41):                  # 木箱不是每层都有：40 层里大约三分之一的层有一个
		mn.m()["run"]["floor"] = ff
		var found := Vector2i(-1, -1)
		for yy in mn.height():
			for xx in mn.width():
				if found.x < 0 and mn.block(xx, yy) == "chest":
					found = Vector2i(xx, yy)
		if found.x >= 0:
			crate_floors += 1
			if crate.x < 0:
				crate = found
				crate_floor = ff
	check(crate.x >= 0 and crate_floors >= 6 and crate_floors <= 24, "木箱不常见：40 层里 %d 层有木箱" % crate_floors)
	mn.m()["run"]["floor"] = crate_floor
	var cdir := Vector2i.ZERO
	for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: Vector2i = crate + dv
		if cdir == Vector2i.ZERO and mn.is_floor(nc.x, nc.y) and mn.block(nc.x, nc.y) == "":
			g.state.mine["run"]["x"] = nc.x
			g.state.mine["run"]["y"] = nc.y
			g.state.mine["run"].erase("fx")
			g.state.mine["run"].erase("fy")
			cdir = -dv
	check(cdir != Vector2i.ZERO and mn.dig_block_reason(cdir.x, cdir.y) == "chest", "站在木箱旁边：面前是木箱，不是石头")
	check(mn.start_dig(cdir.x, cdir.y, clock.t) != "", "木箱不能挖")
	var inv_before: int = g.inventory.count(g.state, "ration") + g.inventory.count(g.state, "jerky") + g.inventory.count(g.state, "tonic")
	var gold_before: int = g.state.wallet_gold
	var oc: Dictionary = mn.open_chest(cdir.x, cdir.y)
	var inv_after: int = g.inventory.count(g.state, "ration") + g.inventory.count(g.state, "jerky") + g.inventory.count(g.state, "tonic")
	check(bool(oc["ok"]) and (inv_after > inv_before or g.state.wallet_gold > gold_before) and mn.block(crate.x, crate.y) == "", "打开木箱：补给进物品栏（或一点钱），木箱消失")
	check(not bool(mn.open_chest(cdir.x, cdir.y)["ok"]), "同一个木箱不能开两次")
	# 吃东西
	g.state.mine["sta"] = 10.0
	g.state.inventory["ration"] = 2
	var r1: Dictionary = g.use_item("ration")
	check(bool(r1["ok"]) and absf(mn.stamina_f() - 30.0) < 0.001 and g.inventory.count(g.state, "ration") == 1, "吃干粮：体力 +20，少一份")
	g.state.mine["sta"] = mx
	check(not bool(g.use_item("ration")["ok"]) and g.inventory.count(g.state, "ration") == 1, "体力是满的不浪费")
	mn.end_run()
	# 休息：家里只补到上限，旅店更快，高档房超过上限
	g.state.mine["sta"] = 5.0
	g.state.wallet_gold = 5000
	check(mn.rest_start("home", clock.t) == "" and mn.resting() and mn.rest_start("suite", clock.t) == "busy", "在家睡觉开始")
	clock.t += 1500
	mn.rest_update(clock.t)
	check(mn.stamina_f() > 5.0 and mn.stamina_f() < mx and mn.resting(), "睡到一半：体力在涨")
	clock.t += 1500
	check(mn.rest_update(clock.t) and absf(mn.stamina_f() - mx) < 0.001 and not mn.resting(), "家里 3 秒补满，不超过上限（%.0f）" % mx)
	check(mn.rest_start("home", clock.t) == "full", "满了不用睡")
	var gold0: int = g.state.wallet_gold
	check(mn.rest_start("suite", clock.t) == "" and g.state.wallet_gold == gold0 - 1500, "总统套房收 1500 铜")
	clock.t += 3000
	mn.rest_update(clock.t)
	check(absf(mn.stamina_f() - mx * 1.3) < 0.01, "总统套房：体力到 130%%（%.0f）" % mn.stamina_f())
	g.state.wallet_gold = 10
	g.state.mine["sta"] = 1.0
	check(mn.rest_start("room", clock.t) == "gold", "钱不够住不了")
	# 存档里带着休息中的状态
	g.state.wallet_gold = 5000
	mn.rest_start("dorm", clock.t)
	var s4 := GameState.new()
	check(s4.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict()))), "休息中也能存档")
	var g4 := Game.new(balance, fish, s4, clock, _rng(79))
	clock.t += 3000
	g4.mine.rest_update(clock.t)
	check(not g4.mine.resting() and g4.mine.stamina_f() >= float(g4.mine.stamina_max()) - 0.01, "读档后休息照常结束")
	# v0.78b：石头碰撞盒变小、典当行、垃圾箱
	mn.begin_run(1, clock.t + 50)
	var nb2 := _stand_next_to_rock(mn)
	var cell2: Vector2i = mn.pos()
	var rockc: Vector2i = cell2 + nb2
	for _i in 60:
		mn.walk(float(nb2.x) * 0.05, float(nb2.y) * 0.05)
	var dist: float = (mn.fpos() - (Vector2(rockc) + Vector2(0.5, 0.5))).length()
	check(dist > 0.25 and dist < 0.5, "能一直走到贴着石头才被挡住（距离 %.2f 格，以前要隔 0.8）" % dist)
	check(mn.target(nb2.x, nb2.y) == rockc, "走到最近处，面前还是那块石头")
	mn.end_run()
	g.state.inventory.clear()
	g.state.bag_slots = 8
	g.state.wallet_gold = 0
	g.state.inventory["stone"] = 4
	g.state.inventory["boot"] = 2
	check(g.ore_sell("boot") == 0 and g.ore_sell("stone") == g.pawn_value("stone") and g.ore_sell("stone", true) == 3 * g.pawn_value("stone") and g.inventory.count(g.state, "stone") == 0 and g.pawn_count("stone") == 0, "老钻只收矿石（石头、金属、金矿石），不记赎回")
	g.state.wallet_gold = 0
	g.state.inventory["boot"] = 2
	g.state.inventory["rope"] = 1
	var pv: int = g.pawn_value("boot")
	check(pv >= 1 and g.pawn_sell("boot") == pv and g.state.wallet_gold == pv and g.pawn_count("boot") == 1 and g.inventory.count(g.state, "boot") == 1, "典当：旧靴子换钱，记在典当行里")
	check(g.pawn_sell("rope") > 0 and g.pawn_count("rope") == 1, "任务物品也能当")
	g.state.wallet_gold = 0
	check(g.pawn_redeem("boot") == "gold", "赎回要钱，钱不够不行")
	g.state.wallet_gold = pv * 2
	check(g.pawn_redeem("boot") == "" and g.state.wallet_gold == 0 and g.inventory.count(g.state, "boot") == 2 and g.pawn_count("boot") == 0, "赎回价是当时的两倍")
	check(g.pawn_redeem("boot") == "none", "没当过的赎不了")
	var s5 := GameState.new()
	check(s5.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict()))) and int(s5.story.get("pawn_rope", 0)) == 1, "典当记录随存档保存")
	check(g.trash_item("rope") == 0 and g.trash_item("boot", true) == 2 and g.inventory.count(g.state, "boot") == 0, "垃圾箱：整堆扔掉")
	g.state.inventory["rope"] = 1
	check(g.trash_item("rope") == 1 and g.inventory.count(g.state, "rope") == 0, "垃圾箱：任务物品也能扔")

func test_v068_sell(balance: Dictionary, fish: Array) -> void:
	print("v0.68: 工坊出售、任务物品、加速对矿井生效")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(68))
	check(g.sell_price("lamp_shell") == 0 and g.sell_price("stone") == 0 and g.sell_price("metal") == 0 and g.sell_price("pearl") == 0, "任务物品、关键物品不能卖")
	check(g.sell_price("rod_0") == 0, "装备不能卖")
	check(g.sell_price("boot") > 0 and g.sell_price("rope") > 0 and g.sell_price("ladder") > 0, "杂物、绳子、梯子能卖")
	g.inventory.add(g.state, "boot", 5)
	var w0 := g.state.wallet_gold
	var got := g.sell_stack("boot")
	check(got == 5 * g.sell_price("boot") and g.inventory.count(g.state, "boot") == 0 and g.state.wallet_gold == w0 + got, "整堆卖：5 只靴子一次卖完")
	check(g.sell_stack("boot") == 0 and g.sell_stack("lamp_shell") == 0, "没有的、不能卖的整堆卖不动")
	# 任务物品不会超额获取：没有任务要雾灯贝就不会发
	check(not g.item_wanted("lamp_shell") and not g.item_wanted("lamp_scale"), "没有任务时不再给雾灯贝、雾灯鳞")
	# 加速：挖掘截止时刻跟着前移
	var mn = g.mine
	mn.ensure(clock.t)
	check(mn.begin_run(1, clock.t), "下井")
	mn.give_first_pick()
	var dd := _stand_next_to_rock(mn)
	mn.start_dig(dd.x, dd.y, clock.t)
	var t1_before := int(mn.run()["dig"]["t1"])
	g._advance_deadlines(-1000)
	check(int(mn.run()["dig"]["t1"]) == t1_before - 1000, "加速会把挖掘进度也往前推")
	# 没结束的一局下次坐矿车直接接着挖
	check(mn.in_run() and not mn.begin_run(1, clock.t), "已经有一局时不能再开一局（界面会接着这一局）")

## 把小猫放到某个空地上、紧挨着一块石头；返回朝石头的方向（dx, dy）。
func _stand_next_to_rock(mn) -> Vector2i:
	for y in range(1, mn.height() - 1):
		for x in range(1, mn.width() - 1):
			if mn.is_floor(x, y) and mn.block(x, y) == "":
				for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if mn.block(x + dv.x, y + dv.y) not in ["", "granite", "chest", "pit", "ladder"]:
						mn.m()["run"]["x"] = x
						mn.m()["run"]["y"] = y
						return dv
	return Vector2i.ZERO

## 把当前层的补给木箱都去掉（测试走路线时不让木箱挡路）。
func _clear_crates(mn) -> void:
	var lay: Dictionary = mn._layout(mn.floor_n())
	var ck: PackedByteArray = lay["chest"]
	ck.fill(0)
	lay["chest"] = ck

## 入口到出口沿着地面走的一条路（不管石头）。
func _floor_path(mn) -> Array:
	var en: Vector2i = mn.entrance(mn.floor_n()) + Vector2i(0, 1)
	var ex: Vector2i = mn.exit_pos(mn.floor_n())
	var prev := {en: en}
	var q: Array = [en]
	while not q.is_empty() and not prev.has(ex):
		var c: Vector2i = q.pop_front()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if not prev.has(n) and mn.is_floor(n.x, n.y):
				prev[n] = c
				q.append(n)
	var path: Array = []
	if not prev.has(ex):
		return path
	var cur: Vector2i = ex
	while cur != en:
		path.push_front(cur)
		cur = prev[cur]
	path.push_front(en)
	return path

func test_v067(balance: Dictionary, fish: Array) -> void:
	print("v0.75: 矿井（洞穴地图、自由挖、炸弹连锁、背包回地面卖、电梯存档点、体力、天赋、做菜、5 口井）")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(67))
	var mn = g.mine
	mn.ensure(clock.t)
	check(mn.shaft_ok(1) and not mn.shaft_ok(2) and not mn.begin_run(2, clock.t), "1 号井通畅，2 号井铁路坏了进不去")
	check(mn.shaft_status(2) == "broken" and mn.shaft_status(3) == "wait" and mn.shaft_count() == 5, "一共 5 口井：2 号坏了，3 号还在等 2 号通")
	check(not g.state.to_dict().has("gems"), "宝石货币已取消")
	check(mn.start_floors() == [1] and not mn.begin_run(1, clock.t, 5), "还没到过整 5 层，只能从第 1 层开始")
	check(mn.begin_run(1, clock.t) and mn.in_run() and mn.floor_n() == 1 and mn.pos() == mn.entrance(1) + Vector2i(0, 1), "坐矿车下井：第 1 层，站在入口梯子下面一格")
	_clear_crates(mn)
	check(mn.width() >= 25 and mn.height() >= 16, "地图比以前大：%d×%d" % [mn.width(), mn.height()])
	check(mn.block(-1, 3) == "granite" and mn.block(mn.width(), 3) == "granite" and mn.block(3, mn.height()) == "granite", "地图外面是岩壁")
	var floor_cells := 0
	var rock_cells := 0
	var wall_cells := 0
	for yy in mn.height():
		for xx in mn.width():
			if mn.is_floor(xx, yy):
				floor_cells += 1
				if mn.has_rock(xx, yy):
					rock_cells += 1
			else:
				wall_cells += 1
	check(floor_cells > 100 and floor_cells < mn.width() * mn.height() * 0.7 and wall_cells > 100, "有地面也有岩壁，不是全铺满（地面 %d 岩壁 %d）" % [floor_cells, wall_cells])
	check(rock_cells > 10 and rock_cells < floor_cells * 0.5, "地面上散落着石块（%d 块）" % rock_cells)
	var path: Array = _floor_path(mn)
	check(not path.is_empty() and path.size() >= 12, "入口到出口沿地面连得通（%d 步）" % path.size())
	var open_walls := 0
	for c in path:
		if mn.block(c.x, c.y) == "granite":
			open_walls += 1
	check(open_walls == 0 and mn.exit_pos(1) == path[path.size() - 1], "路上没有岩壁，终点是出口")
	var ex: Vector2i = mn.exit_pos(1)
	check(mn.has_rock(ex.x, ex.y) and mn.ore(ex.x, ex.y) == "" and mn.block(ex.x, ex.y) in ["dirt", "stone", "rock", "deep"], "下一层的洞埋在一块普通石头下面，不直接露出来")
	check(mn.exit_pos(1) == ex, "同一层的地图每次都一样")
	# 走到第一块挡路的石头前面
	var k := 0
	while k < path.size() and mn.block(path[k].x, path[k].y) == "":
		k += 1
	check(k > 0 and k < path.size(), "路上有石头挡着")
	for j in range(1, k):
		mn.move(path[j].x - path[j - 1].x, path[j].y - path[j - 1].y, clock.t)
	var face: Vector2i = path[k] - path[k - 1]
	check(mn.pos() == path[k - 1] and mn.dig_block_reason(face.x, face.y) == "notool", "没有镐子挖不动")
	check(mn.give_first_pick() and mn.pick() == 1 and not mn.give_first_pick(), "管理员送第一把镐子，只送一次")
	check(mn.buy_level("pick") == "gold", "铁镐要金币")
	check(not mn.cfg().has("perks") and not mn.has_method("draft") and not mn.has_method("choose_perk"), "肉鸽天赋已清理干净")
	var base_ms: int = mn.dig_ms(path[k].x, path[k].y)
	check(base_ms >= 300 and base_ms <= 2500, "主动挖：这一块约 %d 毫秒" % base_ms)
	# 体力
	var sta0: int = mn.stamina()
	check(sta0 == mn.stamina_max() and sta0 >= 60, "开局体力满：%d" % sta0)
	check(mn.start_dig(face.x, face.y, clock.t) == "", "朝石头挖")
	var need: int = mn.dig_ms(path[k].x, path[k].y)
	clock.t += need - 1
	check(mn.update(clock.t).is_empty() and mn.dig_progress(clock.t) > 0.99, "没到时间不会挖开")
	clock.t += 1
	var ev: Array = mn.update(clock.t)
	check(mn.pos() == path[k - 1] and mn.is_dug(path[k].x, path[k].y) and ev.size() >= 1, "挖开后小猫留在原地，那块石头没了")
	check(mn.move(face.x, face.y, clock.t) and mn.pos() == path[k], "挖开后能走过去")
	check(mn.stamina() == sta0 - 1, "泥土层挖一格体力 -1")
	var sta_keep: int = mn.stamina()
	var nb := _stand_next_to_rock(mn)
	g.state.mine["sta"] = 0.0
	check(mn.dig_block_reason(nb.x, nb.y) == "tired", "体力用完了挖不动")
	g.state.mine["sta"] = float(sta_keep)
	check(mn.start_dig(nb.x, nb.y, clock.t) == "" and mn.dig_block_reason(-nb.x, -nb.y) in ["open", "granite"], "往哪个方向都能挖（没有竖井限制）")
	var tgt: Vector2i = mn.pos() + nb
	clock.t += mn.dig_ms(tgt.x, tgt.y) / 2
	mn.stop_dig(clock.t)
	var part: float = mn.progress_at(tgt.x, tgt.y, clock.t)
	check(part > 0.4 and part < 0.6 and not mn.digging(), "松手停下，进度留在块上（%.2f）" % part)
	clock.t += 60000
	check(mn.update(clock.t).is_empty() and mn.progress_at(tgt.x, tgt.y, clock.t) == part, "不挖的时候不会自己挖（没有挂机）")
	mn.stop_dig(clock.t)
	# 一路走（遇到石头就挖）到出口
	g.state.mine["sta"] = 200.0
	g.state.mine["run"]["x"] = path[0].x
	g.state.mine["run"]["y"] = path[0].y
	var guard := 0
	for j in range(1, path.size() - 1):
		var step: Vector2i = path[j] - path[j - 1]
		if mn.block(path[j].x, path[j].y) != "":
			mn.start_dig(step.x, step.y, clock.t)
			clock.t += mn.dig_ms(path[j].x, path[j].y) + 1
			mn.update(clock.t)
			mn.move(step.x, step.y, clock.t)
		else:
			mn.move(step.x, step.y, clock.t)
		guard += 1
	var last: Vector2i = path[path.size() - 1] - path[path.size() - 2]
	check(mn.pos() == path[path.size() - 2] and not mn.exit_ahead(last.x, last.y) and not mn.descend(last.x, last.y) and mn.block(ex.x, ex.y) != "pit", "走到盖着洞的石头前（还下不去）（走了 %d 步）" % guard)
	check(mn.start_dig(last.x, last.y, clock.t) == "", "凿那块石头")
	clock.t += mn.dig_ms(ex.x, ex.y) + 1
	mn.update(clock.t)
	check(mn.block(ex.x, ex.y) == "pit" and mn.pos() == path[path.size() - 2], "凿碎后露出下一层的黑洞")
	check(not mn.move(last.x, last.y, clock.t) and mn.pos() == path[path.size() - 2], "洞口走不上去（像矿石一样要面对着互动）")
	check(not mn.descend(-last.x, -last.y), "背对着洞下不去")
	check(mn.descend(last.x, last.y) and mn.floor_n() == 2 and mn.pos() == mn.entrance(2) + Vector2i(0, 1) and mn.on_entrance(), "下到第 2 层，站在新入口梯子下面")
	check(mn.ascend() == "hall" and mn.floor_n() == 2 and mn.on_entrance(), "每层入口的梯子都是回地面（不是上一层）")
	# 顺滑走动：小步走、撞墙停、不会钻进石头和岩壁
	var p0: Vector2 = mn.fpos()
	var moved := false
	for dv in [Vector2(0.1, 0), Vector2(-0.1, 0), Vector2(0, 0.1), Vector2(0, -0.1)]:
		if not moved and mn.walk(dv.x, dv.y):
			moved = true
	check(moved and mn.fpos() != p0 and (mn.fpos() - p0).length() <= 0.11, "顺滑走：一次只挪一小段")
	var stuck := 0
	for _i in 200:
		mn.walk(0.1, 0)
	var fpw: Vector2 = mn.fpos()
	check(mn.block(int(floor(fpw.x + 0.41)), int(floor(fpw.y))) != "" and mn.block(mn.pos().x, mn.pos().y) == "", "一直往右走会被挡住，不会穿墙（停在 %.2f）" % fpw.x)
	# 同一格不会重复发奖励
	var bag_before: int = mn.bag_n()
	g.state.mine["run"]["floor"] = 1
	check(mn._break_cell(path[k].x, path[k].y).is_empty() and mn.bag_n() == bag_before, "已经挖开的格子再挖不发东西")
	# 背包：装满之后挖到的就带不走；回地面才换钱
	var gf := 0
	var gx := -1
	var gy := -1
	for ff in range(2, 40):
		g.state.mine["run"]["floor"] = ff
		for yy in range(1, mn.height()):
			for xx in range(1, mn.width() - 1):
				if gx < 0 and mn.ore(xx, yy) == "gold_ore" and mn.block(xx, yy) != "":
					gx = xx
					gy = yy
					gf = ff
		if gx >= 0:
			break
	check(gx > 0, "能找到金矿（第 %d 层）" % gf)
	g.state.mine["run"]["floor"] = gf
	g.state.inventory.clear()
	g.state.bag_slots = 8
	var w0: int = g.state.wallet_gold
	var e: Dictionary = mn._break_cell(gx, gy)
	check(int(e["gold"]) == 0 and g.state.wallet_gold == w0 and str(e["item"]) == "gold_ore" and g.inventory.count(g.state, "gold_ore") == 1, "金矿石直接进物品栏，不再产出钱")
	g.state.inventory["gold_ore"] = g.inventory.stack_cap("gold_ore")
	g.state.bag_slots = g.inventory.slots_used(g.state)
	check(mn.bag_cap() == g.state.bag_slots and mn.bag_n() == g.inventory.slots_used(g.state), "背包容量就是物品栏的格子数")
	var lost_e := {}
	for yy in range(1, mn.height()):
		for xx in range(1, mn.width() - 1):
			if lost_e.is_empty() and mn.ore(xx, yy) == "stone" and mn.block(xx, yy) != "":
				lost_e = mn._break_cell(xx, yy)
	check(bool(lost_e.get("lost", false)) and mn.bag_full(), "物品栏满了：挖到的带不走")
	g.state.bag_slots = 8
	var res: Dictionary = mn.end_run()
	check(not mn.in_run() and int(res["coins"]) == 0, "回地面：这一局结束，东西本来就在物品栏里")
	# 电梯存档点：到过第 5 层之后能直接从那里开始
	mn.begin_run(1, clock.t + 1)
	g.state.mine["run"]["floor"] = 4
	var exit4: Vector2i = mn.exit_pos(4)
	g.state.mine["run"]["x"] = exit4.x
	g.state.mine["run"]["y"] = exit4.y
	g.state.mine["run"]["dug"][mn._key(exit4.x, exit4.y)] = 1
	check(mn.descend() and mn.floor_n() == 5 and mn.has_elevator() and mn.ascend() == "hall", "到第 5 层：入口有电梯，直接回大厅")
	mn.end_run()
	check(mn.start_floors() == [1, 5] and mn.begin_run(1, clock.t + 2, 5) and mn.floor_n() == 5 and mn.pos() == mn.entrance(5) + Vector2i(0, 1), "矿车可以直接从第 5 层开始")
	# 工具等级：第 5 层起是石层，要铁镐
	var nb5 := _stand_next_to_rock(mn)
	check(mn.dig_block_reason(nb5.x, nb5.y) == "tool" and mn.need_tool(0, 0) == 2, "第 5 层是石层，鹤嘴锄挖不动")
	g.state.wallet_gold = 10000
	check(mn.buy_level("pick") == "mat", "铁镐要金属，光有钱不行")
	g.inventory.add(g.state, "metal", 3)
	check(mn.buy_level("pick") == "" and mn.pick() == 2, "金币 + 金属买铁镐")
	check(mn.dig_block_reason(nb5.x, nb5.y) == "", "铁镐能挖石层了")
	# 炸弹：找一处地面周围石头多的地方
	var bx := -1
	var by := -1
	for yy in range(2, mn.height() - 2):
		for xx in range(2, mn.width() - 2):
			if bx < 0 and mn.is_floor(xx, yy) and mn.block(xx, yy) == "":
				var cnt := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if mn.has_rock(xx + ox, yy + oy):
							cnt += 1
				if cnt >= 3:
					bx = xx
					by = yy
	check(bx > 0, "找到一处周围有石头的空地")
	check(mn.place_bomb(clock.t) == "empty", "没有炸弹放不了")
	var gold_before_bomb: int = g.state.wallet_gold
	check(mn.buy_bomb() == "" and mn.bombs() == 1 and g.state.wallet_gold == gold_before_bomb - mn.bomb_price(), "买一颗炸弹")
	g.state.mine["run"]["x"] = bx
	g.state.mine["run"]["y"] = by
	var rocks_near := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if mn.block(bx + ox, by + oy) not in ["", "granite"]:
				rocks_near += 1
	var sta_bomb: int = mn.stamina()
	check(mn.place_bomb(clock.t) == "" and mn.bombs() == 0 and mn.live_bombs().size() == 1 and mn.place_bomb(clock.t) == "empty", "放下炸弹")
	check(mn.update(clock.t + 500).is_empty() and mn.live_bombs().size() == 1, "引线没烧完不会炸")
	var bev: Array = mn.update(clock.t + 1200)
	var booms := 0
	for be in bev:
		if be["type"] == "boom":
			booms += 1
	var rocks_after := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if mn.block(bx + ox, by + oy) not in ["", "granite"]:
				rocks_after += 1
	check(booms >= 1 and rocks_near >= 3 and rocks_after == 0 and mn.live_bombs().is_empty(), "炸弹把周围一圈的石头都炸开了（%d 块）" % rocks_near)
	check(mn.stamina() == sta_bomb, "炸弹不耗体力")
	# 矿脉连锁（炸药桶已取消）
	check(mn.ore_def("tnt").is_empty() and mn.ore_def("chest").is_empty(), "矿里不再有炸药桶和宝箱矿")
	# 连锁已取消：挖一块金属矿，旁边连着的金属矿不会跟着碎
	var pair := Vector2i(-1, -1)
	for ff in range(1, 200):
		g.state.mine["run"]["floor"] = ff
		for yy in range(1, mn.height() - 1):
			for xx in range(1, mn.width() - 2):
				if pair.x < 0 and mn.ore(xx, yy) == "metal" and mn.ore(xx + 1, yy) == "metal" and mn.block(xx, yy) != "" and mn.block(xx + 1, yy) != "":
					pair = Vector2i(xx, yy)
		if pair.x > 0:
			break
	var vev: Array = []
	mn._break_chain(pair.x, pair.y, 1, 0, vev, 0)
	check(pair.x > 0 and vev.size() == 1 and not mn.is_dug(pair.x + 1, pair.y), "没有连锁：只碎被挖的那一块")
	mn.end_run()
	# 菜
	mn.begin_run(1, clock.t + 3)
	mn.end_run()
	g.state.wallet_gold = 1000
	g.state.basket = ["crucian", "loach", "bream"]
	g.state.basket_sizes = [10, 10, 10]
	var t_cook: int = clock.t + 10
	g.state.mine["sta"] = 20.0
	check(mn.cook("skewer", g.economy, t_cook) == "" and g.state.basket.size() == 2 and g.state.wallet_gold == 980 and str(g.state.mine["dish"]) == "skewer", "烤鱼串：1 条鱼 + 20 铜")
	check(absf(mn.stamina_f() - 30.0) < 0.01, "吃下去体力马上 +10")
	check(mn.cook("soup", g.economy, t_cook + 1000) == "have", "已经有一道菜不能再做")
	check(absf(mn.speed_mul() - 1.2) < 0.001, "吃下去马上生效：挖速 +20%（不用等下井）")
	mn.begin_run(1, t_cook + 9000)
	check(absf(mn.speed_mul() - 1.2) < 0.001 and mn.dish_left_ms() > 0, "下井以后还在算时间")
	mn.update(t_cook + 10 * 60000 - 1)
	check(absf(mn.speed_mul() - 1.2) < 0.001, "10 分钟还没到，增益还在")
	mn.update(t_cook + 10 * 60000)
	check(absf(mn.speed_mul() - 1.0) < 0.001 and mn.dish_def().is_empty(), "10 分钟到了，增益没了")
	check(mn.light_radius() == float(mn.lamp_def().get("radius", 1.6)), "菜不再加光圈")
	mn.end_run()
	g.state.wallet_gold = 0
	check(mn.cook("bento", g.economy, t_cook + 11 * 60000) == "gold", "钱不够做不了")
	# 2 号井：材料 + 酒馆里雇的工人
	g.state.effects["workers"] = 0
	g.state.inventory["metal"] = 40
	g.state.inventory["stone"] = 50
	check(mn.repair_missing().size() == 1 and mn.repair_shaft() == "crew" and not mn.shaft_ok(2), "没雇够工人修不了 2 号井")
	g.state.effects["workers"] = 2
	var metal0: int = g.inventory.count(g.state, "metal")
	check(mn.repair_shaft() == "" and mn.shaft_ok(2) and g.inventory.count(g.state, "metal") == metal0 - 30, "雇了工人、材料够：2 号井修好，扣材料")
	check(mn.repair_shaft() == "done" and mn.begin_run(2, clock.t + 30) and mn.shaft_id() == 2, "修好后能下 2 号井")
	mn.end_run()
	# 存档
	g.state.wallet_gold = 777
	var s2 := GameState.new()
	check(s2.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict()))) and int(s2.mine["shafts"]["1"]["cp"]) == 5 and s2.wallet_gold == 777, "矿井进度随存档保存")
	var g2 := Game.new(balance, fish, s2, clock, _rng(68))
	check(g2.mine.shaft_ok(1) and g2.mine.shaft_ok(2) and g2.mine.start_floors() == [1, 5] and not g2.mine.in_run(), "读档后矿井的永久进度还在")
	# 中途存档：这一局接着玩（JSON 把数字读成小数，也要对得上）
	g.mine.begin_run(1, clock.t + 21)
	g.mine.give_first_pick()
	var ex2: Vector2i = g.mine.entrance(1)
	g.state.mine["run"]["dug"][g.mine._key(ex2.x, 2)] = 1
	g.state.mine["run"]["y"] = 2
	var s3 := GameState.new()
	check(s3.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict()))), "存档里带着一局")
	var g3 := Game.new(balance, fish, s3, clock, _rng(69))
	g3.mine.ensure(clock.t)
	check(g3.mine.in_run() and g3.mine.floor_n() == g.mine.floor_n() and g3.mine.pos() == g.mine.pos() and g3.mine.exit_pos(1) == g.mine.exit_pos(1), "读档后这一局的位置和地图都在")


func test_v082(balance: Dictionary, fish: Array) -> void:
	print("v0.82: 梯子实心、石头缝隙、无孤立岩壁、5 口井的矿石")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(82))
	var mn = g.mine
	mn.ensure(clock.t)
	mn.begin_run(1, clock.t)
	mn.give_first_pick()
	_clear_crates(mn)
	var en: Vector2i = mn.entrance(1)
	check(mn.block(en.x, en.y) == "ladder" and mn.dig_block_reason(0, -1) == "ladder", "入口的梯子是实心的，不能挖")
	check(mn.pos() == en + Vector2i(0, 1) and mn.ladder_ahead(0, -1) and not mn.ladder_ahead(0, 1), "站在梯子下面，面朝上才够得到梯子")
	for _i in 30:
		mn.walk(0.0, -0.1)
	check(mn.fpos().y > float(en.y) + 1.0, "走不进梯子那一格（脚停在 %.2f）" % mn.fpos().y)
	check(mn.ascend(0, 1) == "" and mn.ascend(0, -1) == "hall", "面朝梯子按空格才能上去")
	# 相邻石头的缝比角色窄
	check(mn.HB.x * 2.0 > 1.0 - 2.0 * mn.ROCK_HALF, "两块贴着的石头之间的缝（%.2f）比角色（%.2f）窄" % [1.0 - 2.0 * mn.ROCK_HALF, mn.HB.x * 2.0])
	# 地形：任何一层都没有被地面围住的孤立岩壁，也没有一格宽的缺口
	var isolated := 0
	var notch := 0
	for f in [1, 2, 3, 7, 12, 25, 40, 66, 99, 100]:
		mn.m()["run"]["floor"] = f
		var W: int = mn.width()
		var H: int = mn.height()
		var seen := {}
		var q: Array = []
		for y in H:
			for x in W:
				if (x == 0 or y == 0 or x == W - 1 or y == H - 1) and not mn.is_floor(x, y):
					seen[Vector2i(x, y)] = 1
					q.append(Vector2i(x, y))
				if x > 0 and y > 0 and x < W - 1 and y < H - 1 and not mn.is_floor(x, y) and ((mn.is_floor(x - 1, y) and mn.is_floor(x + 1, y)) or (mn.is_floor(x, y - 1) and mn.is_floor(x, y + 1))):
					notch += 1
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dv
				if mn.in_map(n.x, n.y) and not seen.has(n) and not mn.is_floor(n.x, n.y):
					seen[n] = 1
					q.append(n)
		for y in H:
			for x in W:
				if not mn.is_floor(x, y) and not seen.has(Vector2i(x, y)):
					isolated += 1
	check(isolated == 0 and notch == 0, "10 层抽查：没有孤立岩壁（%d），没有一格宽的缺口（%d）" % [isolated, notch])
	mn.m()["run"]["floor"] = 1
	# 5 口井的矿石规则
	check(mn.max_floor() == 100 and _count_mines(mn) == 5, "5 口井，每口最深 100 层")
	var ok_start := true
	var ok_rm := true
	var ok_new := true
	var ok_rare := true
	var ok_share := true
	var seen_before := {}
	var prev50 := {}
	for sid in range(1, 6):
		var md: Dictionary = mn.mine_def(sid)
		var p1: Array = mn.ore_pool(sid, 1)
		if p1.size() < 3:
			ok_start = false
		var ids1: Array = p1.map(func(o): return str(o["id"]))
		# 第 21/41/61 层各少一种最常见的，第 21/41/61/81 层各多一种新的
		for step in 4:
			var f0: int = 1 + 20 * step
			var pool: Array = mn.ore_pool(sid, f0).map(func(o): return str(o["id"]))
			var pool_prev: Array = mn.ore_pool(sid, maxi(1, f0 - 1)).map(func(o): return str(o["id"]))
			if step > 0:
				if pool.has(str(md["start"][step - 1]["id"])) or pool_prev.has(str(md["start"][step - 1]["id"])) == false:
					ok_rm = false
				if not pool.has(str(md["new"][step - 1]["id"])) or pool_prev.has(str(md["new"][step - 1]["id"])):
					ok_new = false
			# 一段 20 层之内矿种不变
			if mn.ore_pool(sid, f0 + 19).size() != mn.ore_pool(sid, f0).size() and f0 + 19 < 98:
				ok_new = false
		for f in range(1, 101):
			var has_rare := false
			for o in mn.ore_pool(sid, f):
				for r in md["rare"]:
					if str(o["id"]) == str(r["id"]):
						has_rare = true
			if has_rare != (f >= 98):
				ok_rare = false
		# 重复规则：第 21 层起的矿，前面所有井里都没出现过；前 20 层的矿只能来自上一口井前 50 层
		var later := {}
		for f in range(21, 101):
			for o in mn.ore_pool(sid, f):
				if not ids1.has(str(o["id"])):
					later[str(o["id"])] = 1
		for id in later:
			if seen_before.has(id):
				ok_share = false
		if sid > 1:
			var shared := 0
			for id in ids1:
				if prev50.has(id):
					shared += 1
				elif seen_before.has(id):
					ok_share = false
			if shared < 3:
				ok_share = false
		prev50 = {}
		for f in range(1, 51):
			for o in mn.ore_pool(sid, f):
				prev50[str(o["id"])] = 1
		for f in range(1, 101):
			for o in mn.ore_pool(sid, f):
				seen_before[str(o["id"])] = 1
	check(ok_start, "每口井前 20 层至少 3 种常见矿")
	check(ok_rm, "第 21/41/61 层起，前 20 层里最常见的矿一种一种消失")
	check(ok_new, "第 21/41/61/81 层各出现一种新矿，20 层内不变")
	check(ok_rare, "稀有矿只在最后 3 层（98-100）出现")
	check(ok_share, "只有前 20 层会和上一口井前 50 层的矿重复，第 21 层起全是新矿")
	# 物品栏里的产地信息
	var txt: String = mn.ore_origin_text("stone")
	check(txt.contains("1号井") and txt.contains("1-20"), "石头的产地：" + txt)
	var tin: String = mn.ore_origin_text("tin_ore")
	check(tin.contains("1号井") and tin.contains("2号井"), "锡矿石出在 1 号井和 2 号井：" + tin)
	check(mn.ore_origin_text("world_core").contains("5号井") and mn.ore_origin_text("world_core").contains("稀有"), "世界之核：5 号井 98-100 层，稀有")
	var orphan := 0
	for o in mn.cfg()["ores"]:
		if mn.ore_sources(str(o["id"])).is_empty():
			orphan += 1
	check(orphan == 0, "38 种矿石每种都有产地（没有的 %d）" % orphan)
	# 第 100 层没有往下的洞
	mn.m()["run"]["floor"] = 100
	var ex: Vector2i = mn.exit_pos(100)
	mn.m()["run"]["dug"][mn._key(ex.x, ex.y)] = 1
	check(mn.block(ex.x, ex.y) == "" and not mn.exit_ahead(0, 1), "第 100 层是底，没有往下的洞")
	# 挖出来的矿直接进物品栏，前几层大概一半石头没有矿
	mn.m()["run"]["floor"] = 1
	var with_ore := 0
	var total := 0
	for y in mn.height():
		for x in mn.width():
			if mn.has_rock(x, y):
				total += 1
				if mn.ore(x, y) != "":
					with_ore += 1
	var frac := float(with_ore) / float(maxi(1, total))
	check(frac > 0.2 and frac < 0.6, "不是每块石头都有矿（%.0f%%）" % (frac * 100.0))

func _count_mines(mn) -> int:
	return mn.cfg().get("mines", []).size()


func test_v083(balance: Dictionary, fish: Array) -> void:
	print("v0.83: 全部卖/存/丢只算选中的那一格、菜按时间算")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(83))
	g.state.bag_slots = 40
	g.inventory.add(g.state, "boot", 25)
	var cells: Array = g.inventory.cells(g.state)
	check(cells.size() == 3 and int(cells[0][1]) == 10 and int(cells[2][1]) == 5, "25 个靴子叠成 10 + 10 + 5 三格")
	check(g.stash_item("boot", true, 10) == 10 and g.inventory.count(g.state, "boot") == 15, "全部存：只存选中那一格的 10 个")
	check(g.fetch_item("boot", true, 10) == 10 and g.inventory.count(g.state, "boot") == 25, "全部取：只取选中那一格")
	var w0: int = g.state.wallet_gold
	var got: int = g.pawn_sell_stack("boot", 10)
	check(got > 0 and g.inventory.count(g.state, "boot") == 15 and g.state.wallet_gold == w0 + got, "全部卖：只卖选中那一格的 10 个")
	check(g.trash_item("boot", true, 10) == 10 and g.inventory.count(g.state, "boot") == 5, "全部丢：只丢选中那一格")
	check(g.trash_item("boot", true) == 5 and g.inventory.count(g.state, "boot") == 0, "不指定格数时仍是全部")
	g.inventory.add(g.state, "stone", 12)
	var o: int = g.ore_sell("stone", true, 10)
	check(o > 0 and g.inventory.count(g.state, "stone") == 2, "老钻收矿石：全部卖也只算一格")
	var found_sets := 0
	for d in g.mine.dishes():
		check(not d.has("light"), "菜 %s 没有光照增益" % d["id"])
		if float(d.get("minutes", 0)) > 0:
			found_sets += 1
	check(found_sets == 3, "三道菜都有持续时间（分钟）")
	check(float(g.mine.cfg()["layout"].get("crate_chance", 1.0)) < 0.5, "木箱概率调低了")

func test_unstick(balance: Dictionary, fish: Array) -> void:
	print("v0.83: 重启后站在石头里会被挪到空地")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(84))
	var mn = g.mine
	mn.ensure(clock.t)
	mn.begin_run(1, clock.t)
	_clear_crates(mn)
	var rock := Vector2i(-1, -1)
	for yy in range(2, mn.height()):
		for xx in mn.width():
			if rock.x < 0 and mn.block(xx, yy) in ["dirt", "stone", "rock", "deep"] and mn.has_rock(xx, yy):
				rock = Vector2i(xx, yy)
	check(rock.x >= 0, "找到一块石头")
	mn.m()["run"]["x"] = rock.x
	mn.m()["run"]["y"] = rock.y
	mn.m()["run"].erase("fx")
	check(not mn._free_at(mn.fpos()), "存档里的位置在石头正中（卡住了）")
	check(mn.unstick() and mn._free_at(mn.fpos()) and mn.block(mn.pos().x, mn.pos().y) == "", "自救：挪到了最近的空地")
	check(not mn.unstick(), "站在空地上不会乱挪")
	var en: Vector2i = mn.entrance(1)
	mn.m()["run"]["x"] = en.x
	mn.m()["run"]["y"] = en.y
	mn.m()["run"].erase("fx")
	check(mn.unstick() and mn.pos() != en and mn.block(mn.pos().x, mn.pos().y) == "", "站在梯子里也会被挪出来")

func test_island_layout(balance: Dictionary, fish: Array) -> void:
	print("v0.86: 雾灯岛上的建筑和 NPC 互不重叠")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(86))
	var xs := {"修理厂": g.repair_x(), "信号台": g.signal_x() + 5.0, "看守": g.island_keeper_x() + 8.0, "典当行": g.pawn_x(), "垃圾箱": g.trash_x(), "酒馆": g.tavern_x()}
	var names: Array = xs.keys()
	var bad := ""
	for i in names.size():
		for j in range(i + 1, names.size()):
			if absf(float(xs[names[i]]) - float(xs[names[j]])) < 22.0:
				bad += "%s/%s " % [names[i], names[j]]
	check(bad == "", "互相至少隔 22 像素（太近的：%s）" % bad)
	check(g.trash_x() < g.island_land_x() - 20.0, "垃圾箱不在码头上")

func test_mail(balance: Dictionary, fish: Array) -> void:
	print("v0.87: 邮局寄快递")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(87))
	g.state.bag_slots = 40
	g.inventory.add(g.state, "boot", 12)
	g.inventory.add(g.state, "stone", 3)
	g.state.wallet_gold = 5000
	check(g.mail_places().size() == 2 and g.mail_others("isle").size() == 1 and str(g.mail_others("isle")[0]["id"]) == "mine", "两个岛各有一个邮局")
	var one := {"boot": 1}
	var many := {"boot": 10, "stone": 3}
	check(g.mail_quote("isle", "mine", many) > g.mail_quote("isle", "mine", one), "东西越多邮费越贵")
	check(g.mail_quote("isle", "mine", {}) == 0, "没有东西不收钱")
	var far := int(g.mail_distance("isle", "mine"))
	check(far > 0 and g.mail_distance("isle", "mine") == g.mail_distance("mine", "isle"), "距离是对称的（%d）" % far)
	var price: int = g.mail_quote("isle", "mine", many)
	var w0: int = g.state.wallet_gold
	check(g.mail_send("isle", "mine", many, "p1") == "" and g.state.wallet_gold == w0 - price and g.inventory.count(g.state, "boot") == 2 and g.inventory.count(g.state, "stone") == 0, "寄出：扣邮费，物品离开背包（%d 铜）" % price)
	check(g.mail_send("isle", "mine", many, "p1") == "" and g.state.wallet_gold == w0 - price and g.state.mail.size() == 1, "同一个包裹号重复提交只寄一次")
	check(g.mail_send("isle", "isle", one, "p2") == "same", "不能寄给自己所在的岛")
	check(g.mail_send("isle", "mine", {"boot": 99}, "p3") == "have", "身上东西不够寄不了")
	check(g.mail_send("isle", "mine", {}, "p4") == "none", "空包裹寄不了")
	g.state.wallet_gold = 1
	check(g.mail_send("isle", "mine", one, "p5") == "gold", "钱不够寄不了")
	g.state.wallet_gold = 5000
	check(g.mail_ready("mine").is_empty() and g.mail_incoming("mine")[0] == 13 and g.mail_incoming("mine")[1] > 0, "刚寄出：还在路上，13 件")
	check(g.mail_take("mine", "boot") == 0, "没到不能取")
	check(g.mail_ready("isle").is_empty(), "寄出的岛上什么也取不到")
	clock.t += g.mail_eta_ms("isle", "mine") + 1
	check(int(g.mail_ready("mine").get("boot", 0)) == 10 and int(g.mail_ready("mine").get("stone", 0)) == 3, "到了：对岸取得到")
	check(g.mail_ready_cells("mine").size() == 2, "10 个靴子一格，3 块石头一格")
	check(g.mail_take("mine", "boot", 4) == 4 and g.inventory.count(g.state, "boot") == 6, "取件可以只取一部分")
	check(g.mail_take("mine", "boot") == 6 and g.mail_take("mine", "stone") == 3 and g.state.mail.is_empty(), "取完包裹就没了")
	var s2 := GameState.new()
	g.inventory.add(g.state, "rope", 2)
	g.mail_send("mine", "isle", {"rope": 2}, "p6")
	check(s2.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict()))) and s2.mail.size() == 1 and int(s2.mail[0]["items"]["rope"]) == 2, "在路上的包裹随存档保存")
	g.state.bag_slots = 1
	g.inventory.add(g.state, "boot", 10)
	clock.t += g.mail_eta_ms("mine", "isle") + 1
	check(g.mail_take("isle", "rope") == 0 and int(g.mail_ready("isle").get("rope", 0)) == 2, "背包放不下就留在邮局")


## v0.88：矿车按井号和楼层卖票；邮局会员寄存柜按页收格子。
func test_v088_ticket_and_locker(balance: Dictionary, fish: Array) -> void:
	print("v0.88: 矿车票、会员寄存柜")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(88))
	var mn = g.mine
	mn.ensure(clock.t)
	g.state.bag_slots = 40
	# ---- 矿车票 ----
	var t: Dictionary = balance.get("mine", {}).get("ticket", {})
	var base := int(t.get("base", 0))
	var per_shaft := int(t.get("per_shaft", 0))
	var per_floor := int(t.get("per_floor", 0))
	check(base > 0 and per_shaft > 0 and per_floor > 0, "票价三个数写在 balance 里（不在代码里写死）")
	check(mn.ticket_price(1, 1) == base, "1 号井第 1 层就是起步价 %d" % base)
	check(mn.ticket_price(2, 1) == base + per_shaft, "井号高一级贵 %d" % per_shaft)
	check(mn.ticket_price(1, 6) == base + 5 * per_floor, "每深一层加 %d（第 6 层）" % per_floor)
	check(mn.ticket_price(3, 21) == base + 2 * per_shaft + 20 * per_floor, "井号和楼层一起算：3 号井 21 层")
	check(mn.ticket_price(1, 100) > mn.ticket_price(1, 1) and mn.ticket_price(5, 1) > mn.ticket_price(1, 1), "楼层越深、井越好，票价越高")
	check(mn.ticket_price(0, 0) >= 0, "井号楼层再离谱也不会算出负票价")
	var w0: int = 5000
	g.state.wallet_gold = w0
	var r0: int = g.state.revision
	check(mn.shaft_status(3) == "wait" and mn.buy_ticket(3, 1) == "locked", "3 号井还没开放，买不到票")
	check(g.state.wallet_gold == w0 and g.state.revision == r0, "买不到票不扣钱也不改存档")
	check(mn.buy_ticket(1, 7) == "floor" and g.state.wallet_gold == w0, "没到过的层不能直接买票（也照旧不扣钱）")
	g.state.wallet_gold = base - 1
	r0 = g.state.revision
	check(mn.buy_ticket(1, 1) == "gold", "钱不够买不起票")
	check(g.state.wallet_gold == base - 1 and g.state.revision == r0, "买不起票不扣钱也不改存档")
	g.state.wallet_gold = w0
	r0 = g.state.revision
	check(mn.buy_ticket(1, 1) == "" and g.state.wallet_gold == w0 - base, "买 1 号井 1 层的票扣 %d 铜" % base)
	check(g.state.revision == r0 + 1, "买票要写进存档（修订号 +1）")
	# ---- 2 号井：修好之前买不到票 ----
	var need: Dictionary = mn.repair_need()
	g.inventory.add(g.state, "metal", int(need.get("metal", 0)))
	g.inventory.add(g.state, "stone", int(need.get("stone", 0)))
	g.state.wallet_gold = 90000
	check(mn.repair_shaft() != "" and mn.shaft_status(2) == "broken", "工人没雇好，矿车不发车")
	check(mn.buy_ticket(2, 1) == "locked", "铁路没修好，2 号井买不到票")
	g.state.effects["workers"] = int(need.get("crew", 2))
	var metal0: int = g.inventory.count(g.state, "metal")
	var stone0: int = g.inventory.count(g.state, "stone")
	check(mn.repair_shaft() == "" and mn.shaft_status(2) == "ok", "材料 + 工人齐了就修好了")
	check(g.inventory.count(g.state, "metal") == metal0 - int(need.get("metal", 0)) and g.inventory.count(g.state, "stone") == stone0 - int(need.get("stone", 0)), "修铁路按 repair2 扣材料")
	check(mn.repair_shaft() == "done" and g.inventory.count(g.state, "metal") == metal0 - int(need.get("metal", 0)), "已经修好了再点修理不会重复扣材料")
	check(mn.buy_ticket(2, 1) == "" and g.state.wallet_gold == 90000 - base - per_shaft, "修好后 2 号井的票比 1 号井贵 %d" % per_shaft)
	# ---- 一局只待在一口井里 ----
	check(mn.begin_run(2, clock.t) and mn.in_run() and mn.shaft_id() == 2, "坐上车：开始 2 号井的一局")
	var w1: int = g.state.wallet_gold
	var r1: int = g.state.revision
	check(mn.buy_ticket(1, 1) == "busy" and g.state.wallet_gold == w1 and g.state.revision == r1, "这局没结束就买不了别的井的票")
	check(mn.buy_ticket(2, mn.floor_n()) == "" and g.state.wallet_gold < w1, "接着这一局往下挖也要买票（第 %d 层）" % mn.floor_n())
	# ---- 会员寄存柜 ----
	var mail: Dictionary = balance.get("mail", {})
	var per_page := int(mail.get("locker_page_slots", 0))
	var costs: Array = mail.get("member_upgrade_costs", [])
	check(per_page > 0 and costs.size() == 5, "寄存柜每页格数和五页价格都写在 balance 里")
	g.state.mail_pages = 0
	check(g.mail_addresses("isle").size() == 1 and str(g.mail_addresses("isle")[0]["id"]) == "mine", "没开会员只有一个邮局地址")
	check(g.mail_send("isle", "locker_mine", {"boot": 1}, "x0") == "same", "没开会员寄不进寄存柜")
	for i in costs.size():
		g.state.mail_pages = i
		check(g.mail_member_cost() == int(costs[i]), "开到第 %d 页要 %d 铜" % [i + 1, int(costs[i])])
	g.state.mail_pages = 5
	check(g.mail_member_cost() == 0, "五页到顶，不能再扩")
	var w2: int = 90000
	g.state.mail_pages = 0
	g.state.wallet_gold = int(costs[0]) - 1
	r1 = g.state.revision
	check(g.mail_upgrade() == "gold" and g.state.mail_pages == 0 and g.state.wallet_gold == int(costs[0]) - 1, "钱不够开不了会员")
	g.state.wallet_gold = w2
	g.state.mail_pages = 0
	g.state.wallet_gold = w2
	r1 = g.state.revision
	var c0: int = int(costs[0])
	check(g.mail_upgrade() == "" and g.state.mail_pages == 1 and g.state.wallet_gold == w2 - c0, "开通会员扣 %d 铜，多一页柜子" % c0)
	check(g.state.revision == r1 + 1, "会员页数要写进存档（修订号 +1）")
	var addrs: Array = g.mail_addresses("isle")
	check(addrs.size() == 2 and str(addrs[1]["id"]) == "locker_mine", "开通后多一个会员寄存柜地址")
	check(not g.mail_place("locker_mine").is_empty() and g.mail_distance("isle", "locker_mine") == g.mail_distance("isle", "mine"), "寄存柜和对岸邮局算同一段路")
	check(g.mail_quote("isle", "locker_mine", {"boot": 4}) == g.mail_quote("isle", "mine", {"boot": 4}), "寄到寄存柜的邮费和寄到邮局一样")
	# 容量：格数 = 每页格数 × 页数，按物品栏的叠加上限折算
	var cap: int = g.inventory.stack_cap("boot")
	var full: int = per_page * cap
	g.inventory.add(g.state, "boot", full + cap)
	var half: int = full / 2
	check(g.mail_send("isle", "locker_mine", {"boot": half}, "L1") == "" and g._mail_locker_cells("locker_mine") == per_page / 2, "先存半页（%d 格）" % (per_page / 2))
	var w3: int = g.state.wallet_gold
	var p3: int = g.mail_quote("isle", "mine", {"boot": half})
	check(g.mail_send("isle", "locker_mine", {"boot": half}, "L2") == "" and g.state.wallet_gold == w3 - p3, "再存半页，正好装满一页")
	check(g._mail_locker_cells("locker_mine") == per_page, "一页 %d 格全满" % per_page)
	var n_before: int = g.state.mail.size()
	var boots_before: int = g.inventory.count(g.state, "boot")
	check(g.mail_send("isle", "locker_mine", {"boot": 1}, "L3") == "locker_full", "柜子满了就寄不进去")
	check(g.state.mail.size() == n_before and g.inventory.count(g.state, "boot") == boots_before, "被拒的寄件不扣钱也不扣东西")
	g.inventory.add(g.state, "boot", cap)
	clock.t += g.mail_eta_ms("isle", "locker_mine") + 1
	check(int(g.mail_ready("mine").get("boot", 0)) == full, "到时间后在对岸取得到寄存柜里的东西")
	check(g.mail_ready_cells("mine").size() == per_page, "取回页一格一组（%d 组）" % per_page)
	check(g.mail_take("mine", "boot", cap) == cap and g._mail_locker_cells("locker_mine") == per_page - 1, "取回一组就空出一格")
	check(g.mail_send("isle", "locker_mine", {"boot": cap}, "L4") == "", "空出一格后能再寄一组")
	g.state.mail_pages = 2
	check(g._mail_locker_cells("locker_mine") <= per_page and g.mail_send("isle", "locker_mine", {"boot": cap}, "L5") == "", "开到第二页，容量翻倍")
	g.state.mail_pages = 1
	check(g.mail_send("isle", "locker_mine", {"boot": cap}, "L6") == "locker_full", "页数改回一页，同样的东西就又放不下了")
	g.state.mail_pages = 2
	clock.t += g.mail_eta_ms("isle", "locker_mine") + 1
	var guard := 0
	while not g.state.mail.is_empty() and guard < 30:
		guard += 1
		if g.mail_take("mine", "boot") == 0:
			break
	check(g.state.mail.is_empty() and g._mail_locker_cells("locker_mine") == 0, "全取完，柜子空了")
	# ---- 存档往返 ----
	var s2 := GameState.new()
	check(s2.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict()))) and s2.mail_pages == g.state.mail_pages, "会员页数随存档保存")
	var d: Dictionary = g.state.to_dict()
	d["mail_pages"] = 99
	var s3 := GameState.new()
	check(s3.from_dict(JSON.parse_string(JSON.stringify(d))) and s3.mail_pages == 5, "页数最多算五页")
	d["mail_pages"] = -3
	var s4 := GameState.new()
	check(s4.from_dict(JSON.parse_string(JSON.stringify(d))) and s4.mail_pages == 0, "负数页数当没开通")
	d.erase("mail_pages")
	var s5 := GameState.new()
	check(s5.from_dict(JSON.parse_string(JSON.stringify(d))) and s5.mail_pages == 0, "旧存档没这个字段也能读")


## v0.89：画面脚本要能编译（编译不过 = 游戏直接起不来），SPRITES 里的贴图都要存在。
func test_v089_scripts_and_art() -> void:
	print("v0.89: 画面脚本编译与贴图齐全")
	var main: GDScript = load("res://presentation/main.gd")
	check(main != null and main.can_instantiate(), "main.gd 能编译（游戏入口）")
	for p in ["world", "mine_view", "bag", "works_panel", "shopfronts", "dialog", "dest_panel", "quest_panel"]:
		var s: GDScript = load("res://presentation/%s.gd" % p)
		check(s != null and s.can_instantiate(), "%s.gd 能编译" % p)
	var sprites: Array = main.get_script_constant_map().get("SPRITES", [])
	check(sprites.size() > 100, "SPRITES 列了 %d 张贴图" % sprites.size())
	for n in ["keeper_ko", "island_repair", "island_pawn", "island_tavern", "lighthouse", "mine_gate"]:
		check(str(n) in sprites, "SPRITES 里有 %s" % str(n))
	var missing := 0
	var first_missing := ""
	for n in sprites:
		var path := "res://assets/sprites/%s.png" % str(n)
		if not ResourceLoader.exists(path):
			missing += 1
			if first_missing == "":
				first_missing = str(n)
	check(missing == 0, "SPRITES 里每一张图都生成出来了（缺的第一张：%s）" % first_missing)
	var labels: String = FileAccess.get_file_as_string("res://presentation/labels.gd")
	check(not labels.is_empty(), "labels.gd 在（界面文字表）")



## v0.90：运行时用 label() 画出来的提示文字必须在标签图集里。
## 之前雾灯岛/矿山岛漏了 8 条（空格键进酒馆、空格键看修理厂…），真机跑起来只报警告、玩家什么都看不见。
func test_labels() -> void:
	print("v0.90: 提示文字都在标签图集里")
	var labels: Dictionary = preload("res://presentation/labels.gd").RECTS
	check(labels.size() > 400, "标签图集里有 %d 条文字" % labels.size())
	# 1) 屋里的提示：World.SPOT_HINT 的每个值
	var wsrc: String = FileAccess.get_file_as_string("res://presentation/world.gd")
	var line := ""
	for l in wsrc.split("\n"):
		if str(l).begins_with("const SPOT_HINT"):
			line = str(l)
	check(not line.is_empty(), "World.SPOT_HINT 还在")
	var rv := RegEx.create_from_string(":\\s*\"([^\"]*)\"")
	for m in rv.search_all(line):
		var s: String = m.get_string(1)
		check(labels.has(s), "屋里提示在图集里: %s" % s)
	# 2) 岛上的提示：_island_hint() 里每条 return 的文字
	var msrc: String = FileAccess.get_file_as_string("res://presentation/main.gd")
	var i: int = msrc.find("func _island_hint")
	check(i >= 0, "main.gd 的 _island_hint 还在")
	var j: int = msrc.find("\nfunc ", i + 10)
	if j < 0:
		j = msrc.length()
	var body: String = msrc.substr(i, j - i)
	var rr := RegEx.create_from_string("return \"([^\"]*)\"")
	var n_hint := 0
	for m in rr.search_all(body):
		var s2: String = m.get_string(1)
		if s2 == "":
			continue        # 看守头顶是聊天气泡，故意不写字
		n_hint += 1
		check(labels.has(s2), "岛上提示在图集里: %s" % s2)
	check(n_hint >= 10, "_island_hint 里查到 %d 条提示" % n_hint)
	# 3) 所有画面脚本里写死的 label("…") 字面量
	var dr := DirAccess.open("res://presentation")
	var bad := 0
	var first_bad := ""
	var rl := RegEx.create_from_string("label(?:_centered)?\\(\\s*\"([^\"]*)\"")
	for f in dr.get_files():
		var p: String = "res://presentation/" + str(f)
		if not str(f).ends_with(".gd") or str(f) == "labels.gd":
			continue
		for m in rl.search_all(FileAccess.get_file_as_string(p)):
			var s3: String = m.get_string(1)
			if s3 != "" and not labels.has(s3):
				bad += 1
				if first_bad == "":
					first_bad = "%s: %s" % [str(f), s3]
	check(bad == 0, "画面脚本里写死的 label 文字全在图集里（漏了 %d 条，第一个：%s）" % [bad, first_bad])

func test_v093_open_shafts(balance: Dictionary, fish: Array) -> void:
	print("v0.93: 3–5 号井的开工条件")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(93))
	var mn = g.mine
	var inv = g.inventory
	mn.ensure(clock.t)
	g.state.bag_slots = 60      # 要一次塞下几十份材料，先把物品栏放大
	var om: Dictionary = balance.get("mine", {}).get("open_shafts", {})
	check(om.has("3") and om.has("4") and om.has("5"), "3/4/5 号井的开工条件写在 balance 里（不是写死在代码里）")
	var prev_ok := true
	var d3 := 0
	var d4 := 0
	var d5 := 0
	for k in ["3", "4", "5"]:
		var e: Dictionary = om[k]
		var p := int(e.get("prev", 0))
		if p >= int(k) or p < 1 or p > 5 or int(e.get("depth", 0)) <= 0 or int(e.get("crew", 0)) <= 0:
			prev_ok = false
		if (e.get("items", {}) as Dictionary).is_empty():
			prev_ok = false
	check(prev_ok, "每口井都有：更早的上一口井、正数深度门槛、正数工人、要材料")
	d3 = int(om["3"].get("depth", 0)); d4 = int(om["4"].get("depth", 0)); d5 = int(om["5"].get("depth", 0))
	check(d3 < d4 and d4 < d5, "越往后的井要挖得越深才让开（%d < %d < %d）" % [d3, d4, d5])
	var ids_ok := true
	for k in ["3", "4", "5"]:
		for it in (om[k].get("items", {}) as Dictionary).keys():
			if not inv.by_id.has(str(it)):
				ids_ok = false
	check(ids_ok, "开工要的材料都是真实存在的道具（写错名字就永远凑不齐了）")
	# 开局：2 号井没修 → 3 号井是 wait
	check(mn.shaft_status(3) == "wait" and not mn.shaft_ok(3), "2 号井没修好之前，3 号井只能干等（wait）")
	check(mn.open_shaft(3) == "prev", "上一口井没开，开工被拒（prev）")
	check(mn.shaft_status(5) == "wait" and mn.open_shaft(5) == "prev", "5 号井要等 4 号井，越级开工被拒")
	check(mn.open_need(9).is_empty() and mn.open_shaft(9) == "locked", "没写条件的井号（9 号）永远开不了")
	# 修好 2 号井
	g.state.wallet_gold = 9000
	inv.add(g.state, "metal", 90); inv.add(g.state, "stone", 90)
	g.state.effects["workers"] = 4
	check(mn.repair_shaft() == "" and mn.shaft_ok(2), "先按老办法把 2 号井的铁路修好")
	check(mn.shaft_status(3) == "build", "2 号井通了以后，3 号井变成可以开工（build）")
	# 深度不够
	var n_before: Dictionary = {}
	for k in (om["3"].get("items", {}) as Dictionary).keys():
		inv.add(g.state, str(k), int((om["3"]["items"] as Dictionary)[k]))
		n_before[str(k)] = inv.count(g.state, str(k))
	var r0: int = g.state.revision
	var w0: int = g.state.wallet_gold
	check(mn.deepest_floor(2) == 0 and not mn.open_ready(3), "2 号井还一层没挖过，3 号井不算凑齐")
	check(mn.open_shaft(3) == "depth", "2 号井没挖到指定深度，开工被拒（depth）")
	var same := true
	for k in n_before.keys():
		if inv.count(g.state, str(k)) != int(n_before[k]):
			same = false
	check(same and g.state.wallet_gold == w0 and g.state.revision == r0, "开工被拒不扣材料、不扣钱、不写存档")
	mn.shaft_state(2)["best"] = d3 - 1
	check(mn.deepest_floor(2) == d3 - 1 and mn.open_shaft(3) == "depth", "差一层也不行（%d 层 < %d 层）" % [d3 - 1, d3])
	mn.shaft_state(2)["best"] = d3
	check(mn.deepest_floor(2) == d3 and mn.open_ready(3), "挖到第 %d 层就算够深" % d3)
	# 缺工人
	g.state.effects["workers"] = 0
	r0 = g.state.revision
	check(mn.open_shaft(3) == "crew", "工人没雇够，开工被拒（crew）")
	same = true
	for k in n_before.keys():
		if inv.count(g.state, str(k)) != int(n_before[k]):
			same = false
	check(same and g.state.revision == r0, "缺工人这一趟一件材料都不扣（先查再扣）")
	# 缺材料
	inv.remove(g.state, "metal", inv.count(g.state, "metal"))
	g.state.effects["workers"] = 4
	r0 = g.state.revision
	check(mn.open_shaft(3) == "mat", "材料不够，开工被拒（mat）")
	check(g.state.revision == r0, "缺材料这一趟也不写存档")
	# 凑齐
	for k in (om["3"].get("items", {}) as Dictionary).keys():
		inv.add(g.state, str(k), int((om["3"]["items"] as Dictionary)[k]))
	var m3: Dictionary = om["3"]["items"]
	var metal_before: int = inv.count(g.state, "metal")
	r0 = g.state.revision
	check(mn.open_missing(3).is_empty() and mn.open_ready(3), "材料、深度、工人齐了，open_ready 说可以")
	check(mn.open_shaft(3) == "", "齐了就开得成 3 号井")
	check(mn.shaft_ok(3) and mn.shaft_status(3) == "ok", "开好的井状态变 ok，矿车能过去")
	check(inv.count(g.state, "metal") == metal_before - int(m3.get("metal", 0)), "开工按表扣金属（扣了 %d 个）" % int(m3.get("metal", 0)))
	check(g.state.revision > r0, "开工要写进存档（修订号涨了 %d）" % (g.state.revision - r0))
	r0 = g.state.revision
	var metal_after: int = inv.count(g.state, "metal")
	check(mn.open_shaft(3) == "done", "已经开好的井不能重复开工（done）")
	check(g.state.revision == r0 and inv.count(g.state, "metal") == metal_after, "重复开工不重复扣钱扣材料")
	# 开了就能买票
	g.state.wallet_gold = 9000
	var t: Dictionary = balance.get("mine", {}).get("ticket", {})
	check(mn.buy_ticket(3, 1) == "" and g.state.wallet_gold == 9000 - (int(t.get("base", 0)) + 2 * int(t.get("per_shaft", 0))), "开了 3 号井就能买它的票（贵两档）")
	check(mn.shaft_status(4) == "build" and mn.shaft_status(5) == "wait", "3 号井通了 → 4 号井可开工、5 号井还得等")
	# 存档往返
	mn.shaft_state(4)["open"] = 1
	var s2 := GameState.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict())))
	var g2 := Game.new(balance, fish, s2, clock, _rng(93))
	g2.mine.ensure(clock.t)
	check(g2.mine.shaft_ok(3) and g2.mine.shaft_ok(4) and not g2.mine.shaft_ok(5), "开工状态存得下来、读得回来")
	check(g2.mine.deepest_floor(2) == d3, "每口井挖到过多深也存得下来")
	# 老存档：没有 3/4/5 号井的条目也不能崩
	var s3 := GameState.new()
	s3.from_dict(JSON.parse_string(JSON.stringify(g.state.to_dict())))
	(s3.mine as Dictionary)["shafts"] = {"1": {"cp": 3, "best": 12}}
	var g3 := Game.new(balance, fish, s3, clock, _rng(93))
	g3.mine.ensure(clock.t)
	check(g3.mine.deepest_floor(1) == 12 and g3.mine.shaft_status(3) == "wait", "老存档缺 3/4/5 号井的条目也会自动补上，不报错")

func test_v094_shaft_themes(balance: Dictionary, fish: Array) -> void:
	print("v0.94: 五口井各有各的长相")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(94))
	var mn = g.mine
	mn.ensure(clock.t)
	var Pal = preload("res://presentation/palette.gd")
	var th: Dictionary = balance.get("mine", {}).get("shaft_themes", {})
	check(th.size() >= 5 and th.has("1") and th.has("5"), "五口井的主题写在 balance 里（%d 条）" % th.size())
	var slots := ["dirt", "stone", "rock", "deep", "rim"]
	var complete := true
	var palette_only := true
	var hex_free := true
	for k in th.keys():
		var e: Dictionary = th[k]
		if str(e.get("name", "")) == "" or not e.has("mix"):
			complete = false
		for sl in slots:
			var v = e.get(sl, "")
			if typeof(v) != TYPE_STRING or not Pal.BY_KEY.has(str(v)):
				palette_only = false
			if str(v).length() != 1:
				hex_free = false
	check(complete, "每口井都写了名字、五个部位的颜色和染色强度")
	check(palette_only, "主题里的颜色全是锁定调色板里的键（画不出调色板以外的颜色）")
	check(hex_free, "颜色写成调色板键而不是十六进制（改调色板会一起改）")
	var names: Array = []
	var rocks: Array = []
	var named := true
	for i in range(1, 6):
		var n: String = mn.shaft_name(i)
		if n == "" or not n.contains("矿井"):
			named = false
		names.append(n)
		rocks.append(mn.shaft_color(i, "rock"))
	check(named, "每口井都有名字（%s）" % "、".join(names))
	check(names.size() == 5 and names.has("灰岩矿井") and names.has("星陨矿井"), "从灰岩矿井到星陨矿井，五口井都叫得出名")
	var rockset: Dictionary = {}
	for rc in rocks:
		rockset[str(rc)] = true
	check(rocks.size() == 5 and rockset.size() == 5, "五口井的石头颜色两两不同：%s" % ", ".join(PackedStringArray(rocks)))
	check(mn.shaft_color(1, "dirt") == "O" and mn.shaft_color(1, "stone") == "a" and mn.shaft_color(1, "rock") == "A" and mn.shaft_color(1, "deep") == "S", "1 号井还是原来那四个颜色（老玩家看不出变化）")
	check(mn.shaft_mix(1) == 0.0, "1 号井染色强度 0：素材原色，一个像素都没变")
	var others_ok := true
	for i in range(2, 6):
		var mx := mn.shaft_mix(i)
		if mx < 0.3 or mx > 0.8:
			others_ok = false
	check(others_ok, "2–5 号井的染色在 0.3–0.8 之间：看得出是另一种石头，又不会糊成一团")
	check(mn.shaft_theme(9) == mn.shaft_theme(1) and mn.shaft_name(9) == "9 号井", "没写主题的井号退回 1 号井的样子，不报错")
	check(mn.shaft_color(3, "没这个部位") == mn.shaft_color(3, "rock"), "问一个不存在的部位会退回石头色，不是空白")
	var t3: Dictionary = th["3"]
	check(str(t3.get("mix", -1.0)) == str(mn.shaft_mix(3)), "每口井自己的染色强度优先于全局的 shaft_theme_mix")
	var gm := float(balance["mine"].get("shaft_theme_mix", -1.0))
	check(gm >= 0.0 and gm <= 1.0, "全局默认染色强度 %s 也在 0–1 之间" % str(gm))
	var probe := GameState.new()
	probe.from_dict({"mine": {"shafts": {"3": {"open": 1, "cp": 1, "best": 20}}, "runs": 0, "dish": "", "run": {}, "bombs": 0, "sta": 100.0}})
	var g2 := Game.new(balance, fish, probe, clock, _rng(94))
	g2.mine.ensure(clock.t)
	check(g2.mine.shaft_color(3, "rock") == str(t3.get("rock", "")), "换了个存档，井的颜色还是照 json 走（颜色不进存档）")
	check(not g2.state.to_dict().has("shaft_themes"), "主题只是配置，不会被抄进存档里存两份")
	check(Pal.BY_KEY.has(mn.shaft_color(5, "rim")), "崖边描边用的也是调色板里的颜色（星陨井：%s）" % mn.shaft_color(5, "rim"))
	var named_all := true
	for k in th.keys():
		if str((th[k] as Dictionary).get("name", "")).length() < 3:
			named_all = false
	check(named_all, "名字都不是占位符（至少三个字）")

func test_v095_shaft_backdrop(balance: Dictionary, fish: Array) -> void:
	print("v0.95: 每口井的背景、黑暗、灯光也有自己的颜色")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(95))
	var mn = g.mine
	mn.ensure(clock.t)
	var Pal := preload("res://presentation/palette.gd")
	var MV := preload("res://presentation/mine_view.gd")
	var th: Dictionary = balance.get("mine", {}).get("shaft_themes", {})
	var have_all := true
	var palette_only := true
	for k in th.keys():
		var t: Dictionary = th[k]
		for slot in ["bg", "fog", "lamp"]:
			var key := str(t.get(slot, ""))
			if key == "":
				have_all = false
			elif not Pal.BY_KEY.has(key):
				palette_only = false
	check(have_all, "五口井都写了背景（bg）、黑暗（fog）、灯光（lamp）三个颜色位")
	check(palette_only, "背景、黑暗、灯光用的都是调色板里的键，画不出 24 色以外的颜色")
	var bgs: Array = []
	var lamps: Array = []
	for i in range(1, 6):
		var bk: String = mn.shaft_color(i, "bg")
		if not bgs.has(bk):
			bgs.append(bk)
		var lk: String = mn.shaft_color(i, "lamp")
		if not lamps.has(lk):
			lamps.append(lk)
	check(bgs.size() >= 4, "五口井的背景色至少有 4 种不一样（%s）" % "、".join(PackedStringArray(bgs)))
	check(lamps.size() >= 4, "五口井的灯光色至少有 4 种不一样（%s）" % "、".join(PackedStringArray(lamps)))
	# 1 号井的染色强度是 0，这三个函数必须原样返回旧颜色
	check(MV.shaft_backdrop(mn.shaft_color(1, "bg"), 0.0) == Pal.U_K, "混 0 成的背景 = 原来的深紫黑 Pal.U_K，一个字节都没改")
	check(MV.shaft_backdrop(mn.shaft_color(1, "bg"), mn.shaft_mix(1)) == Pal.U_K, "1 号井按 json 里的强度算出来还是原来的背景色")
	check(MV.shaft_darkness(mn.shaft_color(1, "fog"), 0.0, 0.5) == Color(0.03, 0.02, 0.05, 0.5), "混 0 成的黑暗 = 原来的黑（只换色相，不改透明度）")
	check(MV.shaft_darkness(mn.shaft_color(1, "fog"), mn.shaft_mix(1), 0.75).a == 0.75, "黑暗叠加的透明度不受配色影响")
	check(MV.shaft_lamp(mn.shaft_color(1, "lamp"), mn.shaft_mix(1)) == Pal.L_Y, "1 号井的灯光还是原来的暖黄 Pal.L_Y")
	# 别的井要真的不一样，但不能变亮、变花
	var shifted := true
	var dark_enough := true
	var bgcols: Array = []
	for i in range(1, 6):
		var c: Color = MV.shaft_backdrop(mn.shaft_color(i, "bg"), mn.shaft_mix(i))
		bgcols.append(c)
		if i >= 2 and c == Pal.U_K:
			shifted = false
		if c.get_luminance() > 0.25:
			dark_enough = false
	check(shifted, "2–5 号井的背景确实不是原来那个颜色")
	check(dark_enough, "染完色背景还是暗的（亮度都 ≤ 0.25）：井底不会变成彩色卡片")
	var uniq := true
	for i in bgcols.size():
		for j in range(i + 1, bgcols.size()):
			if bgcols[i] == bgcols[j]:
				uniq = false
	check(uniq, "五口井的背景色两两不同（截图里能一眼看出换了口井）")
	var dark_ok := true
	for i in range(1, 6):
		var d: Color = MV.shaft_darkness(mn.shaft_color(i, "fog"), mn.shaft_mix(i), 1.0)
		if d.get_luminance() > 0.06:
			dark_ok = false
	check(dark_ok, "黑暗叠加再怎么染色也还是黑的（亮度 ≤ 0.06），不会把矿洞照亮")
	var lamp_ok := true
	for i in range(2, 6):
		var l: Color = MV.shaft_lamp(mn.shaft_color(i, "lamp"), mn.shaft_mix(i))
		if l.get_luminance() < Pal.L_Y.get_luminance() * 0.5:
			lamp_ok = false
	check(lamp_ok, "每口井的灯光都够亮（不低于原暖黄的一半）：反光点还看得见")
	check(MV.shaft_backdrop("没有这个键", 0.9) == Pal.U_K, "写了个调色板里没有的键，背景退回原来的深紫黑，不会崩")
	check(MV.shaft_backdrop(mn.shaft_color(3, "bg"), 5.0) == MV.shaft_backdrop(mn.shaft_color(3, "bg"), 1.0), "染色强度写大了会被夹到 1")
	check(MV.shaft_backdrop(mn.shaft_color(3, "bg"), -3.0) == Pal.U_K, "染色强度写成负数等于不染")

func test_v096_ore_dex(balance: Dictionary, fish: Array) -> void:
	print("v0.96: 挖到的矿石进图鉴")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(96))
	var mn = g.mine
	mn.ensure(clock.t)
	var ores: Array = mn.ore_dex()
	check(ores.size() == balance["mine"]["ores"].size() and ores.size() >= 30, "图鉴里有全部 %d 种矿石（按 json 顺序，越深的井越靠后）" % ores.size())
	var uniq := true
	for i in ores.size():
		for j in range(i + 1, ores.size()):
			if ores[i] == ores[j]:
				uniq = false
	check(uniq, "图鉴里的矿石没有重复")
	var known := true
	for id in ores:
		if not g.inventory.by_id.has(str(id)):
			known = false
	check(known, "图鉴里的每种矿石都是物品栏里真有的物品（图标和名字都对得上）")
	check(mn.dex_found() == 0 and mn.ore_dug_count("stone") == 0, "新存档一种矿石都没见过")
	# 找一块埋着矿、头顶是地板的石头，站上去朝下挖一格
	mn.begin_run(1, clock.t)
	mn.give_first_pick()
	g.state.mine["sta"] = float(mn.stamina_max())
	var tx := -1
	var ty := -1
	var oid := ""
	for yy in range(mn.height() - 1):
		for xx in range(mn.width()):
			var o := str(mn.ore(xx, yy))
			if o != "" and mn.is_floor(xx, yy - 1) and mn.need_tool(xx, yy) <= 1 and str(mn.ore_def(o).get("item", "")) != "":
				tx = xx
				ty = yy
				oid = str(mn.ore_def(o)["item"])
				break
		if tx >= 0:
			break
	check(tx >= 0, "第 1 层里找得到一块埋着矿的石头（挖 %s）" % oid)
	# 站到矿石上面那格：整数格和偏移都要写（fpos 只认整数格对得上的偏移）
	var rr: Dictionary = g.state.mine["run"]
	rr["x"] = tx
	rr["y"] = ty - 1
	rr["fx"] = float(tx) + 0.5
	rr["fy"] = float(ty) - 0.3     # 往下挖要往前站一点（和老测试一样偏 0.2 格），否则够不着下面那格
	var ms := int(mn.dig_ms(tx, ty)) + 1
	check(ms > 1 and mn.start_dig(0, 1, clock.t) == "", "站到矿石上方开始挖")
	clock.t += ms
	var ev: Array = mn.update(clock.t)
	var dug := false
	for e in ev:
		if str(e.get("type", "")) == "dug":
			dug = true
	check(dug and mn.is_dug(tx, ty), "石头碎了")
	check(mn.ore_dug_count(oid) == 1, "碎的那块如果是 %s，图鉴里就记 1 块" % oid)
	check(mn.dex_found() == 1, "图鉴进度变成见过 1 种")
	# 再挖同一格不会重复加（一格石头只碎一次）
	mn.stop_dig(clock.t)
	clock.t += 10000
	mn.update(clock.t)
	check(mn.ore_dug_count(oid) == 1, "同一块石头不会记两次（经济幂等）")
	# 存档往返
	var d: Dictionary = g.state.to_dict()
	check((d.get("stats") as Dictionary).has("ore_counts"), "图鉴计数跟着存档走")
	var st2 := GameState.new()
	check(st2.from_dict(d), "带图鉴计数的存档能读回来")
	var g3 := Game.new(balance, fish, st2, clock, _rng(96))
	g3.mine.ensure(clock.t)
	check(g3.mine.ore_dug_count(oid) == 1 and g3.mine.dex_found() == 1, "读档以后图鉴还是那 1 种 1 块")
	# 老存档（没有这个键）不会崩
	var old := GameState.new()
	check(old.from_dict(g.state.to_dict()), "老存档照样能读")
	var st4 := GameState.new()
	st4.stats.erase("ore_counts")
	var g5 := Game.new(balance, fish, st4, clock, _rng(96))
	g5.mine.ensure(clock.t)
	check(g5.mine.ore_dex().size() == ores.size() and g5.mine.dex_found() == 0, "存档里没这个键就当一种都没见过，不报错")
	check(mn.dex_found() <= mn.ore_dex().size(), "见过几种不会超过一共有几种")
	# 翻页的算术（图鉴册的卡片数 = 鱼 + 矿石；一页放不下就得多翻几页）
	var Book := load("res://presentation/book.gd")
	var total: int = int(g.fish_list.size()) + int(mn.ore_dex().size())
	check(Book.dex_pages_for(total, 12) == int(ceil(float(total) / 12.0)) and Book.dex_pages_for(total, 12) >= 3, "%d 张卡一页 12 张要翻 %d 页" % [total, Book.dex_pages_for(total, 12)])
	check(Book.dex_pages_for(0, 12) == 1 and Book.dex_pages_for(12, 12) == 1, "刚好一页或空图鉴都只有一页")
	check(Book.dex_pages_for(13, 12) == 2 and Book.dex_pages_for(13, 0) == 13, "多一张就多一页；一页一张时不会除零")


## v0.97：画面助手（都是 RefCounted）不许**互相**持有。
## 两个带引用计数的对象互相指，谁都归不了零，就永远不回收：v0.96 打调试包退出时引擎报了
## "2 resources still in use at exit" + "5 ObjectDB instances were leaked" + 227 条 Orphan
## StringName，查出来就是 World 存了 Shopfronts、Shopfronts 又存回 World。单向持有没问题
## （持有者被释放时，被持有者跟着归零），所以要拦的是**来回指**。
func test_v097_no_helper_cycles() -> void:
	print("v0.97: 助手之间不许互相持有（退出时不再漏对象）")
	var dir := DirAccess.open("res://presentation")
	check(dir != null, "presentation/ 目录在")
	var helpers := {}
	if dir != null:
		for f in dir.get_files():
			var fn := str(f)
			if not fn.ends_with(".gd"):
				continue
			var src: String = FileAccess.get_file_as_string("res://presentation/%s" % fn)
			var head := ""
			for l in src.split("\n"):
				var t := str(l).strip_edges()
				if t == "" or t.begins_with("#"):
					continue
				head = t
				break
			if head == "extends RefCounted":
				helpers[fn] = src
	check(helpers.size() >= 10, "扫到 %d 个 RefCounted 画面助手" % helpers.size())
	# 类名约定：文件名去掉 .gd、首字母大写（shopfronts.gd → Shopfronts）
	var by_class := {}
	for f in helpers.keys():
		var n := str(f).substr(0, str(f).length() - 3)
		by_class[str(n).substr(0, 1).to_upper() + str(n).substr(1)] = str(f)
	# 先找出"谁把哪个助手赋给了自己的成员"，画出一张单向图
	var edges := {}          # 文件 → { 被持有的类名: 成员名 }
	var loops := 0
	var first_loop := ""
	for f in helpers.keys():
		var src: String = helpers[f]
		var members := {}
		for l in src.split("\n"):
			var t := str(l)
			if not t.begins_with("var ") and not t.begins_with("@export var "):
				continue
			var rest := t.substr(t.find("var ") + 4)
			var end := rest.length()
			for ch in [" ", "\t", "=", ":"]:
				var i := rest.find(ch)
				if i >= 0:
					end = mini(end, i)
			members[rest.substr(0, end)] = true
		var holds := {}
		for cls in by_class.keys():
			if str(by_class[cls]) == str(f):
				continue
			var needle := "= %s.new(" % str(cls)
			var pos := src.find(needle)
			while pos >= 0:
				var ls := src.rfind("\n", pos)
				var line := str(src.substr(ls + 1, pos - ls - 1)).strip_edges()
				if members.has(line):
					holds[str(cls)] = str(line)
				pos = src.find(needle, pos + 1)
		edges[str(f)] = holds
	# 来回指 = 环
	var my_class := {}
	for f in helpers.keys():
		for cls in by_class.keys():
			if str(by_class[cls]) == str(f):
				my_class[str(f)] = str(cls)
	for f in edges.keys():
		var holds: Dictionary = edges[f]
		for cls in holds.keys():
			var target := str(by_class[cls])
			if not edges.has(target):
				continue
			if (edges[target] as Dictionary).has(my_class[f]):
				loops += 1
				if first_loop == "":
					first_loop = "%s 存了 %s，%s 又存回 %s" % [str(f), str(cls), str(target), str(my_class[f])]
	var edge_count := 0
	for f in edges.keys():
		edge_count += (edges[f] as Dictionary).size()
	check(edge_count >= 1, "扫到 %d 条单向持有（说明这个扫描真的在看，不是空转）" % edge_count)
	check(loops == 0, "助手之间没有来回指的环%s" % (("；查出：" + first_loop) if loops > 0 else ""))
	# 当初那处具体的毛病：门面不许再存任何东西
	var sf: String = FileAccess.get_file_as_string("res://presentation/shopfronts.gd")
	check(sf.length() > 200, "shopfronts.gd 还在（街上门面）")
	check(not sf.contains("\nvar w"), "门面不再把 World 存进成员（环断在这一半）")
	check(sf.contains("var _gy0"), "地面高度改成构造时抄一份数值（_gy0）")
	check(sf.contains("return _gy0"), "地面高度取自抄来的数值，不再回头找 World")
	check(sf.find("w.GROUND_Y") < 0, "门面里一处也不再通过 World 取东西")
	check((edges.get("shopfronts.gd", {}) as Dictionary).is_empty(), "门面不再持有任何助手（单向图里它是叶子）")
	var ws: String = FileAccess.get_file_as_string("res://presentation/world.gd")
	check(ws.contains("const GROUND_Y"), "GROUND_Y 是常量，抄一份数值不会有\"过期\"的问题")
	check(ws.contains("Shopfronts.new(self)"), "门面还是 World 现造的（画面没被拆掉）")
	var sfc: GDScript = load("res://presentation/shopfronts.gd")
	check(sfc != null and sfc.can_instantiate(), "shopfronts.gd 改完还能编译")
	var wsc: GDScript = load("res://presentation/world.gd")
	check(wsc != null and wsc.can_instantiate(), "world.gd 还能编译（小镇主画面）")
	var msc: GDScript = load("res://presentation/main.gd")
	check(msc != null and msc.can_instantiate(), "main.gd 还能编译（游戏入口）")




## v0.98：体检脚本的卫生规则。
## 这两个脚本会把游戏真起来跑几分钟，最容易犯的错就是"顺手写了玩家的存档"。
## 所以钉死：tools/ 下任何 .sh 都必须把存档写到临时目录（mktemp 或 CATFISH_SAVE），
## 打包脚本也一样。另外钉住挂机帧率常量（桌面宠物全天挂着，不是满帧在画）。
func test_v098_perf_hygiene() -> void:
	print("v0.98: 体检脚本不许碰真存档 + 挂机帧率常量")
	var dir := DirAccess.open("res://tools/perf")
	check(dir != null, "tools/perf/ 目录在")
	var seen := 0
	var naked := 0
	var first_naked := ""
	if dir != null:
		for f in dir.get_files():
			var fn := str(f)
			if not fn.ends_with(".sh"):
				continue
			seen += 1
			var src: String = FileAccess.get_file_as_string("res://tools/perf/%s" % fn)
			check(src.length() > 400, "%s 有内容（%d 字节）" % [fn, src.length()])
			if not (src.contains("mktemp") and src.contains("CATFISH_SAVE")):
				naked += 1
				if first_naked == "":
					first_naked = fn
	check(seen >= 2, "tools/perf/ 下有 %d 个体检脚本" % seen)
	check(naked == 0, "每个体检脚本都把存档写到临时目录%s" % (("；漏了：" + first_naked) if naked > 0 else ""))
	var sweep: String = FileAccess.get_file_as_string("res://tools/perf/leak_sweep.sh")
	check(sweep.contains("--verbose"), "泄漏扫描开了 --verbose（不然是空跑，抓不到退出时的报告）")
	check(sweep.contains("Leaked instance") and sweep.contains("still in use") and sweep.contains("Orphan StringName"),
		"泄漏扫描认那三类泄漏关键字")
	var screens := 0
	for l in sweep.split("\n"):
		if str(l).begins_with("\t\"") and str(l).contains("|CATFISH_"):
			screens += 1
	check(screens >= 10, "泄漏扫描覆盖 %d 个画面" % screens)
	var idle: String = FileAccess.get_file_as_string("res://tools/perf/idle_rss.sh")
	check(idle.contains("ps -o rss="), "挂机探针读的是 RSS（常驻内存），不是虚拟内存")
	check(idle.contains("trap 'rm -rf"), "挂机探针退出时把临时目录删掉")
	var pack: String = FileAccess.get_file_as_string("res://打包游戏.command")
	check(pack.contains("mktemp") and pack.contains('HOME="$check_home"'), "打包自检也在临时 HOME 里跑（v0.97 的规则）")
	var main: String = FileAccess.get_file_as_string("res://presentation/main.gd")
	check(main.contains("const FPS_NORMAL := 30"), "平时限 30 帧（不是满帧在画）")
	check(main.contains("const FPS_HIDDEN := 5"), "窗口最小化时降到 5 帧")

