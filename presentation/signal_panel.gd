extends RefCounted
## 雾灯信号小游戏面板：光点在横条上来回扫，进入光斑时按空格（或点击横条）。
## 逻辑在 core/signal_game.gd，这里只负责画和接收按键。

const Pal := preload("res://presentation/palette.gd")
const SignalGame := preload("res://core/signal_game.gd")
const Money := preload("res://core/money.gd")

const W := 170.0
const H := 88.0

var open: bool = false
var m
var sg
var stage: String = "intro"       # intro / play / done
var grades: Array = []             # 每一轮的结果
var flash_until: int = 0
var reward: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init(main) -> void:
	m = main
	_rng.randomize()

func open_panel() -> void:
	open = true
	stage = "intro"
	grades = []
	reward = {}

func close() -> void:
	open = false

func rect() -> Rect2:
	var br: Rect2 = m.big_rect()
	return Rect2((br.position + (br.size - Vector2(W, H)) / 2.0).round(), Vector2(W, H))

func _close_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 13, r.position.y + 2, 11, 11)

func _bar() -> Rect2:
	var r := rect()
	return Rect2(r.position.x + 12, r.position.y + 34, W - 24, 12)

func _now() -> int:
	return m.game.now_ms()

func _act() -> void:
	var g = m.game
	match stage:
		"intro":
			if g.signal_ready():
				sg = SignalGame.new(g.signal_cfg())
				sg.start(_now(), _rng)
				grades = []
				stage = "play"
				m.play("click")
			else:
				m.play("deny")
		"play":
			var grade: int = sg.press(_now(), _rng)
			grades.append(grade)
			flash_until = Time.get_ticks_msec() + 600
			m.play("rare" if grade == 2 else ("catch" if grade == 1 else "deny"))
			if sg.finished:
				reward = g.signal_finish(sg.good, sg.perfect)
				stage = "done"
				if int(reward.get("gold", 0)) > 0:
					m._float_money(int(reward["gold"]), m.world.cat_pos + Vector2(34, 8))
				m.log.write("signal", {"good": sg.good, "perfect": sg.perfect, "gold": reward.get("gold", 0)})
		"done":
			m.play("click")
			close()
			m.on_panel_toggled()

func click(p: Vector2) -> bool:
	if not open or not rect().has_point(p):
		return false
	if _close_rect().has_point(p):
		close()
		m.play("click")
		m.on_panel_toggled()
	else:
		_act()
	return true

func key(keycode: int) -> void:
	if keycode == KEY_SPACE or keycode == KEY_ENTER or keycode == KEY_E:
		_act()

func draw() -> void:
	if not open:
		return
	var g = m.game
	var R := rect()
	m.draw_rect(R, Pal.U_A)
	m.draw_rect(R.grow(-1), Pal.U_K)
	m.tex_frame("btn_close", _close_rect().position, 0, 2)
	m.label("雾灯信号", Vector2(R.position.x + 8, R.position.y + 6), Pal.L_Y)
	m.draw_rect(Rect2(R.position.x + 8, R.position.y + 18, 40, 1), Pal.L_Y)
	var bar := _bar()
	m.draw_rect(bar.grow(1), Pal.U_A)
	m.draw_rect(bar, Pal.U_B)
	if stage == "play" and sg != null:
		var tw: float = sg.target_w() * bar.size.x
		var cx: float = bar.position.x + sg.target * bar.size.x
		m.draw_rect(Rect2(cx - tw / 2.0, bar.position.y, tw, bar.size.y), Color(Pal.L_Y, 0.55))
		var pw: float = float(g.signal_cfg().get("perfect_w", 0.06)) * bar.size.x
		m.draw_rect(Rect2(cx - pw / 2.0, bar.position.y, pw, bar.size.y), Pal.L_W)
		var mx: float = bar.position.x + sg.marker(_now()) * bar.size.x
		m.draw_rect(Rect2(mx - 1, bar.position.y - 3, 3, bar.size.y + 6), Pal.L_R)
	else:
		for i in 6:
			m.draw_rect(Rect2(bar.position.x + 10 + i * 22, bar.position.y + 5, 8, 2), Color(Pal.L_C, 0.35))
	# 每一轮的结果点
	var n: int = int(g.signal_cfg().get("rounds", 5))
	for i in n:
		var col: Color = Pal.U_A
		if i < grades.size():
			col = [Pal.L_R, Pal.L_G, Pal.L_Y][int(grades[i])]
		m.draw_rect(Rect2(R.position.x + 12 + i * 9, R.position.y + 52, 6, 6), col)
		m.draw_rect(Rect2(R.position.x + 12 + i * 9, R.position.y + 58, 6, 1), Pal.U_K)
	var line_y := R.position.y + 66
	match stage:
		"intro":
			if g.signal_ready():
				m.label_centered("按空格对准光斑", R.position.x + W / 2.0, line_y, Pal.L_W)
			else:
				m.label_centered("信号灯在冷却", R.position.x + W / 2.0, line_y, Pal.L_R)
				m.text("%d:%02d" % [g.signal_wait_s() / 60, g.signal_wait_s() % 60], Vector2(R.position.x + W / 2.0 + 40, line_y + 2), Pal.L_W)
		"play":
			if Time.get_ticks_msec() < flash_until and not grades.is_empty():
				var gr: int = int(grades[-1])
				m.label_centered(["没对上", "命中", "正中"][gr], R.position.x + W / 2.0, line_y, [Pal.L_R, Pal.L_G, Pal.L_Y][gr])
			else:
				m.label_centered("按空格对准光斑", R.position.x + W / 2.0, line_y, Pal.L_W)
		"done":
			m.label_centered("亮灯成功", R.position.x + 100.0, R.position.y + 50, Pal.L_Y)
			var gold: int = int(reward.get("gold", 0))
			m.draw_texture(m.tex[Money.icon(gold)], Vector2(R.position.x + 80, R.position.y + 63))
			m.text("+%d" % int(Money.tier(gold)[1]), Vector2(R.position.x + 98, R.position.y + 66), Pal.L_W)
			if bool(reward.get("shell", false)):
				m.draw_texture(m.tex["item_lamp_shell"], Vector2(R.position.x + 130, R.position.y + 61))
