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
const OutfitShop := preload("res://presentation/outfit_shop.gd")
const ShipyardPanel := preload("res://presentation/shipyard_panel.gd")
const DestPanel := preload("res://presentation/dest_panel.gd")
const QuestPanel := preload("res://presentation/quest_panel.gd")
const SignalPanel := preload("res://presentation/signal_panel.gd")
const World := preload("res://presentation/world.gd")
const Bag := preload("res://presentation/bag.gd")
const Book := preload("res://presentation/book.gd")
const Admin := preload("res://presentation/admin.gd")

const MINI_VIEW := Vector2i(128, 96)
const FULL_MIN_H := 180          # 全画面至少能看到这么高的世界
const FULL_MIN_W := 256
const FULL_DEFAULT := Vector2i(960, 540)
const FONT_ORDER := "0123456789:/+x-cm%.()"
const FPS_NORMAL := 30
const FPS_DRAG := 60
const SFX := ["click", "cast", "twitch", "bite", "reel", "catch", "rare", "coin", "buy", "deny", "done", "break_end"]
const VOLUME_DB := [-80.0, -22.0, -12.0, -5.0]   # 音效档位 0(静音)..3
const SPRITES := ["boat", "boat_1", "boat_2", "boat_3", "sea", "ground", "pier", "house_0", "house_1", "house_2", "house_3", "wall_clothes", "mannequin", "tree", "stall_back",
	"stall_front", "bird_fly", "bird_perch", "boat_head", "boat_basket_back", "boat_basket", "market_gate", "stall_back_fruit", "stall_back_veg", "stall_back_bread", "stall_back_flower",
	"goods_fruit", "goods_veg", "goods_bread", "goods_flower", "ico_fruit", "ico_bag", "ico_veg", "ico_bread", "ico_flower", "villager_0", "villager_1", "villager_2", "villager_3", "gameboy", "bubble", "bubble_sold", "cloud", "hills",
	"tomato", "coin", "coin_silver", "coin_copper", "umbrella", "piggy", "basket", "hold", "chest", "btn_bag", "room_door", "room_window", "counter", "shelf_tackle",
	"shelf_hats", "mirror", "bookshelf", "calendar", "bed", "rug", "bobber", "bang", "tangle", "zzz", "font", "dots", "panel", "pips", "labels",
	"sparkle", "splash", "btn_play", "btn_stop", "btn_skip", "btn_close", "btn_menu", "btn_plus",
	"btn_dest", "lighthouse", "btn_minus", "btn_left", "btn_right", "btn_gear", "btn_town", "btn_fish", "btn_view", "btn_cat", "anger", "storage", "lock", "lantern", "noren_tackle", "noren_tailor", "noren_ship", "ship_model", "blueprint", "anchor", "wall_bobbers", "specimen_0", "specimen_1", "barrel_rods", "bait_jars", "wall_hats", "hat_stand", "fabric_rolls", "ishidoro", "deco_crate_fruit", "deco_board_fruit", "deco_nobori_fruit", "deco_crate_veg", "deco_board_veg", "deco_nobori_veg", "deco_crate_bread", "deco_board_bread", "deco_nobori_bread", "deco_crate_flower", "deco_board_flower", "deco_nobori_flower", "deco_crate_fish", "deco_board_fish", "deco_nobori_fish"]
const CAT_LAYERS := ["fur_base", "fur_shade", "fur_light", "pat_white", "pat_stripe", "fixed", "rain_gear"]
const CAT_FRAMES := 6

