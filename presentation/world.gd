extends RefCounted
## 横版世界：海 → 码头 → 小镇街道 → 摊位。坐标单位是美术像素，x 向右、y 向下。
## 两种视图（全画面 / 迷你悬浮窗）画的是同一个世界，只是镜头和取景大小不同。
## 自己不是节点：借用主节点 m 的 draw_* 方法，只能在 m._draw() 里调用 draw()。

const Pal := preload("res://presentation/palette.gd")
const Fishing := preload("res://core/fishing_system.gd")
const Journey := preload("res://core/journey.gd")

const WATER_Y := 128        # 海面
const GROUND_Y := 124       # 小镇地面 / 码头面（脚踩的那条线）
const SHORE_X := 640        # 海岸线
const FISH_X := 100         # 钓点：船的左端
const DOCK_X := 512         # 靠岸：船的左端
const PIER_X := 576
const STALL_X := 760
const WALK_FROM_X := 552
const STALL_CAT_X := STALL_X + 1      # 小猫坐在摊位左半边，右半边摆鱼
const ROAM_MIN_X := 548               # 自由走动的范围（小猫贴图左边缘）
const ROAM_MAX_X := 1000
const WORLD_END := 1048               # 世界右边界，镜头不会越过
const ROAM_SPEED := 46.0              # 自由走动速度（像素/秒）
const NEAR := 16                      # 离摊位/码头多近算"到了"
## 可以进去的房子：[门的中心 x, 名字, 用途]
const DOORS := [[674, "小猫的家", "home"], [828, "裁缝铺", "tailor"], [898, "渔具店", "tackle"]]
## 街上散步的居民：[样子, 散步范围左端, 右端, 走一个来回的毫秒数]
const STROLLERS := [[1, 690, 800, 26000], [2, 850, 980, 34000], [0, 930, 1010, 22000]]
const CHAT := ["今天的鱼真新鲜", "听说金锦鲤很稀有", "专注时鱼更值钱", "别让小猫饿着了", "天气真好呀", "你的帽子真好看"]
const HOUSES := [["house_0", 652], ["house_1", 818], ["house_2", 872]]
const TREES := [716, 940]

# 相对小猫贴图左上角的偏移
const HAND := Vector2(21, 22)
const TIP_IDLE := Vector2(33, 6)
const TIP_WAIT := Vector2(38, 12)
const TIP_REEL := Vector2(30, 2)

var m
var cat_pos := Vector2(FISH_X + 10, WATER_Y - 34)   # 小猫贴图左上角（世界坐标）
var boat_x: float = FISH_X
var eat_t0: int = -100000
var eat_fish: String = ""
var splash_t0: int = -100000
var hop_t0: int = -100000
var chest_open_t0: int = -100000   # 宝箱被打开的时刻
var leaving: Array = []       # 买完离开的顾客: {kind, t0}
var walk_flip: bool = false   # 自动行走时是否朝左
var roam_flip: bool = false   # 自由走动时是否朝左
var roam_moving: bool = false
var customer_kind: int = 0        # 当前这一单的顾客样子
var approach_visible: bool = false
var approach_x: float = 0.0
var _customer_phase: int = -1
var chat_who: int = -1        # 正在说话的居民下标
var chat_line: String = ""
var chat_t0: int = -100000
var chat_x: float = 0.0       # 说话时居民停在原地

func _init(main) -> void:
	m = main

func _ease(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)

func boat_y(t: int) -> float:
	return WATER_Y - 11 + (1 if (t / 900) % 2 == 0 else 0)

func bobber_rest() -> Vector2:
	return Vector2(boat_x + 74, WATER_Y - 3)

