extends Node2D
## 表现层入口：把 core 的状态画成像素画面，把鼠标操作翻译成 core 的指令。
##
## 同一个横版世界有两种视图：
##   全画面  普通窗口，取景随窗口大小变化（至少 180 像素高），镜头跟着小猫
##   迷你    桌面透明悬浮窗，固定 128×96，只取小猫周围一小块，透明区域鼠标穿透
## 所有坐标以"美术像素"为单位，整个节点按整数倍放大，保证像素不糊。
## 三套坐标：世界坐标（world.gd）、界面坐标（HUD/菜单，原点在 ui_off）、视图坐标（窗口内的美术像素）。

const Game := preload("res://core/game.gd")
const GameState := preload("res://core/game_state.gd")
const Clock := preload("res://core/clock.gd")
const Fishing := preload("res://core/fishing_system.gd")
const Pomodoro := preload("res://core/pomodoro.gd")
const Journey := preload("res://core/journey.gd")
const ConfigLoader := preload("res://io/config_loader.gd")
const SaveService := preload("res://io/save_service.gd")
const EventLog := preload("res://io/event_log.gd")
const Platform := preload("res://platform/platform.gd")
const Pal := preload("res://presentation/palette.gd")
const Labels := preload("res://presentation/labels.gd")
const Menu := preload("res://presentation/menu.gd")
const Wardrobe := preload("res://presentation/wardrobe.gd")
const World := preload("res://presentation/world.gd")
const Bag := preload("res://presentation/bag.gd")

const MINI_VIEW := Vector2i(128, 96)
const FULL_MIN_H := 180          # 全画面至少能看到这么高的世界
const FULL_MIN_W := 256
const FULL_DEFAULT := Vector2i(960, 540)
const FONT_ORDER := "0123456789:/+x-"
const FPS_NORMAL := 30
const FPS_DRAG := 60
const SFX := ["click", "cast", "bite", "reel", "catch", "rare", "coin", "buy", "deny", "done", "break_end"]
const VOLUME_DB := [-80.0, -22.0, -12.0, -5.0]   # 音效档位 0(静音)..3
const SPRITES := ["boat", "sea", "ground", "pier", "house_0", "house_1", "house_2", "tree", "stall_back",
	"stall_front", "market_gate", "stall_back_fruit", "stall_back_veg", "stall_back_bread", "stall_back_flower",
	"goods_fruit", "goods_veg", "goods_bread", "goods_flower", "ico_fruit", "ico_veg", "ico_bread", "ico_flower", "villager_0", "villager_1", "villager_2", "gameboy", "bubble", "bubble_sold", "cloud", "hills",
	"tomato", "coin", "basket", "hold", "chest", "btn_bag", "room_door", "room_window", "counter", "shelf_tackle",
	"shelf_hats", "mirror", "bookshelf", "calendar", "bed", "rug", "bobber", "bang", "zzz", "font", "dots", "panel", "pips", "labels",
	"sparkle", "splash", "btn_play", "btn_stop", "btn_skip", "btn_close", "btn_menu", "btn_plus",
	"btn_minus", "btn_left", "btn_right", "btn_gear", "btn_town", "btn_fish", "btn_view"]
const CAT_LAYERS := ["fur_base", "fur_shade", "fur_light", "pat_white", "pat_stripe", "fixed", "rain_gear"]
const CAT_FRAMES := 6

# ---- 界面布局（界面坐标） ----
const PANEL_POS := Vector2(15, 1)
const PANEL_SIZE := Vector2(110, 27)
const BTN_MAIN := Rect2(78, 3, 11, 11)
const BTN_TOWN := Rect2(89, 3, 11, 11)
const BTN_MENU := Rect2(100, 3, 11, 11)     # 齿轮：只打开设置
const BTN_VIEW := Rect2(111, 3, 11, 11)
const BTN_BAG := Rect2(100, 14, 11, 11)      # 物品栏
const BTN_CLOSE := Rect2(111, 14, 11, 11)
# 退出确认框
const QUIT_BOX := Rect2(15, 30, 110, 36)
const QUIT_YES := Rect2(24, 49, 36, 13)
const QUIT_NO := Rect2(80, 49, 36, 13)
const MINI_SCENE := Rect2(4, 28, 121, 66)     # 迷你视图里可拖动/可点击的场景区域
const MINI_CAM_Y := World.WATER_Y - 74
const MINI_CAT_X := 44                        # 迷你视图里小猫固定出现的横坐标
const FULL_UI_OFF := Vector2(-11, 3)

var game: Game
var adapter
var saver: SaveService
var log: EventLog
var _save_retry_at: int = 0     # 存档失败后下次重试的时刻
var _low_power: bool = false
const FPS_HIDDEN := 5            # 窗口最小化时的帧率
var clock: Clock
var menu: Menu
var wardrobe: Wardrobe
var bag: Bag
var world: World
var cat_cfg: Dictionary = {}
var tex: Dictionary = {}
var sfx: Dictionary = {}
var px_scale: int = 3
var mini: bool = false
var view := Vector2(320, 180)   # 当前取景大小（美术像素）
var cam := Vector2.ZERO         # 镜头左上角（世界坐标）
var ui_off := Vector2.ZERO      # 界面坐标原点在视图里的位置
var floats: Array = []          # 飘字（世界坐标）: {text, icon, pos, t0}
var particles: Array = []       # 闪光粒子（视图坐标）: {pos, vel, t0, life}

