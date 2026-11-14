extends RefCounted
## 矿山岛：过海过场、岛上（码头/饭店/工具店/矿洞口）、洞穴大厅（矿车）、矿井（主动挖掘、裂痕、光圈、梯子、天赋）。
## 逻辑在 core/mine.gd；这里只管画面和按键。
## 区域："" / "cross_out" / "isle" / "cave" / "ride_in" / "mine" / "ride_back" / "cross_back"。
const Pal := preload("res://presentation/palette.gd")
const MoneyC := preload("res://core/money.gd")

const CELL := 32
const TILE := {"dirt": 0, "stone": 1, "rock": 2, "deep": 3, "granite": 4, "back": 5, "ladder": 6, "gold": 7, "metal": 8, "stone_ore": 9, "chest": 10, "tnt": 15, "exit_mark": 16, "hole": 17, "floor": 18, "wall": 19, "walltop": 20, "crate": 21, "dirt1": 22, "dirt2": 23, "stone1": 24, "stone2": 25, "rock1": 26, "rock2": 27, "deep1": 28, "deep2": 29}
const CRACK0 := 11
const MINE_FRAMES := 30
const CROSS_MS := 4200
const RIDE_MS := 1500
const ISLE_W := 560.0
const SPOT := {"dock": 500.0, "rest": 380.0, "inn": 315.0, "shop": 250.0, "gate": 96.0}
const CAVE_W := 560.0
const CAVE := {"exit": 40.0, "cart": 250.0, "shaft1": 360.0, "rail2": 440.0, "shaft2": 500.0}
const STEP_S := 0.055
const SWING_MS := 440
const WALK_SPEED := 92.0

var m
var region: String = ""
var t0: int = 0
var isle_x: float = 470.0       # 岛上小猫贴图左边缘
var isle_flip: bool = true
var isle_moving: bool = false
var cave_x: float = 60.0
var cave_flip: bool = false
var cave_moving: bool = false
var face: int = 1               # 矿里小猫左右朝向（画图翻转用）
var face_v := Vector2i(0, 1)     # 矿里小猫面朝的方向（空格挖的就是这个方向的那一格）
var mine_moving := false
const MINE_WALK := 4.2           # 矿里走路速度（格/秒），] 加速会乘上去
var cart_pick: Dictionary = {}     # 每口井选中的起始层
var _leave_dbg := false
var _need_release := false      # 爆炸后要先松开方向键
var menu: String = ""           # "" / "shop" / "cook" / "cart" / "repair"
var menu_sel: int = 0
var ride_shaft: int = 1
var ride_floor: int = 1
var flashes: Array = []
var _step_cd: float = 0.0
var _swing_t: int = 0
var _shake_t: int = -10000
var _shake_amp: float = 0.0
var msg: String = ""
var msg_t: int = -100000
var _why_t: int = -10000
var debris: Array = []
var floats: Array = []
var _mcam := Vector2.ZERO

func _init(main) -> void:
	m = main

## 过场动画走了多久（加速时按倍数）。
func _el(t: int) -> float:
	return float(t - t0) * m.game.move_speed()

func active() -> bool:
	return region != ""

func say(s: String) -> void:
	msg = s
	msg_t = Time.get_ticks_msec()

func _warn(s: String) -> void:         # 提示别刷屏
	var t := Time.get_ticks_msec()
	if t - _why_t > 900:
		_why_t = t
		say(s)

## ---- 切换 ----
func go(r: String) -> void:
	region = r
	t0 = Time.get_ticks_msec()
	menu = ""
	var mn = m.game.mine
	if r != "":
		mn.ensure(m.game.now_ms())
	if r == "mine" and not mn.in_run():
		mn.begin_run(1, m.game.now_ms())
	match r:
		"isle", "cave", "mine":
			mn.m()["at"] = r
			if r == "mine":
				_mcam = Vector2.INF
		"":
			mn.m()["at"] = ""
	m.game.dirty = true

## 重启后回到原处：在矿里（这一局还在）回矿里，在大厅回大厅，其余回岛上。
func restore(at: String) -> void:
	var mn = m.game.mine
	mn.ensure(m.game.now_ms())
	if at == "mine" and mn.in_run():
		go("mine")
	elif at == "cave":
		go("cave")
		cave_x = CAVE["cart"] - 16.0
	else:
		go("isle")
		isle_x = SPOT["gate"] - 16.0

func leave() -> void:
	if region == "mine":
		m.game.mine.stop_dig(m.game.now_ms())
	region = ""                          # 不改 at：存档里还记着在矿里

## ---- 每帧 ----
func process(dt: float, dx: int, dy: int) -> void:
	var t := Time.get_ticks_msec()
	if region == "mine" and menu == "" and not _leave_dbg and OS.has_environment("CATFISH_LEAVE") and t > 1500:
		_leave_dbg = true                  # 调试：直接弹出"回地面？"确认
		_open("leave")
		menu_sel = 1
	match region:
		"cross_out":
			if _el(t) >= CROSS_MS:
				go("isle")
				isle_x = SPOT["dock"] - 16.0
				isle_flip = true
				if not m.game.state.islands.has("mine"):
					m.game.state.islands.append("mine")
				say("到了矿山岛！岛上住着鼹鼠")
		"cross_back":
			if _el(t) >= CROSS_MS:
				go("")
		"ride_in":
			if _el(t) >= RIDE_MS:
				var mn2 = m.game.mine
				if mn2.in_run():                  # 上次没结束的一局（中途离开过）：接着挖
					go("mine")
				elif mn2.begin_run(ride_shaft, m.game.now_ms(), ride_floor):
					go("mine")
				else:
					go("cave")
					say("矿车出了点问题，再试一次")
		"ride_back":
			if _el(t) >= RIDE_MS:
				go("cave")
				cave_x = CAVE["cart"] - 16.0
		"isle":
			if menu != "":
				return
			isle_moving = dx != 0
			if dx != 0:
				isle_flip = dx < 0
				isle_x = clampf(isle_x + dx * WALK_SPEED * m.game.move_speed() * dt, 20.0, ISLE_W - 40.0)
		"cave":
			if menu != "":
				return
			cave_moving = dx != 0
			if dx != 0:
				cave_flip = dx < 0
				cave_x = clampf(cave_x + dx * WALK_SPEED * m.game.move_speed() * dt, 20.0, CAVE_W - 40.0)
		"mine":
			_process_mine(dt, dx, dy)

func _process_mine(dt: float, dx: int, dy: int) -> void:
	var mn = m.game.mine
	var now: int = m.game.now_ms()
	for e in mn.update(now):
		_on_event(e)
	mine_moving = false
	if menu != "":
		mn.stop_dig(now)
		return
	# 朝向：最后按的方向；横竖同时按时优先横向
	if dx != 0:
		face_v = Vector2i(dx, 0)
		face = dx
	elif dy != 0:
		face_v = Vector2i(0, dy)
	# 按住空格（或 E / 回车）挖面前那一格；松手停下，进度留在石头上
	var hold: bool = m.get_window().has_focus() and not m.panel_open() and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER))
	hold = hold or OS.has_environment("CATFISH_HOLD")      # 调试：当作一直按着空格
	if hold and _diggable_ahead():
		_dig_ahead(now)                        # 按着方向键也能挖：面朝石头时空格优先，不走动
		return
	if mn.digging():
		mn.stop_dig(now)
	if dx != 0 or dy != 0:
		var v: Vector2 = Vector2(dx, dy).normalized() * MINE_WALK * m.game.move_speed() * minf(dt, 0.05)
		mine_moving = mn.walk(v.x, v.y)

## 面前（大致朝着、够得到）的那一块是能挖的石头：不要求对齐，也不是空地、岩壁、洞或木箱。
func _diggable_ahead() -> bool:
	var mn = m.game.mine
	var t: Vector2i = mn.target(face_v.x, face_v.y)
	var b: String = mn.block(t.x, t.y)
	return b != "" and b not in ["granite", "pit", "chest"]