# ---- 界面布局（界面坐标） ----
const PANEL_POS := Vector2(15, 1)
const PANEL_SIZE := Vector2(110, 27)
const MINI_HUD_DX := -6.0              # 迷你窗里顶栏左移，让它在 128 宽的窗口里居中
const BTN_MAIN := Rect2(78, 3, 11, 11)
const BTN_TOWN := Rect2(89, 3, 11, 11)
const BTN_MENU := Rect2(100, 3, 11, 11)     # 齿轮：只打开设置
const BTN_VIEW := Rect2(111, 3, 11, 11)
const BTN_BAG := Rect2(100, 14, 11, 11)      # 物品栏
const BTN_DEST := Rect2(78, 14, 11, 11)      # 准星：选目的地
const BTN_STATUS := Rect2(89, 14, 11, 11)    # 小猫状态
const BTN_CLOSE := Rect2(111, 14, 11, 11)
# 退出确认框
const QUIT_BOX := Rect2(15, 30, 110, 36)
const QUIT_YES := Rect2(24, 49, 36, 13)
const QUIT_NO := Rect2(80, 49, 36, 13)
const MINI_SCENE := Rect2(0, 28, 128, 66)     # 迷你视图里可拖动/可点击的场景区域
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
var outfit_shop: OutfitShop
var shipyard_panel: ShipyardPanel
var dest_panel: DestPanel
var _title_name: String = ""        # 刚到一座新岛：屏幕中央的白色标题
var _title_t0: int = -100000
var _toast_t0: int = -100000       # 屏幕左侧的两行小提示（行李满了、水太浅了……）
var _toast_l1: String = ""
var _toast_l2: String = ""
var _catch_name: String = ""        # 刚钓到的鱼：右上角显示"名称 (尺寸cm)"，几秒后淡出
var _catch_size: int = 0
var _catch_rare: bool = false
var _catch_t0: int = -100000
const CATCH_SHOW_MS := 4000
const CATCH_FADE_MS := 1200
var quest_panel: QuestPanel
var signal_panel: SignalPanel
var bag: Bag
var book: Book
var admin: Admin
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
var _pix_font: FontFile            # 像素字体：只用来画玩家输入的名字（其余文字都是图集里的）
var _naming: bool = false          # 正在给小猫起名
var _name_buf: String = ""
var _name_pick: int = 0
var _ime_text: String = ""
var _queued_x: float = INF       # 还在上船/出港途中选了目的地：到了能划船时自动出发
var _auto_x: float = INF         # 自动航行的目的地（INF = 没在自动航行）
var _pending_cast_at: int = 0     # 转身结束后要甩竿的时刻（0 = 没有）
var _row_ready_at: int = 0      # 收杆动作做完、可以开始划船的时刻
const KEYS_LEFT := [KEY_LEFT, KEY_A]
const KEYS_RIGHT := [KEY_RIGHT, KEY_D]
const KEYS_ACT := [KEY_SPACE, KEY_ENTER, KEY_E, KEY_UP, KEY_W]
var _cam_snap: bool = true
var _cam_fx: float = 0.0        # 完整窗口镜头的精确横坐标（画面上取整）
const ZONE_LABEL := {"shallow": "浅水区", "deep": "深水区"}
const CAM_MIN := -4700.0           # 镜头最左能看到小岛那边
const AUTO_DECEL := 90.0          # 自动航行进港前的减速度
const BOAT_SPEED := 44.0         # 划船最高速度（像素/秒）
const BOAT_ACCEL := 98.0         # 起桨加速度：约 0.45 秒加到最高速
const WAVE_PUSH := 150.0         # 浪区里把船往回推的加速度（像素/秒²，最大值）
const BOAT_DECEL := 55.0         # 停桨后的滑行减速度：约 0.8 秒滑停
const CAM_PULL := 1.4            # 镜头把小猫拉回正中的速度（每秒，越大越紧）
var _debug_speed: float = 1.0   # 调试：环境变量 CATFISH_SPEED=60 让时间快 60 倍（仅调试版生效）
var _debug_last: String = ""
var _debug_act_frame: int = -1
var _debug_dir_from: int = 0    # 调试：CATFISH_ROAM_AT=帧号，从这一帧才开始"按住方向键"
var _debug_room: String = ""
var _debug_click_frame: int = -1
var _debug_click := Vector2.ZERO
var _boat_fx: float = 0.0        # 划船时船位置的小数部分
var _boat_v: float = 0.0         # 划船的当前速度（像素/秒，带方向）：起桨加速、停桨滑行
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
	outfit_shop = OutfitShop.new(self)
	shipyard_panel = ShipyardPanel.new(self)
	dest_panel = DestPanel.new(self)
	_pix_font = load("res://assets/fonts/pixel.woff") as FontFile
	if _pix_font != null:
		_pix_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_pix_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_pix_font.hinting = TextServer.HINTING_NONE
	quest_panel = QuestPanel.new(self)
	signal_panel = SignalPanel.new(self)
	game.set_cat_cfg(cat_cfg)
	bag = Bag.new(self)
	book = Book.new(self)
	admin = Admin.new(self)
	world = World.new(self)
	wardrobe.open = not state.cat.get("created", false)   # 第一次启动先捏猫
	_apply_debug_env()

	for n in SPRITES:
		tex[n] = load("res://assets/sprites/%s.png" % n)
	for f in fish:
		tex[f["sprite"]] = load("res://assets/sprites/%s.png" % f["sprite"])
	for n in CAT_LAYERS:
		tex["cat/" + n] = load("res://assets/cat/%s.png" % n)
	for h in cat_cfg["hats"] + cat_cfg["outfits"]:
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
			st.cat["fur"] = parts[0].to_int()
			st.cat["pattern"] = parts[1].to_int()
			st.cat["hat"] = parts[2].to_int()
			st.cat["created"] = true
			if parts.size() > 3:
				st.cat["outfit"] = parts[3].to_int()
			wardrobe.open = false
			outfit_shop.open = false
			shipyard_panel.close()
			dest_panel.close()
			quest_panel.open = false
			signal_panel.close()
	if OS.has_environment("CATFISH_FILL"):
		var ids: Array = game.fish_by_id.keys()
		for i in OS.get_environment("CATFISH_FILL").to_int():
			game.economy.add_catch(st, st.new_id("c"), ids[i % ids.size()], false)
	if OS.has_environment("CATFISH_BIRDKIND"):        # 调试：让一只鸟（steal / gift / none）立刻来访
		var bk := OS.get_environment("CATFISH_BIRDKIND")
		var bi: String = String(game.fish_by_id.keys()[0]) if bk == "steal" else ("bottle" if bk == "gift" else "")
		world.call_deferred("bird_start", bk, bi, Time.get_ticks_msec())
	if OS.has_environment("CATFISH_CHEST"):       # 调试：每一竿都钓到宝箱
		game.set_chest_chance(1.0)
	if OS.has_environment("CATFISH_CATNAME"):      # 调试：直接给小猫起名（不弹起名框）
		st.cat_name = OS.get_environment("CATFISH_CATNAME").substr(0, 6)
	if OS.has_environment("CATFISH_BOATLV"):       # 调试：船的等级（0–3）
		st.boat_level = OS.get_environment("CATFISH_BOATLV").to_int()
	if OS.has_environment("CATFISH_BOATX"):        # 调试：船开局停在这个位置（512 = 贴着码头）
		st.journey["boat_x"] = OS.get_environment("CATFISH_BOATX").to_int()
		st.journey["line_out"] = 0
	if OS.has_environment("CATFISH_ITEMS") or OS.has_environment("CATFISH_WH"):
		st.bag_slots = 40                          # 调试：格子开大，所有物品都放得下
	if OS.has_environment("CATFISH_ITEMS"):       # 调试：开局每种物品给这么多个，并打开物品栏
		for d in game.inventory.defs:
			game.inventory.add(st, d["id"], OS.get_environment("CATFISH_ITEMS").to_int())
		wardrobe.open = false
		outfit_shop.open = false
		shipyard_panel.close()
		dest_panel.close()
		quest_panel.open = false
		signal_panel.close()
		bag.open = true
	if OS.has_environment("CATFISH_WH"):          # 调试：物品各给 N 个，一半存进仓库，并打开仓库面板
		for d in game.inventory.defs:
			game.inventory.add(st, d["id"], OS.get_environment("CATFISH_WH").to_int())
			game.inventory.stash(st, d["id"], OS.get_environment("CATFISH_WH").to_int() / 2)
		wardrobe.open = false
		outfit_shop.open = false
		shipyard_panel.close()
		dest_panel.close()
		quest_panel.open = false
		signal_panel.close()
		bag.open_warehouse()
	if OS.has_environment("CATFISH_QSTATE"):      # 调试：keeper,tailor 进行中、keeper2 已完成（也给一点材料）
		st.quests = {"keeper": "active", "tailor": "active"}
		game.inventory.add(st, "pearl", 1)
		game.inventory.add(st, "boot", 1)
	if OS.has_environment("CATFISH_BAGSEL"):      # 调试：物品栏选中第 N 个
		bag.sel = OS.get_environment("CATFISH_BAGSEL").to_int()
	if OS.has_environment("CATFISH_WALLET"):      # 调试：钱包铜币数
		st.wallet_gold = OS.get_environment("CATFISH_WALLET").to_int()
	if OS.has_environment("CATFISH_ADMIN"):       # 调试：直接打开后台，钱包给点钱
		st.wallet_gold = 23456
		st.piggy = 12345
		admin.open = true
	if OS.has_environment("CATFISH_CATCH"):       # 调试：显示钓到鱼的提示（鱼 id）
		var cf: Dictionary = game.fish_by_id.get(OS.get_environment("CATFISH_CATCH"), {})
		_catch_name = str(cf.get("name", ""))
		_catch_size = 37
		_catch_rare = int(cf.get("rarity", 0)) >= 2
		_catch_t0 = Time.get_ticks_msec() + 100000
	if OS.has_environment("CATFISH_BOOK"):        # 调试：造一些统计数据并打开图鉴册的第 N 页
		var rngd := RandomNumberGenerator.new()
		rngd.seed = 7
		for i in 20:
			var key := clock.day_key(i)
			st.stats["daily"][key] = rngd.randi_range(0, 9)
			var hrs: Array = []
			for h in 24:
				hrs.append(rngd.randi_range(0, 3600) if (h >= 9 and h <= 21 and rngd.randf() < 0.5) else 0)
			st.stats["focus_hours"][key] = hrs
		for fid in game.fish_by_id.keys():
			st.stats["fish_counts"][fid] = rngd.randi_range(0, 12)
			st.stats["fish_best"][fid] = rngd.randi_range(8, 90)
		st.stats["total_fish"] = 77
		wardrobe.open = false
		outfit_shop.open = false
		shipyard_panel.close()
		dest_panel.close()
		quest_panel.open = false
		signal_panel.close()
		book.open_page(OS.get_environment("CATFISH_BOOK").to_int())
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
	if OS.has_environment("CATFISH_BIRD"):         # 调试：一开局就有鸟来
		st.effects["bird_next_ms"] = 1
	if OS.has_environment("CATFISH_MOVE"):
		game.time_scale = maxf(1.0, OS.get_environment("CATFISH_MOVE").to_float())
	if OS.has_environment("CATFISH_ROAM_AT"):
		_debug_dir_from = OS.get_environment("CATFISH_ROAM_AT").to_int()
	if OS.has_environment("CATFISH_ROAM"):
		_debug_dir = OS.get_environment("CATFISH_ROAM").to_int()
	if OS.has_environment("CATFISH_GO"):
		game.go_to_town()
	if OS.has_environment("CATFISH_MENU"):
		wardrobe.open = false
		outfit_shop.open = false
		shipyard_panel.close()
		dest_panel.close()
		quest_panel.open = false
		signal_panel.close()
		menu.open = true
		menu.tab = OS.get_environment("CATFISH_MENU").to_int()
		menu.shop_page = OS.get_environment("CATFISH_SHOP").to_int() if OS.has_environment("CATFISH_SHOP") else 0


# ------------------------------------------------------------------ 视图模式
func _apply_view_mode() -> void:
	var win := get_window()
	mini = adapter.is_overlay() and int(game.state.settings.get("view_mode", 1)) == 0
	_cam_snap = true
	_mini_shown = true
	_mini_hide_at = Time.get_ticks_msec() + 2000   # 刚切到迷你窗时先显示 2 秒，方便找到它
	if mini:
		book.open = false                 # 图鉴册只有完整窗口里有
		admin.open = false
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
		_cam_fx = clampf(cx - view.x * 0.5, CAM_MIN, max_x)
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
	_cam_fx = clampf(_cam_fx, CAM_MIN, max_x)
	cam = Vector2(roundf(_cam_fx), FULL_MIN_H - view.y)


## 完整窗口里用方向键带着小猫在镇上走；松手一会儿后交还给自动流程。
var _auto_next_t: int = 0            # 迷你窗自动挂机：下次判断的时刻
var _stand_depart: bool = false     # 走到码头后上船回小镇
var _stand_cast: bool = false      # 走到湖边钓位后自动甩竿
var _stand_to: float = INF         # 和居民聊天时慢慢退到的位置