var _players: Array = []
var _next_player: int = 0
var _last_fs: int = -1
var _pressed_btn: String = ""
var _dragging: bool = false
var _nap_until: int = 0                 # 床上小睡动画结束的时刻
var _mini_pts := PackedVector2Array()   # 迷你窗可交互多边形（窗口像素）
var _mini_shown: bool = true            # 迷你窗当前是否显示（鼠标移入才显示）
var _mini_hide_at: int = 0              # 鼠标移出后，到这个时刻才真正隐藏
var _mini_hover_off: bool = false       # 调试：CATFISH_NOHOVER 关闭"移入才显示"
var _last_win_pos := Vector2i.ZERO
var _pos_stable_since: int = 0
var _config_ok: bool = true
var _limits: Dictionary = {}
var _missing_labels: Dictionary = {}
var _full_notified: bool = false
var _roam_fx: float = 0.0        # 自由走动的亚像素位置
var _confirm_quit: bool = false   # 正在显示"确定要退出吗"
var interior: String = ""        # 小猫所在的屋子（"" = 在室外）；不存档，重启后回到门口
var _last_walk_input: int = -100000
const KEYS_LEFT := [KEY_LEFT, KEY_A]
const KEYS_RIGHT := [KEY_RIGHT, KEY_D]
const KEYS_ACT := [KEY_SPACE, KEY_ENTER, KEY_E, KEY_UP, KEY_W]
var _cam_snap: bool = true
var _cam_fx: float = 0.0        # 完整窗口镜头的精确横坐标（画面上取整）
const CAM_PULL := 1.4            # 镜头把小猫拉回正中的速度（每秒，越大越紧）
var _debug_speed: float = 1.0   # 调试：环境变量 CATFISH_SPEED=60 让时间快 60 倍（仅调试版生效）
var _debug_last: String = ""
var _debug_act_frame: int = -1
var _debug_dir_from: int = 0    # 调试：CATFISH_ROAM_AT=帧号，从这一帧才开始"按住方向键"
var _debug_room: String = ""
var _debug_click_frame: int = -1
var _debug_click := Vector2.ZERO
var _debug_dir: int = 0         # 调试：CATFISH_ROAM=1/-1 模拟一直按着右/左方向键
var _shot_prefix: String = ""   # 调试：CATFISH_SHOT=前缀:帧号,帧号  在这些帧截图后退出
var _shot_frames: Array = []
var _shot_busy: bool = false


func _ready() -> void:
	var balance := ConfigLoader.load_balance()
	var fish := ConfigLoader.load_fish()
	cat_cfg = ConfigLoader.load_cat()
	if balance.is_empty() or fish.is_empty() or cat_cfg.is_empty():
		_config_ok = false
		push_error("配置加载失败，游戏无法启动。请检查 data/*.json")
		get_tree().quit(1)
		return

	saver = SaveService.new()
	log = EventLog.new()
	log.write("app_start", {"version": ProjectSettings.get_setting("application/config/version", ""), "os": OS.get_name()})
	var state := GameState.new()
	var saved := saver.load_data()
	if not saved.is_empty() and not state.from_dict(saved):
		push_warning("存档版本不兼容，已使用新存档（旧档保留为 .bak）")
		state = GameState.new()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if OS.is_debug_build() and OS.has_environment("CATFISH_SEED"):   # 调试：固定随机种子，让每次运行的时间点一致
		rng.seed = OS.get_environment("CATFISH_SEED").to_int()
	clock = Clock.new()
	_limits = balance.get("settings_limits", {})
	game = Game.new(balance, fish, state, clock, rng)
	menu = Menu.new(self)
	wardrobe = Wardrobe.new(self)
	bag = Bag.new(self)
	world = World.new(self)
	wardrobe.open = not state.cat.get("created", false)   # 第一次启动先捏猫
	_apply_debug_env()

	for n in SPRITES:
		tex[n] = load("res://assets/sprites/%s.png" % n)
	for f in fish:
		tex[f["sprite"]] = load("res://assets/sprites/%s.png" % f["sprite"])
	for n in CAT_LAYERS:
		tex["cat/" + n] = load("res://assets/cat/%s.png" % n)
	for h in cat_cfg["hats"]:
		if h.get("sprite", "") != "":
			tex["cat/" + h["sprite"]] = load("res://assets/cat/%s.png" % h["sprite"])
	for it in balance.get("items", []):
		tex[it["sprite"]] = load("res://assets/sprites/%s.png" % it["sprite"])
	for n in SFX:
		sfx[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 4:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)
	_last_fs = game.fishing.state

	adapter = Platform.create()
	adapter.set_fps(FPS_NORMAL)
	# 位置：按电脑时区推算城市（离线）；日出日落、月亮位置都用它
	var loc := Location.resolve(adapter.timezone_name(), clock.bias_s(), Location.load_table())
	game.set_location(loc["lat"], loc["lon"], loc["name"])
	log.write("location", {"city": loc["name"], "source": loc["source"], "lat": snappedf(loc["lat"], 0.1), "lon": snappedf(loc["lon"], 0.1)})
	var wf := WeatherFetcher.new()
	add_child(wf)
	wf.setup(game, log)
	if OS.is_debug_build() and OS.has_environment("CATFISH_LOC"):         # 调试：纬度,经度,名字
		var lp := OS.get_environment("CATFISH_LOC").split(",")
		if lp.size() >= 2:
			game.set_location(lp[0].to_float(), lp[1].to_float(), lp[2] if lp.size() > 2 else "")
	get_tree().auto_accept_quit = false
	_apply_view_mode()