## 面前够得到的是什么特殊物：""/"pit"/"chest"。
func _special_ahead() -> String:
	var mn = m.game.mine
	var t: Vector2i = mn.target(face_v.x, face_v.y)
	var b: String = mn.block(t.x, t.y)
	return b if b in ["pit", "chest"] else ""

func _dig_ahead(now: int) -> void:
	var mn = m.game.mine
	var why: String = mn.start_dig(face_v.x, face_v.y, now)
	match why:
		"":
			var t := Time.get_ticks_msec()
			if t - _swing_t >= SWING_MS:
				_swing_t = t
				m.play("click")
				var tg: Vector2i = mn.dig_target()
				_chips(tg.x, tg.y, 2, 55.0)
				_shake(0.8, 90)
		"notool":
			_warn("没有镐子，去找雾灯岛的老柯要一把")
		"tool":
			_warn("太硬了，要更好的镐子（工具店升级）")
		"tired":
			_warn("体力用完了：矿里恢复不了，回地面去旅店或家里休息")

func _open_crate() -> void:
	var mn = m.game.mine
	var r: Dictionary = mn.open_chest(face_v.x, face_v.y)
	if not bool(r["ok"]):
		if str(r.get("why", "")) == "full":
			_warn("物品栏放不下，先腾点地方")
			m.play("deny")
		return
	_chips(int(r["x"]), int(r["y"]), 14, 80.0)
	_shake(1.5, 140)
	m.play("rare")
	if int(r["gold"]) > 0:
		_float(int(r["x"]), int(r["y"]), "+%s" % _price(int(r["gold"])), Pal.L_Y)
	else:
		var nm: String = str(m.game.inventory.by_id.get(str(r["item"]), {}).get("name", r["item"]))
		_float(int(r["x"]), int(r["y"]), "%s ×%d（进物品栏）" % [nm, int(r["n"])], Pal.L_W)
	m.game.dirty = true

func _descend() -> void:
	var mn = m.game.mine
	if mn.descend(face_v.x, face_v.y):
		_step_cd = 0.3
		m.play("done")
		var f: int = mn.floor_n()
		say("第 %d 层" % f + ("  存档点：下次矿车能直达这里" if mn.has_elevator() else ""))
		_mcam = Vector2.INF
		m.game.dirty = true

func _shake(amp: float, ms: int) -> void:
	_shake_t = Time.get_ticks_msec() + ms
	_shake_amp = maxf(_shake_amp * 0.5, amp)

func _chips(x: int, y: int, n: int, speed: float) -> void:
	var col := _block_color(str(m.game.mine.layer(y).get("block", "dirt")))
	var t := Time.get_ticks_msec()
	for k in n:
		debris.append({"p": Vector2(x * CELL + 6 + randf() * 20.0, y * CELL + 6 + randf() * 20.0), "v": Vector2(randf_range(-speed, speed), randf_range(-speed * 1.6, -speed * 0.4)), "t": t, "c": col})

func _float(x: int, y: int, s: String, c: Color) -> void:
	floats.append({"p": Vector2(x * CELL + 16, y * CELL - 4), "s": s, "c": c, "t": Time.get_ticks_msec()})

func _on_event(e: Dictionary) -> void:
	if e["type"] == "boom":
		_boom_fx(int(e["x"]), int(e["y"]))
		return
	if e["type"] == "tired":
		_warn("体力用完了：矿里恢复不了，回地面去旅店或家里休息")
		m.play("deny")
		return
	if e["type"] != "dug":
		return
	var x: int = e["x"]
	var y: int = e["y"]
	_chips(x, y, 12, 90.0)
	_shake(2.0, 160)
	var o := str(e["ore"])
	if bool(e["lost"]):
		_float(x, y, "背包满了", Pal.L_R)
		_warn("背包满了，带不走：回地面去典当行卖掉或扔掉")
	if str(e["item"]) != "" and not bool(e["lost"]):
		var nm: String = str(m.game.inventory.by_id.get(e["item"], {}).get("name", e["item"]))
		_float(x, y - 1, "%s +%d" % [nm, int(e["n"])], Pal.L_W)
	if o == "gold":
		m.play("coin")
	elif o == "metal" or o == "stone":
		m.play("buy")
	else:
		m.play("catch")
	m.game.dirty = true

func _boom_fx(x: int, y: int) -> void:
	_shake(5.0, 380)
	m.play("deny")
	flashes.append({"p": Vector2(x * CELL + 16, y * CELL + 16), "t": Time.get_ticks_msec()})
	_chips(x, y, 22, 140.0)

func _block_color(b: String) -> Color:
	return {"dirt": Pal.U_O, "stone": Pal.L_A, "rock": Pal.U_A, "deep": Pal.U_S}.get(b, Pal.L_A)

func _price(c: int) -> String:
	var out := ""
	for pr in MoneyC.parts(c):
		out += "%d%s" % [int(pr[1]), {"gold": "金", "silver": "银", "copper": "铜"}[str(pr[0])]]
	return out

## ---- 按键 ----
func key(code: int) -> bool:
	if not active():
		return false
	var act := code in [KEY_SPACE, KEY_ENTER, KEY_E]
	var mn = m.game.mine
	if menu != "":
		_menu_key(code, act)
		return true
	if region == "mine":
		if code in [KEY_B, KEY_X, KEY_F]:
			_bomb()
			return true
		if act:
			var sp := _special_ahead()
			if _diggable_ahead():
				pass                              # 面前有石头：按住空格挖（在每帧里处理）
			elif sp == "pit":
				_open("descend")                  # 默认选"下去"
			elif sp == "chest":
				_open_crate()
			elif mn.on_entrance():
				_open("leave")
				menu_sel = 1                      # 默认停在"再挖一会儿"，免得手滑
			else:
				say("面朝石头按住空格挖；往下的黑洞要先把周围的石头挖开")
			return true
		return code in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]
	if region == "isle" and act:
		_interact_isle()
		return true
	if region == "cave" and act:
		_interact_cave()
		return true
	return region.begins_with("cross") or region.begins_with("ride")

func _bomb() -> void:
	var mn = m.game.mine
	match mn.place_bomb(m.game.now_ms()):
		"":
			m.play("click")
			m.game.dirty = true
		"empty":
			_warn("没有炸弹了，去工具店买")
		"busy":
			_warn("这里已经放着一颗了")

## 站在入口台阶上：回上一层；第 1 层和有电梯的层直接回大厅，背包里的东西换成钱和材料。
func _ascend() -> void:
	var mn = m.game.mine
	var r: String = mn.ascend()
	if r == "up":
		_mcam = Vector2.INF
		say("回到第 %d 层" % mn.floor_n())
		m.play("click")
	elif r == "hall":
		mn.stop_dig(m.game.now_ms())
		var res: Dictionary = mn.end_run()
		var parts: Array = []
		if int(res["coins"]) > 0:
			parts.append("+%s" % _price(int(res["coins"])))
		if int(res["stone"]) > 0:
			parts.append("石头×%d" % int(res["stone"]))
		if int(res["metal"]) > 0:
			parts.append("金属×%d" % int(res["metal"]))
		if int(res["lost"]) > 0:
			parts.append("物品栏满了丢了 %d 个" % int(res["lost"]))
		region = "ride_back"
		menu = ""
		t0 = Time.get_ticks_msec()
		mn.m()["at"] = "cave"
		m.play("coin" if int(res["coins"]) > 0 else "click")
		m.game.dirty = true
		say("回到地面：" + ("  ".join(parts) if not parts.is_empty() else "空手而归"))

func _menu_rows() -> int:
	match menu:
		"shop": return 3
		"cook": return m.game.mine.dishes().size()
		"cart": return m.game.mine.shaft_count()
		"leave": return 2
		"descend": return 2
		"inn": return mine_inn_rows()
	return 1

