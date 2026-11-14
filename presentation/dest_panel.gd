extends RefCounted
## 目的地面板（准星按钮）：选一个地方，船自动航行过去。没去过的岛显示"未探索"。

const Journey := preload("res://core/journey.gd")
const Pal := preload("res://presentation/palette.gd")

const RECT := Rect2(15, 28, 98, 54)
const ROW_X := 19
const ROW_W := 90
const ROW_Y := 44
const ROW_H := 12
const CLOSE_RECT := Rect2(100, 30, 11, 11)

var open: bool = false
var sel: int = 1
var m

func _init(main) -> void:
	m = main

func open_panel() -> void:
	open = true
	sel = 0 if m.game.at_island_dock() else 1      # 默认选"另一边"

func close() -> void:
	open = false

func _row_rect(i: int) -> Rect2:
	return Rect2(ROW_X, ROW_Y + i * ROW_H - 1, ROW_W, ROW_H)

func _island_name() -> String:
	var g = m.game
	return str(g.island_info().get("name", "")) if g.island_visited() else "未探索"

func act(i: int) -> void:
	var g = m.game
	sel = i
	if i == 0:
		if g.can_go_to_town():
			close()
			m.on_panel_toggled()
			m._go_to_town(true)
		else:
			m.play("deny")
	elif i == 1:                                   # 测试用：点一下瞬间到雾灯岛
		close()
		m.debug_teleport("island")
	else:                                          # 测试用：点一下瞬间到矿山岛
		close()
		m.debug_teleport("isle")

func click(p: Vector2) -> bool:
	if not open or not RECT.has_point(p):
		return false
	if CLOSE_RECT.has_point(p):
		close()
		m.play("click")
		m.on_panel_toggled()
		return true
	for i in 3:
		if _row_rect(i).has_point(p):
			act(i)
	return true

func key(keycode: int) -> void:
	match keycode:
		KEY_UP, KEY_W, KEY_DOWN, KEY_S:
			sel = posmod(sel + (-1 if keycode in [KEY_UP, KEY_W] else 1), 3)
		KEY_SPACE, KEY_ENTER, KEY_E:
			act(sel)

func draw() -> void:
	if not open:
		return
	m.draw_rect(RECT, Pal.U_A)
	m.draw_rect(RECT.grow(-1), Pal.U_K)
	m.label("目的地", Vector2(19, 31), Pal.L_W)
	m.tex_frame("btn_close", CLOSE_RECT.position, 0, 2)
	var names := [m.game.town_name(), _island_name(), "矿山岛"]
	for i in 3:
		if _row_rect(i).has_point(m.menu.hover):
			sel = i                          # 蓝色高亮跟着鼠标走
	for i in 3:
		var r := _row_rect(i)
		if i == sel:
			m.draw_rect(r, Pal.U_A)
			m.draw_rect(r.grow(-1), Pal.U_B)
		var col: Color = Pal.L_W
		if i == 1 and not m.game.island_visited():
			col = Pal.L_A
		m.label(names[i], Vector2(ROW_X + 4, ROW_Y + i * ROW_H), col)
