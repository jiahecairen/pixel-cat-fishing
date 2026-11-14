extends RefCounted
## 矿山岛：过海过场、岛上（码头/饭店/工具店/矿洞口）、洞穴大厅（矿车）、矿井（主动挖掘、裂痕、光圈、梯子、天赋）。
## 逻辑在 core/mine.gd；这里只管画面和按键。
## 区域："" / "cross_out" / "isle" / "cave" / "ride_in" / "mine" / "ride_back" / "cross_back"。
const Pal := preload("res://presentation/palette.gd")
const MoneyC := preload("res://core/money.gd")

const CELL := 32
const TILE := {"dirt": 0, "stone": 1, "rock": 2, "deep": 3, "granite": 4, "back": 5, "ladder": 6, "gold": 7, "metal": 8, "stone_ore": 9, "chest": 10, "rubble": 1}
const CRACK0 := 11
const CROSS_MS := 4200
const RIDE_MS := 1500
const ISLE_W := 560.0
const SPOT := {"dock": 500.0, "rest": 380.0, "shop": 250.0, "gate": 96.0}
const CAVE_W := 560.0
const CAVE := {"exit": 40.0, "cart": 250.0, "shaft1": 360.0, "rail2": 440.0, "shaft2": 500.0}
const STEP_S := 0.11
const SWING_MS := 230
const WALK_SPEED := 46.0

var m
var region: String = ""
var t0: int = 0
var isle_x: float = 470.0       # 岛上小猫贴图左边缘
var isle_flip: bool = true
var isle_moving: bool = false
var cave_x: float = 60.0
var cave_flip: bool = false
var cave_moving: bool = false
var face: int = 1               # 矿里小猫朝向
var menu: String = ""           # "" / "shop" / "cook" / "cart" / "repair"
var menu_sel: int = 0
var perk_sel: int = 0
var ride_shaft: int = 1
var ask_ladder: bool = false
var _asked_at: int = -1
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
	ask_ladder = false
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
					perk_sel = 0
					go("mine")
					_asked_at = -1
				elif mn2.begin_run(ride_shaft, m.game.now_ms()):
					perk_sel = 0
					go("mine")
					_asked_at = -1
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
	if ask_ladder or not mn.draft().is_empty():
		mn.stop_dig(now)
		return
	_step_cd -= dt
	if dx != 0:
		dy = 0
		face = dx
	if dx == 0 and dy == 0:
		if mn.digging():
			mn.stop_dig(now)
		return
	var p: Vector2i = mn.pos()
	# 前面是空的就走过去（挖完一格后按住方向键会接着往前走）
	if not mn.digging() and _step_cd <= 0.0:
		if mn.move(dx, dy, now):
			_step_cd = STEP_S / m.game.move_speed()
			if mn.at_ladder_end() and mn.can_extend() and _asked_at != mn.ladder():
				ask_ladder = true
				_asked_at = mn.ladder()
			return
	if dy < 0:
		return
	var why: String = mn.start_dig(dx, dy, now)
	match why:
		"":
			var t := Time.get_ticks_msec()
			if t - _swing_t >= SWING_MS:
				_swing_t = t
				m.play("click")
				var tg: Vector2i = mn.dig_target()
				_chips(tg.x, tg.y, 2, 55.0)
				_shake(0.8, 90)
		"open":
			pass
		"granite":
			_warn("花岗岩挖不动")
		"notool":
			_warn("没有镐子，去找雾灯岛的老柯要一把")
		"tool":
			_warn("太硬了，要更好的镐子（工具店升级）")
		"ladder":
			if mn.can_extend():
				ask_ladder = true
				_asked_at = mn.ladder()
			else:
				_warn("梯子不够长，只能横着挖")
		"shaft":
			_warn("只能在竖井里往下挖")

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
	if e["type"] != "dug":
		return
	var x: int = e["x"]
	var y: int = e["y"]
	_chips(x, y, 14, 90.0)
	_shake(2.0, 160)
	var o := str(e["ore"])
	if int(e["gold"]) > 0:
		_float(x, y, "+%s" % _price(int(e["gold"])), Pal.L_Y)
	if str(e["item"]) != "":
		var nm: String = str(m.game.inventory.by_id.get(e["item"], {}).get("name", e["item"]))
		_float(x, y - 1, ("%s（包满了）" % nm) if e["lost"] else ("%s +%d" % [nm, int(e["n"])]), Pal.L_W if not e["lost"] else Pal.L_R)
	if bool(e["chest"]):
		_float(x, y - 2, "宝箱！", Pal.L_Y)
		_shake(3.5, 260)
		m.play("rare")
		say("宝箱！挑一个天赋")
	elif o == "gold":
		m.play("coin")
	elif o == "metal" or o == "stone":
		m.play("buy")
	else:
		m.play("catch")
	if bool(e["cavein"]):
		_shake(5.0, 500)
		say("落石！身后的路被堵住了")
		m.play("deny")
	m.game.dirty = true

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
	if region == "mine" and not mn.draft().is_empty():
		var n: int = mn.draft().size()
		if code in [KEY_LEFT, KEY_A]:
			perk_sel = posmod(perk_sel - 1, n)
		elif code in [KEY_RIGHT, KEY_D]:
			perk_sel = posmod(perk_sel + 1, n)
		elif code >= KEY_1 and code < KEY_1 + n:
			_take_perk(code - KEY_1)
		elif act:
			_take_perk(perk_sel)
		return true
	if ask_ladder:
		if act:
			if mn.extend_ladder():
				say("梯子延长了 %d 格" % int(mn.cfg().get("ladder_rows", 3)))
				m.play("buy")
				m.game.dirty = true
		ask_ladder = false
		return true
	if menu != "":
		_menu_key(code, act)
		return true
	if region == "mine":
		if act:
			if mn.pos().y == 0:
				mn.stop_dig(m.game.now_ms())
				mn.end_run()
				region = "ride_back"
				menu = ""
				t0 = Time.get_ticks_msec()
				mn.m()["at"] = "cave"
				m.play("click")
			elif mn.at_ladder_end() and mn.can_extend():
				ask_ladder = true
			else:
				say("爬回最上面一层，按空格坐矿车回大厅")
			return true
		return code in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]
	if region == "isle" and act:
		_interact_isle()
		return true
	if region == "cave" and act:
		_interact_cave()
		return true
	return region.begins_with("cross") or region.begins_with("ride")

