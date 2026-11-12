extends Node2D
## 表现层入口：把 core 的状态画成像素画面，把鼠标操作翻译成 core 的指令。
## 所有坐标以"美术像素"为单位（画布 128×96），整个节点按整数倍放大，保证像素不糊。

const Game := preload("res://core/game.gd")
const GameState := preload("res://core/game_state.gd")
const Clock := preload("res://core/clock.gd")
const Fishing := preload("res://core/fishing_system.gd")
const Pomodoro := preload("res://core/pomodoro.gd")
const ConfigLoader := preload("res://io/config_loader.gd")
const SaveService := preload("res://io/save_service.gd")
const Platform := preload("res://platform/platform.gd")
const Pal := preload("res://presentation/palette.gd")

const ART := Vector2i(128, 96)
const FONT_ORDER := "0123456789:/+x-"
const FPS_NORMAL := 30
const FPS_DRAG := 60

# ---- 布局（美术像素） ----
const PANEL_POS := Vector2(15, 1)
const BTN_MAIN := Rect2(78, 3, 11, 11)
const BTN_SELL := Rect2(89, 3, 11, 11)
const BTN_CLOSE := Rect2(100, 3, 11, 11)
const DRAG_RECT := Rect2(30, 28, 90, 66)
const WATER_POS := Vector2(2, 73)
const BOAT_POS := Vector2(34, 62)
const CAT_POS := Vector2(44, 39)
const BOBBER_POS := Vector2(108, 70)
const HAND := Vector2(21, 22)
const TIP_IDLE := Vector2(33, 6)
const TIP_WAIT := Vector2(38, 12)
const TIP_REEL := Vector2(30, 2)

var game: Game
var adapter
var saver: SaveService
var tex: Dictionary = {}
var px_scale: int = 3
var floats: Array = []          # 飘字: {text, icon, pos, t0}
var _pressed_btn: String = ""
var _dragging: bool = false
var _last_win_pos := Vector2i.ZERO
var _pos_stable_since: int = 0
var _config_ok: bool = true
var _clock: Clock
var _debug_speed: float = 1.0   # 调试：环境变量 CATFISH_SPEED=60 让时间快 60 倍（仅调试版生效）
var _debug_last_state: int = -1


func _ready() -> void:
	var balance := ConfigLoader.load_balance()
	var fish := ConfigLoader.load_fish()
	if balance.is_empty() or fish.is_empty():
		_config_ok = false
		push_error("配置加载失败，游戏无法启动。请检查 data/*.json")
		get_tree().quit(1)
		return

	saver = SaveService.new()
	var state := GameState.new()
	var saved := saver.load_data()
	if not saved.is_empty() and not state.from_dict(saved):
		push_warning("存档版本不兼容，已使用新存档（旧档保留为 .bak）")
		state = GameState.new()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_clock = Clock.new()
	game = Game.new(balance, fish, state, _clock, rng)
	if OS.is_debug_build():
		if OS.has_environment("CATFISH_SPEED"):
			_debug_speed = maxf(1.0, OS.get_environment("CATFISH_SPEED").to_float())
		if OS.has_environment("CATFISH_AUTOFOCUS"):
			game.start_focus()

	for n in ["cat", "boat", "water", "tomato", "coin", "basket", "bobber", "bang", "zzz",
			"font", "dots", "panel", "btn_play", "btn_stop", "btn_sell", "btn_skip", "btn_close"]:
		tex[n] = load("res://assets/sprites/%s.png" % n)
	for f in fish:
		tex[f["sprite"]] = load("res://assets/sprites/%s.png" % f["sprite"])

	adapter = Platform.create()
	var win := get_window()
	px_scale = adapter.pixel_scale(int(state.settings.get("pixel_scale", 3)))
	adapter.setup_window(win, ART, px_scale)
	adapter.set_fps(FPS_NORMAL)
	if adapter.is_overlay():
		scale = Vector2(px_scale, px_scale)
		var pos: Vector2i = adapter.default_position(win)
		if state.window.get("has_pos", false):
			pos = adapter.clamp_position(win, Vector2i(int(state.window["x"]), int(state.window["y"])))
		win.position = pos
		_last_win_pos = pos
		adapter.set_interactive_polygon(win, _interactive_polygon())
	get_tree().auto_accept_quit = false