func _apply_debug_env() -> void:
	if not OS.is_debug_build():
		return
	var st := game.state
	if OS.has_environment("CATFISH_SPEED"):
		_debug_speed = maxf(1.0, OS.get_environment("CATFISH_SPEED").to_float())
	_mini_hover_off = OS.has_environment("CATFISH_NOHOVER")
	if OS.has_environment("CATFISH_SHOT"):
		var sp := OS.get_environment("CATFISH_SHOT").split(":")
		if sp.size() == 2:
			_shot_prefix = sp[0]
			for f in sp[1].split(","):
				_shot_frames.append(f.to_int())
	if OS.has_environment("CATFISH_VIEW"):
		st.settings["view_mode"] = OS.get_environment("CATFISH_VIEW").to_int()
	if OS.has_environment("CATFISH_LOOK"):
		var parts := OS.get_environment("CATFISH_LOOK").split(",")
		if parts.size() == 3:
			st.cat = {"fur": parts[0].to_int(), "pattern": parts[1].to_int(), "hat": parts[2].to_int(), "created": true}
			wardrobe.open = false
	if OS.has_environment("CATFISH_FILL"):
		var ids: Array = game.fish_by_id.keys()
		for i in OS.get_environment("CATFISH_FILL").to_int():
			game.economy.add_catch(st, st.new_id("c"), ids[i % ids.size()], false)
	if OS.has_environment("CATFISH_CHEST"):       # 调试：每一竿都钓到宝箱
		game.set_chest_chance(1.0)
	if OS.has_environment("CATFISH_ITEMS"):       # 调试：开局每种物品给这么多个，并打开物品栏
		for d in game.inventory.defs:
			game.inventory.add(st, d["id"], OS.get_environment("CATFISH_ITEMS").to_int())
		wardrobe.open = false
		bag.open = true
	if OS.has_environment("CATFISH_AUTOFOCUS"):
		game.start_focus()
	if OS.has_environment("CATFISH_ACT_AT"):      # 调试：走到某帧时模拟按一次互动键
		_debug_act_frame = OS.get_environment("CATFISH_ACT_AT").to_int()
	if OS.has_environment("CATFISH_CLICK"):       # 调试：帧号:x,y  在该帧模拟点击界面坐标 (x,y)
		var c := OS.get_environment("CATFISH_CLICK").split(":")
		var xy := c[1].split(",")
		_debug_click_frame = c[0].to_int()
		_debug_click = Vector2(xy[0].to_float(), xy[1].to_float())
	if OS.has_environment("CATFISH_WEATHER"):     # 调试：rain / clear 强制天气
		game.weather_override = 1 if OS.get_environment("CATFISH_WEATHER") == "rain" else 0
	if OS.has_environment("CATFISH_DAYS"):        # 调试：把日期往后挪几天（看不同月相）
		game.day_shift = OS.get_environment("CATFISH_DAYS").to_int()
	if OS.has_environment("CATFISH_HOUR"):        # 调试：把现在当成这个钟点（0–24）
		game.hour_override = OS.get_environment("CATFISH_HOUR").to_float()
	if OS.has_environment("CATFISH_ROOM"):        # 调试：到镇上后直接进这间屋子（tackle / tailor / home）
		_debug_room = OS.get_environment("CATFISH_ROOM")
	if OS.has_environment("CATFISH_ROAM_AT"):
		_debug_dir_from = OS.get_environment("CATFISH_ROAM_AT").to_int()
	if OS.has_environment("CATFISH_ROAM"):
		_debug_dir = OS.get_environment("CATFISH_ROAM").to_int()
	if OS.has_environment("CATFISH_GO"):
		game.go_to_town()
	if OS.has_environment("CATFISH_MENU"):
		wardrobe.open = false
		menu.open = true
		menu.tab = OS.get_environment("CATFISH_MENU").to_int()


# ------------------------------------------------------------------ 视图模式
func _apply_view_mode() -> void:
	var win := get_window()
	mini = adapter.is_overlay() and int(game.state.settings.get("view_mode", 1)) == 0
	_cam_snap = true
	_mini_shown = true
	_mini_hide_at = Time.get_ticks_msec() + 2000   # 刚切到迷你窗时先显示 2 秒，方便找到它
	if mini:
		px_scale = adapter.pixel_scale(int(game.state.settings.get("pixel_scale", 3)))
		view = Vector2(MINI_VIEW)
		ui_off = Vector2.ZERO
		adapter.enter_mini(win, MINI_VIEW * px_scale)
		var pos: Vector2i = adapter.default_position(win)
		if game.state.window.get("has_pos", false):
			pos = adapter.clamp_position(win, Vector2i(int(game.state.window["x"]), int(game.state.window["y"])))
		win.position = pos
		_last_win_pos = pos
	else:
		ui_off = FULL_UI_OFF
		adapter.enter_full(win, FULL_DEFAULT * adapter.screen_scale())
	_layout()
	_update_polygon()


func toggle_view_mode() -> void:
	if not adapter.is_overlay():
		return
	game.state.settings["view_mode"] = 1 if mini else 0
	game.dirty = true
	_apply_view_mode()


## 根据窗口实际大小决定放大倍数和取景范围（全画面窗口可以随意拉伸）。
func _layout() -> void:
	if not mini:
		var vs := get_viewport_rect().size
		px_scale = maxi(1, mini_i(int(vs.y / FULL_MIN_H), int(vs.x / FULL_MIN_W)))
		view = Vector2(ceilf(vs.x / px_scale), ceilf(vs.y / px_scale))
	scale = Vector2(px_scale, px_scale)


static func mini_i(a: int, b: int) -> int:
	return a if a < b else b


func _update_camera(dt: float) -> void:
	if mini:
		cam = Vector2(world.cat_pos.x - MINI_CAT_X, MINI_CAM_Y).round()
		_cam_snap = false
		return
	# 完整窗口：镜头像橡皮筋一样跟着小猫。
	# 1) 镜头一直在慢慢把小猫拉回画面正中（缓动，速度不快，所以小猫在中间 30%–70% 里走动时镜头几乎不动）；
	# 2) 如果小猫走得比缓动快，走出 30%–70% 的静止区，镜头立刻跟上，保证小猫永远不会走出画面。
	# 世界底边对齐窗口底边，多出来的高度都给天空。
	var cx := world.cat_pos.x + 16.0
	var max_x := maxf(0.0, World.WORLD_END - view.x)
	var sailing: int = game.journey.activity()
	if sailing == Journey.Activity.SAIL_OUT or sailing == Journey.Activity.SAIL_BACK:
		# 航行时镜头死死跟着船（小猫在画面里位置不变，船和水岸平滑滑过），不再用缓动，避免抖动
		_cam_fx = clampf(cx - view.x * 0.5, 0.0, max_x)
		_cam_snap = false
		cam = Vector2(roundf(_cam_fx), FULL_MIN_H - view.y)
		return
	if _cam_snap:
		_cam_fx = cx - view.x * 0.5
		_cam_snap = false
	else:
		var target := cx - view.x * 0.5
		_cam_fx += (target - _cam_fx) * (1.0 - exp(-CAM_PULL * minf(dt, 0.1)))
		if cx < _cam_fx + view.x * 0.3:
			_cam_fx = cx - view.x * 0.3
		elif cx > _cam_fx + view.x * 0.7:
			_cam_fx = cx - view.x * 0.7
	_cam_fx = clampf(_cam_fx, 0.0, max_x)
	cam = Vector2(roundf(_cam_fx), FULL_MIN_H - view.y)


