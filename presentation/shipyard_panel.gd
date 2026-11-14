extends RefCounted
## 造船厂的升级面板：一排船只，一级一级买；买到的船让左边的浪区变小，能划得更远。
## 数值（名字、价格、浪区范围）来自 data/balance.json 的 water.boat_levels。

const Pal := preload("res://presentation/palette.gd")

const RECT := Rect2(15, 28, 98, 66)
const ROW_X := 19
const ROW_W := 90
const ROW_Y := 42
const ROW_H := 10
const CLOSE_RECT := Rect2(100, 30, 11, 11)

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

func _row_rect(i: int) -> Rect2:
	return Rect2(ROW_X, ROW_Y + i * ROW_H - 1, ROW_W, ROW_H)

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
		_say("浪区变小了", true)
	else:
		_say("金币不够", false)
		m.play("deny")

func click(p: Vector2) -> bool:
	if not open or not RECT.has_point(p):
		return false
	if CLOSE_RECT.has_point(p):
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
	m.draw_rect(RECT, Pal.U_A)
	m.draw_rect(RECT.grow(-1), Pal.U_K)
	m.label("造船厂", Vector2(19, 31), Pal.L_W)
	m.tex_frame("btn_close", CLOSE_RECT.position, 0, 2)
	var cur: int = int(g.state.boat_level)
	var levels: Array = g.boat_levels()
	for i in levels.size():
		var y: int = ROW_Y + i * ROW_H
		var r := _row_rect(i)
		if i == sel:
			m.draw_rect(r, Pal.U_A)
			m.draw_rect(r.grow(-1), Pal.U_B)
		m.label(str(levels[i]["name"]), Vector2(ROW_X + 3, y), Pal.L_W if i <= cur else Pal.L_A)
		if i == cur:
			m.label("使用中", Vector2(ROW_X + ROW_W - 33, y), Pal.L_G)
		elif i < cur:
			m.label("已有", Vector2(ROW_X + ROW_W - 23, y), Pal.L_A)
		else:
			var price: int = g.boat_price(i)
			var col: Color = Pal.L_A
			if i == cur + 1:
				col = Pal.L_Y if g.state.wallet_gold >= price else Pal.L_R
			m.money_full_right(price, ROW_X + ROW_W - 3, y + 3, col)
	if Time.get_ticks_msec() - note_t0 < 1500:
		m.label(note, Vector2(19, 83), Pal.L_G if note_ok else Pal.L_R)
	else:
		m.draw_money_full(int(g.state.wallet_gold), Vector2(19, 83), Pal.L_Y)
