extends RefCounted
## 后台（开发/调试面板，只在完整窗口里，F9 开关）：加减钱、加减道具、任务、背包格子、存钱罐。
## 所有改动都走 Game 的正式接口（give / inventory.remove），不绕过规则；钱直接加在 GameState 上。

const Pal := preload("res://presentation/palette.gd")

var open: bool = false
var take_mode: bool = false        # false：点物品加一个；true：点物品拿走一个
var m

const BUTTONS := [
	["+1铜", "c1"], ["+1银", "s1"], ["+1金", "g1"], ["+10金", "g10"], ["钱清零", "zero"],
	["任务全完成", "q_done"], ["重置任务", "q_reset"], ["格子加四", "slots"], ["存钱罐加钱", "piggy"], ["加一个", "mode"],
]

func _init(main) -> void:
	m = main

func rect() -> Rect2:
	return Rect2(Vector2(4, 33) - m.ui_off, Vector2(m.view.x - 8, m.view.y - 39))

func _close_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 13, r.position.y + 2, 11, 11)

func _btn_rect(i: int) -> Rect2:
	var r := rect()
	var per_row := 5
	var w := (r.size.x - 12.0) / per_row
	return Rect2(r.position.x + 6 + (i % per_row) * w, r.position.y + 18 + (i / per_row) * 13, w - 2, 11)

func _cell_rect(i: int) -> Rect2:
	var r := rect()
	var cols := maxi(1, int((r.size.x - 12.0) / 20.0))
	return Rect2(r.position.x + 6 + (i % cols) * 20, r.position.y + 48 + (i / cols) * 20, 18, 18)

func toggle() -> void:
	open = not open
	m.on_panel_toggled()

func click(p: Vector2) -> bool:
	if not open or not rect().has_point(p):
		return false
	var g = m.game
	if _close_rect().has_point(p):
		open = false
		m.play("click")
		m.on_panel_toggled()
		return true
	for i in BUTTONS.size():
		if _btn_rect(i).has_point(p):
			_press(BUTTONS[i][1])
			return true
	for i in g.inventory.defs.size():
		if _cell_rect(i).has_point(p):
			var id: String = str(g.inventory.defs[i]["id"])
			if take_mode:
				m.play("click" if g.inventory.remove(g.state, id, 1) else "deny")
			else:
				g.give(id, 1, [])
				m.play("buy")
			g.state.revision += 1
			g.dirty = true
			return true
	return true

func _press(id: String) -> void:
	var g = m.game
	match id:
		"c1": g.state.wallet_gold += 1
		"s1": g.state.wallet_gold += Money.PER_SILVER
		"g1": g.state.wallet_gold += Money.PER_GOLD
		"g10": g.state.wallet_gold += Money.PER_GOLD * 10
		"zero": g.state.wallet_gold = 0
		"piggy": g.state.piggy += Money.PER_GOLD * 100
		"slots": g.state.bag_slots += 4
		"q_done":
			for q in g._quest_cfg_list():
				g.state.quests[str(q["id"])] = "done"
		"q_reset": g.state.quests = {}
		"mode":
			take_mode = not take_mode
	g.state.revision += 1
	g.dirty = true
	m.play("click")

func draw() -> void:
	if not open:
		return
	var g = m.game
	var r := rect()
	m.draw_rect(r, Pal.U_A)
	m.draw_rect(r.grow(-1), Pal.U_K)
	m.label("后台", r.position + Vector2(6, 2), Pal.L_Y)
	m.tex_frame("btn_close", _close_rect().position, 0, 2)
	for i in BUTTONS.size():
		var br := _btn_rect(i)
		var name: String = str(BUTTONS[i][0])
		if BUTTONS[i][1] == "mode":
			name = "拿走一个" if take_mode else "加一个"
		m.draw_rect(br, Pal.L_G if BUTTONS[i][1] != "mode" else Pal.L_Y)
		m.draw_rect(Rect2(br.position.x, br.end.y - 2, br.size.x, 2), Pal.U_G if BUTTONS[i][1] != "mode" else Pal.U_H)
		m.label_centered(name, br.position.x + br.size.x / 2, br.position.y, Pal.U_K)
	m.draw_money(g.state.wallet_gold, r.position + Vector2(36, 3), Pal.L_Y)
	m.draw_money(g.state.piggy, r.position + Vector2(r.size.x * 0.5, 3), Pal.L_A)
	for i in g.inventory.defs.size():
		var d: Dictionary = g.inventory.defs[i]
		var cr := _cell_rect(i)
		m.draw_rect(cr, Pal.U_A)
		m.draw_rect(cr.grow(-1), Pal.U_B)
		if m.tex.has(d.get("sprite", "")):
			m.draw_texture(m.tex[d["sprite"]], cr.position + Vector2(1, 1))
		var n: int = g.inventory.count(g.state, str(d["id"]))
		if n > 0:
			var s := str(n)
			m.draw_rect(Rect2(cr.end.x - s.length() * 4 - 1, cr.end.y - 6, s.length() * 4, 6), Pal.U_K)
			m.text(s, Vector2(cr.end.x - s.length() * 4, cr.end.y - 6), Pal.L_W)