func _take_perk(i: int) -> void:
	var id: String = m.game.mine.choose_perk(i)
	if id != "":
		var pd: Dictionary = m.game.mine.perk_def(id)
		say("%s：%s" % [str(pd.get("name", id)), str(pd.get("desc", ""))])
		m.play("buy")
		m.game.dirty = true

func _menu_rows() -> int:
	match menu:
		"shop": return 3
		"cook": return m.game.mine.dishes().size()
		"cart": return 2
	return 1

func _menu_key(code: int, act: bool) -> void:
	if code == KEY_ESCAPE:
		menu = ""
	elif code in [KEY_UP, KEY_W]:
		menu_sel = posmod(menu_sel - 1, _menu_rows())
	elif code in [KEY_DOWN, KEY_S]:
		menu_sel = posmod(menu_sel + 1, _menu_rows())
	elif act:
		match menu:
			"shop": _buy(menu_sel)
			"cook": _cook(menu_sel)
			"cart": _cart(menu_sel)
			"repair": menu = ""

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

func _cart(i: int) -> void:
	if i == 0:
		ride_shaft = 1
		menu = ""
		region = "ride_in"
		t0 = Time.get_ticks_msec()
		m.play("click")
	else:
		menu = "repair"
		menu_sel = 0

func _buy(i: int) -> void:
	var mn = m.game.mine
	var why: String = ""
	match i:
		0: why = mn.buy_level("pick")
		1: why = mn.buy_level("lamp")
		2: why = mn.buy_rope(m.game.now_ms())
	match why:
		"":
			m.play("buy")
			m.game.dirty = true
			say(["买到了：%s" % str(mn.pick_def().get("name", "")), "买到了：%s" % str(mn.lamp_def().get("name", "")), "买到一根绳子"][i])
		"gold": say("钱不够")
		"mat": say("材料不够（石头和金属在矿里挖）")
		"nopick": say("你还没有镐子，去找雾灯岛的老柯")
		"max": say("已经是最好的了")
		"soldout": say("绳子卖完了，过一会儿再来")
		"bag": say("物品栏满了")
	if why != "":
		m.play("deny")

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
			if ask_ladder or not m.game.mine.draft().is_empty():
				return ""
			if m.game.mine.pos().y == 0:
				return "按住方向键挖  空格键坐矿车回大厅"
			return "按住方向键挖  ↑↓爬梯子"
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
	if (t / 300) % 2 == 0:                                         # 饭店烟囱冒烟
		m.draw_rect(Rect2(SPOT["rest"] + 14, fy - 52 - (t / 300) % 6, 3, 3), Color(Pal.U_W, 0.7))
	m.tex_frame("mole_0", Vector2(SPOT["shop"] + 30, fy - 22), (t / 900) % 2, 2)
	m.tex_frame("mole_1", Vector2(SPOT["rest"] + 30, fy - 22), (t / 1100) % 2, 2)
	for sx in [SPOT["shop"], SPOT["rest"], SPOT["gate"]]:
		var name: String = {SPOT["shop"]: "工具店", SPOT["rest"]: "饭店", SPOT["gate"]: "矿洞"}[sx]
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