## 每帧先调用：根据活动状态算出船和猫的位置。
func update(now: int, t: int) -> void:
	_update_customer(now)
	var j: Journey = m.game.journey
	var p := _ease(j.progress(now))
	match j.activity():
		Journey.Activity.SAIL_OUT:
			boat_x = lerpf(FISH_X, DOCK_X, p)
		Journey.Activity.SAIL_BACK:
			boat_x = lerpf(DOCK_X, FISH_X, p)
		Journey.Activity.FISHING, Journey.Activity.IDLE_FULL:
			boat_x = FISH_X
		_:
			boat_x = DOCK_X
	boat_x = roundf(boat_x)
	match j.activity():
		Journey.Activity.WALK_TO_STALL, Journey.Activity.WALK_TO_BOAT:
			# 默认从码头走到摊位（或反过来）；如果是玩家松手后接管，则从松手的位置出发
			var to_stall: bool = j.activity() == Journey.Activity.WALK_TO_STALL
			var from: float = j.walk_from() if j.walk_from() >= 0 else (WALK_FROM_X if to_stall else STALL_CAT_X)
			var to: float = STALL_CAT_X if to_stall else WALK_FROM_X
			walk_flip = to < from
			cat_pos = Vector2(roundf(lerpf(from, to, j.progress(now))), GROUND_Y - 30)
		Journey.Activity.ROAM:
			cat_pos = Vector2(j.roam_x(), GROUND_Y - 30)
		Journey.Activity.VENDING:
			cat_pos = Vector2(STALL_CAT_X, GROUND_Y - 31)
		_:
			cat_pos = Vector2(boat_x + 10, boat_y(t) - 23)

## 满篓气泡的点击区域（世界坐标）；不显示气泡时返回空矩形。
func bubble_rect(t: int) -> Rect2:
	if m.game.journey.activity() != Journey.Activity.IDLE_FULL or m.game.pomodoro.is_break():
		return Rect2()
	return Rect2(cat_pos + Vector2(34, -11 - (t / 600) % 2), Vector2(19, 18))   # 在头的右上方，不被迷你视图的面板挡住

## 从 x 走到摊位 / 码头的路程，占"码头↔摊位"全程的比例。
func frac_to_stall(x: float) -> float:
	return absf(x - STALL_CAT_X) / float(STALL_CAT_X - WALK_FROM_X)

func frac_to_boat(x: float) -> float:
	return absf(x - WALK_FROM_X) / float(STALL_CAT_X - WALK_FROM_X)

func near_stall(x: float) -> bool:
	return absf(x - STALL_CAT_X) <= NEAR

func near_pier(x: float) -> bool:
	return x <= PIER_X + NEAR

## 小猫中心点附近的门；没有返回空数组。
func door_near(x: float) -> Array:
	for d in DOORS:
		if absf(x + 16.0 - float(d[0])) <= 11.0:
			return d
	return []

## 居民此刻的位置和朝向：返回 [x, 是否朝左]。说话时停在原地。
func stroller_at(i: int, t: int) -> Array:
	if i == chat_who and t - chat_t0 < 3500:
		return [chat_x, chat_x > cat_pos.x]
	var s: Array = STROLLERS[i]
	var ph := fposmod(float(t + i * 7000) / float(s[3]), 1.0)
	var going_right := ph < 0.5
	var k := ph * 2.0 if going_right else (1.0 - ph) * 2.0
	return [roundf(lerpf(float(s[1]), float(s[2]), k)), not going_right]

func stroller_near(x: float, t: int) -> int:
	for i in STROLLERS.size():
		if absf(float(stroller_at(i, t)[0]) + 8.0 - (x + 16.0)) <= 18.0:
			return i
	return -1

func chat_with(i: int, t: int) -> void:
	chat_x = float(stroller_at(i, t)[0])
	chat_who = i
	chat_line = CHAT[(t / 1000 + i) % CHAT.size()]
	chat_t0 = t

func _draw_strollers(t: int) -> void:
	for i in STROLLERS.size():
		var at := stroller_at(i, t)
		var talking := i == chat_who and t - chat_t0 < 3500
		var name := "villager_%d" % int(STROLLERS[i][0])
		var pos := Vector2(float(at[0]), GROUND_Y - 21)
		# 居民贴图本身面朝左：朝左走直接画，朝右走才翻转（之前写反了，看起来像倒着走）
		if at[1]:
			m.tex_frame(name, pos, 0 if talking else (t / 220) % 2, 2)
		else:
			m.tex_frame_flipped(name, pos, 0 if talking else (t / 220) % 2, 2)