## 完整窗口里用方向键带着小猫在镇上走；松手一会儿后交还给自动流程。
func _update_roam(dt: float) -> void:
	var j: Journey = game.journey
	var t := Time.get_ticks_msec()
	world.roam_moving = false
	var dir := 0
	if _debug_dir != 0 and Engine.get_frames_drawn() >= _debug_dir_from:
		dir = _debug_dir
	elif not mini and not panel_open() and get_window().has_focus():
		for k in KEYS_LEFT:
			if Input.is_key_pressed(k):
				dir -= 1
				break
		for k in KEYS_RIGHT:
			if Input.is_key_pressed(k):
				dir += 1
				break
	if interior != "":
		# 在屋里：只在屋内左右走。切到迷你悬浮窗或旅程状态变了就回到室外
		if mini or j.activity() != Journey.Activity.ROAM:
			interior = ""
			world.napping = false
			return
		if world.napping and Time.get_ticks_msec() >= _nap_until:
			world.napping = false
		world.room_moving = dir != 0 and not world.napping
		if dir != 0 and not world.napping:
			world.room_x = clampf(world.room_x + dir * World.ROAM_SPEED * dt, World.ROOM_MIN_X, World.ROOM_MAX_X)
			world.room_flip = dir < 0
		return
	if dir != 0 and j.in_town():
		if j.activity() != Journey.Activity.ROAM and game.begin_roam(world.cat_pos.x):
			_roam_fx = world.cat_pos.x
		if j.activity() == Journey.Activity.ROAM:
			if absf(_roam_fx - j.roam_x()) > 1.5:
				_roam_fx = j.roam_x()      # 读档后或从屋里出来：以存档里的位置为准，避免第一步瞬移到码头
			_roam_fx = clampf(_roam_fx + dir * World.ROAM_SPEED * dt, World.ROAM_MIN_X, World.ROAM_MAX_X)
			j.set_roam_x(_roam_fx)
			world.roam_moving = true
			world.roam_flip = dir < 0
			_last_walk_input = t
	elif j.activity() == Journey.Activity.ROAM and mini:
		# 玩家接管后小猫就一直听玩家的，不会自己走开；只有切到迷你悬浮窗才交还给自动流程
		var x := float(j.roam_x())
		game.end_roam(world.frac_to_stall(x), world.frac_to_boat(x))


## 互动键：在海上 = 去小镇；自由走动时在摊位旁 = 开张，在码头 = 上船。
func _interact() -> void:
	var j: Journey = game.journey
	if interior != "":
		_interact_inside()
	elif j.on_boat():
		_go_to_town()
	elif j.activity() == Journey.Activity.SOLD_OUT:
		_go_fishing()
	elif j.activity() == Journey.Activity.ROAM:
		var x := float(j.roam_x())
		if world.near_pier(x):
			game.roam_board(world.frac_to_boat(x))
			play("click")
		elif world.near_stall(x) and not game.state.basket.is_empty():
			game.end_roam(0.0, world.frac_to_boat(x))
		elif not world.door_near(x).is_empty():
			_enter_building(world.door_near(x)[2])
		elif world.stroller_near(x, Time.get_ticks_msec()) >= 0:
			var t := Time.get_ticks_msec()
			world.chat_with(world.stroller_near(x, t), t)
			_last_walk_input = t
			play("click")
		else:
			play("deny")


## 走进镇上的房子：切到室内场景。
func _enter_building(kind: String) -> void:
	play("buy")
	log.write("enter", {"building": kind})
	interior = kind
	world.enter_room(Time.get_ticks_msec())


## 在屋里按互动键：门口 = 出门；柜台/镜子/书架/日历 = 打开对应的面板。
func _interact_inside() -> void:
	match world.room_spot(interior):
		"exit":
			play("click")
			log.write("leave", {"building": interior})
			interior = ""
		"shop":
			play("click")
			menu.tab = 0
			menu.open = true
		"dex":
			play("click")
			menu.tab = 1
			menu.open = true
		"stats":
			play("click")
			menu.tab = 2
			menu.open = true
		"mirror":
			play("click")
			wardrobe.open = true
		"bed":
			if world.napping:
				pass
			elif game.nap():
				play("break_end")
				world.napping = true
				_nap_until = Time.get_ticks_msec() + 2600
				log.write("nap", {"lucky_until_ms": game.state.effects["lucky_until_ms"]})
			else:
				play("deny")
		_:
			play("deny")
	_update_polygon()


## 设置里循环切换：迷你窗大小 2→3→4→5→2，音效 0→1→2→3→0。
func cycle_setting(key: String) -> void:
	var lim: Array = _limits.get(key, [0, 3, 1])
	var v := int(game.state.settings.get(key, lim[0])) + 1
	if v > int(lim[1]):
		v = int(lim[0])
	game.state.settings[key] = v
	game.dirty = true
	if key == "pixel_scale" and mini:
		_apply_view_mode()


## 菜单或捏猫面板开合后调用：更新可交互区域。
func on_panel_toggled() -> void:
	_update_polygon()


func _update_polygon() -> void:
	if not adapter.is_overlay():
		return
	if not mini:
		adapter.set_interactive_polygon(get_window(), PackedVector2Array())
		return
	# 上面是 HUD 面板，下面是场景；两块拼成一个多边形，其余透明区域鼠标穿透
	var p := PANEL_POS
	var s := MINI_SCENE
	var pts := PackedVector2Array([
		p, Vector2(p.x + PANEL_SIZE.x, p.y), Vector2(p.x + PANEL_SIZE.x, s.end.y),
		Vector2(s.position.x, s.end.y), s.position, Vector2(p.x, s.position.y),
	])
	var scene_only := PackedVector2Array([
		s.position, Vector2(s.end.x, s.position.y), s.end, Vector2(s.position.x, s.end.y),
	])
	for i in pts.size():
		pts[i] *= px_scale
	for i in scene_only.size():
		scene_only[i] *= px_scale
	_mini_pts = pts
	# 菜单隐藏时，菜单所在的透明区域不拦截点击；鼠标移入仍由全局坐标判断
	adapter.set_interactive_polygon(get_window(), pts if _mini_shown else scene_only)


# ------------------------------------------------------------------ 主循环
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _quit() -> void:
	_save_retry_at = 0
	_save()
	log.write("app_quit", {"gold": game.state.wallet_gold if game != null else 0})
	get_tree().quit()


