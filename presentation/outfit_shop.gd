extends RefCounted
## 帽子店 / 服装店的货架面板：左边预览小猫，右边一排货，买下或穿上。
## kind 是 "hat" 或 "outfit"，货物和价格来自 data/cat.json。借用主节点 m 的绘制方法。

const Pal := preload("res://presentation/palette.gd")

const RECT := Rect2(15, 28, 98, 66)
const ROW_X := 58
const ROW_Y := 44
const ROW_H := 11
const CLOSE_RECT := Rect2(100, 30, 11, 11)

var open: bool = false
var kind: String = "hat"
var sel: int = 0
var note: String = ""        # 买不起时在底部闪一下
var note_t0: int = -100000
var m

func _init(main) -> void:
	m = main

func open_kind(k: String) -> void:
	kind = k
	open = true
	sel = int(m.game.state.cat.get(k, 0))

func close() -> void:
	open = false

func _tab_rect(i: int) -> Rect2:
	return Rect2(52 + i * 24, 30, 22, 11)

func _switch(k: String) -> void:
	if kind != k:
		kind = k
		sel = int(m.game.state.cat.get(k, 0))
		m.play("click")

func _items() -> Array:
	return m.game.cat_items(kind)

func _row_rect(i: int) -> Rect2:
	return Rect2(ROW_X, ROW_Y + i * ROW_H - 1, 54, ROW_H)

## 对第 i 件货做"买下 / 穿上"。
func act(i: int) -> void:
	var g = m.game
	if i < 0 or i >= _items().size():
		return
	sel = i
	if g.cat_owns(kind, i):
		if g.wear_cat_item(kind, i):
			m.play("click")
	elif g.buy_cat_item(kind, i):
		g.wear_cat_item(kind, i)
		m.play("buy")
	else:
		note = "金币不够"
		note_t0 = Time.get_ticks_msec()
		m.play("deny")

func click(p: Vector2) -> bool:
	if not open or not RECT.has_point(p):
		return false
	if CLOSE_RECT.has_point(p):
		close()
		m.play("click")
		m.on_panel_toggled()
		return true
	if _tab_rect(0).has_point(p):
		_switch("hat")
		return true
	if _tab_rect(1).has_point(p):
		_switch("outfit")
		return true
	for i in _items().size():
		if _row_rect(i).has_point(p):
			act(i)
	return true

func key(keycode: int) -> void:
	var n := _items().size()
	match keycode:
		KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_TAB:
			_switch("outfit" if kind == "hat" else "hat")
		KEY_UP, KEY_W:
			sel = posmod(sel - 1, n)
		KEY_DOWN, KEY_S:
			sel = posmod(sel + 1, n)
		KEY_SPACE, KEY_ENTER, KEY_E:
			act(sel)

func draw() -> void:
	if not open:
		return
	var g = m.game
	m.draw_rect(RECT, Pal.U_A)
	m.draw_rect(RECT.grow(-1), Pal.U_K)
	m.label("服装店", Vector2(19, 31), Pal.L_W)
	for ti in 2:
		var tr := _tab_rect(ti)
		var on: bool = (kind == "hat") == (ti == 0)
		m.draw_rect(tr, Pal.L_Y if on else Pal.U_A)
		m.draw_rect(tr.grow(-1), Pal.L_A if on else Pal.U_K)
		m.label_centered("帽子" if ti == 0 else "衣服", tr.position.x + 11, tr.position.y, Pal.U_K if on else Pal.L_A)
	m.tex_frame("btn_close", CLOSE_RECT.position, 0, 2)
	# 预览：试穿的那一件（光标指着的）
	var prev: int = int(g.state.cat.get(kind, 0))
	m.draw_rect(Rect2(19, 44, 36, 36), Pal.L_C)
	m.draw_rect(Rect2(19, 72, 36, 8), Pal.L_B)
	m.draw_rect(Rect2(19, 72, 36, 1), Pal.U_W)
	g.state.cat[kind] = sel          # 只在画这一帧时借用，画完立刻还原
	m.draw_cat(Vector2(21, 44), (Time.get_ticks_msec() / 700) % 2)
	g.state.cat[kind] = prev
	var items := _items()
	for i in items.size():
		var y: int = ROW_Y + i * ROW_H
		var r := _row_rect(i)
		if i == sel:
			m.draw_rect(r, Pal.U_A)
			m.draw_rect(r.grow(-1), Pal.U_B)
		var owned: bool = g.cat_owns(kind, i)
		m.label(str(items[i]["name"]), Vector2(ROW_X + 3, y), Pal.L_W if owned else Pal.L_A)
		if g.cat_wearing(kind, i):
			m.label("穿着", Vector2(ROW_X + 32, y), Pal.L_G)
		elif owned:
			m.label("已有", Vector2(ROW_X + 32, y), Pal.L_A)
		else:
			m.money_right(g.cat_price(kind, i), ROW_X + 51, y + 3, Pal.L_Y if g.state.wallet_gold >= g.cat_price(kind, i) else Pal.L_R)
	if Time.get_ticks_msec() - note_t0 < 1500:
		m.label(note, Vector2(19, 82), Pal.L_R)
	else:
		m.draw_money(int(g.state.wallet_gold), Vector2(19, 83), Pal.L_Y)
