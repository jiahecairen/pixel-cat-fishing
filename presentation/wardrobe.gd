extends RefCounted
## 捏猫面板：选毛色、花纹、帽子。首次启动自动弹出，之后点 HUD 上的小猫按钮打开。
## 和 menu.gd 一样借用主节点 m 的绘制方法。

const Pal := preload("res://presentation/palette.gd")

const RECT := Rect2(15, 28, 98, 66)
## 开发者模式（按 ` 键）：随便换毛色、花纹、帽子、衣服，不花钱，也不影响已买的东西。首次启动捏猫也用这块面板。
## [存档里的键, cat.json 里的列表名]
const ROWS := [["fur", "furs"], ["pattern", "patterns"], ["hat", "hats"], ["outfit", "outfits"]]
const ROW_Y := 44
const ROW_H := 10
const DONE_RECT := Rect2(25, 82, 25, 10)

var open: bool = false
var dev: bool = false
var m

func _init(main) -> void:
	m = main

func _left(row: int) -> Rect2:
	return Rect2(57, ROW_Y + row * ROW_H - 1, 11, 11)

func _right(row: int) -> Rect2:
	return Rect2(100, ROW_Y + row * ROW_H - 1, 11, 11)

func close() -> void:
	open = false
	dev = false
	if not m.game.state.cat.get("created", false):
		m.game.state.cat["created"] = true
		m.game.dirty = true

func click(p: Vector2) -> bool:
	if not open or not RECT.has_point(p):
		return false
	for i in ROWS.size():
		var dir := 0
		if _left(i).has_point(p):
			dir = -1
		elif _right(i).has_point(p):
			dir = 1
		if dir != 0:
			var key: String = ROWS[i][0]
			var n: int = m.cat_cfg[ROWS[i][1]].size()
			m.game.state.cat[key] = posmod(int(m.game.state.cat.get(key, 0)) + dir, n)
			m.game.dirty = true
			m.play("click")
	if DONE_RECT.has_point(p):
		m.play("buy")
		close()
		m.on_panel_toggled()
	return true

func draw() -> void:
	if not open:
		return
	var cat: Dictionary = m.game.state.cat
	m.draw_rect(RECT, Pal.U_A)
	m.draw_rect(RECT.grow(-1), Pal.U_K)
	m.label("开发者模式" if dev else ("我的小猫" if cat.get("created", false) else "给小猫选个样子"), Vector2(19, 31), Pal.L_W)
	# 预览：天空 + 水面小景
	m.draw_rect(Rect2(19, 44, 36, 36), Pal.L_C)
	m.draw_rect(Rect2(19, 72, 36, 8), Pal.L_B)
	m.draw_rect(Rect2(19, 72, 36, 1), Pal.U_W)
	m.draw_cat(Vector2(21, 44), (Time.get_ticks_msec() / 700) % 2)
	for i in ROWS.size():
		var y: int = ROW_Y + i * ROW_H
		var list: Array = m.cat_cfg[ROWS[i][1]]
		var item: Dictionary = list[posmod(int(cat.get(ROWS[i][0], 0)), list.size())]
		m.tex_frame("btn_left", _left(i).position, 0, 2)
		m.tex_frame("btn_right", _right(i).position, 0, 2)
		m.label_centered(item["name"], 84, y, Pal.L_W)
	m.draw_rect(DONE_RECT, Pal.L_G)
	m.draw_rect(Rect2(DONE_RECT.position.x, DONE_RECT.end.y - 1, DONE_RECT.size.x, 1), Pal.U_G)
	m.label_centered("完成", DONE_RECT.position.x + 13, DONE_RECT.position.y - 1, Pal.U_K)