func _interactive_polygon() -> PackedVector2Array:
	# 上面是 HUD 面板，下面是猫/船/水面；两块拼成一个多边形，其余透明区域鼠标穿透
	var p := PANEL_POS
	var d := DRAG_RECT
	var pts := PackedVector2Array([
		p, Vector2(p.x + 98, p.y), Vector2(p.x + 98, d.position.y), Vector2(d.end.x, d.position.y),
		d.end, Vector2(d.position.x, d.end.y), d.position, Vector2(p.x, d.position.y),
	])
	for i in pts.size():
		pts[i] *= px_scale
	return pts


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _quit() -> void:
	_save()
	get_tree().quit()


func _save() -> void:
	if game == null:
		return
	if saver.save(game.state.to_dict()):
		game.dirty = false


func _process(dt: float) -> void:
	if not _config_ok:
		return
	if _debug_speed > 1.0:
		_clock.debug_offset_ms += dt * 1000.0 * (_debug_speed - 1.0)
	for e in game.tick():
		_on_event(e)
		if _debug_speed > 1.0:
			print("[debug] frame %d event %s" % [Engine.get_frames_drawn(), str(e)])
	if _debug_speed > 1.0 and game.fishing.state != _debug_last_state:
		_debug_last_state = game.fishing.state
		print("[debug] frame %d fishing=%s" % [Engine.get_frames_drawn(), Fishing.State.keys()[_debug_last_state]])
	_track_window()
	if game.dirty:
		_save()
	if not adapter.is_overlay():
		_fit_fullscreen()
	queue_redraw()


func _fit_fullscreen() -> void:
	var vs := get_viewport_rect().size
	px_scale = max(1, int(min(vs.x / ART.x, vs.y / ART.y)))
	scale = Vector2(px_scale, px_scale)
	position = ((vs - Vector2(ART * px_scale)) / 2.0).floor()


func _track_window() -> void:
	if not adapter.is_overlay():
		return
	var now := Time.get_ticks_msec()
	var pos := get_window().position
	if pos != _last_win_pos:
		_last_win_pos = pos
		_pos_stable_since = now
		game.state.window = {"has_pos": true, "x": pos.x, "y": pos.y}
	elif _dragging and now - _pos_stable_since > 500 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# 原生拖动结束时可能收不到松开事件，用"位置稳定 + 左键已松"兜底
		_dragging = false
		adapter.set_fps(FPS_NORMAL)
		game.dirty = true


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		"catch":
			pass   # 鱼的上钩动画由钓鱼状态直接驱动
		"focus_done":
			_float("+%d" % e["gold"], "coin", Vector2(36, 31))
			adapter.notify("番茄完成！", "钓到 %d 条鱼，获得 %d 金币。休息一下吧。" % [e["fish_count"], e["gold"]])
		"break_done":
			adapter.notify("休息结束", "小猫睡醒了，准备开始下一个番茄吧。")
		"basket_full":
			adapter.notify("鱼篓满了", "卖掉鱼，或者开始一个番茄让小猫继续钓。")


func _float(text: String, icon: String, pos: Vector2) -> void:
	floats.append({"text": text, "icon": icon, "pos": pos, "t0": Time.get_ticks_msec()})


# ------------------------------------------------------------------ 输入
func _unhandled_input(event: InputEvent) -> void:
	if not _config_ok or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = (event.position - position) / float(px_scale)
	if not event.pressed:
		_pressed_btn = ""
		return
	if BTN_MAIN.has_point(p):
		_pressed_btn = "main"
		_press_main()
	elif BTN_SELL.has_point(p):
		_pressed_btn = "sell"
		var gold := game.sell_basket()
		if gold > 0:
			_float("+%d" % gold, "coin", Vector2(36, 31))
	elif BTN_CLOSE.has_point(p):
		_quit()
	elif DRAG_RECT.has_point(p):
		if adapter.start_window_drag(get_window()):
			_dragging = true
			_pos_stable_since = Time.get_ticks_msec()
			adapter.set_fps(FPS_DRAG)