## 居民说的话：最后画，保证不被摊位和房子挡住。
func _draw_chat(t: int) -> void:
	if chat_who < 0 or t - chat_t0 >= 3500 or m.label_width(chat_line) <= 0:
		return
	var pos := Vector2(chat_x, GROUND_Y - 21)
	var w: float = m.label_width(chat_line) + 6
	var box := Rect2(roundf(pos.x + 8 - w / 2), pos.y - 17, w, 13)
	m.draw_rect(box.grow(1), Pal.U_K)
	m.draw_rect(box, Pal.U_W)
	m.draw_rect(Rect2(pos.x + 6, box.end.y, 3, 2), Pal.U_W)
	m.label(chat_line, box.position + Vector2(3, 1), Pal.U_K)

func on_sale(fish_id: String) -> void:
	var f: Dictionary = m.game.fish_by_id.get(fish_id, {})
	leaving.append({"kind": customer_kind, "t0": Time.get_ticks_msec(), "x0": float(STALL_X + 50), "fish": f.get("sprite", "")})
	approach_visible = false

## 这一单的顾客：每单换一位（不连续重复），在这一单的后半段从右边走过来。
## 如果顾客走到一半小猫离开了摊位（被玩家带走、或进入休息），顾客空手掉头回去，而不是凭空消失。
func _update_customer(now: int) -> void:
	var g = m.game
	var j: Journey = g.journey
	var selling: bool = j.activity() == Journey.Activity.VENDING and not g.pomodoro.is_break() and not g.state.basket.is_empty()
	if not selling:
		if approach_visible:
			leaving.append({"kind": customer_kind, "t0": Time.get_ticks_msec(), "x0": approach_x, "fish": ""})
			approach_visible = false
		return
	var phase := int(g.state.journey["phase_start_ms"])
	if phase != _customer_phase:
		_customer_phase = phase
		customer_kind = (customer_kind + 1 + randi() % 2) % 3
	var p: float = j.progress(now)
	approach_visible = p > 0.45
	if approach_visible:
		approach_x = STALL_X + 50 + roundf((1.0 - minf(1.0, (p - 0.45) / 0.5)) * 80.0)

# ------------------------------------------------------------------ 绘制
func draw(cam: Vector2, view: Vector2, mini: bool, now: int, t: int) -> void:
	var g = m.game
	var j: Journey = g.journey
	var act: int = j.activity()
	var on_break: bool = g.pomodoro.is_break()
	var left := cam.x + (2 if mini else 0)
	var right := cam.x + view.x - (2 if mini else 0)
	var bottom := cam.y + view.y

	if not mini:
		_draw_sky(cam, view, t)
	for h in HOUSES:
		m.draw_texture(m.tex[h[0]], Vector2(h[1], GROUND_Y - 60))
	for x in TREES:
		m.draw_texture(m.tex["tree"], Vector2(x, GROUND_Y - 36))

	# 海
	var sea_right := minf(right, SHORE_X)
	if left < sea_right:
		_tile_row("sea", (t / 600) % 3, 3, WATER_Y, left, sea_right)
		m.draw_rect(Rect2(left, WATER_Y + 6, sea_right - left, 14), Pal.L_B)
		m.draw_rect(Rect2(left, WATER_Y + 20, sea_right - left, maxf(0, bottom - WATER_Y - 20)), Pal.U_B)
	# 地面
	var land_left := maxf(left, SHORE_X)
	if land_left < right:
		_tile_row("ground", 0, 1, GROUND_Y, land_left, right)
		m.draw_rect(Rect2(land_left, GROUND_Y + 16, right - land_left, maxf(0, bottom - GROUND_Y - 16)), Pal.L_N)
	m.draw_texture(m.tex["pier"], Vector2(PIER_X, GROUND_Y))

	for d in DOORS:      # 门楣上的木招牌
		var w: float = m.label_width(d[1]) + 5
		var plate := Rect2(roundf(float(d[0]) - w / 2), GROUND_Y - 39, w, 12)
		m.draw_rect(plate.grow(1), Pal.U_K)
		m.draw_rect(plate, Pal.L_N)
		m.draw_rect(Rect2(plate.position.x, plate.end.y - 2, plate.size.x, 2), Pal.L_O)
		m.label(d[1], plate.position + Vector2(3, 0), Pal.U_K)
	# 摊位（后半）→ 摆摊的小猫 → 柜台 → 路过的居民、顾客、走动中的小猫（都在摊位前面）
	m.draw_texture(m.tex["stall_back"], Vector2(STALL_X, GROUND_Y - 40))
	var in_town: bool = not j.on_boat()
	var bob_y := boat_y(t)
	var behind_counter: bool = act == Journey.Activity.VENDING
	if in_town and behind_counter:
		_draw_town_cat(act, on_break, now, t)
	m.draw_texture(m.tex["stall_front"], Vector2(STALL_X, GROUND_Y - 15))
	if act == Journey.Activity.VENDING:
		_draw_stall_goods()
	_draw_strollers(t)
	_draw_customer(t)
	_draw_leaving(t)
	if in_town and not behind_counter:
		_draw_town_cat(act, on_break, now, t)
	_draw_chat(t)

	# 船
	if not in_town:
		_draw_boat_cat(act, on_break, now, t)
	m.draw_texture(m.tex["boat"], Vector2(boat_x, bob_y))
	if not in_town:
		_draw_boat_extras(act, on_break, now, t)