func _menu_key(code: int, act: bool) -> void:
	if code == KEY_ESCAPE:
		menu = ""
	elif menu == "cart" and code in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
		_cart_page(menu_sel + 1, -1 if code in [KEY_LEFT, KEY_A] else 1)
	elif code in [KEY_UP, KEY_W]:
		menu_sel = posmod(menu_sel - 1, _menu_rows())
	elif code in [KEY_DOWN, KEY_S]:
		menu_sel = posmod(menu_sel + 1, _menu_rows())
	elif act:
		match menu:
			"shop": _buy(menu_sel)
			"cook": _cook(menu_sel)
			"cart": _cart(menu_sel)
			"repair": _repair()
			"descend":
				var go_down := menu_sel == 0
				menu = ""
				if go_down:
					_descend()
			"inn":
				_inn_pick(menu_sel)
			"leave":
				var go_up := menu_sel == 0
				menu = ""
				if go_up:
					_ascend()

func _open(name: String) -> void:
	menu = name
	menu_sel = 0
	m.play("click")

func _spot() -> String:
	var cx := isle_x + 16.0
	for k in SPOT:
		if absf(cx - SPOT[k]) <= 20.0:
			return k
	return ""

func _cave_spot() -> String:
	var cx := cave_x + 16.0
	for k in ["exit", "cart", "rail2"]:
		if absf(cx - CAVE[k]) <= 24.0:
			return k
	return ""

func _interact_isle() -> void:
	match _spot():
		"dock":
			go("cross_back")
			m.play("click")
		"gate":
			go("cave")
			cave_x = CAVE["exit"] + 10.0
			cave_flip = false
			m.play("click")
		"shop":
			_open("shop")
		"rest":
			_open("cook")
		"inn":
			_open("inn")

func _interact_cave() -> void:
	match _cave_spot():
		"exit":
			go("isle")
			isle_x = SPOT["gate"] - 16.0
			isle_flip = false
			m.play("click")
		"cart":
			_open("cart")
		"rail2":
			_open("repair")

## 每口井各记一个"准备从第几层开始"，默认是这口井到过的最深存档层。
func _cart_floor(id: int) -> int:
	var fl: Array = m.game.mine.start_floors(id)
	if not cart_pick.has(id):
		cart_pick[id] = fl.size() - 1
	cart_pick[id] = clampi(int(cart_pick[id]), 0, fl.size() - 1)
	return int(fl[int(cart_pick[id])])

func _cart_page(id: int, d: int) -> void:
	var mn = m.game.mine
	if not mn.shaft_ok(id) or mn.in_run():
		m.play("deny")
		return
	var fl: Array = mn.start_floors(id)
	if fl.size() <= 1:
		m.play("deny")
		return
	cart_pick[id] = posmod(int(cart_pick.get(id, fl.size() - 1)) + d, fl.size())
	m.play("click")

func _cart(i: int) -> void:
	var mn = m.game.mine
	var id := i + 1
	match mn.shaft_status(id):
		"ok":
			if mn.in_run() and mn.shaft_id() != id:
				say("上一局还没结束，先回到那口井")
				m.play("deny")
				return
			ride_shaft = id
			ride_floor = _cart_floor(id)
			menu = ""
			region = "ride_in"
			t0 = Time.get_ticks_msec()
			m.play("click")
		"broken":
			menu = "repair"
			menu_sel = 0
		_:
			say("%d 号井还没有开放" % id)
			m.play("deny")

func _repair() -> void:
	var mn = m.game.mine
	var why: String = mn.repair_shaft()
	match why:
		"":
			m.play("done")
			m.game.dirty = true
			say("2 号井的铁路修好了！")
			menu = ""
		"done":
			menu = ""
		"crew":
			say("工人不够：去雾灯岛酒馆雇人")
			m.play("deny")
		_:
			say("材料不够，先去矿里挖金属和石头")
			m.play("deny")

func _buy(i: int) -> void:
	var mn = m.game.mine
	var why: String = ""
	match i:
		0: why = mn.buy_level("pick")
		1: why = mn.buy_level("lamp")
		2: why = mn.buy_bomb()
	match why:
		"":
			m.play("buy")
			m.game.dirty = true
			say(["买到了：%s" % str(mn.pick_def().get("name", "")), "买到了：%s" % str(mn.lamp_def().get("name", "")), "买到一颗炸弹（有 %d 颗）" % mn.bombs()][i])
		"gold": say("钱不够")
		"mat": say("材料不够（石头和金属在矿里挖）")
		"nopick": say("你还没有镐子，去找雾灯岛的老柯")
		"max": say("已经是最好的了")
		"full": say("炸弹带不下了（最多 %d 颗）" % mn.bomb_carry())
	if why != "":
		m.play("deny")

func mine_inn_rows() -> int:
	return m.game.mine.inn_rooms().size()

func _inn_pick(i: int) -> void:
	var mn = m.game.mine
	var rooms: Array = mn.inn_rooms()
	if mn.resting() or i >= rooms.size():
		return
	var why: String = mn.rest_start(str(rooms[i]["id"]), m.game.now_ms())
	match why:
		"":
			m.play("break_end")
			m.game.dirty = true
			say("住进了%s，好好睡一觉" % str(rooms[i]["name"]))
		"gold":
			say("钱不够")
		"full":
			say("体力已经满了，住这间没有意义")
		_:
			say("现在不能住")
	if why != "":
		m.play("deny")

func _draw_inn(view: Vector2) -> void:
	var mn = m.game.mine
	var now: int = m.game.now_ms()
	var rooms: Array = mn.inn_rooms()
	var sta := "体力 %d/%d" % [mn.stamina(), mn.stamina_max()]
	if mn.resting():
		var k: float = mn.rest_progress(now)
		var r := _panel(view, "旅店：休息中……", sta, [], "Esc离开（睡眠会继续）", 70.0)
		m.draw_rect(Rect2(r.position + Vector2(10, 30), Vector2(260, 10)), Pal.U_K)
		m.draw_rect(Rect2(r.position + Vector2(11, 31), Vector2(258.0 * k, 8)), Pal.L_G)
		m.dyn_text("Zzz…", r.position + Vector2(10, 44), Pal.L_C)
		return
	var rows: Array = []
	for rm in rooms:
		var to := int(round(float(mn.stamina_max()) * float(rm["mult"])))
		var mins := int(rm["minutes"])
		var dur := "测试 %d 秒" % int(round(float(mn.rest_cfg().get("test_ms", 0)) / 1000.0)) if int(mn.rest_cfg().get("test_ms", 0)) > 0 else "%d 分钟" % mins
		rows.append(["%s  %s  → 体力 %d" % [str(rm["name"]), _price(int(rm["price"])), to], "%s（%s）" % [str(rm["desc"]), dur]])
	_panel(view, "旅店：选一间房", sta + "   " + _wallet_text(), rows, "↑↓选择  空格入住  Esc离开", 20.0 + rows.size() * 28.0 + 20.0)

func _cook(i: int) -> void:
	var mn = m.game.mine
	var ds: Array = mn.dishes()
	if i >= ds.size():
		return
	var why: String = mn.cook(str(ds[i]["id"]), m.game.economy)
	match why:
		"":
			m.play("done")
			m.game.dirty = true
			say("做好了：%s，下一次下井生效" % str(ds[i]["name"]))
		"have": say("已经有一道菜等着你了，先下井吧")
		"gold": say("钱不够")
		"fish": say("鱼不够（稀有的鱼不会拿来做菜）")
	if why != "":
		m.play("deny")

