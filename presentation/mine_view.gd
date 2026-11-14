extends RefCounted
## 矿山岛：过海过场、岛上（码头/饭店/工具店/矿洞口）、矿井（挖掘、裂痕、光圈、梯子）。
## 逻辑在 core/mine.gd；这里只管画面和按键。区域："" / "cross_out" / "isle" / "mine" / "cross_back"。
const Pal := preload("res://presentation/palette.gd")

const CELL := 32
const TILE := {"dirt": 0, "stone": 1, "rock": 2, "deep": 3, "granite": 4, "back": 5, "ladder": 6, "gem": 7, "metal": 8, "stone_ore": 9, "chest": 10}
const CRACK0 := 11
const CROSS_MS := 4200
const ISLE_W := 560.0
const SPOT := {"dock": 500.0, "rest": 380.0, "shop": 250.0, "gate": 96.0}
const STEP_S := 0.16
const WALK_SPEED := 46.0

var m
var region: String = ""
var t0: int = 0
var isle_x: float = 470.0       # 岛上小猫贴图左边缘
var isle_flip: bool = true
var isle_moving: bool = false
var face: int = 1               # 矿里小猫朝向
var _step_cd: float = 0.0
var shop_open: bool = false
var shop_sel: int = 0
var ask_ladder: bool = false
var _asked_at: int = -1         # 在第几格梯子底问过（同一个位置不反复问）
var msg: String = ""
var msg_t: int = -100000
var debris: Array = []
var _mcam := Vector2.ZERO

func _init(main) -> void:
	m = main

func active() -> bool:
	return region != ""

func say(s: String) -> void:
	msg = s
	msg_t = Time.get_ticks_msec()

## ---- 切换 ----
func go(r: String) -> void:
	region = r
	t0 = Time.get_ticks_msec()
	shop_open = false
	ask_ladder = false
	var mn = m.game.mine
	if r != "":
		mn.ensure(m.game.now_ms())
	match r:
		"isle":
			mn.m()["at"] = "isle"
		"mine":
			mn.ensure(m.game.now_ms())
			mn.m()["at"] = "mine"
			_mcam = Vector2.INF
		"":
			mn.m()["at"] = ""
	m.game.dirty = true

func leave() -> void:
	if region == "mine":
		m.game.mine.stop_dig()
	go("")

## ---- 每帧 ----
func process(dt: float, dx: int, dy: int) -> void:
	var t := Time.get_ticks_msec()
	match region:
		"cross_out":
			if t - t0 >= CROSS_MS:
				go("isle")
				isle_x = SPOT["dock"] - 16.0
				isle_flip = true
				if not m.game.state.islands.has("mine"):
					m.game.state.islands.append("mine")
				say("到了矿山岛！岛上住着鼹鼠")
		"cross_back":
			if t - t0 >= CROSS_MS:
				go("")
		"isle":
			if shop_open:
				return
			isle_moving = dx != 0
			if dx != 0:
				isle_flip = dx < 0
				isle_x = clampf(isle_x + dx * WALK_SPEED * m.game.move_speed() * dt, 20.0, ISLE_W - 40.0)
		"mine":
			_process_mine(dt, dx, dy)

func _process_mine(dt: float, dx: int, dy: int) -> void:
	var mn = m.game.mine
	for e in mn.update(m.game.now_ms()):
		_on_event(e)
	if ask_ladder:
		return
	_step_cd -= dt
	if (dx == 0 and dy == 0) or _step_cd > 0.0:
		return
	_step_cd = STEP_S
	if dx != 0:
		dy = 0
		face = dx
	if mn.move(dx, dy):
		if mn.at_ladder_end() and mn.can_extend() and _asked_at != mn.ladder():
			ask_ladder = true
			_asked_at = mn.ladder()
		return
	if dy < 0:
		return
	var p: Vector2i = mn.pos()
	if mn.digging() and mn.dig_target() == p + Vector2i(dx, dy):
		return
	var why: String = mn.start_dig(dx, dy, m.game.now_ms())
	match why:
		"":
			m.play("click")
		"granite":
			say("花岗岩挖不动")
		"notool":
			say("没有镐子，去工具店买一把吧")
		"tool":
			say("太硬了，要更好的镐子")
		"ladder":
			if mn.can_extend():
				ask_ladder = true
				_asked_at = mn.ladder()
			else:
				say("梯子不够长，只能横着挖")
		"shaft":
			say("只能在竖井里往下挖")

