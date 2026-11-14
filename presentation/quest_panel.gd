extends RefCounted
## 支线任务面板：读漂流瓶里的信（letter），或在渔具店和店主说话（talk）。
## 文字都在 data/balance.json 的 quests 里；借用主节点 m 的绘制方法。

const Pal := preload("res://presentation/palette.gd")


var open: bool = false
var mode: String = "talk"      # "letter" / "talk"
var qid: String = "keeper"
var just_done: bool = false     # 刚交付完：这次面板里还念"交接的话"，下次聊天就是默认的话
var m

func _init(main) -> void:
	m = main

func open_letter(id: String) -> void:
	qid = id
	mode = "letter"
	open = true

func open_talk(id: String) -> void:
	qid = id
	m.game.begin_talk_quest(id)
	just_done = false
	mode = "talk"
	open = true

func close() -> void:
	open = false

## 面板上的主按钮：交付（满足条件时）或关闭。
func _press() -> void:
	var g = m.game
	if mode == "talk" and g.quest_state(qid) == "active":
		if g.turn_in(qid):
			just_done = true
			m.play("rare")
			m.log.write("quest_done", {"quest": qid})
		else:
			m.play("deny")
		return
	m.play("click")
	close()
	m.on_panel_toggled()

## 完整窗口里占满窗口；迷你窗里（读漂流瓶的信）还是小面板。
func rect() -> Rect2:
	return Rect2(15, 28, 98, 66) if m.mini else m.big_rect()

func _close_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 13, r.position.y + 2, 11, 11)

func _btn_rect() -> Rect2:
	var r := rect()
	if m.mini:
		return Rect2(76, 83, 33, 10)
	return Rect2(r.end.x - 52, r.end.y - 20, 44, 14)

func click(p: Vector2) -> bool:
	if not open or not rect().has_point(p):
		return false
	if _close_rect().has_point(p):
		close()
		m.play("click")
		m.on_panel_toggled()
	elif _btn_rect().has_point(p):
		_press()
	return true

func key(keycode: int) -> void:
	if keycode == KEY_SPACE or keycode == KEY_ENTER or keycode == KEY_E:
		_press()

func _lines(ls: Array, x: float, y0: float) -> float:
	var y := y0
	for l in ls:
		m.label(str(l), Vector2(x, y), Pal.L_W)
		y += 10.0 if m.mini else 14.0
	return y

func draw() -> void:
	if not open:
		return
	var g = m.game
	var q: Dictionary = g.quest_cfg(qid)
	var R := rect()
	var x := R.position.x + (4.0 if m.mini else 12.0)
	var mini: bool = m.mini
	m.draw_rect(R, Pal.U_A)
	m.draw_rect(R.grow(-1), Pal.U_K)
	m.tex_frame("btn_close", _close_rect().position, 0, 2)
	var btn := "好"
	var btn_on := true
	if mode == "letter":
		_lines(q.get("letter_lines", []), x, R.position.y + (3 if mini else 8))
	else:
		var st: String = g.quest_state(qid)
		m.label("看守的心愿" if str(q.get("npc", "")) == "lighthouse" else "店主的心愿", Vector2(x, R.position.y + (3 if mini else 6)), Pal.L_Y)
		var y0 := R.position.y + (16.0 if mini else 26.0)
		if not mini:
			m.draw_rect(Rect2(x, R.position.y + 18, 60, 1), Pal.L_Y)
		if st == "":
			_lines(q.get("idle_lines", []), x, y0)
		elif st == "done":
			if just_done:
				_lines(q.get("done_lines", []), x, y0)
			else:      # 任务早就完成了：店主说平常的话
				_lines(g.shop_chat(str(q.get("npc", ""))), x, y0)
		else:
			var y := _lines(q.get("talk_lines", []), x, y0 - (3.0 if mini else 0.0)) + (1.0 if mini else 4.0)
			for n in g.quest_needs(qid):
				var it: Dictionary = g.inventory.by_id.get(str(n[0]), {})
				var enough: bool = int(n[1]) >= int(n[2])
				if not mini and m.tex.has(str(it.get("sprite", ""))):
					m.draw_texture(m.tex[it["sprite"]], Vector2(x, y - 3))
				m.label(str(it.get("name", "")), Vector2(x + (0 if mini else 20), y), Pal.L_W)
				m.text_right("%d/%d" % [int(n[1]), int(n[2])], (R.end.x - 5.0) if mini else x + 150.0, y + 3.0, Pal.L_G if enough else Pal.L_R)
				y += 10.0 if mini else 18.0
			btn = "交付"
			btn_on = g.can_turn_in(qid)
	var br := _btn_rect()
	m.draw_rect(br, Pal.L_G if btn_on else Pal.U_A)
	m.draw_rect(Rect2(br.position.x, br.end.y - 2, br.size.x, 2), Pal.U_G if btn_on else Pal.U_K)
	m.label_centered(btn, br.position.x + br.size.x / 2.0, br.position.y + (-1 if mini else 1), Pal.U_K if btn_on else Pal.L_A)