## ---- 提示（左上角） ----
func hint() -> String:
	if menu != "":
		return ""
	match region:
		"isle":
			match _spot():
				"inn": return "空格键进旅店休息"
				"dock": return "空格键坐船回雾灯岛"
				"gate": return "空格键进矿洞"
				"shop": return "空格键看工具店"
				"rest": return "空格键让厨师做菜"
			return "方向键走动"
		"cave":
			match _cave_spot():
				"exit": return "空格键回岛上"
				"cart": return "空格键坐矿车"
				"rail2": return "空格键看 2 号井"
			return "方向键走动"
		"mine":
			var mh = m.game.mine
			if _special_ahead() == "pit":
				return "空格键：下一层"
			if _special_ahead() == "chest":
				return "空格键：打开木箱"
			if mh.on_entrance():
				return "空格键回地面（背包换钱）"
			return "第 %d 层  方向键走  空格挖  B 放炸弹（有 %d 颗）" % [mh.floor_n(), mh.bombs()]
	return ""

## ================= 绘制 =================
func _draw_cross(view: Vector2, t: int) -> void:
	var k := clampf(_el(t) / float(CROSS_MS), 0.0, 1.0)
	var cam := Vector2(0, 180.0 - view.y)
	m.draw_set_transform(-cam)
	m.world._draw_sky(cam, view, t)
	m.draw_set_transform(Vector2.ZERO)
	var sea_y := view.y - 60.0
	m.draw_rect(Rect2(0, sea_y, view.x, view.y - sea_y), Pal.U_B)
	# 大浪：比平时高一截的浪头一排排滚过去
	for row in 4:
		var amp := 7.0 - row
		var y0 := sea_y + row * 12.0
		for x in range(0, int(view.x) + 8, 4):
			var h := amp * (0.5 + 0.5 * sin(float(x) / 18.0 + float(t) / 260.0 + row * 1.7))
			m.draw_rect(Rect2(x, y0 - h, 4, h + 3), Pal.L_B if row % 2 == 0 else Pal.U_B)
			if h > amp * 0.85:
				m.draw_rect(Rect2(x, y0 - h, 4, 2), Pal.U_W)
	var dir := 1.0 if region == "cross_back" else -1.0
	var bx := lerpf(view.x * 0.75, view.x * 0.25, k) if dir < 0 else lerpf(view.x * 0.25, view.x * 0.75, k)
	var bob := roundf(sin(float(t) / 180.0) * 3.0)
	var by := sea_y - 18.0 + bob
	var boat_tex: String = ["boat", "boat_1", "boat_2", "boat_3"][clampi(m.game.state.boat_level, 0, 3)]
	if dir < 0:
		m.tex_frame_flipped(boat_tex, Vector2(bx - 40, by), 0, 1)
		m.draw_cat(Vector2(bx - 18, by - 22), 0, true)
	else:
		m.draw_texture(m.tex[boat_tex], Vector2(bx - 40, by))
		m.draw_cat(Vector2(bx - 18, by - 22), 0, false)
	var title := "驶向矿山岛……" if dir < 0 else "回雾灯岛……"
	m.dyn_text(title, Vector2(view.x / 2.0 - m.dyn_text_width(title) / 2.0, 40), Pal.L_W)

func _isle_cam(view: Vector2) -> float:
	return clampf(isle_x + 16.0 - view.x / 2.0, 0.0, ISLE_W - view.x)

func _draw_isle(view: Vector2, t: int) -> void:
	var cx := roundf(_isle_cam(view))
	var cam := Vector2(cx, 180.0 - view.y)
	m.draw_set_transform(-cam)
	m.world._draw_sky(cam, view, t)
	m.draw_set_transform(Vector2(-cx, 0))
	var fy := view.y - 40.0
	# 远山（视差），山腰的洞口前有鼹鼠挥镐
	var par := cx * 0.5
	for i in 5:
		var mx := float(i) * 160.0 + par - 40.0
		m.draw_texture(m.tex["mine_mtn"], Vector2(mx, fy - 58))
		var hole: Array = [[40, 34], [92, 28], [128, 38]][i % 3]
		m.tex_frame("mole_miner", Vector2(mx + hole[0] + 6, fy - 58 + hole[1] - 16), ((t + i * 250) / 420) % 2, 2)
	# 地面和海
	m.draw_rect(Rect2(0, fy, ISLE_W - 60, view.y - fy), Pal.L_N)
	m.draw_rect(Rect2(0, fy, ISLE_W - 60, 3), Pal.L_G)
	m.draw_rect(Rect2(0, fy + 3, ISLE_W - 60, 1), Pal.U_G)
	m.draw_rect(Rect2(ISLE_W - 60, fy + 6, 120, view.y - fy), Pal.L_B)
	for x in range(int(ISLE_W - 60), int(ISLE_W + 60), 6):
		m.draw_rect(Rect2(x, fy + 6 + roundf(sin(float(x) / 9.0 + float(t) / 400.0)), 4, 1), Pal.U_W)
	# 码头和停着的船
	m.draw_rect(Rect2(ISLE_W - 100, fy - 2, 80, 4), Pal.L_O)
	m.draw_rect(Rect2(ISLE_W - 100, fy + 2, 80, 1), Pal.U_O)
	for px in [ISLE_W - 96, ISLE_W - 66, ISLE_W - 36]:
		m.draw_rect(Rect2(px, fy + 2, 3, 12), Pal.U_O)
	var boat_tex: String = ["boat", "boat_1", "boat_2", "boat_3"][clampi(m.game.state.boat_level, 0, 3)]
	m.draw_texture(m.tex[boat_tex], Vector2(ISLE_W - 40, fy - 10 + roundf(sin(float(t) / 500.0))))
	# 建筑：矿洞口、工具店、饭店
	m.draw_texture(m.tex["mine_gate"], Vector2(SPOT["gate"] - 28, fy - 46))
	m.draw_texture(m.tex["mine_shop"], Vector2(SPOT["shop"] - 28, fy - 46))
	m.draw_texture(m.tex["mine_rest"], Vector2(SPOT["rest"] - 28, fy - 46))
	m.draw_texture(m.tex["mine_inn"], Vector2(SPOT["inn"] - 28, fy - 46))
	if (t / 300) % 2 == 0:                                         # 饭店烟囱冒烟
		m.draw_rect(Rect2(SPOT["rest"] + 14, fy - 52 - (t / 300) % 6, 3, 3), Color(Pal.U_W, 0.7))
	m.tex_frame("mole_0", Vector2(SPOT["shop"] + 30, fy - 22), (t / 900) % 2, 2)
	m.tex_frame("mole_1", Vector2(SPOT["rest"] + 30, fy - 22), (t / 1100) % 2, 2)
	for sx in [SPOT["shop"], SPOT["inn"], SPOT["rest"], SPOT["gate"]]:
		var name: String = {SPOT["shop"]: "工具店", SPOT["inn"]: "旅店", SPOT["rest"]: "饭店", SPOT["gate"]: "矿洞"}[sx]
		var w: float = m.dyn_text_width(name) + 6.0
		m.draw_rect(Rect2(sx - w / 2.0 - 1, fy - 62, w + 2, 14), Pal.U_K)
		m.draw_rect(Rect2(sx - w / 2.0, fy - 61, w, 12), Pal.L_N)
		m.dyn_text(name, Vector2(sx - w / 2.0 + 3, fy - 61), Pal.U_K)
	# 小猫
	m.draw_cat(Vector2(roundf(isle_x), fy - 32), 4 if isle_moving else 0, isle_flip)
	m.draw_set_transform(Vector2.ZERO)
	_draw_menu(view)


func draw(view: Vector2, t: int) -> void:
	match region:
		"cross_out", "cross_back":
			_draw_cross(view, t)
		"isle":
			_draw_isle(view, t)
		"cave", "ride_in", "ride_back":
			_draw_cave(view, t)
		"mine":
			_draw_mine(view, t)
	_draw_overlay(view, t)