func _update_roam(dt: float) -> void:
	var j: Journey = game.journey
	var t := Time.get_ticks_msec()
	if _pending_cast_at > 0 and t >= _pending_cast_at:
		_pending_cast_at = 0
		game.cast_line()
	world.roam_moving = false
	world.boat_moving = false
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
			world.room_x = clampf(world.room_x + dir * World.ROAM_SPEED * game.move_speed() * dt, World.ROOM_MIN_X, World.ROOM_MAX_X)
			world.room_flip = dir < 0
		return
	if _stand_to != INF:
		if dir != 0 or (j.activity() != Journey.Activity.ROAM and not j.on_island()):
			_stand_to = INF
			_stand_cast = false
			_stand_depart = false
		else:
			if absf(_roam_fx - j.roam_x()) > 1.5:
				_roam_fx = j.roam_x()
			if game.line_out():
				game.reel_in()
			world.roam_flip = _stand_to < _roam_fx - 0.5
			_roam_fx = move_toward(_roam_fx, _stand_to, World.ROAM_SPEED * game.move_speed() * dt)
			j.set_roam_x(_roam_fx)
			world.roam_moving = true
			_last_walk_input = t
			if absf(_roam_fx - _stand_to) < 0.5:
				_stand_to = INF
				if _stand_depart:
					_stand_depart = false
					if game.leave_island():
						play("click")
						_go_to_town()
				if _stand_cast:
					_stand_cast = false
					world.roam_flip = true
					if game.cast_line():
						play("click")
	if int(game.state.effects.get("lake_resume", 0)) == 1 and j.activity() == Journey.Activity.FISHING:
		if game.can_land():
			game.state.effects["lake_resume"] = 0
			if game.land_on_island():
				_roam_fx = game.island_land_x()
				world.roam_flip = true
				_stand_to = game.lake_spot_x()
				_stand_cast = true
		elif not game.at_island_dock():
			game.state.effects["lake_resume"] = 0
	if mini and dir == 0 and t >= _auto_next_t and t - _last_walk_input > int(game.auto_cfg().get("idle_ms", 4000)) \
			and not panel_open() and _stand_to == INF and _auto_x == INF and _queued_x == INF and interior == "" \
			and not game.pomodoro.is_break():
		_auto_next_t = t + 1500
		_auto_policy()
	if _queued_x != INF:
		var qa: int = j.activity()
		if dir != 0 or not (qa == Journey.Activity.WALK_TO_BOAT or qa == Journey.Activity.SAIL_OUT or qa == Journey.Activity.SAIL_BACK or game.can_steer()):
			_queued_x = INF
		elif game.can_steer():
			var qx := _queued_x
			_queued_x = INF
			start_auto_sail(qx)
	if _auto_x != INF:
		if dir != 0 or not game.can_steer() or interior != "":
			_auto_x = INF                      # 按方向键 / 进入休息：取消自动航行，交还给手动
		else:
			_auto_step(dt)
			return
	if dir == 0 and (absf(_boat_v) > 0.5 or (game.wave_push(_boat_fx) > 0.0 and not game.line_out())) and game.can_steer() and interior == "":
		# 松开方向键后船不会立刻停：按减速度滑行到 0，滑行时桨还在划（速度慢到一定程度再收桨）
		_boat_v = move_toward(_boat_v, 0.0, BOAT_DECEL * game.move_speed() * dt)
		if absf(_boat_fx - float(j.boat_x())) > 1.5:
			_boat_fx = float(j.boat_x())
		_apply_waves(dt, false)
		_boat_fx = clampf(_boat_fx + _boat_v * game.move_speed() * dt, -20000.0, 9999.0)
		game.steer_to(_boat_fx)
		var glim := game.boat_limits()
		if j.boat_x() <= int(glim.x) or j.boat_x() >= int(glim.y):
			_boat_v = 0.0
		world.boat_dir = 1.0 if _boat_v >= 0.0 else -1.0
		world.boat_moving = absf(_boat_v) > 8.0
		if world.boat_moving:
			world.face_left = world.boat_dir < 0.0
	elif dir == 0 or not game.can_steer():
		if dir == 0:
			_boat_v = 0.0
	if dir != 0 and interior == "" and game.can_halt_sail():
		game.halt_sail()                       # 方向键随时打断自动航行，船停在当前位置，接着手动划
	if dir != 0 and game.can_steer() and interior == "":
		# 在船上：方向键划船（每帧重新读回存档里的位置，避免和别处改动打架）
		if absf(_boat_fx - float(j.boat_x())) > 1.5:
			_boat_fx = float(j.boat_x())
		if game.line_out():                          # 竿还在水里：先快速收杆，收完才开始划
			# 只有浮漂已经在水里时才演收杆动画；上饵、甩竿途中浮漂还没入水，直接收起来就划
			var bobber_in_water: bool = _bobber_in_water()
			game.reel_in()
			if bobber_in_water:
				world.retract_t0 = t
				_row_ready_at = t + World.RETRACT_MS
		world.boat_dir = float(dir)
		world.face_left = dir < 0
		_pending_cast_at = 0
		_last_walk_input = t
		if t >= _row_ready_at:
			_boat_v = move_toward(_boat_v, float(dir) * BOAT_SPEED * game.current_mult(_boat_fx, float(dir)), BOAT_ACCEL * game.move_speed() * dt)
			_apply_waves(dt, dir < 0)
			_boat_fx = clampf(_boat_fx + _boat_v * game.move_speed() * dt, -20000.0, 9999.0)
			game.steer_to(_boat_fx)
			var lim := game.boat_limits()
			var at_end: bool = (dir < 0 and j.boat_x() <= lim.x) or (dir > 0 and j.boat_x() >= lim.y)
			if at_end:
				_boat_v = 0.0
			world.boat_moving = not at_end
	elif dir != 0 and j.in_town():
		if j.activity() != Journey.Activity.ROAM:
			var was_behind: bool = world.walk_behind or j.activity() == Journey.Activity.VENDING or j.activity() == Journey.Activity.SOLD_OUT
			if game.begin_roam(world.cat_pos.x):
				_roam_fx = world.cat_pos.x
				world.roam_behind = was_behind       # 在摊位里按方向键：先在柜台后面走，走出摊位才回到前面
		if j.activity() == Journey.Activity.ROAM:
			if absf(_roam_fx - j.roam_x()) > 1.5:
				_roam_fx = j.roam_x()      # 读档后或从屋里出来：以存档里的位置为准，避免第一步瞬移到码头
			_roam_fx = clampf(_roam_fx + dir * World.ROAM_SPEED * game.move_speed() * dt, World.ROAM_MIN_X, World.ROAM_MAX_X)
			j.set_roam_x(_roam_fx)
			world.roam_moving = true
			world.roam_flip = dir < 0
			_last_walk_input = t
	elif dir != 0 and j.on_island():
		# 在小岛上：方向键带着小猫走，东边最远到码头尽头，西边到岛的西岸
		if absf(_roam_fx - j.roam_x()) > 1.5:
			_roam_fx = j.roam_x()
		_roam_fx = clampf(_roam_fx + dir * World.ROAM_SPEED * game.move_speed() * dt, game.island_walk_min(), game.island_land_x())
		if game.line_out() and absf(_roam_fx - j.roam_x()) > 0.01:
			game.reel_in()                      # 一走动就收竿
		j.set_roam_x(_roam_fx)
		world.roam_moving = true
		world.roam_flip = dir < 0
		_last_walk_input = t
	elif j.on_island() and mini:
		pass                                 # 迷你窗里也留在岛上当前的位置（在钓位就继续钓）
	elif j.activity() == Journey.Activity.ROAM and mini:
		# 玩家接管后小猫就一直听玩家的，不会自己走开；只有切到迷你悬浮窗才交还给自动流程
		_end_roam_auto(float(j.roam_x()), true)


## 自动航行：加速到巡航速度，进港前平滑减速，到了就停。
func _auto_step(dt: float) -> void:
	var j: Journey = game.journey
	if absf(_boat_fx - float(j.boat_x())) > 1.5:
		_boat_fx = float(j.boat_x())
	var remain := _auto_x - _boat_fx
	var dirn := 1.0 if remain >= 0.0 else -1.0
	var cruise: float = BOAT_SPEED * game.current_mult(_boat_fx, dirn)       # 和手动划一样快（顺流快、逆流慢）
	var cap := maxf(14.0, minf(cruise, sqrt(2.0 * AUTO_DECEL * absf(remain))))
	_boat_v = move_toward(_boat_v, dirn * cap, BOAT_ACCEL * game.move_speed() * dt)
	_boat_fx += _boat_v * game.move_speed() * dt
	game.steer_to(_boat_fx)
	world.boat_dir = dirn
	world.boat_moving = true
	world.face_left = dirn < 0.0
	_last_walk_input = Time.get_ticks_msec()
	if absf(_auto_x - _boat_fx) < 1.0 or absf(_auto_x - float(j.boat_x())) < 1.0:
		_boat_v = 0.0
		_auto_x = INF
		world.boat_moving = false