func _save() -> void:
	if game == null:
		return
	var t := Time.get_ticks_msec()
	if t < _save_retry_at:
		return
	if saver.save(game.state.to_dict()):
		game.dirty = false
	else:
		# 写盘失败：内存里的进度保留（dirty 不清），5 秒后再试，不每帧硬写
		_save_retry_at = t + 5000
		log.write("save_failed", {"revision": game.state.revision})


## 窗口最小化时降到 5 帧并停止重绘；逻辑照常推进（靠时间戳，不靠帧数）。
func _update_power() -> void:
	var hidden := get_window().mode == Window.MODE_MINIMIZED
	if hidden != _low_power:
		_low_power = hidden
		adapter.set_fps(FPS_HIDDEN if hidden else FPS_NORMAL)
		log.write("low_power", {"on": hidden})


func _process(dt: float) -> void:
	if not _config_ok:
		return
	if _debug_speed > 1.0:
		clock.debug_offset_ms += dt * 1000.0 * (_debug_speed - 1.0)
	_update_power()
	for e in game.tick():
		log.write(e["type"], e)
		_on_event(e)
		if _debug_speed > 1.0:
			print("[debug] frame %d event %s" % [Engine.get_frames_drawn(), str(e)])
	if _debug_room != "" and game.journey.in_town():
		game.begin_roam(World.STALL_CAT_X)
		if OS.has_environment("CATFISH_BREAK"):   # 调试：进屋时处于番茄休息中（休息中去不了镇上，所以到镇上再设）
			game.state.pomodoro["phase"] = Pomodoro.Phase.SHORT_BREAK
			game.state.pomodoro["phase_end_ms"] = game.now_ms() + 3600000
		_enter_building(_debug_room)
		_debug_room = ""
		if OS.has_environment("CATFISH_NAP"):     # 调试：进屋后直接走到床边按一下
			world.room_x = 156.0
			_interact_inside()
			if OS.get_environment("CATFISH_NAP") == "2":   # 一直睡着，方便截图
				_nap_until = Time.get_ticks_msec() + 600000
	if _debug_click_frame >= 0 and Engine.get_frames_drawn() >= _debug_click_frame:
		_debug_click_frame = -1
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = (_debug_click + ui_off) * px_scale
		_unhandled_input(ev)
	_update_roam(dt)
	if _debug_act_frame >= 0 and Engine.get_frames_drawn() >= _debug_act_frame:
		_debug_act_frame = -1
		_debug_dir = 0
		_interact()
	_fishing_feedback()
	_debug_trace()
	_track_window()
	_update_mini_hover()
	_layout()
	world.update(game.now_ms(), Time.get_ticks_msec())
	_update_camera(dt)
	if game.dirty:
		_save()
	if not _low_power:
		queue_redraw()
	if not _shot_frames.is_empty() and not _shot_busy and Engine.get_frames_drawn() >= int(_shot_frames[0]):
		_take_debug_shot()


func _take_debug_shot() -> void:
	_shot_busy = true
	var frame: int = _shot_frames.pop_front()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%d.png" % [_shot_prefix, frame])
	_shot_busy = false
	if _shot_frames.is_empty():
		get_tree().quit()


func _debug_trace() -> void:
	if _debug_speed <= 1.0:
		return
	var s := "%s/%s" % [Journey.Activity.keys()[game.journey.activity()], Fishing.State.keys()[game.fishing.state]]
	if s != _debug_last:
		_debug_last = s
		print("[debug] frame %d %s" % [Engine.get_frames_drawn(), s])


## 钓鱼状态切换时的音效和水花。
func _fishing_feedback() -> void:
	var fs: int = game.fishing.state
	if fs == _last_fs:
		return
	_last_fs = fs
	match fs:
		Fishing.State.CASTING:
			play("cast")
		Fishing.State.WAITING:
			world.splash_t0 = Time.get_ticks_msec()
		Fishing.State.HOOKED:
			world.splash_t0 = Time.get_ticks_msec()
			play("bite")
		Fishing.State.REELING:
			play("reel")


## 迷你窗：鼠标不在窗口上时，只隐藏上方的菜单（HUD 面板），小猫和场景一直显示。
## 鼠标移出后再停留 0.8 秒才隐藏，防止边缘抖动；拖动窗口或打开面板时保持显示。
func _update_mini_hover() -> void:
	if not mini:
		return
	var always: bool = _mini_hover_off or not bool(game.state.settings.get("mini_hover", true))
	var now := Time.get_ticks_msec()
	if always or _dragging or panel_open() or _confirm_quit \
			or adapter.mouse_over_polygon(get_window(), _mini_pts):
		_mini_hide_at = now + 800
		if not _mini_shown:
			_set_mini_shown(true)
	elif _mini_shown and now >= _mini_hide_at:
		_set_mini_shown(false)


func _set_mini_shown(on: bool) -> void:
	_mini_shown = on
	_update_polygon()
	queue_redraw()


func _track_window() -> void:
	if not mini:
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
	var t := Time.get_ticks_msec()
	match e["type"]:
		"catch":
			world.hop_t0 = t
			var f: Dictionary = game.fish_by_id.get(e["fish_id"], {})
			if int(f.get("rarity", 0)) >= 2:
				play("rare")
				_sparkles(_world_to_view(world.cat_pos + Vector2(17, -10)), 12, 8.0)
			else:
				play("catch")
		"chest":
			world.hop_t0 = t
			world.chest_open_t0 = t
			play("rare")
			_sparkles(_world_to_view(world.cat_pos + Vector2(17, -12)), 16 if e["tier"] == "big" else 9, 9.0)
			_float("+%d" % e["gold"], "coin", world.cat_pos + Vector2(30, -4))
			if e.get("item", "") != "":
				var it: Dictionary = game.inventory.by_id.get(e["item"], {})
				if tex.has(it.get("sprite", "")):
					_float("+1", it["sprite"], world.cat_pos + Vector2(34, 8))
		"basket_full":
			if not _full_notified:
				_full_notified = true
				adapter.notify("鱼篓满了", "点小猫头上的气泡，让它去小镇摆摊卖鱼。")
		"depart":
			_full_notified = false
		"open":
			play("buy")
		"sale":
			play("coin")
			world.hop_t0 = t
			world.on_sale(e["fish_id"])
			_float("+%d" % e["gold"], "coin", Vector2(World.STALL_X + 8, World.GROUND_Y - 52))
		"ate":
			world.eat_t0 = t
			world.eat_fish = e["fish_id"]
			play("bite")
		"focus_done":
			play("done")
			world.hop_t0 = t
			_sparkles(Vector2(view.x / 2, 30), 26, minf(view.x * 0.4, 90.0), true)
			if e["gold"] > 0:
				_float("+%d" % e["gold"], "coin", world.cat_pos + Vector2(-6, -14))
			adapter.notify("番茄完成！", "木箱里的 %d 条鱼卖了 %d 金币。休息一下吧。" % [e["fish_count"], e["gold"]])
		"break_done":
			play("break_end")
			adapter.notify("休息结束", "小猫睡醒了，准备开始下一个番茄吧。")