## 岩壁（像星露谷的洞穴外围）：下面挨着地面的画崖壁正面；其它挨着地面的画岩壁顶面，朝地面那一边描亮边；再往外全黑。
func _draw_wall(mn, x: int, y: int, pos: Vector2) -> void:
	if mn.is_floor(x, y + 1):
		m.tex_frame("mine_tiles", pos, TILE["wall"], MINE_FRAMES)
		return
	var near := false
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if mn.is_floor(x + ox, y + oy) or (oy == 0 and ox == 0 and false):
				near = true
	if not near and not mn.is_floor(x, y + 2):
		return
	m.tex_frame("mine_tiles", pos, TILE["walltop"], MINE_FRAMES)
	var rim := Color(Pal.U_O, 1.0)
	if mn.is_floor(x - 1, y):
		m.draw_rect(Rect2(pos, Vector2(3, CELL)), rim)
	if mn.is_floor(x + 1, y):
		m.draw_rect(Rect2(pos + Vector2(CELL - 3, 0), Vector2(3, CELL)), rim)
	if mn.is_floor(x, y - 1):
		m.draw_rect(Rect2(pos, Vector2(CELL, 3)), rim)

## 迷你窗里的挖矿动画：小猫对着岩壁一下一下挥镐，碎石飞溅、矿石闪光。游戏暂停，放大窗口接着挖。
func draw_mini(view: Vector2, t: int) -> void:
	var mn = m.game.mine
	var r := Rect2(3, 31, view.x - 6, 61)
	m.draw_rect(r.grow(1), Pal.U_K)
	m.draw_rect(r, Color("#241c2e"))
	var col: Color = _block_color(str(mn.layer(mn.floor_n()).get("block", "dirt")))
	# 右边的岩壁：一格一格的块，被敲的那块跟着挥镐抖
	var swing := (t / 260) % 2
	for ix in 3:
		for iy in 4:
			var bx := r.position.x + 74.0 + ix * 16.0
			var by := r.position.y + 2.0 + iy * 14.0
			var hit := ix == 0 and iy == 2
			var off := Vector2(1 if (hit and swing == 1) else 0, 0)
			var shade := Color(col, 1.0).darkened(0.12 * float((ix + iy) % 3))
			m.draw_rect(Rect2(Vector2(bx, by) + off, Vector2(15, 13)), shade)
			m.draw_rect(Rect2(Vector2(bx, by + 12) + off, Vector2(15, 1)), shade.darkened(0.35))
			if (ix * 5 + iy * 3) % 7 == 2 and (t / 400 + ix + iy) % 3 != 0:
				m.draw_rect(Rect2(Vector2(bx + 6, by + 5) + off, Vector2(3, 3)), Pal.L_Y)
	# 小猫 + 镐
	var cp := Vector2(r.position.x + 36.0, r.position.y + 22.0)
	m.draw_cat(cp, 0, false)
	var hand := cp + Vector2(28, 18)
	var tip := hand + (Vector2(13, -11) if swing == 0 else Vector2(11, 4))
	m.draw_line(hand, tip, Pal.U_O, 2.0)
	m.draw_rect(Rect2(tip + Vector2(-2, -3), Vector2(4, 6)), Pal.L_A)
	# 碎石
	for k in 6:
		var ph := fmod(float(t) / 520.0 + float(k) * 0.17, 1.0)
		var q := Vector2(r.position.x + 74.0 - ph * 14.0 + float(k % 3) * 2.0, r.position.y + 38.0 - sin(ph * PI) * 12.0 + ph * ph * 26.0)
		if ph < 0.9:
			m.draw_rect(Rect2(q.round(), Vector2(2, 2)), col.lightened(0.15))
	var line := "第 %d 层  体力 %d/%d" % [mn.floor_n(), mn.stamina(), mn.stamina_max()]
	m.dyn_text(line, Vector2(r.position.x + 4, r.end.y - 12), Pal.L_W)

## ---- 菜单（工具店 / 饭店 / 矿车 / 2 号井） ----
func _panel(view: Vector2, title: String, right: String, rows: Array, footer: String, h: float, compact := false) -> Rect2:
	var r := Rect2(view.x / 2.0 - 140, 28 if compact else 30, 280, h)
	var rh := 22.0 if compact else 28.0
	var top := 17.0 if compact else 20.0
	m.draw_rect(r.grow(1), Pal.U_K)
	m.draw_rect(r, Color("#2b2137"))
	m.dyn_text(title, r.position + Vector2(8, 3 if compact else 4), Pal.L_Y)
	if right != "":
		m.dyn_text(right, Vector2(r.end.x - 8 - m.dyn_text_width(right), r.position.y + 3), Pal.L_C)
	for i in rows.size():
		var rr := Rect2(r.position.x + 6, r.position.y + top + i * rh, r.size.x - 12, rh - 3)
		m.draw_rect(rr, Color("#3d3450") if i != menu_sel else Color("#5a4a6e"))
		if i == menu_sel:
			m.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), Pal.L_Y)
		var dim: bool = rows[i].size() > 2 and bool(rows[i][2])
		if compact:
			m.dyn_text(str(rows[i][0]), rr.position + Vector2(6, 4), Pal.L_A if dim else Pal.L_W)
			var rt := str(rows[i][1])
			m.dyn_text(rt, Vector2(rr.end.x - 6 - m.dyn_text_width(rt), rr.position.y + 4), Pal.L_A if dim else Pal.L_Y)
		else:
			m.dyn_text(str(rows[i][0]), rr.position + Vector2(6, 1), Pal.L_W)
			m.dyn_text(str(rows[i][1]), rr.position + Vector2(6, 12), Pal.L_A)
	m.dyn_text(footer, Vector2(r.position.x + 8, r.end.y - 13), Pal.L_A)
	return r

func _wallet_text() -> String:
	return _price(m.game.state.wallet_gold)

func _cost_text(c: Dictionary) -> String:
	if c.is_empty():
		return ""
	var parts: Array = []
	if int(c["gold"]) > 0:
		parts.append(_price(int(c["gold"])))
	for id in c["items"]:
		var nm: String = str(m.game.inventory.by_id.get(id, {}).get("name", id))
		parts.append("%s×%d（有 %d）" % [nm, int(c["items"][id]), m.game.inventory.count(m.game.state, str(id))])
	return " + ".join(parts)