## ---- 菜单（工具店 / 饭店 / 矿车 / 2 号井） ----
func _panel(view: Vector2, title: String, right: String, rows: Array, footer: String, h: float) -> Rect2:
	var r := Rect2(view.x / 2.0 - 140, 30, 280, h)
	m.draw_rect(r.grow(1), Pal.U_K)
	m.draw_rect(r, Color("#2b2137"))
	m.dyn_text(title, r.position + Vector2(8, 4), Pal.L_Y)
	if right != "":
		m.dyn_text(right, Vector2(r.end.x - 8 - m.dyn_text_width(right), r.position.y + 4), Pal.L_C)
	for i in rows.size():
		var rr := Rect2(r.position.x + 6, r.position.y + 20 + i * 28, r.size.x - 12, 25)
		m.draw_rect(rr, Color("#3d3450") if i != menu_sel else Color("#5a4a6e"))
		if i == menu_sel:
			m.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), Pal.L_Y)
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
			var rc: Dictionary = mn.cfg().get("rope", {})
			rows.append(["绳子（剩 %d/%d，每小时补 %d）" % [mn.rope_stock(m.game.now_ms()), int(rc.get("cap", 6)), int(rc.get("per_hour", 2))], "%s 一根" % _price(int(rc.get("price", 25)))])
			_panel(view, "鼹鼠工具店", _wallet_text(), rows, "↑↓选择  空格买  Esc离开", 112.0)
		"cook":
			var rows2: Array = []
			for d in mn.dishes():
				rows2.append(["%s   鱼×%d  %s" % [str(d["name"]), int(d["fish"]), _price(int(d["price"]))], str(d["desc"])])
			var waiting: String = str(mn.dish_by_id(str(mn.m().get("dish", ""))).get("name", ""))
			var foot := ("已备好：%s" % waiting) if waiting != "" else ("鱼篓里有 %d 条鱼" % m.game.state.basket.size())
			_panel(view, "鼹鼠饭店  下一次下井生效", _wallet_text(), rows2, foot + "   空格点菜  Esc离开", 20.0 + rows2.size() * 28.0 + 20.0)
		"cart":
			_panel(view, "矿车", "", [["1 号井", "接着上次的一局往下挖" if m.game.mine.in_run() else "铁路畅通，直达"], ["2 号井", "铁路坏了"]], "↑↓选择  空格出发  Esc离开", 96.0)
		"repair":
			var need: Dictionary = mn.cfg().get("repair2", {})
			var inv = m.game.inventory
			var st = m.game.state
			var r := _panel(view, "2 号井：铁路塌了", "", [], "空格 / Esc 关闭", 112.0)
			var lines: Array = [
				"修好它需要：",
				"金属 ×%d（有 %d）   石头 ×%d（有 %d）" % [int(need.get("metal", 0)), inv.count(st, "metal"), int(need.get("stone", 0)), inv.count(st, "stone")],
				"还要从雾灯岛雇一队工人，",
				"得有更大的船才载得动他们。（以后开放）"]
			for i in lines.size():
				m.dyn_text(str(lines[i]), r.position + Vector2(10, 22 + i * 14), Pal.L_W if i != 1 else Pal.L_Y)

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
	var target := Vector2(p.x * CELL + 16 - view.x / 2.0, p.y * CELL + 16 - view.y / 2.0 - 10.0)
	if _mcam == Vector2.INF:
		_mcam = target
	_mcam = _mcam.lerp(target, 0.18)
	var cam := _mcam.round()
	if t < _shake_t:
		var k := clampf(float(_shake_t - t) / 160.0, 0.0, 1.0)
		cam += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).round() * _shake_amp * k
	else:
		_shake_amp = 0.0
	m.draw_rect(Rect2(Vector2.ZERO, view), Pal.U_K)
	m.draw_set_transform(-cam)
	var w: int = mn.width()
	var x0 := int(floor(cam.x / CELL)) - 1
	var x1 := int(ceil((cam.x + view.x) / CELL)) + 1
	var y0 := int(floor(cam.y / CELL)) - 1
	var y1 := int(ceil((cam.y + view.y) / CELL)) + 1
	var now: int = m.game.now_ms()
	var R: float = mn.light_radius()
	var dt: Vector2i = mn.dig_target()
	# 洞口那一行以上：岩顶
	if y0 < 0:
		m.draw_rect(Rect2(x0 * CELL, y0 * CELL, (x1 - x0) * CELL, -y0 * CELL), Color("#1d1626"))
	for y in range(maxi(0, y0), y1):
		for x in range(x0, x1):
			var pos := Vector2(x * CELL, y * CELL)
			var b: String = mn.block(x, y)
			if b == "":
				m.tex_frame("mine_tiles", pos, TILE["back"], 15)
				if x == mn.shaft() and y >= 0 and y <= mn.ladder():
					m.tex_frame("mine_tiles", pos, TILE["ladder"], 15)
			else:
				var f: float = mn.progress_at(x, y, now) if b != "granite" else 0.0
				var shake := Vector2.ZERO
				if Vector2i(x, y) == dt and f > 0.0:
					shake = Vector2(roundf(sin(float(t) / 35.0) * (0.5 + f)), 0)
				m.tex_frame("mine_tiles", pos + shake, TILE.get(b, 0), 15)
				if b == "rubble":
					m.draw_rect(Rect2(pos + shake + Vector2(4, 4), Vector2(10, 8)), Pal.U_A)
					m.draw_rect(Rect2(pos + shake + Vector2(17, 15), Vector2(11, 9)), Pal.U_S)
				var o: String = mn.ore(x, y) if b != "granite" and b != "rubble" else ""
				var seen := Vector2(x - p.x, y - p.y).length() <= R + 0.6
				if o != "" and seen:
					m.tex_frame("mine_tiles", pos + shake, TILE["stone_ore" if o == "stone" else o], 15)
				if f > 0.02:
					m.tex_frame("mine_tiles", pos + shake, CRACK0 + clampi(int(f * 4.0), 0, 3), 15)
	# 洞口行的矿车（空格坐它回大厅）
	m.draw_texture(m.tex["mine_cart"], Vector2((mn.shaft() - 3) * CELL + 6, 12))
	# 碎块
	var keep: Array = []
	for d in debris:
		var age := float(t - int(d["t"])) / 1000.0
		if age < 0.7:
			keep.append(d)
			var q: Vector2 = d["p"] + d["v"] * age + Vector2(0, 220.0 * age * age)
			m.draw_rect(Rect2(q.round(), Vector2(3, 3)), d["c"])
	debris = keep
	# 小猫（挖的时候挥镐）
	var cp := Vector2(p.x * CELL - 1, p.y * CELL)
	var dig: bool = mn.digging()
	var dirv := dt - p
	var flip := face < 0
	if dig and dirv.x != 0:
		flip = dirv.x < 0
	m.draw_cat(cp, 0, flip)
	if dig:
		var sw := (t / 115) % 2 == 0
		var hx := cp.x + (6.0 if flip else 24.0)
		var hy := cp.y + 18.0
		var tip := Vector2(hx + (-10.0 if flip else 10.0) * (1.0 if sw else 0.6), hy - (10.0 if sw else -4.0))
		if dirv.y > 0:
			tip = Vector2(hx + (4.0 if not flip else -4.0), hy + (12.0 if sw else 6.0))
		m.pixel_line(Vector2(hx, hy), tip, Pal.U_O)
		m.draw_rect(Rect2(tip - Vector2(2, 1), Vector2(5, 2)), Pal.L_A)
	# 黑暗：按到小猫的距离一格一格变暗（4 档），洞口那一行有天光
	for y in range(maxi(0, y0), y1):
		for x in range(x0, x1):
			var d := Vector2(x - p.x, y - p.y).length()
			var a := clampf((d - R + 0.5) / 2.0, 0.0, 1.0)
			if y == 0:
				a = minf(a, 0.35)
			a = floorf(a * 4.0) / 4.0
			if a > 0.0:
				m.draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), Color(0.06, 0.04, 0.09, a * 0.95))
	# 飘字
	var fkeep: Array = []
	for f2 in floats:
		var age2 := float(t - int(f2["t"])) / 1000.0
		if age2 < 1.1:
			fkeep.append(f2)
			var fp: Vector2 = f2["p"] - Vector2(m.dyn_text_width(str(f2["s"])) / 2.0, age2 * 30.0)
			m.dyn_text(str(f2["s"]), fp.round(), Color(f2["c"], clampf(1.6 - age2 * 1.4, 0.0, 1.0)))
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
	# 信息：几号井、深度、梯子、镐、这一局的天赋和菜
	var info := "%d号井 深 %d 层  梯子 %d  %s" % [mn.shaft_id(), p.y, mn.ladder(), str(mn.pick_def().get("name", ""))]
	m.dyn_text(info, Vector2(view.x - 8 - m.dyn_text_width(info), view.y - 18), Pal.L_W)
	var line := ""
	for pid in mn.run().get("perks", {}):
		line += "%s×%d " % [str(mn.perk_def(str(pid)).get("name", pid)), mn.perk_count(str(pid))]
	var dn: String = str(mn.dish_def().get("name", ""))
	if dn != "":
		line += "【%s】" % dn
	if line != "":
		m.dyn_text(line, Vector2(8, view.y - 18), Pal.L_Y)
	if ask_ladder:
		var r := Rect2(view.x / 2.0 - 100, view.y / 2.0 - 22, 200, 44)
		m.draw_rect(r.grow(1), Pal.U_K)
		m.draw_rect(r, Color("#2b2137"))
		m.dyn_text("要用一架梯子把它延长 %d 格吗？" % int(mn.cfg().get("ladder_rows", 3)), r.position + Vector2(8, 6), Pal.L_W)
		m.dyn_text("空格=好（还有 %d 架）  其他键=不了" % m.game.inventory.count(m.game.state, "ladder"), r.position + Vector2(8, 24), Pal.L_Y)
	if not mn.draft().is_empty():
		_draw_draft(view)