func _float(text: String, icon: String, world_pos: Vector2) -> void:
	floats.append({"text": text, "icon": icon, "pos": world_pos, "t0": Time.get_ticks_msec()})


func _world_to_view(p: Vector2) -> Vector2:
	return p - cam


func play(name: String) -> void:
	var vol := clampi(int(game.state.settings.get("sfx_volume", 2)), 0, 3)
	if vol == 0 or not sfx.has(name):
		return
	var pl: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	pl.stream = sfx[name]
	pl.volume_db = VOLUME_DB[vol]
	pl.play()


func _sparkles(center: Vector2, count: int, spread: float, fall := false) -> void:
	var t := Time.get_ticks_msec()
	for i in count:
		var a := randf() * TAU
		var vel := Vector2(cos(a), sin(a)) * randf_range(4.0, 14.0)
		var pos := center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread) * 0.5)
		if fall:
			vel = Vector2(randf_range(-3.0, 3.0), randf_range(10.0, 22.0))
		particles.append({"pos": pos, "vel": vel, "t0": t + randi() % 300, "life": randi_range(700, 1500)})


# ------------------------------------------------------------------ 输入
func _unhandled_input(event: InputEvent) -> void:
	if not _config_ok:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and not mini:
			if _confirm_quit:
				if event.keycode == KEY_ESCAPE:
					_confirm_quit = false
			elif event.keycode == KEY_TAB or event.keycode == KEY_I:
				toggle_bag()               # Tab / I 开关物品栏
			elif bag.open:
				if event.keycode == KEY_ESCAPE:
					bag.open = false
					_update_polygon()
				else:
					bag.key(event.keycode)     # 方向键选格子，空格使用
			elif (menu.open or wardrobe.open) and event.keycode == KEY_ESCAPE:
				menu.open = false          # Esc 关闭面板（从店里出来）
				if wardrobe.open:
					wardrobe.close()
				_update_polygon()
			elif not panel_open() and event.keycode in KEYS_ACT:
				_interact()
		return
	if event is InputEventMouseMotion:
		menu.hover = event.position / float(px_scale) - ui_off
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		_pressed_btn = ""
		return
	var v: Vector2 = event.position / float(px_scale)   # 视图坐标
	var p := v - ui_off                                  # 界面坐标
	if _confirm_quit:
		# 确认框打开时只认这两个按钮，点别处一律当作取消
		if QUIT_YES.has_point(p):
			_quit()
		else:
			_confirm_quit = false
			play("click")
		return
	if BTN_MAIN.has_point(p):
		_pressed_btn = "main"
		_press_main()
	elif BTN_TOWN.has_point(p):
		_pressed_btn = "town"
		_town_button()
	elif BTN_MENU.has_point(p):
		# 面板上只留"设置"。商店、图鉴、统计、换形象都要去镇上对应的房子里
		play("click")
		if wardrobe.open:
			wardrobe.close()
		bag.open = false
		if menu.open:
			menu.open = false
		else:
			menu.tab = 3
			menu.open = true
		_update_polygon()
	elif BTN_VIEW.has_point(p):
		play("click")
		toggle_view_mode()
	elif BTN_BAG.has_point(p):
		toggle_bag()
	elif BTN_CLOSE.has_point(p) and _quit_button_visible():
		play("click")
		_confirm_quit = true      # 先问一句，不直接退出
	elif Rect2(PANEL_POS, PANEL_SIZE).has_point(p):
		pass
	elif bag.click(p) or menu.click(p) or wardrobe.click(p):
		pass
	elif world.bubble_rect(Time.get_ticks_msec()).has_point(v + cam):
		_town_button()
	elif mini and MINI_SCENE.has_point(p):
		if adapter.start_window_drag(get_window()):
			_dragging = true
			_pos_stable_since = Time.get_ticks_msec()
			adapter.set_fps(FPS_DRAG)


## 商店、图鉴、统计、设置、换形象任何一个面板开着时，不显示退出按钮，免得把它当成"关闭面板"点错。
func _quit_button_visible() -> bool:
	return not panel_open()


## 有任何面板（菜单、换形象、物品栏）开着。
func panel_open() -> bool:
	return menu.open or wardrobe.open or bag.open


func toggle_bag() -> void:
	play("click")
	menu.open = false
	if wardrobe.open:
		wardrobe.close()
	bag.toggle()
	_update_polygon()


func _draw_quit_confirm() -> void:
	draw_rect(QUIT_BOX, Pal.U_A)
	draw_rect(QUIT_BOX.grow(-1), Pal.U_K)
	label_centered("确定要退出吗", QUIT_BOX.position.x + QUIT_BOX.size.x / 2, QUIT_BOX.position.y + 5, Pal.L_W)
	draw_rect(QUIT_YES, Pal.L_R)
	draw_rect(Rect2(QUIT_YES.position.x, QUIT_YES.end.y - 2, QUIT_YES.size.x, 2), Pal.U_R)
	label_centered("退出", QUIT_YES.position.x + QUIT_YES.size.x / 2, QUIT_YES.position.y + 1, Pal.L_W)
	draw_rect(QUIT_NO, Pal.L_A)
	draw_rect(Rect2(QUIT_NO.position.x, QUIT_NO.end.y - 2, QUIT_NO.size.x, 2), Pal.U_A)
	label_centered("取消", QUIT_NO.position.x + QUIT_NO.size.x / 2, QUIT_NO.position.y + 1, Pal.U_K)