## 开始自动航行去 x。成功返回 true。
func start_auto_sail(x: float) -> bool:
	if not game.can_steer():
		_toast("现在不能出航", "")
		play("deny")
		return false
	if not game.boat_passes_waves() and x < game.wave_zone().x:
		_toast("浪太大了", "小船过不去")
		play("deny")
		return false
	if game.line_out():
		var in_water: bool = _bobber_in_water()
		game.reel_in()
		if in_water:
			world.retract_t0 = Time.get_ticks_msec()
	_auto_x = x
	_boat_v = 0.0
	play("click")
	return true


func _end_roam_auto(x: float, by_policy: bool = false) -> void:
	world.route_behind_start = world.roam_behind
	game.end_roam(world.frac_to_stall(x), world.frac_to_boat(x), by_policy)


## ` 键（中文输入法下是"·"）：开发者模式，随便换形象，不花钱。
## 浪区：推力把船往右推，划得越深推得越狠；第一次被推时提示一下。
func _apply_waves(dt: float, rowing_left: bool) -> void:
	var push: float = game.wave_push(_boat_fx)
	if push <= 0.0:
		return
	_boat_v += WAVE_PUSH * lerpf(0.4, 1.0, push) * game.move_speed() * dt
	var stop: float = game.wave_zone().y
	if _boat_fx <= stop and _boat_v < 0.0:
		_boat_v = 0.0
	if rowing_left and push > 0.35 and Time.get_ticks_msec() - _toast_t0 > 3500:
		_toast("浪太大了", "小船过不去")
		play("deny")


func _toast(l1: String, l2: String = "") -> void:
	_toast_l1 = l1
	_toast_l2 = l2
	_toast_t0 = Time.get_ticks_msec()


func _is_dev_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_QUOTELEFT or event.unicode == 96 or event.unicode == 183


func _toggle_dev_mode() -> void:
	if wardrobe.open:
		wardrobe.close()
	else:
		menu.open = false
		bag.open = false
		book.open = false
		outfit_shop.close()
		shipyard_panel.close()
		dest_panel.close()
		quest_panel.close()
		signal_panel.close()
		wardrobe.open = true
		wardrobe.dev = true
	play("click")
	_update_polygon()


## 互动键：在海上 = 收着竿时重新甩竿；自由走动时在摊位旁 = 开张，在码头 = 上船。
func _interact() -> void:
	var j: Journey = game.journey
	if interior != "":
		_interact_inside()
	elif j.on_boat():
		if game.at_dock() and game.can_go_to_town():
			_go_to_town()             # 船贴着码头：按互动键直接上岸
		elif game.can_land():
			if game.land_on_island():
				_roam_fx = game.island_land_x()
				world.roam_flip = true
				play("click")
				log.write("land", {"island": game.island_info().get("id", "")})
		elif j.activity() == Journey.Activity.FISHING and game.fishing_blocked() and not game.pomodoro.is_break():
			_toast("水太浅了", "不能钓鱼")
			play("deny")
		elif j.activity() == Journey.Activity.FISHING and world.face_left and not game.line_out() and not game.pomodoro.is_break() and not game.fishing_blocked():
			world.face_left = false           # 朝左停着：先转身，转完再甩竿
			world.turn_t0 = Time.get_ticks_msec()
			_pending_cast_at = world.turn_t0 + World.TURN_MS
			play("click")
		elif j.activity() == Journey.Activity.FISHING and game.cast_line():
			play("click")             # 停船后按互动键：重新甩竿
	elif j.on_island():
		_interact_island(float(j.roam_x()))
	elif j.activity() == Journey.Activity.SOLD_OUT:
		_go_fishing()
	elif j.activity() == Journey.Activity.ROAM:
		var x := float(j.roam_x())
		if world.near_pier(x):
			game.roam_board(world.frac_to_boat(x))
			play("click")
		elif world.near_stall(x) and not game.state.basket.is_empty():
			_end_roam_auto(x)      # 从当前位置走到摊位后面开张
			play("click")
		elif not world.door_near(x).is_empty():
			_enter_building(world.door_near(x)[2])
		elif world.stroller_near(x, Time.get_ticks_msec()) >= 0:
			var t := Time.get_ticks_msec()
			var si: int = world.stroller_near(x, t)
			world.chat_with(si, t)
			var nx: float = world.chat_stand_x(x, world.chat_x)      # 太近就退开一点（走过去，不是瞬移），免得和居民叠在一起
			if absf(nx - x) > 0.5 and game.state.journey.get("activity", -1) == Journey.Activity.ROAM:
				_stand_to = clampf(nx, World.ROAM_MIN_X, World.ROAM_MAX_X)
			world.roam_flip = world.chat_x + 8.0 < nx + 16.0           # 站定后面向居民
			_last_walk_input = t
			play("click")
		else:
			play("deny")


## 小岛上的互动：码头尽头 = 回船；灯塔看守旁 = 聊天（接任务 / 交付）；湖边 = 看一眼。
func _interact_island(x: float) -> void:
	if world.island_near_pier(x):
		if game.leave_island():
			play("click")
	elif world.island_near_keeper(x):
		play("click")
		quest_panel.open_talk(game.room_quest("lighthouse"))
		on_panel_toggled()
	elif world.island_near_console(x):
		if not game.lighthouse_lit():
			_toast("灯塔还没修好", "")
			play("deny")
		else:
			play("click")
			signal_panel.open_panel()
			on_panel_toggled()
	elif world.island_near_bench(x):
		if not game.has_pot_recipe():
			_toast("需要蟹笼配方", "")
			play("deny")
		elif game.pot_count() >= int(game.pots_cfg().get("max", 3)):
			_toast("蟹笼已满", "")
			play("deny")
		elif not game.pot_materials_ok():
			_toast("材料不够", "雾灯贝和木板")
			play("deny")
		elif game.craft_pot():
			_toast("蟹笼做好了", "已放进湖里")
			play("catch")
		else:
			play("deny")
	elif world.island_near_chest(x):
		var cg: Dictionary = game.open_west_chest()
		if cg.is_empty():
			play("deny")
		else:
			play("chest")
			_toast("打开了木箱", "")
			world.chest_open_t0 = Time.get_ticks_msec()
			_float_money(int(cg["gold"]), world.cat_pos + Vector2(34, 8))
			for iid in cg["items"]:
				_float("+%d" % int(cg["items"][iid]), str(game.inventory.by_id.get(iid, {}).get("sprite", "")), world.cat_pos + Vector2(34, -6))
	elif world.island_near_drift(x) >= 0:
		var di: int = world.island_near_drift(x)
		var got: Dictionary = game.pick_drift(di)
		if got.is_empty():
			play("deny")
		else:
			play("catch")
			if int(got["gold"]) > 0:
				_toast("捡到了", "一点铜币")
				_float_money(int(got["gold"]), world.cat_pos + Vector2(34, 8))
			else:
				var idef: Dictionary = game.inventory.by_id.get(str(got["item"]), {})
				_toast("捡到了", str(idef.get("name", "")))
				_float("+1", str(idef.get("sprite", "")), world.cat_pos + Vector2(34, 8))
	elif world.island_near_lake(x):
		if game.at_lake_spot():
			if game.pots_ready() > 0 and not game.line_out():
				var pc: Dictionary = game.collect_pots()
				play("catch")
				_toast("收蟹笼", "有收获")
				_float_money(int(pc["gold"]), world.cat_pos + Vector2(-24, 8))
				for iid in pc["items"]:
					_float("+%d" % int(pc["items"][iid]), str(game.inventory.by_id.get(iid, {}).get("sprite", "")), world.cat_pos + Vector2(-24, -6))
			elif game.line_out():
				game.reel_in()
				play("click")
			elif game.pomodoro.is_break():
				play("deny")
			elif game.cast_line():
				world.roam_flip = true
				play("click")
			else:
				play("deny")
		elif not game.pomodoro.is_break():
			_stand_to = game.lake_spot_x()       # 慢慢走到湖边，到了自动甩竿
			_stand_cast = true
			play("click")
		else:
			play("deny")
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
		"storage":
			play("click")
			bag.open_warehouse()
			_update_polygon()
		"dex":
			play("click")
			if not mini:
				open_book(0)
				return
			menu.tab = 1
			menu.open = true
		"piggy":
			var what: String = game.piggy_use()
			if what == "":
				play("deny")
				_toast("存钱罐是空的", "")
			else:
				play("coin")
				_toast("存进存钱罐" if what == "deposit" else "从存钱罐取出", "")
		"stats":
			play("click")
			if not mini:
				open_book(2)
				return
			menu.tab = 2
			menu.open = true
		"quest":
			play("click")
			quest_panel.open_talk(game.room_quest(interior))
		"hats":
			play("click")
			outfit_shop.open_kind("hat")
		"boats":
			play("click")
			shipyard_panel.open_panel()
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