func _on_event(e: Dictionary) -> void:
	if e["type"] == "dug":
		var x: int = e["x"]
		var y: int = e["y"]
		for k in 8:
			debris.append({"p": Vector2(x * CELL + 8 + (k % 4) * 5, y * CELL + 6 + (k / 4) * 10), "v": Vector2(randf_range(-40, 40), randf_range(-70, -20)), "t": Time.get_ticks_msec(), "c": _block_color(m.game.mine.layer(y).get("block", "dirt"))})
		var parts: Array = []
		if int(e["gems"]) > 0:
			parts.append("宝石 +%d" % int(e["gems"]))
		if str(e["item"]) != "":
			var nm: String = str(m.game.inventory.by_id.get(e["item"], {}).get("name", e["item"]))
			parts.append(("%s（包满了）" % nm) if e["lost"] else ("%s +1" % nm))
		if not parts.is_empty():
			say("  ".join(parts))
			m.play("coin")
		else:
			m.play("click")
		m.game.dirty = true
	elif e["type"] == "stop":
		match str(e["why"]):
			"granite": say("花岗岩挖不动")
			"tool": say("太硬了，要更好的镐子")
			"ladder": say("梯子不够长，只能横着挖")

func _block_color(b: String) -> Color:
	return {"dirt": Pal.U_O, "stone": Pal.L_A, "rock": Pal.U_A, "deep": Pal.U_S}.get(b, Pal.L_A)

## ---- 按键（空格 / Esc / 商店上下） ----
func key(code: int) -> bool:
	if not active():
		return false
	var act := code in [KEY_SPACE, KEY_ENTER, KEY_E]
	if ask_ladder:
		if act:
			if m.game.mine.extend_ladder():
				say("梯子延长了 %d 格" % int(m.game.mine.cfg().get("ladder_rows", 3)))
				m.play("buy")
				m.game.dirty = true
		ask_ladder = false
		return true
	if shop_open:
		if code == KEY_ESCAPE:
			shop_open = false
		elif code in [KEY_UP, KEY_W]:
			shop_sel = posmod(shop_sel - 1, 3)
		elif code in [KEY_DOWN, KEY_S]:
			shop_sel = posmod(shop_sel + 1, 3)
		elif act:
			_buy(shop_sel)
		return true
	if region == "mine":
		if act or code == KEY_ESCAPE:
			var p: Vector2i = m.game.mine.pos()
			if p.y == 0:
				leave_mine()
			elif act and m.game.mine.at_ladder_end() and m.game.mine.can_extend():
				ask_ladder = true
			elif act:
				say("回到洞口（第 0 层）按空格出去")
			return true
		return code in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]
	if region == "isle" and act:
		_interact_isle()
		return true
	return region.begins_with("cross")

func leave_mine() -> void:
	m.game.mine.stop_dig()
	go("isle")
	isle_x = SPOT["gate"] - 16.0
	isle_flip = false

func _spot() -> String:
	var cx := isle_x + 16.0
	for k in SPOT:
		if absf(cx - SPOT[k]) <= 20.0:
			return k
	return ""

func _interact_isle() -> void:
	match _spot():
		"dock":
			go("cross_back")
			m.play("click")
		"gate":
			go("mine")
			m.play("click")
		"shop":
			shop_open = true
			shop_sel = 0
			m.play("click")
		"rest":
			var got: int = m.game.mine.sell_fish(m.game.economy._prices, m.game.state.new_id("rest"))
			if got > 0:
				say("鼹鼠厨师收下了鱼：宝石 +%d" % got)
				m.play("coin")
				m.game.dirty = true
			else:
				say("鱼篓是空的。厨师说：带鱼来换宝石吧")
				m.play("deny")

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
		"gems": say("宝石不够")
		"max": say("已经是最好的了")
		"soldout": say("绳子卖完了，过一会儿再来")
		"bag": say("物品栏满了")
	if why != "":
		m.play("deny")

## ---- 提示（左上角） ----
func hint() -> String:
	match region:
		"isle":
			match _spot():
				"dock": return "空格键坐船回雾灯岛"
				"gate": return "空格键进矿洞"
				"shop": return "空格键看工具店"
				"rest": return "空格键把鱼卖给饭店"
			return "方向键走动"
		"mine":
			if ask_ladder:
				return ""
			if m.game.mine.pos().y == 0:
				return "方向键挖矿  空格键出矿洞"
			return "方向键挖矿/走动  ↑↓爬梯子"
	return ""