func _press_main() -> void:
	match game.pomodoro.phase():
		Pomodoro.Phase.IDLE:
			game.start_focus()
		Pomodoro.Phase.FOCUS:
			var gold := game.abandon_focus()
			if gold > 0:
				_float("+%d" % gold, "coin", Vector2(36, 31))
		_:
			game.skip_break()


# ------------------------------------------------------------------ 绘制
func _draw() -> void:
	if game == null:
		return
	var now := game.now_ms()
	var t := Time.get_ticks_msec()
	if not adapter.is_overlay():
		draw_rect(Rect2(Vector2.ZERO, ART), Pal.L_C)
	var bob := Vector2(0, 1 if (t / 900) % 2 == 0 else 0)
	var on_break: bool = game.pomodoro.is_break()
	var fs: int = game.fishing.state
	var prog: float = game.fishing.progress(now)

	_tex_frame("water", WATER_POS, (t / 600) % 3, 3)
	var cat_pos := CAT_POS + bob
	var frame := (2 + (t / 1100) % 2) if on_break else (t / 700) % 2
	_tex_frame("cat", cat_pos, frame, 4)

	draw_texture(tex["boat"], BOAT_POS + bob)
	if on_break:
		draw_texture(tex["zzz"], cat_pos + Vector2(32, -2 - (t / 500) % 3))
	else:
		_draw_fishing(cat_pos, fs, prog, t)
	_draw_hud(now)
	_draw_floats(t)


func _draw_fishing(cat_pos: Vector2, fs: int, prog: float, t: int) -> void:
	var tip := TIP_IDLE
	var bobber := Vector2.INF     # INF = 不画浮漂
	var fish_tex: Texture2D = null
	var fish_pos := Vector2.ZERO
	var water_bob := Vector2(0, (t / 800) % 2)
	match fs:
		Fishing.State.CASTING:
			tip = TIP_IDLE.lerp(TIP_WAIT, prog)
			if prog > 0.4:
				var k := (prog - 0.4) / 0.6
				var from := cat_pos + tip
				bobber = (from.lerp(BOBBER_POS, k) + Vector2(0, -10.0 * sin(k * PI))).round()
		Fishing.State.WAITING:
			tip = TIP_WAIT
			bobber = BOBBER_POS + water_bob
		Fishing.State.HOOKED:
			tip = TIP_WAIT + Vector2(1, 2)
			bobber = BOBBER_POS + Vector2((t / 80) % 2, 3)
			draw_texture(tex["bang"], cat_pos + Vector2(24, -12))
		Fishing.State.REELING:
			tip = TIP_WAIT.lerp(TIP_REEL, minf(1.0, prog * 2.0))
			fish_tex = _fish_tex()
			fish_pos = (BOBBER_POS.lerp(cat_pos + TIP_REEL + Vector2(-6, 8), prog)).round()
		Fishing.State.SETTLEMENT:
			tip = TIP_REEL.lerp(TIP_IDLE, prog)
			fish_tex = _fish_tex()
			fish_pos = (cat_pos + Vector2(8, -12 - 6.0 * prog)).round()
	var tip_abs := (cat_pos + tip).round()
	_pixel_line(cat_pos + HAND, tip_abs, Pal.U_O)
	if bobber != Vector2.INF:
		_pixel_line(tip_abs, bobber + Vector2(2, 0), Pal.L_W)
		draw_texture(tex["bobber"], bobber)
	if fish_tex != null:
		if fs == Fishing.State.REELING:
			_pixel_line(tip_abs, fish_pos + Vector2(16, 5), Pal.L_W)
		draw_texture(fish_tex, fish_pos)


func _fish_tex() -> Texture2D:
	var f: Dictionary = game.fish_by_id.get(game.fishing.hooked_fish, {})
	return tex.get(f.get("sprite", ""), null)