func _draw_draft(view: Vector2) -> void:
	var mn = m.game.mine
	var d: Array = mn.draft()
	m.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.55))
	var title := "选一个天赋（只在这一局有效）"
	m.dyn_text(title, Vector2(view.x / 2.0 - m.dyn_text_width(title) / 2.0, 46), Pal.L_Y)
	var cw := 98.0
	var gap := 5.0
	var x0 := view.x / 2.0 - (cw * d.size() + gap * (d.size() - 1)) / 2.0
	for i in d.size():
		var pd: Dictionary = mn.perk_def(str(d[i]))
		var r := Rect2(x0 + i * (cw + gap), 62, cw, 84)
		m.draw_rect(r.grow(1), Pal.L_Y if i == perk_sel else Pal.U_K)
		m.draw_rect(r, Color("#3d3450") if i != perk_sel else Color("#5a4a6e"))
		m.dyn_text("%d %s" % [i + 1, str(pd.get("name", ""))], r.position + Vector2(6, 6), Pal.L_W)
		var have: int = mn.perk_count(str(d[i]))
		if have > 0:
			m.dyn_text("已有 ×%d" % have, r.position + Vector2(6, 20), Pal.L_C)
		var ly := 38.0
		var line := ""
		for word in str(pd.get("desc", "")).split(" "):     # 按宽度换行
			var tryl: String = word if line == "" else line + " " + word
			if line != "" and m.dyn_text_width(tryl) > cw - 10.0:
				m.dyn_text(line, r.position + Vector2(6, ly), Pal.L_A)
				ly += 14.0
				line = word
			else:
				line = tryl
		if line != "":
			m.dyn_text(line, r.position + Vector2(6, ly), Pal.L_A)
	var foot := "←→选择  空格确定（或按 1 2 3）"
	m.dyn_text(foot, Vector2(view.x / 2.0 - m.dyn_text_width(foot) / 2.0, 156), Pal.L_A)

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