## ================= 绘制 =================
func draw(view: Vector2, t: int) -> void:
	match region:
		"cross_out", "cross_back":
			_draw_cross(view, t)
		"isle":
			_draw_isle(view, t)
		"mine":
			_draw_mine(view, t)
	_draw_overlay(view, t)

func _draw_cross(view: Vector2, t: int) -> void:
	var k := clampf(float(t - t0) / float(CROSS_MS), 0.0, 1.0)
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
	if shop_open:
		_draw_shop(view)

func _draw_shop(view: Vector2) -> void:
	var mn = m.game.mine
	var r := Rect2(view.x / 2.0 - 120, 34, 240, 112)
	m.draw_rect(r.grow(1), Pal.U_K)
	m.draw_rect(r, Color("#2b2137"))
	m.dyn_text("鼹鼠工具店", r.position + Vector2(8, 4), Pal.L_Y)
	var gems := "宝石 %d" % m.game.state.gems
	m.dyn_text(gems, Vector2(r.end.x - 8 - m.dyn_text_width(gems), r.position.y + 4), Pal.L_C)
	var rows := []
	var pp: int = mn.next_price("pick")
	rows.append(["镐子：%s" % str(mn.pick_def().get("name", "")), ("升级为%s  %d 宝石" % [str(mn.pick_def(mn.pick() + 1).get("name", "")), pp]) if pp >= 0 else "已经最好"])
	var lp: int = mn.next_price("lamp")
	rows.append(["灯：%s" % str(mn.lamp_def().get("name", "")), ("升级为%s  %d 宝石" % [str(mn.lamp_def(mn.lamp() + 1).get("name", "")), lp]) if lp >= 0 else "已经最好"])
	var rc: Dictionary = mn.cfg().get("rope", {})
	rows.append(["绳子（剩 %d/%d，每小时补 %d）" % [mn.rope_stock(m.game.now_ms()), int(rc.get("cap", 6)), int(rc.get("per_hour", 2))], "%d 宝石一根" % int(rc.get("price", 3))])
	for i in rows.size():
		var rr := Rect2(r.position.x + 6, r.position.y + 20 + i * 28, r.size.x - 12, 25)
		m.draw_rect(rr, Color("#3d3450") if i != shop_sel else Color("#5a4a6e"))
		if i == shop_sel:
			m.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), Pal.L_Y)
		m.dyn_text(str(rows[i][0]), rr.position + Vector2(6, 1), Pal.L_W)
		m.dyn_text(str(rows[i][1]), rr.position + Vector2(6, 12), Pal.L_A)
	m.dyn_text("↑↓选择  空格买  Esc离开", Vector2(r.position.x + 8, r.end.y - 13), Pal.L_A)