func _hud_dx() -> float:
	return MINI_HUD_DX if mini else 0.0


func _update_polygon() -> void:
	if not adapter.is_overlay():
		return
	if not mini:
		adapter.set_interactive_polygon(get_window(), PackedVector2Array())
		return
	# 上面是 HUD 面板，下面是场景；两块拼成一个多边形，其余透明区域鼠标穿透
	var p := PANEL_POS + Vector2(_hud_dx(), 0)
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
	elif what == NOTIFICATION_OS_IME_UPDATE and _naming:
		_ime_text = DisplayServer.ime_get_text()


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
	if not _naming and game.state.cat_name == "" and not wardrobe.open and bool(game.state.cat.get("created", false)) and not mini:
		_begin_naming()                    # 捏完猫、还没有名字：先给小猫起名
	game.fast_forward(dt * 1000.0)        # [ ] 全局加速：把所有截止时刻前移
	if game.take_wallet_full():
		_toast("钱包满了", "多的放进存钱罐")
		play("deny")
	var _ov: String = game.take_overflow()
	if _ov != "":
		_toast("物品栏满了", {"dropped": "东西扔掉了", "replaced": "换掉了旧物品"}.get(_ov, "送去了仓库"))
		play("deny")
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
		if OS.has_environment("CATFISH_QUEST"):        # 调试：letter = 读信；talk = 任务进行中、东西凑齐了和店主说话
			if OS.get_environment("CATFISH_QUEST") == "letter":
				quest_panel.open_letter("keeper")
			else:
				game.state.quests["keeper"] = "active"
				game.inventory.add(game.state, "pearl")
				quest_panel.open_talk(game.room_quest(interior))
		if OS.has_environment("CATFISH_OUTFITSHOP"):   # 调试：进屋后直接打开货架（hat / outfit）
			game.state.wallet_gold = 150
			outfit_shop.open_kind(OS.get_environment("CATFISH_OUTFITSHOP"))
		if OS.has_environment("CATFISH_SHIPYARD"):     # 调试：进造船厂后直接打开升级面板，值为钱包铜币数
			game.state.wallet_gold = int(OS.get_environment("CATFISH_SHIPYARD"))
			shipyard_panel.open_panel()
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
	var prev_fs := _last_fs
	_last_fs = fs
	match fs:
		Fishing.State.BAITING:
			play("click")
		Fishing.State.CASTING:
			play("cast")
		Fishing.State.TWITCH:
			play("twitch")
		Fishing.State.TANGLED:
			play("deny")
		Fishing.State.WAITING:
			if prev_fs == Fishing.State.CASTING:       # 抛竿落水才溅水花，动漂之间的再等待不溅
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
			_catch_name = str(f.get("name", ""))
			_catch_suffix = ""
			_catch_size = int(e.get("size", 0))
			_catch_rare = int(f.get("rarity", 0)) >= 2
			_catch_t0 = t
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
			_float_money(e["gold"], world.cat_pos + Vector2(30, -4))
			if e.get("item", "") != "":
				var it: Dictionary = game.inventory.by_id.get(e["item"], {})
				if tex.has(it.get("sprite", "")):
					_float("+1", it["sprite"], world.cat_pos + Vector2(34, 8))
		"junk":
			world.hop_t0 = t
			play("catch")
			var jd: Dictionary = game.inventory.by_id.get(e["item"], {})
			if tex.has(jd.get("sprite", "")):
				_float("+1", jd["sprite"], world.cat_pos + Vector2(34, 8))
		"bait":
			world.bait_id = e["bait"]
		"basket_full":
			if not _full_notified:
				_full_notified = true
				adapter.notify("鱼篓满了", "点小猫头上的气泡，让它去小镇摆摊卖鱼。")
		"depart":
			_full_notified = false
		"docked":
			world.roam_flip = false      # 靠岸上岸：面朝小镇
		"open":
			play("buy")
		"sale":
			play("coin")
			world.hop_t0 = t
			world.on_sale(e["fish_id"])
			_float_money(e["gold"], Vector2(World.STALL_X + 8, World.GROUND_Y - 52))
		"bird_visit":
			world.bird_start(e["kind"], e["item"], t)
		"bird_gift":
			var gift: Dictionary = game.inventory.by_id.get(e["item"], {})
			play("catch")      # 礼物已经在鸟松爪时掉进船里了，不再另外飘一个
		"bird_steal":
			play("deny")
			_show_loss(str(e.get("fish_id", "")), int(e.get("size", 0)), "被偷走了")
		"ate":
			_show_loss(str(e.get("fish_id", "")), int(e.get("size", 0)), "被吃掉了")
			world.eat_t0 = t
			world.eat_fish = e["fish_id"]
			play("bite")
		"island_found":
			_title_name = str(e.get("name", ""))
			_title_t0 = t
			play("rare")
		"focus_done":
			play("done")
			world.hop_t0 = t
			_sparkles(Vector2(view.x / 2, 30), 26, minf(view.x * 0.4, 90.0), true)
			if e["gold"] > 0:
				_float_money(e["gold"], world.cat_pos + Vector2(-6, -14))
			adapter.notify("番茄完成！", "木箱里的 %d 条鱼卖了 %d 金币。休息一下吧。" % [e["fish_count"], e["gold"]])
		"break_done":
			play("break_end")
			adapter.notify("休息结束", "小猫睡醒了，准备开始下一个番茄吧。")


func _float_money(copper: int, world_pos: Vector2) -> void:
	_float("+%d" % int(Money.tier(copper)[1]), Money.icon(copper), world_pos)


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
	if _naming:
		_name_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and not mini:
			if _confirm_quit:
				if event.keycode == KEY_ESCAPE:
					_confirm_quit = false
			elif event.keycode == KEY_BRACKETRIGHT or event.keycode == KEY_BRACKETLEFT:
				game.change_move_speed(1 if event.keycode == KEY_BRACKETRIGHT else -1)   # ] 加快 [ 减慢（测试用）
				play("click")
			elif event.keycode == KEY_F9:
				play("click")
				if not admin.open:
					menu.open = false
					bag.open = false
					book.open = false
				admin.toggle()             # F9 后台
			elif admin.open:
				if event.keycode == KEY_ESCAPE:
					admin.open = false
					_update_polygon()
			elif event.keycode == KEY_C and not wardrobe.open:
				toggle_status()            # C 开关小猫状态
			elif book.open:
				if event.keycode == KEY_ESCAPE:
					book.open = false
					_update_polygon()
				else:
					book.key(event.keycode)    # Tab 换页，左右换日，上下换月
			elif (event.keycode == KEY_TAB or event.keycode == KEY_I) and bag.open and bag.wh:
				bag.switch_tab()           # 在仓库里：Tab 切换"身上 / 仓库"
			elif event.keycode == KEY_TAB or event.keycode == KEY_I:
				toggle_bag()               # Tab / I 开关物品栏
			elif bag.open:
				if event.keycode == KEY_ESCAPE:
					bag.open = false
					_update_polygon()
				else:
					bag.key(event.keycode)     # 方向键选格子，空格使用
			elif signal_panel.open:
				if event.keycode == KEY_ESCAPE:
					signal_panel.close()
					_update_polygon()
				else:
					signal_panel.key(event.keycode)
			elif quest_panel.open:
				if event.keycode == KEY_ESCAPE:
					quest_panel.close()
					signal_panel.close()
					_update_polygon()
				else:
					quest_panel.key(event.keycode)
			elif dest_panel.open:
				if event.keycode == KEY_ESCAPE:
					dest_panel.close()
					_update_polygon()
				else:
					dest_panel.key(event.keycode)
			elif shipyard_panel.open:
				if event.keycode == KEY_ESCAPE:
					shipyard_panel.close()
					dest_panel.close()
					_update_polygon()
				else:
					shipyard_panel.key(event.keycode)
			elif outfit_shop.open:
				if event.keycode == KEY_ESCAPE:
					outfit_shop.close()
					shipyard_panel.close()
					dest_panel.close()
					quest_panel.close()
					signal_panel.close()
					_update_polygon()
				else:
					outfit_shop.key(event.keycode)     # 上下选货，空格买下 / 穿上
			elif (menu.open or wardrobe.open) and event.keycode == KEY_ESCAPE:
				menu.open = false          # Esc 关闭面板（从店里出来）
				if wardrobe.open:
					wardrobe.close()
				_update_polygon()
			elif _is_dev_key(event):
				_toggle_dev_mode()
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
	var hp := p - Vector2(_hud_dx(), 0)                  # 顶栏自己的坐标（迷你窗里整体左移了）
	if _confirm_quit:
		# 确认框打开时只认这两个按钮，点别处一律当作取消
		if QUIT_YES.has_point(p):
			_quit()
		else:
			_confirm_quit = false
			play("click")
		return
	if BTN_MAIN.has_point(hp):
		_pressed_btn = "main"
		_press_main()
	elif BTN_TOWN.has_point(hp):
		_pressed_btn = "town"
		_town_button()
	elif BTN_MENU.has_point(hp):
		# 面板上只留"设置"。商店、图鉴、统计、换形象都要去镇上对应的房子里
		play("click")
		if wardrobe.open:
			wardrobe.close()
		bag.open = false
		book.open = false
		if menu.open:
			menu.open = false
		else:
			menu.tab = 3
			menu.open = true
		_update_polygon()
	elif BTN_DEST.has_point(hp):
		play("click")
		if dest_panel.open:
			dest_panel.close()
		elif game.journey.on_boat():
			menu.open = false
			bag.open = false
			book.open = false
			dest_panel.open_panel()
		else:
			_toast("要先上船", "")
			play("deny")
		_update_polygon()
	elif BTN_STATUS.has_point(hp):
		toggle_status()
	elif BTN_VIEW.has_point(hp):
		play("click")
		toggle_view_mode()
	elif BTN_BAG.has_point(hp):
		toggle_bag()
	elif BTN_CLOSE.has_point(hp) and _quit_button_visible():
		play("click")
		_confirm_quit = true      # 先问一句，不直接退出
	elif Rect2(PANEL_POS, PANEL_SIZE).has_point(hp):
		pass
	elif admin.click(p) or book.click(p) or bag.click(p) or menu.click(p) or wardrobe.click(p) or outfit_shop.click(p) or shipyard_panel.click(p) or dest_panel.click(p) or quest_panel.click(p) or signal_panel.click(p):
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
	return menu.open or _naming or wardrobe.open or outfit_shop.open or shipyard_panel.open or dest_panel.open or quest_panel.open or signal_panel.open or bag.open or book.open or admin.open