func _draw_sky(cam: Vector2, view: Vector2, t: int) -> void:
	m.draw_rect(Rect2(cam, view), Pal.L_C)
	m.draw_rect(Rect2(cam.x, WATER_Y - 26, view.x, 26), Pal.U_W)
	# 远景视差：云最慢，山其次
	var cloud_shift := fposmod(cam.x * 0.85 - t / 500.0, 150.0)
	for i in range(-1, int(view.x / 150) + 2):
		var cx := cam.x - cloud_shift + i * 150
		m.draw_texture(m.tex["cloud"], Vector2(roundf(cx + 20), cam.y + 14 + (i * 37) % 23 + maxf(0, view.y - 180) * 0.5))
		m.draw_texture(m.tex["cloud"], Vector2(roundf(cx + 95), cam.y + 40 + (i * 53) % 17 + maxf(0, view.y - 180) * 0.5))
	var hill_shift := fposmod(cam.x * 0.4, 64.0)
	for i in range(-1, int(view.x / 64) + 2):
		m.draw_texture(m.tex["hills"], Vector2(roundf(cam.x - hill_shift + i * 64), WATER_Y - 22))

func _draw_town_cat(act: int, on_break: bool, now: int, t: int) -> void:
	# 番茄休息时小猫原地打盹——但玩家正用方向键带着它走的时候除外，那时照常画走路
	if on_break and act != Journey.Activity.ROAM:
		m.draw_cat(cat_pos + Vector2(0, -1 if act != Journey.Activity.VENDING else 0), 2 + (t / 1100) % 2)
		m.draw_texture(m.tex["zzz"], cat_pos + Vector2(30, -4 - (t / 500) % 3))
		return
	match act:
		Journey.Activity.WALK_TO_STALL, Journey.Activity.WALK_TO_BOAT:
			m.draw_cat(cat_pos, 4 + (t / 180) % 2, walk_flip)
			if not m.game.state.basket.is_empty():        # 还有鱼就背着鱼篓
				m.draw_texture(m.tex["basket"], cat_pos + Vector2(18 if walk_flip else 3, 16 + (t / 180) % 2))
		Journey.Activity.ROAM:
			m.draw_cat(cat_pos, (4 + (t / 180) % 2) if roam_moving else 4, roam_flip)
			if not m.game.state.basket.is_empty():
				m.draw_texture(m.tex["basket"], cat_pos + Vector2(18 if roam_flip else 3, 16 + ((t / 180) % 2 if roam_moving else 0)))
		Journey.Activity.VENDING:
			var frame := (t / 700) % 2
			var p := cat_pos
			if t - hop_t0 < 500:
				frame = 2
				p.y -= 2 if t - hop_t0 < 140 else (1 if t - hop_t0 < 280 else 0)
			m.draw_cat(p, frame)

