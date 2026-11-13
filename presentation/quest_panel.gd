extends RefCounted
## 支线任务面板：读漂流瓶里的信（letter），或在渔具店和店主说话（talk）。
## 文字都在 data/balance.json 的 quests 里；借用主节点 m 的绘制方法。

const Pal := preload("res://presentation/palette.gd")

const RECT := Rect2(15, 28, 98, 66)
const CLOSE_RECT := Rect2(100, 30, 11, 11)
const BTN_RECT := Rect2(76, 83, 33, 10)

var open: bool = false
var mode: String = "talk"      # "letter" / "talk"
var qid: String = "keeper"
var m

func _init(main) -> void:
	m = main

func open_letter(id: String) -> void:
	qid = id
	mode = "letter"
	open = true

func open_talk(id: String) -> void:
	qid = id
	mode = "talk"
	open = true

func close() -> void:
	open = false

## 面板上的主按钮：交付（满足条件时）或关闭。
func _press() -> void:
	var g = m.game
	if mode == "talk" and g.quest_state(qid) == "active":
		if g.turn_in(qid):
			m.play("rare")
			m.log.write("quest_done", {"quest": qid})
		else:
			m.play("deny")
		return
	m.play("click")
	close()
	m.on_panel_toggled()

func click(p: Vector2) -> bool:
	if not open or not RECT.has_point(p):
		return false
	if CLOSE_RECT.has_point(p):
		close()
		m.play("click")
		m.on_panel_toggled()
	elif BTN_RECT.has_point(p):
		_press()
	return true

func key(keycode: int) -> void:
	if keycode == KEY_SPACE or keycode == KEY_ENTER or keycode == KEY_E:
		_press()

func _lines(ls: Array, y0: float) -> float:
	var y := y0
	for l in ls:
		m.label(str(l), Vector2(19, y), Pal.L_W)
		y += 10.0
	return y

func draw() -> void:
	if not open:
		return
	var g = m.game
	var q: Dictionary = g.quest_cfg(qid)
	m.draw_rect(RECT, Pal.U_A)
	m.draw_rect(RECT.grow(-1), Pal.U_K)
	m.tex_frame("btn_close", CLOSE_RECT.position, 0, 2)
	var btn := "好"
	var btn_on := true
	if mode == "letter":
		_lines(q.get("letter_lines", []), 31.0)
	else:
		var st: String = g.quest_state(qid)
		m.label("店主的心愿", Vector2(19, 31), Pal.L_Y)
		if st == "":
			_lines(q.get("idle_lines", []), 44.0)
		elif st == "done":
			_lines(q.get("done_lines", []), 44.0)
		else:
			var y := _lines(q.get("talk_lines", []), 41.0) + 1.0
			for n in g.quest_needs(qid):
				var it: Dictionary = g.inventory.by_id.get(str(n[0]), {})
				var enough: bool = int(n[1]) >= int(n[2])
				m.label(str(it.get("name", "")), Vector2(19, y), Pal.L_W)
				m.text_right("%d/%d" % [int(n[1]), int(n[2])], 108.0, y + 3.0, Pal.L_G if enough else Pal.L_R)
				y += 10.0
			btn = "交付"
			btn_on = g.can_turn_in(qid)
	m.draw_rect(BTN_RECT, Pal.L_G if btn_on else Pal.U_A)
	m.draw_rect(Rect2(BTN_RECT.position.x, BTN_RECT.end.y - 1, BTN_RECT.size.x, 1), Pal.U_G if btn_on else Pal.U_K)
	m.label_centered(btn, BTN_RECT.position.x + BTN_RECT.size.x / 2.0, BTN_RECT.position.y - 1, Pal.U_K if btn_on else Pal.L_A)