func _draw_menu(view: Vector2) -> void:
	if menu == "":
		return
	var mn = m.game.mine
	match menu:
		"shop":
			var rows: Array = []
			var pc: Dictionary = mn.next_cost("pick")
			var pk := "镐子：%s" % str(mn.pick_def().get("name", ""))
			if mn.pick() < 1:
				rows.append([pk, "第一把镐子由雾灯岛的老柯送你"])
			else:
				rows.append([pk, ("升级 %s：%s" % [str(mn.pick_def(mn.pick() + 1).get("name", "")), _cost_text(pc)]) if not pc.is_empty() else "已经最好"])
			var lc: Dictionary = mn.next_cost("lamp")
			rows.append(["灯：%s（光圈 %.1f 格）" % [str(mn.lamp_def().get("name", "")), mn.lamp_def().get("radius", 1.6)], ("升级 %s：%s" % [str(mn.lamp_def(mn.lamp() + 1).get("name", "")), _cost_text(lc)]) if not lc.is_empty() else "已经最好"])
			rows.append(["炸弹（有 %d/%d 颗）" % [mn.bombs(), mn.bomb_carry()], "%s 一颗，一次炸一片" % _price(mn.bomb_price())])
			_panel(view, "鼹鼠工具店", _wallet_text(), rows, "↑↓选择  空格买  Esc离开", 20.0 + rows.size() * 28.0 + 20.0)
		"cook":
			var rows2: Array = []
			for d in mn.dishes():
				rows2.append(["%s   鱼×%d  %s" % [str(d["name"]), int(d["fish"]), _price(int(d["price"]))], str(d["desc"])])
			var waiting: String = str(mn.dish_by_id(str(mn.m().get("dish", ""))).get("name", ""))
			var foot := ("已备好：%s" % waiting) if waiting != "" else ("鱼篓里有 %d 条鱼" % m.game.state.basket.size())
			_panel(view, "鼹鼠饭店  下一次下井生效", _wallet_text(), rows2, foot + "   空格点菜  Esc离开", 20.0 + rows2.size() * 28.0 + 20.0)
		"cart":
			var crow: Array = []
			for id in range(1, mn.shaft_count() + 1):
				var st: String = mn.shaft_status(id)
				if st == "ok":
					if mn.in_run() and mn.shaft_id() == id:
						crow.append(["%d 号井" % id, "接着上一局：第 %d 层" % mn.floor_n()])
					elif mn.in_run():
						crow.append(["%d 号井" % id, "先结束上一局", true])
					else:
						var fl: Array = mn.start_floors(id)
						var f := _cart_floor(id)
						crow.append(["%d 号井" % id, ("◀  第 %d 层  ▶" % f) if fl.size() > 1 else "第 %d 层" % f])
				elif st == "broken":
					crow.append(["%d 号井" % id, "铁路坏了（空格看看）"])
				else:
					crow.append(["%d 号井" % id, "还没开放", true])
			_panel(view, "矿车", "", crow, "↑↓选井  ←→换层  空格出发  Esc离开", 17.0 + crow.size() * 22.0 + 17.0, true)
		"repair":
			var need: Dictionary = mn.cfg().get("repair2", {})
			var inv = m.game.inventory
			var st2 = m.game.state
			var r := _panel(view, "2 号井：铁路塌了", "", [], "空格修理  Esc关闭", 112.0)
			var lines: Array = [
				"修好它需要：",
				"金属 ×%d（有 %d）   石头 ×%d（有 %d）" % [int(need.get("metal", 0)), inv.count(st2, "metal"), int(need.get("stone", 0)), inv.count(st2, "stone")],
				"工人 ×%d（已雇 %d）  工人在雾灯岛的酒馆雇" % [int(need.get("crew", 0)), mn.crew()]]
			for i in lines.size():
				m.dyn_text(str(lines[i]), r.position + Vector2(10, 22 + i * 14), Pal.L_W if i != 1 else Pal.L_Y)
		"descend":
			_panel(view, "下到第 %d 层？" % (mn.floor_n() + 1), "", [["下去", "沿着梯子爬进黑洞，更深一层"], ["先不下去", "继续待在第 %d 层" % mn.floor_n()]], "↑↓选择  空格确认  Esc取消", 20.0 + 2 * 28.0 + 20.0)
		"inn":
			_draw_inn(view)
		"leave":
			_panel(view, "回地面？", "", [["回地面", "这一局结束，挖到的东西都在物品栏里"], ["再挖一会儿", "继续待在第 %d 层" % mn.floor_n()]], "↑↓选择  空格确认  Esc取消", 20.0 + 2 * 28.0 + 20.0)