func _draw_hud(now: int) -> void:
	draw_texture(tex["panel"], PANEL_POS)
	var ph: int = game.pomodoro.phase()
	var on_break: bool = game.pomodoro.is_break()
	draw_texture(tex["zzz" if on_break else "tomato"], Vector2(19, 3))
	var secs := int(ceil(game.pomodoro.remaining_ms(now) / 1000.0))
	var tint := Pal.L_C if on_break else (Pal.L_W if ph == Pomodoro.Phase.FOCUS else Pal.L_A)
	_text("%02d:%02d" % [secs / 60, secs % 60], Vector2(32, 6), tint)
	for i in game.pomodoro.cycle_length():
		_tex_frame("dots", Vector2(55 + i * 6, 6), 1 if i < game.pomodoro.cycle_done() else 0, 2)

	var main_btn := "btn_play"
	if ph == Pomodoro.Phase.FOCUS:
		main_btn = "btn_stop"
	elif on_break:
		main_btn = "btn_skip"
	_tex_frame(main_btn, BTN_MAIN.position, 1 if _pressed_btn == "main" else 0, 2)
	var can_sell: bool = not game.state.basket.is_empty()
	_tex_frame("btn_sell", BTN_SELL.position, 1 if _pressed_btn == "sell" else 0, 2,
			Color.WHITE if can_sell else Color(1, 1, 1, 0.35))
	_tex_frame("btn_close", BTN_CLOSE.position, 0, 2)

	draw_texture(tex["coin"], Vector2(20, 15))
	_text(str(game.state.wallet_gold), Vector2(31, 17), Pal.L_Y)
	draw_texture(tex["basket"], Vector2(56, 14))
	if ph == Pomodoro.Phase.FOCUS:
		_text("x%d" % game.state.session_haul.size(), Vector2(69, 17), Pal.L_W)
	else:
		var full: bool = game.economy.basket_full(game.state)
		_text("%d/%d" % [game.state.basket.size(), game.state.basket_capacity], Vector2(69, 17),
				Pal.L_R if full else Pal.L_W)


func _draw_floats(t: int) -> void:
	var keep: Array = []
	for f in floats:
		var age: int = t - int(f["t0"])
		if age < 2500:
			keep.append(f)
			var pos: Vector2 = f["pos"] + Vector2(0, -int(age / 180))
			draw_texture(tex[f["icon"]], pos)
			_text(f["text"], pos + Vector2(11, 2), Pal.L_Y, true)
	floats = keep


# ---- 绘制小工具 ----
func _tex_frame(name: String, pos: Vector2, frame: int, count: int, mod := Color.WHITE) -> void:
	var tx: Texture2D = tex[name]
	var w := tx.get_width() / count
	draw_texture_rect_region(tx, Rect2(pos, Vector2(w, tx.get_height())),
			Rect2(frame * w, 0, w, tx.get_height()), mod)


func _text(s: String, pos: Vector2, color: Color, shadow := false) -> void:
	for pass_i in (2 if shadow else 1):
		var x := pos.x
		var is_shadow := shadow and pass_i == 0
		for ch in s:
			var i := FONT_ORDER.find(ch)
			if i >= 0:
				var at := Vector2(x, pos.y) + (Vector2(1, 1) if is_shadow else Vector2.ZERO)
				draw_texture_rect_region(tex["font"], Rect2(at, Vector2(3, 5)), Rect2(i * 4, 0, 3, 5),
						Pal.U_K if is_shadow else color)
			x += 4


## 逐像素画线（Bresenham），保证斜线也是整齐的像素台阶。
func _pixel_line(a: Vector2, b: Vector2, color: Color) -> void:
	var x0 := int(a.x); var y0 := int(a.y)
	var x1 := int(b.x); var y1 := int(b.y)
	var dx := absi(x1 - x0); var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		draw_rect(Rect2(x0, y0, 1, 1), color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy; x0 += sx
		if e2 <= dx:
			err += dx; y0 += sy