## 柜台上摆出接下来要卖的两条鱼（先卖的在前面）。
func _draw_stall_goods() -> void:
	var g = m.game
	var n: int = mini(g.state.basket.size(), 2)
	for i in n:
		var f: Dictionary = g.fish_by_id.get(g.state.basket[n - 1 - i], {})
		if m.tex.has(f.get("sprite", "")):
			m.draw_texture(m.tex[f["sprite"]], Vector2(STALL_X + 29 - (n - 1 - i) * 3, GROUND_Y - 24 - (n - 1 - i) * 3))

## 正走向摊位的顾客（位置在 update 里算好）。
func _draw_customer(t: int) -> void:
	if approach_visible:
		var arrived := approach_x <= STALL_X + 50
		m.tex_frame("villager_%d" % customer_kind, Vector2(approach_x, GROUND_Y - 21), 0 if arrived else (t / 200) % 2, 2)

## 离开的顾客：买到鱼的拎着鱼走；没买成的（小猫被玩家带走了）空手掉头回去。
func _draw_leaving(t: int) -> void:
	var keep: Array = []
	for c in leaving:
		var age: int = t - int(c["t0"])
		var x: float = float(c["x0"]) + roundf(age * 0.028)
		if age < 6000 and x < STALL_X + 190:
			keep.append(c)
			if m.tex.has(c["fish"]):      # 鱼先画，人在鱼前面
				m.draw_texture(m.tex[c["fish"]], Vector2(x + 6, GROUND_Y - 12))
			m.tex_frame_flipped("villager_%d" % int(c["kind"]), Vector2(x, GROUND_Y - 21), (t / 200) % 2, 2)
	leaving = keep

func _draw_boat_cat(act: int, on_break: bool, now: int, t: int) -> void:
	var frame := (t / 700) % 2
	var pos := cat_pos
	var flip := act == Journey.Activity.SAIL_BACK
	if on_break:
		frame = 2 + (t / 1100) % 2
	elif act == Journey.Activity.IDLE_FULL:
		if t - eat_t0 < 1600:
			frame = 2
			pos.y -= 1 if (t / 200) % 2 == 0 else 0
		elif _idle_sleeping(now):
			frame = 2 + (t / 1100) % 2
	elif t - hop_t0 < 600:
		frame = 2   # 钓到鱼：眯眼开心跳一下
		pos.y -= 2 if t - hop_t0 < 140 else (1 if t - hop_t0 < 280 else 0)
	m.draw_cat(pos, frame, flip)

func _idle_sleeping(now: int) -> bool:
	return (now / 40000) % 2 == 0