## 小猫状态页（菜单的第 5 页）：已经开着就关，否则打开。
func toggle_status() -> void:
	play("click")
	book.open = false
	if wardrobe.open:
		wardrobe.close()
	outfit_shop.close()
	shipyard_panel.close()
	dest_panel.close()
	quest_panel.close()
	signal_panel.close()
	bag.open = false
	if menu.open and menu.tab == 4:
		menu.open = false
	else:
		menu.tab = 4
		menu.open = true
	_update_polygon()


## 打开图鉴册（只有完整窗口里有）：0 图鉴 / 1 最高纪录 / 2 统计。
func open_book(page: int) -> void:
	if mini:
		return
	menu.open = false
	bag.open = false
	if wardrobe.open:
		wardrobe.close()
	outfit_shop.close()
	shipyard_panel.close()
	dest_panel.close()
	quest_panel.close()
	signal_panel.close()
	book.open_page(page)
	_update_polygon()


func toggle_bag() -> void:
	play("click")
	book.open = false
	menu.open = false
	if wardrobe.open:
		wardrobe.close()
	outfit_shop.close()
	shipyard_panel.close()
	dest_panel.close()
	quest_panel.close()
	signal_panel.close()
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
	var act: int = game.journey.activity()
	if act == Journey.Activity.SAIL_OUT:
		if game.halt_sail():           # 去小镇的路上再点一下：船停在当前位置，不去了
			play("click")
		else:
			play("deny")
	elif act == Journey.Activity.SAIL_BACK:
		if game.halt_sail():           # 回钓点的路上再点一下：船停在当前位置
			play("click")
		else:
			play("deny")
	elif act == Journey.Activity.WALK_TO_BOAT:
		if game.begin_roam(world.cat_pos.x):     # 走向码头的路上再点一下：小猫停下，交给玩家自己走
			_roam_fx = world.cat_pos.x
			play("click")
		else:
			play("deny")
	elif game.journey.on_island():
		game.state.effects["lake_resume"] = 1          # 卖完鱼回来，直接回湖边接着钓
		if absf(float(game.journey.roam_x()) - game.island_land_x()) < 2.0:
			if game.leave_island():
				play("click")
				_go_to_town()
		else:
			game.reel_in()
			_stand_to = game.island_land_x()            # 先走到码头，再上船出发
			_stand_cast = false
			_stand_depart = true
			play("click")
	elif game.journey.in_town():
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


func _bobber_in_water() -> bool:
	return game.fishing.state in [Fishing.State.WAITING, Fishing.State.TWITCH, Fishing.State.HOOKED, Fishing.State.REELING, Fishing.State.SETTLEMENT]


func _go_to_town(stop_at_dock: bool = false) -> void:
	var had_line: bool = game.line_out() and game.fishing.is_active() and _bobber_in_water()
	if game.go_to_town(stop_at_dock):
		if had_line:
			world.retract_t0 = Time.get_ticks_msec()      # 先收杆再开船
		log.write("go_to_town", {"basket": game.state.basket.size()})
		world.face_left = false          # 往东开：小猫朝前（不是倒着开），上岸后面朝小镇
		world.roam_flip = false
		_full_notified = false
		play("cast")
	else:
		play("deny")


## 回小镇按钮外圈的跑马灯：一段亮光顺时针绕着边转，再点一下（或按方向键）就停下。
func _draw_marquee(r: Rect2, t: int) -> void:
	var w := int(r.size.x)
	var h := int(r.size.y)
	var per := 2 * (w + h) - 4
	var head := (t / 45) % per
	for k in 10:
		var idx := ((head - k) % per + per) % per
		var pt: Vector2
		if idx < w:
			pt = Vector2(idx, 0)
		elif idx < w + h - 1:
			pt = Vector2(w - 1, idx - w + 1)
		elif idx < 2 * w + h - 2:
			pt = Vector2(w - 1 - (idx - (w + h - 2)), h - 1)
		else:
			pt = Vector2(0, h - 1 - (idx - (2 * w + h - 3)))
		var c: Color = Pal.L_W if k < 3 else (Pal.L_Y if k < 7 else Pal.U_O)
		draw_rect(Rect2(r.position + pt, Vector2.ONE), c)


func _press_main() -> void:
	play("click")
	match game.pomodoro.phase():
		Pomodoro.Phase.IDLE:
			game.start_focus()
		Pomodoro.Phase.FOCUS:
			var gold := game.abandon_focus()
			if gold > 0:
				play("coin")
				_float_money(gold, world.cat_pos + Vector2(-6, -14))
		_:
			game.skip_break()


