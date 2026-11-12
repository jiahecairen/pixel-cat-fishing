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

func test_game_focus(balance: Dictionary, fish: Array) -> void:
	print("game: focus")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(3))
	check(g.start_focus(), "开始专注")
	var caught := 0
	var done: Dictionary = {}
	for i in 25 * 60 * 4 + 8:
		clock.t += 250
		for e in g.tick():
			if e["type"] == "catch": caught += 1
			if e["type"] == "focus_done": done = e
	check(caught > 20, "25 分钟专注钓到不少鱼 (%d)" % caught)
	check(not done.is_empty(), "产生 focus_done 事件")
	check(done.get("gold", 0) > 0 and g.state.wallet_gold == done.get("gold", -1), "结算金币入账 (%d)" % g.state.wallet_gold)
	check(g.state.session_haul.is_empty(), "番茄渔获已清空")
	check(g.state.stats["total_pomodoros"] == 1 and g.state.stats["daily"].get("2026-01-01", 0) == 1, "统计 +1")
	check(g.pomodoro.is_break() and not g.fishing.is_active(), "休息时小猫不钓鱼")
	# 放弃：原价结算、不计数
	g.skip_break(); g.start_focus()
	for i in 600:
		clock.t += 250; g.tick()
	var expect := g.economy.value_of(g.state.session_haul)
	var before := g.state.wallet_gold
	check(g.abandon_focus() == expect and g.state.wallet_gold == before + expect, "放弃按原价结算")
	check(g.state.stats["total_pomodoros"] == 1, "放弃不计入番茄数")

func test_game_free_mode(balance: Dictionary, fish: Array) -> void:
	print("game: free mode")
	var clock := FakeClock.new()
	var g := Game.new(balance, fish, GameState.new(), clock, _rng(5))
	var full_events := 0
	for i in 4 * 3600 * 2:
		clock.t += 500
		for e in g.tick():
			if e["type"] == "basket_full": full_events += 1
	check(g.state.basket.size() == 10, "自由挂机鱼篓停在 10")
	check(not g.fishing.is_active() and full_events == 1, "满后停钓并只提示一次 (%d)" % full_events)
	check(g.sell_basket() > 0 and g.state.basket.is_empty(), "卖鱼清空鱼篓")
	clock.t += 500; g.tick()
	check(g.fishing.is_active(), "卖完后自动继续钓")

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