func _draw_boat_extras(act: int, on_break: bool, now: int, t: int) -> void:
	if on_break:
		m.draw_texture(m.tex["zzz"], cat_pos + Vector2(32, -2 - (t / 500) % 3))
		return
	match act:
		Journey.Activity.FISHING:
			_draw_fishing(t, now)
		Journey.Activity.IDLE_FULL:
			if t - eat_t0 < 1600:
				var f: Dictionary = m.game.fish_by_id.get(eat_fish, {})
				if t - eat_t0 < 1000 and m.tex.has(f.get("sprite", "")):
					m.draw_texture(m.tex[f["sprite"]], cat_pos + Vector2(21, 11))
			elif _idle_sleeping(now):
				m.draw_texture(m.tex["zzz"], cat_pos + Vector2(21, -11 - (t / 500) % 3))
			else:
				m.draw_texture(m.tex["gameboy"], cat_pos + Vector2(18, 17))
				if (t / 350) % 3 == 0:
					m.draw_rect(Rect2(cat_pos + Vector2(27, 13), Vector2(1, 1)), Pal.L_G)
			var b := bubble_rect(t)
			if b.size.x > 0:
				m.draw_texture(m.tex["bubble"], b.position)
		Journey.Activity.SAIL_OUT, Journey.Activity.SAIL_BACK:
			# 划桨：桨叶沿一个扁椭圆连续转动，没有突变，所以看起来是顺的。
			#   椭圆下半圈在水面以下 = 划水：桨叶从船头一侧推向船尾一侧，入水溅水花，身后留水纹
			#   椭圆上半圈在水面以上 = 回桨：桨叶贴着水面收回船头一侧（只抬高几个像素）
			var dir := -1.0 if act == Journey.Activity.SAIL_BACK else 1.0    # 船前进的方向
			var ang := fposmod(t / 1700.0, 1.0) * TAU                        # 0 = 桨叶在最靠船头处、正好在水面
			var depth := sin(ang)                                            # >0 在水里，<0 在空中
			var pivot_x := boat_x + 32 - dir * 3
			var blade := Vector2(pivot_x + dir * 10.0 * cos(ang), WATER_Y + (depth * 3.0 if depth > 0 else depth * 4.0)).round()
			var hand := cat_pos + (Vector2(10, 23) if dir < 0 else Vector2(21, 23))
			m.pixel_line(hand, blade, Pal.U_O)
			m.draw_rect(Rect2(blade.x - 1, blade.y, 3, 3), Pal.L_N)
			if depth > 0:
				if ang < 0.9:        # 刚入水：水花
					m.tex_frame("splash", Vector2(blade.x - 5, WATER_Y - 3), 0 if ang < 0.45 else 1, 2)
				# 桨叶划过的地方留下水纹（在桨叶的船头一侧，划得越远越长）
				for i in int(ang / PI * 5.0):
					m.draw_rect(Rect2(blade.x + dir * (3 + i * 4), WATER_Y + 1 + (i % 2), 2, 1), Pal.U_W if i == 0 else Pal.L_C)
			elif ang < PI + 0.7:     # 刚出水：甩下一滴水
				m.draw_rect(Rect2(blade.x, WATER_Y - 1, 1, 1), Pal.L_C)

func _draw_fishing(t: int, now: int) -> void:
	var fs: int = m.game.fishing.state
	var prog: float = m.game.fishing.progress(now)
	var rest := bobber_rest()
	var tip := TIP_IDLE
	var bobber := Vector2.INF     # INF = 不画浮漂
	var fish_tex: Texture2D = null
	var fish_pos := Vector2.ZERO
	match fs:
		Fishing.State.CASTING:
			tip = TIP_IDLE.lerp(TIP_WAIT, prog)
			if prog > 0.4:
				var k := (prog - 0.4) / 0.6
				bobber = ((cat_pos + tip).lerp(rest, k) + Vector2(0, -10.0 * sin(k * PI))).round()
		Fishing.State.WAITING:
			tip = TIP_WAIT
			bobber = rest + Vector2(0, (t / 800) % 2)
		Fishing.State.HOOKED:
			tip = TIP_WAIT + Vector2(1, 2)
			bobber = rest + Vector2((t / 80) % 2, 3)
			m.draw_texture(m.tex["bang"], cat_pos + Vector2(24, -12))
		Fishing.State.REELING:
			tip = TIP_WAIT.lerp(TIP_REEL, minf(1.0, prog * 2.0))
			fish_tex = _hooked_tex()
			fish_pos = (rest.lerp(cat_pos + TIP_REEL + Vector2(-6, 8), prog)).round()
		Fishing.State.SETTLEMENT:
			tip = TIP_REEL.lerp(TIP_IDLE, prog)
			fish_tex = _hooked_tex()
			fish_pos = (cat_pos + Vector2(8, -12 - 6.0 * prog)).round()
	var tip_abs := (cat_pos + tip).round()
	m.pixel_line(cat_pos + HAND, tip_abs, Pal.U_O)
	if bobber != Vector2.INF:
		m.pixel_line(tip_abs, bobber + Vector2(2, 0), Pal.L_W)
		m.draw_texture(m.tex["bobber"], bobber)
	if (fs == Fishing.State.REELING or fs == Fishing.State.SETTLEMENT) and m.game.fishing.hooked_fish != "":
		if fs == Fishing.State.REELING:
			m.pixel_line(tip_abs, fish_pos + Vector2(16, 5), Pal.L_W)
		_draw_hooked(fish_pos, t)
	if t - splash_t0 < 360:
		m.tex_frame("splash", rest + Vector2(-3, 3), 0 if t - splash_t0 < 180 else 1, 2)

