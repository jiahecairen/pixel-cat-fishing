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

class FakeClock:
	var t: int = 1_000_000
	var day: String = "2026-01-01"
	func now_ms() -> int: return t
	func today_key() -> String: return day

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
	check(fish.size() == 3, "fish.json 有 3 种鱼")
	if _fails == 0:
		test_economy(fish)
		test_fishing(balance, fish)
		test_pomodoro(balance)
		test_game_focus(balance, fish)
		test_game_free_mode(balance, fish)
		test_upgrades_and_settings(balance, fish)
		test_cat_config()
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
	var now := 0
	fs.start(now)
	check(fs.state == Fishing.State.CASTING, "开始后进入抛竿")
	var waits: Array = []
	var catches := 0
	var counts := {}
	for i in 400000:
		now += 100
		var before := fs.state
		var got := fs.advance(now)
		if before == Fishing.State.CASTING and fs.state == Fishing.State.WAITING:
			waits.append(fs.deadline_ms - now)
		if got != "":
			catches += 1
			counts[got] = counts.get(got, 0) + 1
		if catches >= 300:
			break
	check(catches == 300, "跑出 300 次鱼获")
	check(waits.min() >= 20000 and waits.max() <= 60000, "咬钩等待在 20–60 秒 (%d..%d)" % [waits.min(), waits.max()])
	check(counts.get("crucian", 0) > counts.get("bass", 0) and counts.get("bass", 0) > counts.get("koi", 0),
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

func _count(events: Array, type: String) -> int:
	return events.filter(func(e): return e["type"] == type).size()

func test_game_focus(balance: Dictionary, fish: Array) -> void:
	print("game: focus（木箱结算）")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(3))
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
	check(not g.go_to_town(), "空鱼篓不能出发")
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
	trip = _run(g2, c2, 39)
	check(_count(trip, "boarded") == 1 and _count(trip, "back") == 1, "走回码头并返航")
	check(g2.journey.activity() == Journey.Activity.FISHING, "回到钓点")
	_run(g2, c2, 5)
	check(g2.fishing.is_active(), "自动继续钓鱼")
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
	check(g6.state.wallet_gold == 15 and _count(ev6, "sale") == 3 and _count(ev6, "back") == 1, "卖完自动返航")
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
	var k0 := 0; var k1 := 0
	for i in 5000:
		if base._roll_fish() == "koi": k0 += 1
		if baited._roll_fish() == "koi": k1 += 1
	check(k1 > k0 * 1.4, "满级鱼饵锦鲤明显变多 (%d → %d)" % [k0, k1])
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
