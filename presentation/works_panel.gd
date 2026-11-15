extends RefCounted
## 雾灯岛的修理厂和酒馆面板。
##   修理厂：每个项目投入材料开工，工人越多完工越快；完工后岛上多一样东西。
##   酒馆：花钱和材料雇岛民，雇到的工人会让所有修理变快，有的项目还要求最少几位工人。
## 逻辑在 core/island_works.gd；文字用像素字体现画。

const Pal := preload("res://presentation/palette.gd")
const Money := preload("res://core/money.gd")

var open: bool = false
var mode: String = "repair"        # repair / tavern
var sel: int = 0
var m

func _init(main) -> void:
	m = main

func open_panel(md: String) -> void:
	mode = md
	sel = 0
	open = true

func close() -> void:
	open = false

func rect() -> Rect2:
	return m.big_rect()

func _close_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 13, r.position.y + 2, 11, 11)

func _rows() -> Array:
	var g = m.game
	if mode == "repair":
		return g.works.projects()
	return range(g.works.max_workers())

func _row_rect(i: int) -> Rect2:
	var r := rect()
	return Rect2(r.position.x + 6, r.position.y + 19 + i * 40, r.size.x - 12, 37)

func _btn_rect(i: int) -> Rect2:
	var rr := _row_rect(i)
	return Rect2(rr.end.x - 58, rr.end.y - 16, 52, 12)

func click(p: Vector2) -> bool:
	if not open or not rect().has_point(p):
		return false
	if _close_rect().has_point(p):
		close()
		m.play("click")
		m.on_panel_toggled()
		return true
	for i in _rows().size():
		if _btn_rect(i).has_point(p) or _row_rect(i).has_point(p):
			sel = i
			if _btn_rect(i).has_point(p):
				act()
			return true
	return true

func key(keycode: int) -> bool:
	match keycode:
		KEY_UP, KEY_W:
			sel = maxi(0, sel - 1)
		KEY_DOWN, KEY_S:
			sel = mini(maxi(0, _rows().size() - 1), sel + 1)
		KEY_SPACE, KEY_ENTER, KEY_E:
			act()
	return true

func act() -> void:
	var g = m.game
	if mode == "repair":
		var ps: Array = g.works.projects()
		if sel >= ps.size():
			return
		var id := str(ps[sel]["id"])
		if g.works.start(id, g.now_ms()):
			g.dirty = true
			m.play("buy")
			m.log.write("repair_start", {"id": id})
		else:
			m.play("deny")
	else:
		if g.works.hire_one(sel):
			g.dirty = true
			m.play("rare")
			m.log.write("hire", {"n": g.works.workers()})
		else:
			m.play("deny")

func _cost_line(cost: Array, pos: Vector2, enough_fn: Callable) -> void:
	var x := pos.x
	for c in cost:
		var id := str(c[0])
		var d: Dictionary = m.game.inventory.by_id.get(id, {})
		if m.tex.has(str(d.get("sprite", ""))):
			m.draw_texture(m.tex[str(d["sprite"])], Vector2(x, pos.y - 2))
		var have: int = m.game.inventory.count(m.game.state, id)
		var txt := "%d/%d" % [have, int(c[1])]
		m.text(txt, Vector2(x + 16, pos.y + 3), Pal.L_G if have >= int(c[1]) else Pal.L_R)
		x += 22.0 + float(txt.length()) * 4.0

func draw() -> void:
	if not open:
		return
	var g = m.game
	var r := rect()
	m.draw_rect(r, Pal.U_A)
	m.draw_rect(r.grow(-1), Pal.U_K)
	m.dyn_text("修理厂" if mode == "repair" else "酒馆", r.position + Vector2(8, 5), Pal.L_Y)
	var w: int = g.works.workers()
	m.dyn_text("工人 %d/%d" % [w, g.works.max_workers()], r.position + Vector2(66, 5), Pal.L_C)
	m.tex_frame("btn_close", _close_rect().position, 0, 2)
	var rows := _rows()
	for i in rows.size():
		var rr := _row_rect(i)
		m.draw_rect(rr, Pal.L_Y if i == sel else Pal.U_A)
		m.draw_rect(rr.grow(-1), Color("#2d2a44"))
		var br := _btn_rect(i)
		if mode == "repair":
			var p: Dictionary = rows[i]
			var id := str(p["id"])
			var st: String = g.works.status(id)
			m.dyn_text(str(p["name"]), rr.position + Vector2(6, 2), Pal.L_W)
			m.dyn_text(str(p["desc"]), rr.position + Vector2(6, 14), Pal.L_A)
			if st != "done":
				_cost_line(p.get("cost", []), rr.position + Vector2(6, 26), func(): return true)
			var need_w: int = g.works.needs_workers(id)
			var label := ""
			var col: Color = Pal.U_A
			match st:
				"done":
					label = "已完工"
				"locked":
					label = "未解锁"
				"building":
					var left_s := maxi(0, int((g.works.ends_ms(id) - g.now_ms()) / 1000))
					label = "%02d:%02d" % [left_s / 60, left_s % 60]
					col = Pal.L_C
				_:
					label = "开工"
					col = Pal.L_G if g.works.can_start(id) else Pal.U_A
					if w < need_w:
						m.dyn_text("需要 %d 位工人（去酒馆雇）" % need_w, rr.position + Vector2(rr.size.x - 150, 2), Pal.L_R)
			m.draw_rect(br, col)
			m.dyn_text(label, br.position + Vector2(6, 1), Pal.U_K if col != Pal.U_A else Pal.L_A)
		else:
			var wd: Dictionary = g.works.worker_def(i)
			var hired: bool = i < w
			m.dyn_text("%s · %s" % [str(wd.get("name", "")), str(wd.get("job", ""))], rr.position + Vector2(6, 2), Pal.L_W if hired else Pal.L_N)
			m.dyn_text("已雇佣" if hired else "雇佣后修理更快", rr.position + Vector2(6, 14), Pal.L_G if hired else Pal.L_A)
			if not hired:
				m.draw_money(int(wd.get("copper", 0)), rr.position + Vector2(6, 25), Pal.L_Y)
				_cost_line(wd.get("items", []), rr.position + Vector2(52, 26), func(): return true)
				var ok: bool = i == w and g.works.can_hire()
				m.draw_rect(br, Pal.L_G if ok else Pal.U_A)
				m.dyn_text("雇佣" if i == w else "先雇前一位", br.position + Vector2(6, 1), Pal.U_K if ok else Pal.L_A)