func _hooked_tex() -> Texture2D:
	if m.game.fishing.hooked_fish == Fishing.CHEST:
		return null      # 宝箱是两帧的图，由 _draw_hooked 单独画
	var f: Dictionary = m.game.fish_by_id.get(m.game.fishing.hooked_fish, {})
	return m.tex.get(f.get("sprite", ""), null)

## 画钓上来的东西：鱼，或者宝箱（提上来时关着，结算时打开）。
func _draw_hooked(pos: Vector2, t: int) -> void:
	if m.game.fishing.hooked_fish == Fishing.CHEST:
		m.tex_frame("chest", pos + Vector2(0, -3), 1 if t - chest_open_t0 < 2500 else 0, 2)
	else:
		var tx := _hooked_tex()
		if tx != null:
			m.draw_texture(tx, pos)

## 横向平铺一行瓦片，两端按 x_from / x_to 精确裁切。
func _tile_row(name: String, frame: int, count: int, y: float, x_from: float, x_to: float) -> void:
	var tx: Texture2D = m.tex[name]
	var w: int = tx.get_width() / count
	var h: int = tx.get_height()
	var x := floorf(x_from / w) * w
	while x < x_to:
		var a := maxf(x, x_from)
		var b := minf(x + w, x_to)
		if b > a:
			m.draw_texture_rect_region(tx, Rect2(a, y, b - a, h), Rect2(frame * w + (a - x), 0, b - a, h))
		x += w


# ------------------------------------------------------------------ 室内
## 三间屋子。坐标是"屋内坐标"：x 从左墙算起，脚踩的地面线是 fy（由 draw_interior 换算到视图里）。
## spots: [小猫中心点的 x, 用途]；keeper: 店主的居民样子，-1 表示没有店主。
const ROOM_W := 216
const ROOM_H := 76
const ROOM_MIN_X := 2
const ROOM_MAX_X := ROOM_W - 34
const ROOM_DOOR_X := 14          # 门的中心
const ROOMS := {
	"tackle": {"keeper": 1, "wall": "h", "spots": [[150, "shop"]]},
	"tailor": {"keeper": 0, "wall": "w", "spots": [[128, "mirror"]]},
	"home": {"keeper": -1, "wall": "w", "spots": [[84, "dex"], [128, "stats"], [172, "bed"]]},
}
const SPOT_HINT := {"exit": "空格键出门", "shop": "空格键看货", "mirror": "空格键照镜子", "dex": "空格键看图鉴", "stats": "空格键看统计", "bed": "空格键小睡"}

var room_x: float = 0.0          # 小猫贴图左边缘（屋内坐标）
var room_flip: bool = false
var room_moving: bool = false
var napping: bool = false       # 正在床上睡觉
var room_t0: int = -100000       # 进门的时刻（店主打招呼用）

func enter_room(t: int) -> void:
	room_x = ROOM_DOOR_X - 10
	room_flip = false
	room_moving = false
	room_t0 = t

## 小猫此刻站在屋里的什么位置："exit" / "shop" / "mirror" / "dex" / "stats" / ""。
func room_spot(kind: String) -> String:
	var cx := room_x + 16.0
	for sp in ROOMS[kind]["spots"]:
		if absf(cx - float(sp[0])) <= 13.0:
			return sp[1]
	if absf(cx - ROOM_DOOR_X) <= 13.0:
		return "exit"
	return ""

