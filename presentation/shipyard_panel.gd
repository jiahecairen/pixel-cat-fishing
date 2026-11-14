extends RefCounted
## 造船厂的升级面板：一排船只，一级一级买；买到的船让左边的浪区变小，能划得更远。
## 数值（名字、价格、浪区范围）来自 data/balance.json 的 water.boat_levels。

const Pal := preload("res://presentation/palette.gd")

const ROW_H := 22
const PREVIEW_W := 92

var open: bool = false
var sel: int = 1
var note: String = ""
var note_ok: bool = false
var note_t0: int = -100000
var m

func _init(main) -> void:
	m = main

func open_panel() -> void:
	open = true
	sel = mini_sel()

func mini_sel() -> int:
	var g = m.game
	return mini_clamp(int(g.state.boat_level) + 1)

func mini_clamp(i: int) -> int:
	return clampi(i, 0, maxi(0, m.game.boat_levels().size() - 1))

func close() -> void:
	open = false

## 面板占满窗口：左边是选中那艘船的样子，右边一排船只。
func rect() -> Rect2:
	return m.big_rect()

func _close_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 13, r.position.y + 2, 11, 11)

func _list_x() -> float:
	return rect().position.x + 10.0 + PREVIEW_W + 10.0

func _row_rect(i: int) -> Rect2:
	var r := rect()
	return Rect2(_list_x(), r.position.y + 22 + i * ROW_H, r.end.x - 8 - _list_x(), ROW_H - 2)

func _say(text: String, ok: bool) -> void:
	note = text
	note_ok = ok
	note_t0 = Time.get_ticks_msec()

## 对第 i 级船做"买下"。
func act(i: int) -> void:
	var g = m.game
	if i < 0 or i >= g.boat_levels().size():
		return
	sel = i
	var cur: int = int(g.state.boat_level)
	if i <= cur:
		m.play("click")
	elif i > cur + 1:
		_say("先买前一级", false)
		m.play("deny")
	elif g.buy_boat_upgrade(i):
		m.play("buy")
		m.log.write("boat_upgrade", {"level": i})
		_say("能过浪区了", true)
	else:
		_say("金币不够", false)
		m.play("deny")

func click(p: Vector2) -> bool:
	if not open or not rect().has_point(p):
		return false
	if _close_rect().has_point(p):
		close()
		m.play("click")
		m.on_panel_toggled()
		return true
	for i in m.game.boat_levels().size():
		if _row_rect(i).has_point(p):
			act(i)
	return true

func key(keycode: int) -> void:
	var n: int = m.game.boat_levels().size()
	match keycode:
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
	var R := rect()
	m.draw_rect(R, Pal.U_A)
	m.draw_rect(R.grow(-1), Pal.U_K)
	m.label("造船厂", R.position + Vector2(6, 4), Pal.L_W)
	m.tex_frame("btn_close", _close_rect().position, 0, 2)
	var cur: int = int(g.state.boat_level)
	var levels: Array = g.boat_levels()
	# 左边：选中的那艘船，浮在水面上
	var box := Rect2(R.position.x + 10, R.position.y + 22, PREVIEW_W, 66)
	m.draw_rect(box, Pal.L_C)
	m.draw_rect(Rect2(box.position.x, box.position.y + 40, box.size.x, 26), Pal.L_B)
	m.draw_rect(Rect2(box.position.x, box.position.y + 40, box.size.x, 1), Pal.U_W)
	var bt: String = "boat" if sel <= 0 else "boat_%d" % clampi(sel, 0, 3)
	if m.tex.has(bt):
		var bx: float = box.position.x + (PREVIEW_W - float(m.tex[bt].get_width())) / 2.0
		m.draw_texture(m.tex[bt], Vector2(bx, box.position.y + 28))
		m.draw_texture(m.tex["boat_head"], Vector2(bx - 2, box.position.y + 11))
		m.draw_rect(Rect2(bx + 4, box.position.y + 40, float(m.tex[bt].get_width()) - 8, 1), Pal.L_W)      # 水线
	for i in levels.size():
		var r := _row_rect(i)
		if i == sel:
			m.draw_rect(r, Pal.U_A)
			m.draw_rect(r.grow(-1), Pal.U_B)
		var ty := r.position.y + 5
		m.label(str(levels[i]["name"]), Vector2(r.position.x + 5, ty), Pal.L_W if i <= cur else Pal.L_A)
		var rx := R.end.x - 14.0
		if i == cur:
			m.label("使用中", Vector2(rx - m.label_width("使用中"), ty), Pal.L_G)
		elif i < cur:
			m.label("已有", Vector2(rx - m.label_width("已有"), ty), Pal.L_A)
		else:
			var price: int = g.boat_price(i)
			var col: Color = Pal.L_A
			if i == cur + 1:
				col = Pal.L_Y if g.state.wallet_gold >= price else Pal.L_R
			m.money_full_right(price, rx, ty + 3, col)
	var by := R.end.y - 15.0
	if Time.get_ticks_msec() - note_t0 < 1500:
		m.label(note, Vector2(R.position.x + 10, by), Pal.L_G if note_ok else Pal.L_R)
	else:
		m.draw_money_full(int(g.state.wallet_gold), Vector2(R.position.x + 10, by + 1), Pal.L_Y)