func _draw_mine(view: Vector2, t: int) -> void:
	var mn = m.game.mine
	var p: Vector2i = mn.pos()
	var target := Vector2(p.x * CELL + 16 - view.x / 2.0, p.y * CELL + 16 - view.y / 2.0 - 10.0)
	if _mcam == Vector2.INF:
		_mcam = target
	_mcam = _mcam.lerp(target, 0.15)
	var cam := _mcam.round()
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
	var prog: float = mn.dig_progress(now)
	# 地面以上：天空和山体
	if y0 < 0:
		m.draw_rect(Rect2(x0 * CELL, y0 * CELL, (x1 - x0) * CELL, -y0 * CELL), Pal.U_S)
		m.draw_rect(Rect2(x0 * CELL, -CELL / 2, (x1 - x0) * CELL, CELL / 2), Pal.U_A)
		m.draw_rect(Rect2((mn.shaft() - 1) * CELL, -CELL / 2, 3 * CELL, CELL / 2), Pal.U_K)
	for y in range(maxi(0, y0), y1):
		for x in range(x0, x1):
			var pos := Vector2(x * CELL, y * CELL)
			var b: String = "granite" if (x <= 0 or x >= w - 1) else mn.block(x, y)
			if b == "":
				m.tex_frame("mine_tiles", pos, TILE["back"], 15)
				if x == mn.shaft() and y >= 0 and y <= mn.ladder():
					m.tex_frame("mine_tiles", pos, TILE["ladder"], 15)
			else:
				var shake := Vector2.ZERO
				if Vector2i(x, y) == dt and prog > 0.0:
					shake = Vector2(roundf(sin(float(t) / 40.0) * prog), 0)
				m.tex_frame("mine_tiles", pos + shake, TILE.get(b, 0), 15)
				var o: String = mn.ore(x, y) if b != "granite" else ""
				var seen := Vector2(x - p.x, y - p.y).length() <= R + 0.6
				if o != "" and seen:
					m.tex_frame("mine_tiles", pos + shake, TILE["stone_ore" if o == "stone" else o], 15)
				if Vector2i(x, y) == dt and prog > 0.0:
					m.tex_frame("mine_tiles", pos + shake, CRACK0 + clampi(int(prog * 4.0), 0, 3), 15)
	# 碎块
	var keep: Array = []
	for d in debris:
		var age := float(t - int(d["t"])) / 1000.0
		if age < 0.7:
			keep.append(d)
			var q: Vector2 = d["p"] + d["v"] * age + Vector2(0, 160.0 * age * age)
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
		var sw := (t / 220) % 2 == 0
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
	m.draw_set_transform(Vector2.ZERO)
	# 屏幕四周暗角
	for i in 6:
		var a := 0.12 * float(6 - i) / 6.0
		var e := float(i) * 6.0
		m.draw_rect(Rect2(0, e, view.x, 6), Color(0, 0, 0, a))
		m.draw_rect(Rect2(0, view.y - e - 6, view.x, 6), Color(0, 0, 0, a))
		m.draw_rect(Rect2(e, 0, 6, view.y), Color(0, 0, 0, a))
		m.draw_rect(Rect2(view.x - e - 6, 0, 6, view.y), Color(0, 0, 0, a))
	# 深度、梯子、宝石
	var info := "深 %d 层  梯子 %d  镐 %s" % [p.y, mn.ladder(), str(mn.pick_def().get("name", ""))]
	m.dyn_text(info, Vector2(view.x - 8 - m.dyn_text_width(info), view.y - 30), Pal.L_W)
	if dig:
		var left_s := maxi(0, (mn.m()["dig"]["t1"] - now) / 1000)
		var s := "还要 %d 秒" % left_s
		m.dyn_text(s, Vector2(view.x - 8 - m.dyn_text_width(s), view.y - 42), Pal.L_Y)
	if ask_ladder:
		var r := Rect2(view.x / 2.0 - 100, view.y / 2.0 - 22, 200, 44)
		m.draw_rect(r.grow(1), Pal.U_K)
		m.draw_rect(r, Color("#2b2137"))
		m.dyn_text("要用一架梯子把它延长 %d 格吗？" % int(mn.cfg().get("ladder_rows", 3)), r.position + Vector2(8, 6), Pal.L_W)
		m.dyn_text("空格=好（还有 %d 架）  其他键=不了" % m.game.inventory.count(m.game.state, "ladder"), r.position + Vector2(8, 24), Pal.L_Y)

func _draw_overlay(view: Vector2, t: int) -> void:
	if region == "isle" or region == "mine":
		var g := "宝石 %d" % m.game.state.gems
		var w: float = m.dyn_text_width(g)
		m.draw_rect(Rect2(view.x - w - 26, 5, w + 22, 16), Color(0.1, 0.08, 0.14, 0.8))
		m.draw_set_transform(Vector2(view.x - w - 24, 5), 0.0, Vector2(0.5, 0.5))
		m.tex_frame("mine_tiles", Vector2.ZERO, TILE["gem"], 15)
		m.draw_set_transform(Vector2.ZERO)
		m.dyn_text(g, Vector2(view.x - w - 8, 7), Pal.L_C)
		var h := hint()
		if h != "" and not shop_open:
			m.dyn_text(h, Vector2(8, 28), Pal.L_W if region == "mine" else Pal.U_K)
	if msg != "" and t - msg_t < 2600:
		var w2: float = m.dyn_text_width(msg)
		var r := Rect2(view.x / 2.0 - w2 / 2.0 - 6, view.y - 44, w2 + 12, 16)
		m.draw_rect(r, Color(0.1, 0.08, 0.14, 0.85))
		m.dyn_text(msg, r.position + Vector2(6, 2), Pal.L_Y)