## 海上 = 去小镇；在镇上 = 去钓鱼。
func _town_button() -> void:
	if game.journey.in_town():
		_go_fishing()
	else:
		_go_to_town()


func _go_fishing() -> void:
	var x: float = world.cat_pos.x
	if game.journey.activity() == Journey.Activity.ROAM:
		x = float(game.journey.roam_x())
	if game.go_fishing(x, world.frac_to_boat(x)):
		log.write("go_fishing", {"basket": game.state.basket.size()})
		play("click")
	else:
		play("deny")


func _go_to_town() -> void:
	if game.go_to_town():
		log.write("go_to_town", {"basket": game.state.basket.size()})
		_full_notified = false
		play("cast")
	else:
		play("deny")


func _press_main() -> void:
	play("click")
	match game.pomodoro.phase():
		Pomodoro.Phase.IDLE:
			game.start_focus()
		Pomodoro.Phase.FOCUS:
			var gold := game.abandon_focus()
			if gold > 0:
				play("coin")
				_float("+%d" % gold, "coin", world.cat_pos + Vector2(-6, -14))
		_:
			game.skip_break()


# ------------------------------------------------------------------ 绘制
func _draw() -> void:
	if game == null:
		return
	var now := game.now_ms()
	var t := Time.get_ticks_msec()
	if interior != "":
		draw_set_transform(Vector2.ZERO)
		world.draw_interior(interior, view, t)
	else:
		draw_set_transform(-cam)
		world.draw(cam, view, mini, now, t)
		_draw_weather(t)
		_draw_floats(t)
	draw_set_transform(ui_off)
	if not mini or _mini_shown:
		_draw_hud(now)
	menu.draw()
	wardrobe.draw()
	bag.draw()
	if _confirm_quit:
		_draw_quit_confirm()
	draw_set_transform(Vector2.ZERO)
	_draw_particles(t)


## 夜里的暗色 + 下雨（雨丝、水面涟漪）。黄昏的日落在 world 的天空里画。
## 迷你窗是透明背景：不盖任何半透明色块，只留雨丝和涟漪。
func _draw_weather(t: int) -> void:
	var r := Rect2(cam, view)
	if mini:
		r = Rect2(cam + MINI_SCENE.position, MINI_SCENE.size)
	if not mini:
		var dark := float(game.sky()["dark"])
		if dark > 0.0:
			draw_rect(r, Color(Pal.U_K, 0.3 * dark))
	if not game.is_raining():
		return
	if not mini:
		draw_rect(r, Color(Pal.U_A, 0.22))
	for i in 14:   # 水面涟漪
		var rx := r.position.x + fposmod(i * 47.0 + 13.0, r.size.x)
		var ry := World.WATER_Y + 3 + (i * 7) % 11
		if rx < World.SHORE_X - 4 and ry > r.position.y and ry < r.end.y and ((t / 350) + i) % 5 == 0:
			draw_rect(Rect2(roundf(rx), ry, 3, 1), Color(Pal.U_W, 0.8))
	var n := int(r.size.x * r.size.y / 650.0)
	for i in n:   # 雨丝
		var sp := 0.2 + (i % 3) * 0.05
		var y := fposmod(i * 37.0 + t * sp, r.size.y + 6.0) - 6.0
		var x := fposmod(i * 53.0 + y * 0.3, r.size.x)
		draw_rect(Rect2(r.position + Vector2(roundf(x), roundf(y)), Vector2(1, 3)), Color(Pal.U_W, 0.7))


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
	var in_town: bool = game.journey.in_town()
	var town_ok: bool = game.can_go_fishing() if in_town else game.can_go_to_town()
	_tex_frame("btn_fish" if in_town else "btn_town", BTN_TOWN.position, 1 if _pressed_btn == "town" else 0, 2,
			Color.WHITE if town_ok else Color(1, 1, 1, 0.35))
	_tex_frame("btn_gear", BTN_MENU.position, 1 if menu.open and menu.tab == 3 else 0, 2)
	if adapter.is_overlay():
		_tex_frame("btn_view", BTN_VIEW.position, 0, 2)
	_tex_frame("btn_bag", BTN_BAG.position, 1 if bag.open else 0, 2)
	if _quit_button_visible():
		_tex_frame("btn_close", BTN_CLOSE.position, 1 if _confirm_quit else 0, 2)

	draw_texture(tex["coin"], Vector2(20, 15))
	_text(str(game.state.wallet_gold), Vector2(31, 17), Pal.L_Y)
	# 专注且在海上：显示不限量的木箱（番茄渔获）；其余时候显示鱼篓
	if ph == Pomodoro.Phase.FOCUS and game.journey.on_boat():
		draw_texture(tex["hold"], Vector2(56, 14))
		_text("x%d" % game.state.session_haul.size(), Vector2(69, 17), Pal.L_W)
	else:
		draw_texture(tex["basket"], Vector2(56, 14))
		var full: bool = game.economy.basket_full(game.state)
		_text("%d/%d" % [game.state.basket.size(), game.state.basket_capacity], Vector2(69, 17),
				Pal.L_R if full else Pal.L_W)
	# 完整窗口里的操作提示（夜里天空是深色，换成浅色字）
	var hint_col: Color = Pal.L_W if float(game.sky()["dark"]) > 0.35 else Pal.U_K
	if not mini and not panel_open():
		if interior != "":
			label("方向键走动", Vector2(17, 30), Pal.L_W)
			var spot: String = world.room_spot(interior)
			if spot == "bed":
				var st := game.nap_status()
				label("小猫睡得真香" if world.napping else ("空格键小睡" if st == 1 else ("已经睡饱了" if st == 2 else "休息时才能小睡")),
						Vector2(17, 41), Pal.L_Y)
			elif World.SPOT_HINT.has(spot):
				label(World.SPOT_HINT[spot], Vector2(17, 41), Pal.L_Y)
		elif game.journey.in_town():
			label("方向键走动", Vector2(17, 30), hint_col)
			if game.journey.activity() == Journey.Activity.SOLD_OUT:
				label("空格键去钓鱼", Vector2(17, 41), hint_col)
			elif game.journey.activity() == Journey.Activity.ROAM:
				var rx := float(game.journey.roam_x())
				var hint := "空格键互动"
				if world.near_pier(rx):
					hint = "空格键去钓鱼"
				elif not world.door_near(rx).is_empty():
					hint = "空格键进入"
				elif world.stroller_near(rx, Time.get_ticks_msec()) >= 0 and not world.near_stall(rx) and not world.near_pier(rx):
					hint = "空格键聊天"
				label(hint, Vector2(17, 41), hint_col)
		elif game.can_go_to_town():
			label("空格键去小镇", Vector2(17, 30), hint_col)