func draw_interior(kind: String, view: Vector2, t: int) -> void:
	var room: Dictionary = ROOMS[kind]
	var ox := floorf((view.x - ROOM_W) / 2.0)
	var fy := view.y - 56.0                    # 地面线，和室外的地面同高
	m.draw_rect(Rect2(Vector2.ZERO, view), Pal.U_K)
	# 墙、护墙板、地板
	m.draw_rect(Rect2(ox, fy - ROOM_H, ROOM_W, ROOM_H), Pal.BY_KEY[room["wall"]])
	m.draw_rect(Rect2(ox, fy - 14, ROOM_W, 14), Pal.L_N)
	m.draw_rect(Rect2(ox, fy - 15, ROOM_W, 1), Pal.L_O)
	m.draw_rect(Rect2(ox, fy, ROOM_W, 16), Pal.L_O)
	m.draw_rect(Rect2(ox, fy, ROOM_W, 1), Pal.U_K)
	for x in range(0, ROOM_W, 18):
		m.draw_rect(Rect2(ox + x, fy + 1, 1, 15), Pal.U_O)
	m.draw_rect(Rect2(ox, fy + 8, ROOM_W, 1), Pal.U_O)
	m.draw_texture(m.tex["room_door"], Vector2(ox + ROOM_DOOR_X - 9, fy - 29))
	m.draw_texture(m.tex["room_window"], Vector2(ox + 34, fy - 56))
	var keeper_pos := Vector2.INF
	match kind:
		"tackle":
			m.draw_texture(m.tex["shelf_tackle"], Vector2(ox + 76, fy - 62))
			m.draw_texture(m.tex["barrel"] if m.tex.has("barrel") else m.tex["hold"], Vector2(ox + 196, fy - 10))
			keeper_pos = Vector2(ox + 156, fy - 31)      # 店主站在柜台后的踏板上，露出上半身
			m.tex_frame("villager_%d" % int(room["keeper"]), keeper_pos, 0, 2)
			m.draw_texture(m.tex["counter"], Vector2(ox + 134, fy - 17))
			m.draw_texture(m.tex["fish_bass"], Vector2(ox + 135, fy - 26))
		"tailor":
			m.draw_texture(m.tex["shelf_hats"], Vector2(ox + 150, fy - 62))
			m.draw_texture(m.tex["mirror"], Vector2(ox + 120, fy - 32))
			m.draw_texture(m.tex["rug"], Vector2(ox + 108, fy + 3))
			keeper_pos = Vector2(ox + 176, fy - 21)
			m.tex_frame("villager_%d" % int(room["keeper"]), keeper_pos, 0, 2)
		"home":
			m.draw_texture(m.tex["bookshelf"], Vector2(ox + 70, fy - 39))
			m.draw_texture(m.tex["calendar"], Vector2(ox + 120, fy - 50))
			m.draw_texture(m.tex["bed"], Vector2(ox + 160, fy - 19))
			m.draw_texture(m.tex["rug"], Vector2(ox + 96, fy + 3))
	# 小猫
	var pos := Vector2(ox + roundf(room_x), fy - 30)
	if napping and kind == "home":
		m.draw_cat(Vector2(ox + 162, fy - 34), 2 + (t / 700) % 2, false)
		var zy := (t / 400) % 3
		m.label("Z", Vector2(ox + 150 + zy * 3, fy - 52 - zy * 4), Pal.U_K)
	else:
		m.draw_cat(pos, (4 + (t / 180) % 2) if room_moving else 4, room_flip)
	# 店主进门时打招呼
	if keeper_pos != Vector2.INF and t - room_t0 < 3000:
		var w: float = m.label_width("欢迎光临") + 6
		var box := Rect2(roundf(keeper_pos.x + 8 - w / 2), keeper_pos.y - 17, w, 13)
		m.draw_rect(box.grow(1), Pal.U_K)
		m.draw_rect(box, Pal.U_W)
		m.draw_rect(Rect2(keeper_pos.x + 6, box.end.y, 3, 2), Pal.U_W)
		m.label("欢迎光临", box.position + Vector2(3, 1), Pal.U_K)
	# 四周的墙边
	m.draw_rect(Rect2(ox - 2, fy - ROOM_H - 2, ROOM_W + 4, 2), Pal.U_O)
	m.draw_rect(Rect2(ox - 2, fy - ROOM_H, 2, ROOM_H + 16), Pal.U_O)
	m.draw_rect(Rect2(ox + ROOM_W, fy - ROOM_H, 2, ROOM_H + 16), Pal.U_O)