## ---- 洞穴大厅 ----
func _cart_world_x(t: int) -> float:
	var k := clampf(_el(t) / float(RIDE_MS), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	match region:
		"ride_in": return lerpf(CAVE["cart"], CAVE["shaft1"] - 26.0, k)
		"ride_back": return lerpf(CAVE["shaft1"] - 26.0, CAVE["cart"], k)
	return CAVE["cart"]

func _draw_cave(view: Vector2, t: int) -> void:
	var riding := region != "cave"
	var cart_x := _cart_world_x(t)
	var focus := cart_x if riding else cave_x + 16.0
	var cx := roundf(clampf(focus - view.x / 2.0, 0.0, CAVE_W - view.x))
	var fy := view.y - 40.0
	m.draw_rect(Rect2(Vector2.ZERO, view), Color("#1d1626"))
	m.draw_set_transform(Vector2(-cx, 0))
	# 岩壁：深浅不一的石块
	for i in 70:
		var hx := absi(hash([i, 7])) % int(CAVE_W)
		var hy := absi(hash([i, 11])) % int(fy - 20.0)
		m.draw_rect(Rect2(hx, hy, 14 + hx % 18, 6 + hy % 8), Color("#2b2137") if i % 2 == 0 else Color("#33283f"))
	# 钟乳石
	for i in 18:
		var sx := float(i) * 34.0 + float(absi(hash([i, 3])) % 20)
		var sh := 8.0 + float(absi(hash([i, 5])) % 16)
		for k in int(sh / 3.0):
			m.draw_rect(Rect2(sx + k, k * 3, 12 - 2 * k, 3), Pal.U_A)
	# 出口的天光
	m.draw_rect(Rect2(0, fy - 70, 34, 70), Pal.L_C)
	m.draw_rect(Rect2(34, fy - 70, 6, 70), Color(Pal.L_C, 0.5))
	m.draw_rect(Rect2(40, fy - 70, 8, 70), Color(Pal.L_C, 0.2))
	m.draw_rect(Rect2(0, fy - 70, 34, 6), Pal.L_W)
	# 吊灯和光晕
	for lx in [130.0, 300.0, 440.0]:
		m.draw_rect(Rect2(lx, 0, 1, fy - 120), Pal.U_K)
		m.draw_rect(Rect2(lx - 3, fy - 120, 7, 7), Pal.L_Y)
		m.draw_rect(Rect2(lx - 2, fy - 119, 5, 2), Pal.L_W)
		for ring in 4:
			m.draw_circle(Vector2(lx, fy - 116), 70.0 - ring * 16.0, Color(1.0, 0.85, 0.45, 0.05 + ring * 0.02))
	# 地面
	m.draw_rect(Rect2(0, fy, CAVE_W + 20, view.y - fy), Pal.U_A)
	m.draw_rect(Rect2(0, fy, CAVE_W + 20, 3), Pal.L_A)
	m.draw_rect(Rect2(0, fy + 3, CAVE_W + 20, 1), Pal.U_K)
	# 铁轨：1 号井这一段是好的，2 号井前面塌了一截
	for seg in [[170.0, CAVE["shaft1"] + 20.0], [CAVE["shaft1"] + 28.0, 404.0], [446.0, CAVE["shaft2"] + 22.0]]:
		var a: float = seg[0]
		var b: float = seg[1]
		for x in range(int(a), int(b), 8):
			m.draw_rect(Rect2(x, fy + 4, 5, 3), Pal.U_O)
		m.draw_rect(Rect2(a, fy + 3, b - a, 1), Pal.L_A)
		m.draw_rect(Rect2(a, fy + 6, b - a, 1), Pal.U_K)
	for k in 6:                                       # 塌下来的碎石和断掉的铁轨
		var bx := 408.0 + float(absi(hash([k, 9])) % 34)
		m.draw_rect(Rect2(bx, fy - 2 - (k % 3), 6 + k % 4, 4 + k % 3), Pal.U_S if k % 2 == 0 else Pal.L_A)
	m.draw_rect(Rect2(414, fy + 1, 12, 2), Pal.L_A)
	# 两个井口
	m.draw_texture(m.tex["mine_gate"], Vector2(CAVE["shaft1"] - 28, fy - 46))
	m.draw_texture(m.tex["mine_gate"], Vector2(CAVE["shaft2"] - 28, fy - 46))
	m.pixel_line(Vector2(CAVE["shaft2"] - 22, fy - 40), Vector2(CAVE["shaft2"] + 22, fy - 6), Pal.L_O)
	m.pixel_line(Vector2(CAVE["shaft2"] - 22, fy - 6), Vector2(CAVE["shaft2"] + 22, fy - 40), Pal.L_O)
	for sx in [CAVE["exit"], CAVE["shaft1"], CAVE["shaft2"]]:
		var name: String = {CAVE["exit"]: "出口", CAVE["shaft1"]: "1号井", CAVE["shaft2"]: "2号井 封闭"}[sx]
		var w: float = m.dyn_text_width(name) + 6.0
		m.draw_rect(Rect2(sx - w / 2.0 - 1, fy - 62, w + 2, 14), Pal.U_K)
		m.draw_rect(Rect2(sx - w / 2.0, fy - 61, w, 12), Pal.L_N)
		m.dyn_text(name, Vector2(sx - w / 2.0 + 3, fy - 61), Pal.U_K)
	# 墙边干活的鼹鼠
	m.tex_frame("mole_miner", Vector2(150, fy - 22), (t / 420) % 2, 2)
	# 矿车和小猫
	m.draw_texture(m.tex["mine_cart"], Vector2(cart_x - 16, fy - 20))
	if riding:
		var sway := roundf(sin(float(t) / 60.0))
		m.draw_cat(Vector2(cart_x - 14, fy - 46 + sway), 0, region == "ride_back")
	else:
		m.draw_cat(Vector2(roundf(cave_x), fy - 32), 4 if cave_moving else 0, cave_flip)
	m.draw_set_transform(Vector2.ZERO)
	# 四周暗角
	for i in 5:
		var e := float(i) * 6.0
		var a := 0.1 * float(5 - i) / 5.0
		m.draw_rect(Rect2(0, e, view.x, 6), Color(0, 0, 0, a))
		m.draw_rect(Rect2(0, view.y - e - 6, view.x, 6), Color(0, 0, 0, a))
	_draw_menu(view)

## ---- 矿井 ----
func _draw_mine(view: Vector2, t: int) -> void:
	var mn = m.game.mine
	var p: Vector2i = mn.pos()
	var mw: float = float(mn.width() * CELL)
	var mh: float = float(mn.height() * CELL)
	var fp: Vector2 = mn.fpos()
	var target := Vector2(fp.x * CELL - view.x / 2.0, fp.y * CELL - view.y / 2.0)
	target.x = clampf(target.x, -16.0, maxf(-16.0, mw + 16.0 - view.x)) if mw + 32.0 > view.x else (mw - view.x) / 2.0
	target.y = clampf(target.y, -16.0, maxf(-16.0, mh + 16.0 - view.y)) if mh + 32.0 > view.y else (mh - view.y) / 2.0
	if _mcam == Vector2.INF:
		_mcam = target
	_mcam = _mcam.lerp(target, 0.2)
	var cam := _mcam.round()
	if t < _shake_t:
		var k := clampf(float(_shake_t - t) / 160.0, 0.0, 1.0)
		cam += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).round() * _shake_amp * k
	else:
		_shake_amp = 0.0
	m.draw_rect(Rect2(Vector2.ZERO, view), Pal.U_K)
	m.draw_set_transform(-cam)
	var x0 := int(floor(cam.x / CELL)) - 1
	var x1 := int(ceil((cam.x + view.x) / CELL)) + 1
	var y0 := int(floor(cam.y / CELL)) - 1
	var y1 := int(ceil((cam.y + view.y) / CELL)) + 1
	var now: int = m.game.now_ms()
	var R: float = mn.light_radius()
	var dt: Vector2i = mn.dig_target()
	var ex: Vector2i = mn.exit_pos(mn.floor_n())
	var en: Vector2i = mn.entrance(mn.floor_n())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var pos := Vector2(x * CELL, y * CELL)
			var b: String = mn.block(x, y)
			if not mn.is_floor(x, y):
				_draw_wall(mn, x, y, pos)
				continue
			m.tex_frame("mine_tiles", pos, TILE["floor"], MINE_FRAMES)
			if not mn.is_floor(x, y - 1):                # 崖壁脚下的一道阴影
				m.draw_rect(Rect2(pos, Vector2(CELL, 4)), Color(0, 0, 0, 0.35))
			if not mn.is_floor(x - 1, y):
				m.draw_rect(Rect2(pos, Vector2(2, CELL)), Color(0, 0, 0, 0.25))
			if b == "":
				if Vector2i(x, y) == en:
					m.tex_frame("mine_tiles", pos, TILE["ladder"], MINE_FRAMES)
			elif b == "pit":
				m.tex_frame("mine_tiles", pos, TILE["hole"], MINE_FRAMES)
			elif b == "chest":
				m.tex_frame("mine_tiles", pos, TILE["crate"], MINE_FRAMES)
			else:
				var f: float = mn.progress_at(x, y, now) if b != "granite" else 0.0
				var shake := Vector2.ZERO
				if Vector2i(x, y) == dt and f > 0.0:
					shake = Vector2(roundf(sin(float(t) / 35.0) * (0.5 + f)), 0)
				var vr: int = absi(hash([x, y, mn.floor_n()])) % 3                 # 石头的形状（和里面有没有矿无关）
				m.tex_frame("mine_tiles", pos + shake, TILE.get(b if vr == 0 or b == "granite" else b + str(vr), 0), MINE_FRAMES)
				# 矿不再明显标出来：只有一部分矿石会有一点点反光，也有几块普通石头会反光（迷惑）
				var o: String = mn.ore(x, y) if b != "granite" else ""
				var seen := Vector2(x + 0.5 - fp.x, y + 0.5 - fp.y).length() <= R * 0.8
				var gl: int = absi(hash([x, y, mn.floor_n(), "glint"])) % 100
				if seen and ((o in ["gold", "metal"] and gl < 45) or (o == "" and b != "granite" and gl < 8)):
					var gc: Color = Pal.L_Y if (o == "gold" or (o == "" and gl % 2 == 0)) else Pal.L_C
					m.draw_rect(Rect2(pos + shake + Vector2(12 + gl % 7, 11 + gl % 5), Vector2(2, 2)), gc)
				if f > 0.02:
					m.tex_frame("mine_tiles", pos + shake, CRACK0 + clampi(int(f * 4.0), 0, 3), MINE_FRAMES)
	# 放着的炸弹
	for bm in mn.live_bombs():
		var bp := Vector2(int(bm["x"]) * CELL + 10, int(bm["y"]) * CELL + 14)
		m.draw_rect(Rect2(bp + Vector2(-1, -1), Vector2(14, 14)), Pal.U_K)
		m.draw_rect(Rect2(bp, Vector2(12, 12)), Pal.U_S)
		m.draw_rect(Rect2(bp + Vector2(2, 2), Vector2(3, 3)), Pal.L_A)
		m.draw_rect(Rect2(bp + Vector2(6, -4), Vector2(2, 4)), Pal.U_O)
		if (t / 120) % 2 == 0:
			m.draw_rect(Rect2(bp + Vector2(6, -7), Vector2(3, 3)), Pal.L_Y)
		else:
			m.draw_rect(Rect2(bp + Vector2(6, -7), Vector2(3, 3)), Pal.L_R)
	# 碎块
	var keep: Array = []
	for d in debris:
		var age := float(t - int(d["t"])) / 1000.0
		if age < 0.7:
			keep.append(d)
			var q: Vector2 = d["p"] + d["v"] * age + Vector2(0, 220.0 * age * age)
			m.draw_rect(Rect2(q.round(), Vector2(3, 3)), d["c"])
	debris = keep
	# 面前那块能挖的石头：黄色框
	if _diggable_ahead() or _special_ahead() != "":
		var tc: Vector2i = mn.target(face_v.x, face_v.y)
		var tr := Rect2(tc.x * CELL + 1, tc.y * CELL + 1, CELL - 2, CELL - 2)
		var blink := 0.55 + 0.35 * sin(float(t) / 140.0)
		var yc := Color(Pal.L_Y, blink)
		m.draw_rect(Rect2(tr.position, Vector2(tr.size.x, 1)), yc)
		m.draw_rect(Rect2(tr.position + Vector2(0, tr.size.y - 1), Vector2(tr.size.x, 1)), yc)
		m.draw_rect(Rect2(tr.position, Vector2(1, tr.size.y)), yc)
		m.draw_rect(Rect2(tr.position + Vector2(tr.size.x - 1, 0), Vector2(1, tr.size.y)), yc)
	# 小猫（脚在 fpos；挖的时候挥镐）
	var cp := Vector2(roundf(fp.x * CELL - 15.0), roundf(fp.y * CELL - 26.0))
	var dig: bool = mn.digging()
	var dirv := face_v
	var flip := face < 0
	m.draw_cat(cp, 4 if mine_moving else 0, flip)
	if dig:
		_draw_swing(cp, flip, dirv, t)
	# 黑暗：按到小猫的距离一格一格变暗（4 档）
	for y in range(y0, y1):
		for x in range(x0, x1):
			var d2 := Vector2(x + 0.5 - fp.x, y + 0.5 - fp.y).length()
			var a := clampf((d2 - R + 0.5) / 2.0, 0.0, 1.0)
			a = floorf(a * 4.0) / 4.0
			if a > 0.0:
				m.draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), Color(0.03, 0.02, 0.05, a))
	# 爆炸的闪光（盖在黑暗上面）
	var fk: Array = []
	for fl in flashes:
		var age3 := float(t - int(fl["t"])) / 1000.0
		if age3 < 0.35:
			fk.append(fl)
			var rr := 20.0 + age3 * 120.0
			var al := clampf(1.0 - age3 / 0.35, 0.0, 1.0)
			m.draw_rect(Rect2(fl["p"] - Vector2(rr, rr), Vector2(rr, rr) * 2.0), Color(1.0, 0.85, 0.4, 0.45 * al))
			m.draw_rect(Rect2(fl["p"] - Vector2(rr * 0.5, rr * 0.5), Vector2(rr, rr)), Color(1.0, 1.0, 0.9, 0.7 * al))
	flashes = fk
	# 飘字
	var fkeep: Array = []
	for f2 in floats:
		var age2 := float(t - int(f2["t"])) / 1000.0
		if age2 < 1.1:
			fkeep.append(f2)
			var fpp: Vector2 = f2["p"] - Vector2(m.dyn_text_width(str(f2["s"])) / 2.0, age2 * 30.0)
			m.dyn_text(str(f2["s"]), fpp.round(), Color(f2["c"], clampf(1.6 - age2 * 1.4, 0.0, 1.0)))
	floats = fkeep
	m.draw_set_transform(Vector2.ZERO)
	# 屏幕四周暗角
	for i in 6:
		var a2 := 0.12 * float(6 - i) / 6.0
		var e := float(i) * 6.0
		m.draw_rect(Rect2(0, e, view.x, 6), Color(0, 0, 0, a2))
		m.draw_rect(Rect2(0, view.y - e - 6, view.x, 6), Color(0, 0, 0, a2))
		m.draw_rect(Rect2(e, 0, 6, view.y), Color(0, 0, 0, a2))
		m.draw_rect(Rect2(view.x - e - 6, 0, 6, view.y), Color(0, 0, 0, a2))
	# 右下角只有两样：体力条、背包容量（背包就是物品栏）
	var mx: float = float(mn.stamina_max())
	var stam: float = mn.stamina_f()
	var low: bool = stam <= mx * float(mn.cfg().get("stamina", {}).get("low", 0.25))
	var bw := 96.0
	var bx := view.x - 8.0 - bw
	var by := view.y - 18.0
	m.draw_rect(Rect2(bx - 1, by - 1, bw + 2, 9), Pal.U_K)
	m.draw_rect(Rect2(bx, by, bw, 7), Pal.U_A)
	var capv: float = mx * float(mn.cfg().get("stamina", {}).get("cap_mult", 1.3))
	m.draw_rect(Rect2(bx, by, bw * minf(stam, mx) / capv, 7), Pal.L_R if low else Pal.L_G)
	if stam > mx:                                        # 旅店睡出来的超上限部分：金色
		m.draw_rect(Rect2(bx + bw * mx / capv, by, bw * (stam - mx) / capv, 7), Pal.L_Y)
	m.draw_rect(Rect2(bx + bw * mx / capv, by - 1, 1, 9), Pal.L_W)     # 上限的刻度
	var st := "体力 %d/%d" % [mn.stamina(), mn.stamina_max()]
	m.dyn_text(st, Vector2(bx - 4 - m.dyn_text_width(st), by - 2), Pal.L_R if low else Pal.L_W)
	var bl := "背包 %d/%d" % [mn.bag_n(), mn.bag_cap()]
	m.dyn_text(bl, Vector2(view.x - 8 - m.dyn_text_width(bl), by - 14), Pal.L_R if mn.bag_full() else Pal.L_W)
	# 天赋和菜（左下，超过一行就往上折行，不盖住右边）
	var words: Array = []
	var dn: String = str(mn.dish_def().get("name", ""))
	if dn != "":
		words.append("【%s】" % dn)
	var lines: Array = []
	var cur := ""
	for wd in words:
		var tryl: String = (cur + " " + str(wd)) if cur != "" else str(wd)
		if cur != "" and m.dyn_text_width(tryl) > 100.0:
			lines.append(cur)
			cur = str(wd)
		else:
			cur = tryl
	if cur != "":
		lines.append(cur)
	for li in lines.size():
		m.dyn_text(str(lines[lines.size() - 1 - li]), Vector2(8, view.y - 18 - 12 * li), Pal.L_Y)
	_draw_menu(view)