func _draw_floats(t: int) -> void:
	var keep: Array = []
	for f in floats:
		var age: int = t - int(f["t0"])
		if age < 2500:
			keep.append(f)
			var pos: Vector2 = f["pos"] + Vector2(0, -int(age / 180))
			draw_texture(tex[f["icon"]], pos)
			var icon: Texture2D = tex[f["icon"]]
			_text(f["text"], pos + Vector2(icon.get_width() + 3, maxi(2, icon.get_height() / 2 - 2)), Pal.L_Y, true)
	floats = keep


func _draw_particles(t: int) -> void:
	var keep: Array = []
	for p in particles:
		var age: int = t - int(p["t0"])
		if age < int(p["life"]):
			keep.append(p)
			if age >= 0:
				var pos: Vector2 = (p["pos"] + p["vel"] * (age / 1000.0)).round()
				# 一闪一闪：大小两帧交替，寿命末尾只剩小的
				var small: bool = age > int(p["life"]) * 0.6 or (age / 120) % 2 == 1
				_tex_frame("sparkle", pos, 1 if small else 0, 2)
	particles = keep


## 按存档里的形象分层画猫：毛色三层 + 花纹两层（白色蒙版乘上颜色）+ 固定层 + 帽子。
func draw_cat(pos: Vector2, frame: int, flip := false) -> void:
	var look: Dictionary = game.state.cat
	var furs: Array = cat_cfg["furs"]
	var pats: Array = cat_cfg["patterns"]
	var hats: Array = cat_cfg["hats"]
	var fur: Dictionary = furs[posmod(int(look.get("fur", 0)), furs.size())]
	var pat: Dictionary = pats[posmod(int(look.get("pattern", 0)), pats.size())]
	var hat: Dictionary = hats[posmod(int(look.get("hat", 0)), hats.size())]
	var base: Color = Pal.BY_KEY.get(fur["base"], Pal.L_F)
	var shade: Color = Pal.BY_KEY.get(fur["shade"], Pal.U_F)
	var light: Color = Pal.BY_KEY.get(fur["light"], Pal.L_L)
	_tex_frame("cat/fur_base", pos, frame, CAT_FRAMES, base, flip)
	_tex_frame("cat/fur_shade", pos, frame, CAT_FRAMES, shade, flip)
	_tex_frame("cat/fur_light", pos, frame, CAT_FRAMES, light, flip)
	_tex_frame("cat/pat_white", pos, frame, CAT_FRAMES, Pal.L_W if pat.get("white", false) else light, flip)
	_tex_frame("cat/pat_stripe", pos, frame, CAT_FRAMES, shade if pat.get("stripes", false) else base, flip)
	_tex_frame("cat/fixed", pos, frame, CAT_FRAMES, Color.WHITE, flip)
	if game.is_raining() and interior == "" and not wardrobe.open:
		# 下雨天在室外：穿蓑衣、戴蓑衣帽（盖掉平时的帽子），进屋就脱掉
		_tex_frame("cat/rain_gear", pos, frame, CAT_FRAMES, Color.WHITE, flip)
	elif hat.get("sprite", "") != "":
		_tex_frame("cat/" + hat["sprite"], pos, frame, CAT_FRAMES, Color.WHITE, flip)


# ---- 给 world / menu / wardrobe 用的公开绘制接口 ----
func tex_frame(name: String, pos: Vector2, frame: int, count: int, mod := Color.WHITE) -> void:
	_tex_frame(name, pos, frame, count, mod)

func tex_frame_flipped(name: String, pos: Vector2, frame: int, count: int) -> void:
	_tex_frame(name, pos, frame, count, Color.WHITE, true)

func text(s: String, pos: Vector2, color: Color) -> void:
	_text(s, pos, color)

func text_right(s: String, right_x: float, y: float, color: Color) -> void:
	_text(s, Vector2(right_x - s.length() * 4 + 1, y), color)

func pixel_line(a: Vector2, b: Vector2, color: Color) -> void:
	_pixel_line(a, b, color)

## 画一个预渲染的中文标签；图集里没有的文字会被跳过并报一次警告。
func label(s: String, pos: Vector2, color: Color) -> void:
	if not Labels.RECTS.has(s):
		if not _missing_labels.has(s):
			_missing_labels[s] = true
			push_warning("标签图集缺少文字: %s（请加到 tools/art/generate.py 的 LABELS 后重新生成）" % s)
		return
	var r: Rect2 = Labels.RECTS[s]
	draw_texture_rect_region(tex["labels"], Rect2(pos, r.size), r, color)

func label_width(s: String) -> float:
	return Labels.RECTS[s].size.x if Labels.RECTS.has(s) else 0.0


func label_centered(s: String, center_x: float, y: float, color: Color) -> void:
	if Labels.RECTS.has(s):
		label(s, Vector2(center_x - int(Labels.RECTS[s].size.x / 2), y), color)
	else:
		label(s, Vector2(center_x, y), color)


# ---- 绘制小工具 ----
func _tex_frame(name: String, pos: Vector2, frame: int, count: int, mod := Color.WHITE, flip := false) -> void:
	var tx: Texture2D = tex[name]
	var w := tx.get_width() / count
	var h := tx.get_height()
	var dst := Rect2(pos, Vector2(w, h))
	if flip:
		# 负宽度 = 水平翻转。Godot 只翻转贴图、不移动矩形，所以位置保持 pos 不变
		# （之前写成 pos.x + w，翻转后整只猫会向右跳 32 像素）
		dst = Rect2(pos.x, pos.y, -w, h)
	draw_texture_rect_region(tx, dst, Rect2(frame * w, 0, w, h), mod)


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