# ------------------------------------------------------------------ 大面板
## 完整窗口里的商店、造船厂、店主任务：和物品栏一样占满窗口（分辨率更大，不是把小面板放大）。
func big_rect() -> Rect2:
	return Rect2(Vector2(4, 33) - ui_off, Vector2(view.x - 8, view.y - 39))


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
		draw_set_transform(ui_off + Vector2(_hud_dx(), 0))
		_draw_hud(now)
		draw_set_transform(ui_off)
	draw_set_transform(Vector2.ZERO)
	_draw_particles(t)               # 闪光在顶栏之上、所有面板（物品栏、菜单……）之下
	draw_set_transform(ui_off)
	menu.draw()
	wardrobe.draw()
	outfit_shop.draw()
	shipyard_panel.draw()
	dest_panel.draw()
	quest_panel.draw()
	signal_panel.draw()
	if Time.get_ticks_msec() - _toast_t0 < 3000:
		label(_toast_l1, Vector2(17, 63), Pal.L_R)
		label(_toast_l2, Vector2(17, 74), Pal.L_R)
	_draw_catch_pop()
	bag.draw()
	book.draw()
	admin.draw()
	if _confirm_quit:
		_draw_quit_confirm()
	draw_set_transform(Vector2.ZERO)
	_draw_name_dialog(t)
	_draw_island_title()
	if not mini or _mini_shown:       # 右下角的版本号
		var ver: String = str(ProjectSettings.get_setting("application/config/version", ""))
		_text(ver, Vector2(view.x - ver.length() * 4 - 1, view.y - 6), Color(Pal.L_W, 0.7), true)


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
	var act_now: int = game.journey.activity()
	var show_fish: bool = in_town or act_now == Journey.Activity.SAIL_BACK
	var sailing: bool = act_now == Journey.Activity.SAIL_OUT or act_now == Journey.Activity.SAIL_BACK
	var town_ok: bool = game.can_halt_sail() if sailing else (true if act_now == Journey.Activity.WALK_TO_BOAT else true if act_now == Journey.Activity.ISLAND else game.can_go_fishing() if in_town else game.can_go_to_town())
	_tex_frame("btn_fish" if show_fish else "btn_town", BTN_TOWN.position, 1 if _pressed_btn == "town" else 0, 2,
			Color.WHITE if town_ok else Color(1, 1, 1, 0.35))
	if act_now == Journey.Activity.SAIL_OUT or act_now == Journey.Activity.SAIL_BACK or act_now == Journey.Activity.WALK_TO_BOAT:
		_draw_marquee(Rect2(BTN_TOWN.position - Vector2.ONE, BTN_TOWN.size + Vector2(2, 2)), Time.get_ticks_msec())
	_tex_frame("btn_gear", BTN_MENU.position, 1 if menu.open and menu.tab == 3 else 0, 2)
	if adapter.is_overlay():
		_tex_frame("btn_view", BTN_VIEW.position, 0, 2)
	_tex_frame("btn_bag", BTN_BAG.position, 1 if bag.open else 0, 2)
	_tex_frame("btn_dest", BTN_DEST.position, 1 if dest_panel.open else 0, 2)
	_tex_frame("btn_cat", BTN_STATUS.position, 1 if menu.open and menu.tab == 4 else 0, 2)
	if _quit_button_visible():
		_tex_frame("btn_close", BTN_CLOSE.position, 1 if _confirm_quit else 0, 2)

	draw_money(game.state.wallet_gold, Vector2(20, 15), Pal.L_R if game.wallet_is_full() else Pal.L_Y)
	# 专注且在海上：显示不限量的木箱（番茄渔获）；其余时候显示鱼篓
	if ph == Pomodoro.Phase.FOCUS and game.journey.on_boat():
		draw_texture(tex["hold"], Vector2(47, 14))
		_text("x%d" % game.state.session_haul.size(), Vector2(60, 17), Pal.L_W)
	else:
		draw_texture(tex["basket"], Vector2(47, 14))
		var full: bool = game.economy.basket_full(game.state)
		_text("%d%%" % game.economy.basket_percent(game.state), Vector2(60, 17),
				Pal.L_R if full else Pal.L_W)
	if game.move_speed() != 1.0 and not mini:
		_text("x%d" % int(game.move_speed()), Vector2(17, 66), Pal.L_Y)      # 移动倍速（] 加快 / [ 减慢）
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
		elif game.journey.on_island():
			label("方向键走动", Vector2(17, 30), hint_col)
			var ix := float(game.journey.roam_x())
			label(_island_hint(ix), Vector2(17, 41), hint_col)
		elif game.journey.in_town():
			label("方向键走动", Vector2(17, 30), hint_col)
			if game.journey.activity() == Journey.Activity.SOLD_OUT:
				label("空格键去钓鱼", Vector2(17, 41), hint_col)
			elif game.journey.activity() == Journey.Activity.ROAM:
				var rx := float(game.journey.roam_x())
				var hint := "空格键互动"
				if world.near_pier(rx):
					hint = "空格键去钓鱼"
				elif world.near_stall(rx) and not game.state.basket.is_empty():
					hint = "空格键摆摊"
				elif not world.door_near(rx).is_empty():
					hint = "空格键进入"
				elif world.stroller_near(rx, Time.get_ticks_msec()) >= 0 and not world.near_pier(rx):
					hint = "空格键聊天"
				label(hint, Vector2(17, 41), hint_col)
		elif game.can_land():
			label("空格键登岛", Vector2(17, 30), hint_col)
		elif game.at_dock() and game.can_go_to_town():
			label("空格键上岸", Vector2(17, 30), hint_col)
		elif game.journey.activity() == Journey.Activity.FISHING and not game.line_out() and not game.pomodoro.is_break() and not game.fishing_blocked():
			label("空格键开始钓鱼", Vector2(17, 30), hint_col)
		if game.can_steer():
			label("方向键划船", Vector2(17, 41), hint_col)
			label("浅滩" if game.fishing_blocked() else ZONE_LABEL.get(game.zone_id(float(game.journey.boat_x())), "浅水区"), Vector2(17, 52), hint_col)


## 右上角：钓到的鱼名 + 括号里的尺寸，停几秒后淡出。
## 鱼被偷走 / 被吃掉：右上角播报"鱼名(尺寸cm)被偷走了"，和钓到鱼的提示用同一个位置。
var _catch_suffix: String = ""

func _show_loss(fish_id: String, size: int, suffix: String) -> void:
	var f: Dictionary = game.fish_by_id.get(fish_id, {})
	if f.is_empty():
		return
	_catch_name = str(f.get("name", ""))
	_catch_size = size
	_catch_rare = false
	_catch_suffix = suffix
	_catch_t0 = Time.get_ticks_msec()


## 第一次到一座岛：像空洞骑士那样，屏幕中央慢慢浮现白色的大字岛名，上下各一道细线，停一会儿再淡出。
const TITLE_IN := 1400
const TITLE_HOLD := 2800
const TITLE_OUT := 1800

## 画玩家输入的文字（小猫的名字）：用像素字体现画，和图集里的字一样大（10 像素）。
func dyn_text_width(s: String) -> float:
	return _pix_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if _pix_font != null else float(s.length() * 10)