## 挥镐：慢慢举起、猛地砸下，镐头划出一道弧；砸中的一瞬间有闪光。
func _draw_swing(cp: Vector2, flip: bool, dirv: Vector2i, t: int) -> void:
	var ph := float(t % SWING_MS) / float(SWING_MS)
	var k: float = ph / 0.7 if ph < 0.7 else 1.0 - (ph - 0.7) / 0.3      # 举起 0→1（慢）；砸下 1→0（快）
	k = k * k * (3.0 - 2.0 * k) if ph < 0.7 else k * k
	var s := -1.0 if flip else 1.0
	var hand := Vector2(cp.x + (8.0 if flip else 22.0), cp.y + 19.0)
	var dirf := Vector2(s, 0.0)
	var up := Vector2(0, -1)
	var ang: float = lerpf(1.7, -0.9, k)                      # 弧度：从砸向前下方摆到举过头顶
	var along := Vector2(0, 1) if dirv.y > 0 else (Vector2(0, -1) if dirv.y < 0 else dirf)
	var perp := up if dirv.y == 0 else Vector2(s, 0.0)
	var v: Vector2 = along * sin(ang) + perp * cos(ang)       # 举起时偏向头顶/身侧，砸下时指向面前
	var tip: Vector2 = hand + v * 15.0
	m.pixel_line(hand + Vector2(0, 1), tip + Vector2(0, 1), Pal.U_K)    # 黑边，免得和地面混在一起
	m.pixel_line(hand, tip, Pal.L_N)
	var cross: Vector2 = Vector2(-v.y, v.x).normalized() * 4.0
	m.pixel_line(tip - cross, tip + cross, Pal.L_A)
	m.draw_rect(Rect2(tip - Vector2(1, 1), Vector2(3, 3)), Pal.L_A)
	if ph > 0.7 and ph < 0.85:                               # 砸中：火花
		m.draw_rect(Rect2(tip + v * 3.0 - Vector2(2, 2), Vector2(4, 4)), Pal.L_Y)

func _draw_overlay(view: Vector2, t: int) -> void:
	if region in ["isle", "cave", "mine", "ride_in", "ride_back"]:
		var w: float = 22.0 + m.dyn_text_width(_wallet_text())
		m.draw_rect(Rect2(view.x - w - 8, 5, w + 4, 16), Color(0.1, 0.08, 0.14, 0.8))
		m.draw_texture(m.tex[MoneyC.icon(m.game.state.wallet_gold)], Vector2(view.x - w - 4, 6))
		m.dyn_text(_wallet_text(), Vector2(view.x - w + 8, 7), Pal.L_Y)
		var h := hint()
		if h != "" and menu == "":
			m.dyn_text(h, Vector2(8, 28), Pal.L_W if region != "isle" else Pal.U_K)
	if msg != "" and t - msg_t < 2800:
		var w2: float = m.dyn_text_width(msg)
		var r := Rect2(view.x / 2.0 - w2 / 2.0 - 6, view.y - 44, w2 + 12, 16)
		m.draw_rect(r, Color(0.1, 0.08, 0.14, 0.85))
		m.dyn_text(msg, r.position + Vector2(6, 2), Pal.L_Y)