func dyn_text(s: String, pos: Vector2, color: Color) -> void:
	if _pix_font == null or s == "":
		return
	draw_string(_pix_font, pos + Vector2(0, _pix_font.get_ascent(10)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func cat_title() -> String:
	return game.state.cat_name + "的家" if game.state.cat_name != "" else "小猫的家"


func _begin_naming() -> void:
	_naming = true
	_name_buf = OS.get_environment("CATFISH_NAMETEXT")      # 调试：预填一段文字，截图看字的位置
	_name_pick = 0
	_ime_text = ""
	DisplayServer.window_set_ime_active(true)
	DisplayServer.window_set_ime_position(Vector2i(int(view.x * px_scale * 0.5), int(view.y * px_scale * 0.5)))
	_update_polygon()


func _finish_naming() -> void:
	game.set_cat_name(_name_buf)
	_naming = false
	DisplayServer.window_set_ime_active(false)
	play("buy")
	log.write("name_cat", {"name": game.state.cat_name})
	_update_polygon()


func _name_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var k: int = event.keycode
	if k == KEY_ENTER or k == KEY_KP_ENTER:
		_finish_naming()
	elif k == KEY_BACKSPACE:
		if _ime_text == "" and _name_buf.length() > 0:
			_name_buf = _name_buf.substr(0, _name_buf.length() - 1)
	elif k == KEY_TAB:
		_name_pick = (_name_pick + 1) % Game.DEFAULT_NAMES.size()
		_name_buf = Game.DEFAULT_NAMES[_name_pick]
		play("click")
	elif event.unicode >= 32 and event.unicode != 127 and _name_buf.length() < Game.NAME_MAX:
		_name_buf += String.chr(event.unicode)


func _draw_name_dialog(t: int) -> void:
	if not _naming:
		return
	var r := Rect2(roundf(view.x / 2.0) - 60, roundf(view.y / 2.0) - 32, 120, 64)
	draw_rect(Rect2(Vector2.ZERO, view), Color(Pal.U_K, 0.55))
	draw_rect(r, Pal.U_A)
	draw_rect(r.grow(-1), Pal.U_K)
	label_centered("给小猫起个名字", r.position.x + 60, r.position.y + 4, Pal.L_W)
	var box := Rect2(r.position.x + 16, r.position.y + 19, 88, 14)
	draw_rect(box, Pal.U_A)
	draw_rect(box.grow(-1), Pal.U_B)
	var shown := _name_buf + _ime_text
	dyn_text(shown, box.position + Vector2(2, 0), Pal.L_W)
	if (t / 450) % 2 == 0:
		draw_rect(Rect2(box.position.x + 2 + dyn_text_width(shown), box.position.y + 2, 1, 10), Pal.L_Y)
	label("最多六个字", Vector2(r.position.x + 6, r.position.y + 37), Pal.L_A)
	label("回车确认", Vector2(r.end.x - 6 - label_width("回车确认"), r.position.y + 37), Pal.L_G)
	label("Tab键换一个", Vector2(r.position.x + 6, r.position.y + 49), Pal.L_A)


func _draw_island_title() -> void:
	var age := Time.get_ticks_msec() - _title_t0
	var total := TITLE_IN + TITLE_HOLD + TITLE_OUT
	if _title_name == "" or age >= total or not Labels.RECTS.has(_title_name):
		return
	var a := 1.0
	if age < TITLE_IN:
		a = float(age) / float(TITLE_IN)
	elif age > TITLE_IN + TITLE_HOLD:
		a = 1.0 - float(age - TITLE_IN - TITLE_HOLD) / float(TITLE_OUT)
	a = a * a * (3.0 - 2.0 * a)
	var r: Rect2 = Labels.RECTS[_title_name]
	var k := 3.0
	var w := r.size.x * k
	var cx := roundf(view.x / 2.0)
	var y := roundf(view.y * 0.3)
	var col := Color(1, 1, 1, a)
	draw_rect(Rect2(0, y - 12, view.x, r.size.y * k + 24), Color(Pal.U_K, 0.45 * a))      # 衬一条深色的带，白字才看得清
	draw_texture_rect_region(tex["labels"], Rect2(cx - w / 2.0, y, w, r.size.y * k), r, col)
	var lw := minf(w + 40.0, view.x - 10.0)
	var ly1 := y - 7.0
	var ly2 := y + r.size.y * k + 6.0
	var lc := Color(1, 1, 1, a * 0.8)
	draw_rect(Rect2(cx - lw / 2.0, ly1, lw, 1), lc)       # 上下细线，中间一个小菱形
	draw_rect(Rect2(cx - lw / 2.0, ly2, lw, 1), lc)
	for ly in [ly1, ly2]:
		draw_rect(Rect2(cx - 1, ly - 1, 3, 3), Color(1, 1, 1, a))
		draw_rect(Rect2(cx, ly - 2, 1, 5), Color(1, 1, 1, a))
		draw_rect(Rect2(cx - 2, ly, 5, 1), Color(1, 1, 1, a))


func _draw_catch_pop() -> void:
	var age := Time.get_ticks_msec() - _catch_t0
	if age >= CATCH_SHOW_MS or _catch_name == "" or not Labels.RECTS.has(_catch_name):
		return
	var a := 1.0 if age < CATCH_SHOW_MS - CATCH_FADE_MS else float(CATCH_SHOW_MS - age) / float(CATCH_FADE_MS)
	var col := Color(Pal.L_Y if _catch_rare else Pal.L_W, a)
	var sz := "%dcm" % _catch_size
	var suffix_w: float = (label_width(_catch_suffix) + 3.0) if _catch_suffix != "" and Labels.RECTS.has(_catch_suffix) else 0.0
	var total := label_width(_catch_name) + 4 + 3 + sz.length() * 4 + 3 + suffix_w
	var x := view.x - 5.0 - total
	var y := 31.0 if mini else 5.0
	label(_catch_name, Vector2(x, y), col)
	var px := x + label_width(_catch_name) + 4.0
	var cp := Color(Pal.L_A, a)
	draw_rect(Rect2(px + 1, y + 3, 1, 1), cp)         # "("
	draw_rect(Rect2(px, y + 4, 1, 3), cp)
	draw_rect(Rect2(px + 1, y + 7, 1, 1), cp)
	_text(sz, Vector2(px + 3, y + 4), col)
	var qx := px + 3.0 + sz.length() * 4
	draw_rect(Rect2(qx, y + 3, 1, 1), cp)             # ")"
	draw_rect(Rect2(qx + 1, y + 4, 1, 3), cp)
	draw_rect(Rect2(qx, y + 7, 1, 1), cp)
	if suffix_w > 0.0:
		label(_catch_suffix, Vector2(qx + 5.0, y), Color(Pal.L_R, a))


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
	var outfits: Array = cat_cfg["outfits"]
	var outfit: Dictionary = outfits[posmod(int(look.get("outfit", 0)), outfits.size())]
	var base: Color = Pal.BY_KEY.get(fur["base"], Pal.L_F)
	var shade: Color = Pal.BY_KEY.get(fur["shade"], Pal.U_F)
	var light: Color = Pal.BY_KEY.get(fur["light"], Pal.L_L)
	_tex_frame("cat/fur_base", pos, frame, CAT_FRAMES, base, flip)
	_tex_frame("cat/fur_shade", pos, frame, CAT_FRAMES, shade, flip)
	_tex_frame("cat/fur_light", pos, frame, CAT_FRAMES, light, flip)
	_tex_frame("cat/pat_white", pos, frame, CAT_FRAMES, Pal.L_W if pat.get("white", false) else light, flip)
	_tex_frame("cat/pat_stripe", pos, frame, CAT_FRAMES, shade if pat.get("stripes", false) else base, flip)
	_tex_frame("cat/fixed", pos, frame, CAT_FRAMES, Color.WHITE, flip)
	if outfit.get("sprite", "") != "" and not (game.is_raining() and interior == "" and not wardrobe.open):
		_tex_frame("cat/" + outfit["sprite"], pos, frame, CAT_FRAMES, Color.WHITE, flip)
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

## 画钱：只写最高一档（去尾），前面是金/银/铜币图标。pos 是图标左上角。
func draw_money(copper: int, pos: Vector2, color: Color) -> void:
	draw_texture(tex[Money.icon(copper)], pos)
	_text(str(Money.tier(copper)[1]), pos + Vector2(11, 2), color)

## 同上，靠右对齐：right_x 是数字右边，y 是数字的纵坐标（图标自动对齐）。
func money_right(copper: int, right_x: float, y: float, color: Color) -> void:
	var n := str(Money.tier(copper)[1])
	draw_texture(tex[Money.icon(copper)], Vector2(right_x - n.length() * 4 - 10, y - 2))
	_text(n, Vector2(right_x - n.length() * 4 + 1, y), color)

## 完整的价格/金额：几金几银几铜，每一档一个图标加数字，不去尾。pos 是第一个图标的左上角。
func draw_money_full(copper: int, pos: Vector2, color: Color) -> void:
	var x := pos.x
	for part in Money.parts(copper):
		draw_texture(tex[Money.icon_of(part[0])], Vector2(x, pos.y))
		var n := str(part[1])
		_text(n, Vector2(x + 11, pos.y + 2), color)
		x += 11.0 + n.length() * 4.0 + 2.0

func money_full_width(copper: int) -> float:
	var w := 0.0
	for part in Money.parts(copper):
		w += 11.0 + str(part[1]).length() * 4.0 + 2.0
	return w - 2.0

## 同上，靠右对齐到 right_x；y 是数字的纵坐标（图标自动对齐）。
func money_full_right(copper: int, right_x: float, y: float, color: Color) -> void:
	draw_money_full(copper, Vector2(right_x - money_full_width(copper), y - 2.0), color)

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


## 迷你窗挂机：在海上/湖边鱼篓不到 50% 就自动钓（钓不了就去附近水域），到了 50% 自动回镇卖；
## 卖完回来，鱼篓不到 30% 就去随机的近水域钓鱼，到 30% 就继续去摊位卖鱼（这一条在 game.end_roam）。
func _auto_policy() -> void:
	var j: Journey = game.journey
	var pct: int = game.economy.basket_percent(game.state)
	var has_fish: bool = not game.state.basket.is_empty()
	var fish_pct: int = int(game.auto_cfg().get("fish_pct", 50))
	match j.activity():
		Journey.Activity.FISHING:
			if has_fish and pct >= fish_pct:
				_go_to_town()
			elif game.fishing_blocked():
				start_auto_sail(game.auto_fish_x())
			elif not game.line_out():
				world.face_left = false
				if game.cast_line():
					play("cast")
		Journey.Activity.ISLAND:
			if game.at_lake_spot():
				if has_fish and pct >= fish_pct:
					_town_button()
				elif not game.line_out():
					world.roam_flip = true
					if game.cast_line():
						play("cast")
		Journey.Activity.SOLD_OUT:
			game.journey.set_fish_spot(game.pick_water_x())
			_go_fishing()

## 岛上此刻站的位置能做什么，作为屏幕底部的提示文字。
func _island_hint(ix: float) -> String:
	if world.island_near_pier(ix):
		return "空格键回船"
	if world.island_near_keeper(ix):
		return "空格键和看守聊聊"
	if world.island_near_console(ix):
		return "空格键开信号灯"
	if world.island_near_bench(ix):
		return "空格键做蟹笼"
	if world.island_near_chest(ix):
		return "空格键打开木箱"
	if world.island_near_drift(ix) >= 0:
		return "空格键拾取"
	if world.island_near_lake(ix):
		if game.at_lake_spot():
			if game.pots_ready() > 0 and not game.line_out():
				return "空格键收蟹笼"
			return "空格键收竿" if game.line_out() else "空格键钓鱼"
		return "空格键去湖边钓鱼"
	if ix <= game.island_walk_min() + 2.0:
		return "岛的最西边" if game.bridge_built() else "岛的西边还没开发"
	return ""
