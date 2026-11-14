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
const FISH_X := 260         # 新档默认的钓点（船的左端）；之后玩家可以划船改位置
const DOCK_X := 512         # 靠岸：船的左端
const PIER_X := 576
const GATE_X := 1012                  # 市场拱门
const STALL_X := 1186                 # 你的鱼摊，在市场中间
const WALK_FROM_X := 552
const STALL_CAT_X := STALL_X + 1      # 小猫坐在摊位左半边，右半边摆鱼
const ROAM_MIN_X := 552               # 自由走动的范围（小猫贴图左边缘）
const ROAM_MAX_X := 1430
const WORLD_END := 1470               # 世界右边界，镜头不会越过
const ROAM_SPEED := 70.0              # 自由走动速度（像素/秒）
const CORNER_L := STALL_X - 29        # 绕过柜台的两个拐点：到这里小猫的身体不再和柜台重叠
const CORNER_R := STALL_X + 43
const LIFT := 3
const ZONE_BLEND := 28.0              # 水域分界处颜色过渡的半宽（像素）                       # 绕到柜台后面时抬高几像素（更靠里）
const NEAR := 16                      # 离摊位/码头多近算"到了"
## 可以进去的房子：[门的中心 x, 名字, 用途]
const DOORS := [[674, "造船厂", "shipyard"], [828, "服装店", "tailor"], [898, "渔具店", "tackle"], [1410, "小猫的家", "home"]]
## 街上散步的居民：[样子, 散步范围左端, 右端, 走一个来回的毫秒数]
const STROLLERS := [[1, 690, 800, 26000], [2, 850, 980, 34000], [0, 930, 1010, 22000]]
## 市场里 NPC 的摊位：[摊位左端 x, 货物, 招牌, 摊主样子]
const MARKET := [[1070, "fruit", "水果", 1], [1128, "veg", "蔬菜", 2], [1244, "bread", "面包", 0], [1302, "flower", "鲜花", 1]]
## 逛市场的顾客：[样子, 错开的毫秒数, 依次光顾的摊位下标]
const SHOPPERS := [[0, 0, [0, 1, 3, 2, 1]], [2, 9000, [3, 2, 0, 1]], [1, 17000, [1, 3, 0, 2]]]
const SHOP_SPEED := 26.0       # 顾客走路速度（像素/秒）
const DWELL_MS := 4200         # 在一个摊位前停留多久
const BUY_AT_MS := 1500        # 停下后多久付钱拿货
const CHAT := ["今天的鱼真新鲜", "听说金锦鲤很稀有", "专注时鱼更值钱", "别让小猫饿着了", "天气真好呀", "你的帽子真好看"]
const HOUSES := [["house_3", 652], ["house_1", 818], ["house_2", 872], ["house_0", 1388]]
const TREES := [716, 940]

# 相对小猫贴图左上角的偏移
const HAND := Vector2(21, 22)
const TIP_IDLE := Vector2(33, 6)
const TIP_WAIT := Vector2(38, 12)
const TIP_REEL := Vector2(30, 2)

var m
var cat_pos := Vector2(FISH_X + 10, WATER_Y - 34)   # 小猫贴图左上角（世界坐标）
var boat_x: float = FISH_X
var boat_moving: bool = false   # 玩家正用方向键划船
var boat_dir: float = 1.0
var bird: Dictionary = {}       # 正在来访的鸟：{kind, item, t0}
var retract_t0: int = -100000     # 划船前收杆动作开始的时刻
var bait_id: String = ""        # 这一竿钩上的饵（"" = 面团），画上饵动作用
var eat_t0: int = -100000
var eat_fish: String = ""
var splash_t0: int = -100000
var hop_t0: int = -100000
var chest_open_t0: int = -100000   # 宝箱被打开的时刻
var leaving: Array = []       # 买完离开的顾客: {kind, t0}
var walk_flip: bool = false   # 自动行走时是否朝左
var walk_behind: bool = false # 小猫此刻在柜台后面（自动绕过摊位的那一段，或玩家带着它在摊位里走）
var roam_behind: bool = false # 玩家在摊位里按方向键：小猫先留在柜台后面，走出摊位才回到前面
var roam_exit_x: float = -1e9 # 刚从柜台后面走出来的位置（用来让小猫从抬高处慢慢落回地面）
var route_behind_start: bool = false # 这一趟去摊位是从柜台后面出发的，不用再绕一圈
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
	var p := Journey.sail_curve(j.progress(now))
	match j.activity():
		Journey.Activity.SAIL_OUT:
			boat_x = lerpf(float(j.boat_x()), DOCK_X, p)
		Journey.Activity.SAIL_BACK:
			boat_x = lerpf(DOCK_X, float(j.boat_x()), p)
		Journey.Activity.FISHING, Journey.Activity.IDLE_FULL:
			boat_x = float(j.boat_x())
		_:
			boat_x = DOCK_X
	boat_x = roundf(boat_x)
	_update_wake(t)
	walk_behind = false
	if j.activity() != Journey.Activity.ROAM:
		roam_behind = false
	if j.activity() != Journey.Activity.WALK_TO_STALL:
		route_behind_start = false
	match j.activity():
		Journey.Activity.WALK_TO_STALL, Journey.Activity.WALK_TO_BOAT:
			# 默认从码头走到摊位（或反过来）；如果是玩家松手后接管，则从松手的位置出发
			var pose := _walk_pose(j.activity() == Journey.Activity.WALK_TO_STALL, float(j.walk_from()), j.progress(now))
			walk_flip = pose["flip"]
			walk_behind = pose["behind"]
			cat_pos = Vector2(roundf(pose["x"]), roundf(pose["y"]))
		Journey.Activity.ROAM:
			var rx := float(j.roam_x())
			var ry := float(GROUND_Y - 28)
			if roam_behind:
				if rx <= CORNER_L or rx >= CORNER_R:       # 完全走出摊位了：回到柜台前面
					roam_behind = false
					roam_exit_x = rx
				else:
					ry = float(GROUND_Y) - 31.0 + 2.0 * clampf(minf(rx - CORNER_L, CORNER_R - rx) / 30.0, 0.0, 1.0)
			if not roam_behind:
				ry -= float(LIFT) * clampf(1.0 - absf(rx - roam_exit_x) / 12.0, 0.0, 1.0)   # 刚走出来时还抬高着，慢慢落回地面
			walk_behind = roam_behind
			cat_pos = Vector2(rx, roundf(ry))
		Journey.Activity.VENDING, Journey.Activity.SOLD_OUT:
			cat_pos = Vector2(STALL_CAT_X, GROUND_Y - 29)      # 脚踩在地面上
		_:
			cat_pos = Vector2(boat_x + 10, boat_y(t) - 23)

## 气泡的点击区域（世界坐标）：满篓（去小镇）或卖光了（去钓鱼）；不显示气泡时返回空矩形。
func bubble_rect(t: int) -> Rect2:
	var a: int = m.game.journey.activity()
	if (a != Journey.Activity.IDLE_FULL and a != Journey.Activity.SOLD_OUT) or m.game.pomodoro.is_break():
		return Rect2()
	return Rect2(cat_pos + Vector2(34, -11 - (t / 600) % 2), Vector2(19, 18))   # 在头的右上方，不被迷你视图的面板挡住

## 小猫从 x 绕进柜台后面的路线：先在柜台前走到最近的一端，再绕进去走到摊位后面。
func stall_route(from_x: float, behind_start: bool = false) -> Dictionary:
	if behind_start and from_x > CORNER_L and from_x < CORNER_R:        # 已经在柜台后面：直接走过去
		return {"corner": from_x, "l1": 0.0, "l2": absf(STALL_CAT_X - from_x)}
	var dl := absf(from_x - CORNER_L) + float(STALL_CAT_X - CORNER_L)
	var dr := absf(CORNER_R - from_x) + float(CORNER_R - STALL_CAT_X)
	var corner: float = CORNER_L if dl <= dr else CORNER_R
	return {"corner": corner, "l1": absf(corner - from_x), "l2": absf(STALL_CAT_X - corner)}

## 自动走路时小猫此刻的位置。from < 0 表示默认起点。返回 {x, y, flip, behind}。
## 去摊位：在柜台前走到柜台一端 → 抬高几像素"绕过去" → 在柜台后面走到摊位；回码头反过来。
func _walk_pose(to_stall: bool, from: float, prog: float) -> Dictionary:
	var front_y := float(GROUND_Y - 28)
	if to_stall:
		var f := from if from >= 0.0 else float(WALK_FROM_X)
		var r := stall_route(f, route_behind_start)
		var corner: float = r["corner"]
		var l1: float = r["l1"]
		var l2: float = r["l2"]
		var s := prog * (l1 + l2)
		if s < l1:
			var d := signf(corner - f)
			return {"x": f + d * s, "y": front_y - float(LIFT) * clampf((s - (l1 - 12.0)) / 12.0, 0.0, 1.0),
					"flip": d < 0.0, "behind": false}
		var d2 := signf(STALL_CAT_X - corner)
		return {"x": corner + d2 * (s - l1), "y": lerpf(front_y - LIFT, float(GROUND_Y - 29), clampf((s - l1) / maxf(l2, 1.0), 0.0, 1.0)),
				"flip": d2 < 0.0, "behind": true}
	if from >= 0.0:                          # 玩家松手后接管：直接在柜台前走回码头
		return {"x": lerpf(from, WALK_FROM_X, prog), "y": front_y, "flip": float(WALK_FROM_X) < from, "behind": false}
	var b1 := float(STALL_CAT_X - CORNER_L)   # 先在柜台后面走到左端，再绕出来
	var b2 := float(CORNER_L - WALK_FROM_X)
	var s2 := prog * (b1 + b2)
	if s2 < b1:
		return {"x": STALL_CAT_X - s2, "y": lerpf(float(GROUND_Y - 29), front_y - LIFT, s2 / b1), "flip": true, "behind": true}
	return {"x": CORNER_L - (s2 - b1), "y": front_y - float(LIFT) * (1.0 - clampf((s2 - b1) / 12.0, 0.0, 1.0)),
			"flip": true, "behind": false}

## 从 x 走到摊位 / 码头的路程，占"码头↔摊位"全程的比例。
func frac_to_stall(x: float) -> float:
	var r := stall_route(x, roam_behind)
	return (float(r["l1"]) + float(r["l2"])) / float(STALL_CAT_X - WALK_FROM_X)

func frac_to_boat(x: float) -> float:
	return absf(x - WALK_FROM_X) / float(STALL_CAT_X - WALK_FROM_X)

## 小猫（贴图左边缘 x）站在鱼摊前的任何位置都算"到摊位了"：中心落在摊位宽度内（再宽 8 像素）。
func near_stall(x: float) -> bool:
	return absf(x + 16.0 - (STALL_X + 23.0)) <= 31.0

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

## 下雨时外面的居民少一大半（只留第 0 位，打着伞）；市场买鱼的顾客不受影响。
func stroller_active(i: int) -> bool:
	return i == 0 or not m.game.is_raining()

const CHAT_RANGE := 46.0        # 离居民这么近就能按键聊天
const CHAT_GAP := 24.0          # 聊天时小猫和居民中心点至少隔这么远，免得叠在一起

func stroller_near(x: float, t: int) -> int:
	var best := -1
	var best_d := CHAT_RANGE + 1.0
	for i in STROLLERS.size():
		if not stroller_active(i):
			continue
		var d := absf(float(stroller_at(i, t)[0]) + 8.0 - (x + 16.0))
		if d <= CHAT_RANGE and d < best_d:
			best = i
			best_d = d
	return best

## 聊天时小猫该站的位置（贴图左边缘 x）：离居民太近就退到 CHAT_GAP 远，已经够远就不动。
func chat_stand_x(cat_x: float, npc_x: float) -> float:
	var d := (cat_x + 16.0) - (npc_x + 8.0)
	if absf(d) >= CHAT_GAP:
		return cat_x
	var side := -1.0 if d < 0.0 else 1.0
	return npc_x + 8.0 + side * CHAT_GAP - 16.0

func chat_with(i: int, t: int) -> void:
	chat_x = float(stroller_at(i, t)[0])
	chat_who = i
	roam_flip = chat_x + 8.0 < cat_pos.x + 16.0      # 小猫转身面对居民（居民在 stroller_at 里已经转向小猫）
	chat_line = CHAT[(t / 1000 + i) % CHAT.size()]
	chat_t0 = t

func _draw_strollers(t: int) -> void:
	for i in STROLLERS.size():
		if not stroller_active(i):
			continue
		var at := stroller_at(i, t)
		var talking := i == chat_who and t - chat_t0 < 3500
		var name := "villager_%d" % int(STROLLERS[i][0])
		var pos := Vector2(float(at[0]), GROUND_Y - 19)
		# 居民贴图本身面朝左：朝左走直接画，朝右走才翻转（之前写反了，看起来像倒着走）
		if at[1]:
			m.tex_frame(name, pos, 0 if talking else (t / 220) % 2, 2)
		else:
			m.tex_frame_flipped(name, pos, 0 if talking else (t / 220) % 2, 2)
		if m.game.is_raining():
			m.draw_texture(m.tex["umbrella"], pos + Vector2(0, -7))

## 居民说的话：最后画，保证不被摊位和房子挡住。
func _draw_chat(t: int) -> void:
	if chat_who < 0 or t - chat_t0 >= 3500 or m.label_width(chat_line) <= 0:
		return
	var pos := Vector2(chat_x, GROUND_Y - 19)
	var w: float = m.label_width(chat_line) + 6
	var box := Rect2(roundf(pos.x + 8 - w / 2), pos.y - 17, w, 13)
	m.draw_rect(box.grow(1), Pal.U_K)
	m.draw_rect(box, Pal.U_W)
	m.draw_rect(Rect2(pos.x + 6, box.end.y, 3, 2), Pal.U_W)
	m.label(chat_line, box.position + Vector2(3, 1), Pal.U_K)

## 顾客在第 stall 号摊位前的站位。
func _stand_x(stall: int, k: int) -> float:
	return float(MARKET[stall][0]) + 6.0 + float(k % 2) * 16.0

## 第 k 位顾客此刻的状态（纯函数，只看时间）：
## x 位置；facing_right 朝向；dwell 在摊位前停着；d 停了多久；stall 当前/刚离开的摊位；carry 手里拿着的货
func shopper_at(k: int, t: int) -> Dictionary:
	var route: Array = SHOPPERS[k][2]
	var n := route.size()
	var cycle := 0.0
	for i in n:
		var nx: int = route[(i + 1) % n]
		cycle += float(DWELL_MS) + absf(_stand_x(nx, k) - _stand_x(route[i], k)) / SHOP_SPEED * 1000.0
	var tt := fposmod(float(t + int(SHOPPERS[k][1])), cycle)
	for i in n:
		var cur: int = route[i]
		var nxt: int = route[(i + 1) % n]
		var x0 := _stand_x(cur, k)
		var x1 := _stand_x(nxt, k)
		var prev_x := _stand_x(route[(i + n - 1) % n], k)
		if tt < float(DWELL_MS):
			return {"x": x0, "facing_right": x0 > prev_x, "dwell": true, "d": tt, "stall": cur, "carry": ""}
		tt -= float(DWELL_MS)
		var leg := absf(x1 - x0) / SHOP_SPEED * 1000.0
		if tt < leg:
			return {"x": roundf(lerpf(x0, x1, tt / leg)), "facing_right": x1 > x0, "dwell": false, "d": 0.0,
					"stall": cur, "carry": MARKET[cur][1]}
		tt -= leg
	return {"x": _stand_x(route[0], k), "facing_right": false, "dwell": true, "d": 0.0, "stall": route[0], "carry": ""}

func _stall_hopping(i: int, t: int) -> bool:
	for k in SHOPPERS.size():
		var s := shopper_at(k, t)
		if s["dwell"] and s["stall"] == i and s["d"] >= BUY_AT_MS and s["d"] < BUY_AT_MS + 350.0:
			return true
	return false

## 木招牌（门楣 / 摊位上方），文字走标签图集。
func _plate(cx: float, y: float, text: String) -> void:
	var w: float = m.label_width(text) + 5
	var plate := Rect2(roundf(cx - w / 2), y, w, 12)
	m.draw_rect(plate.grow(1), Pal.U_K)
	m.draw_rect(plate, Pal.L_N)
	m.draw_rect(Rect2(plate.position.x, plate.end.y - 2, plate.size.x, 2), Pal.L_O)
	m.label(text, plate.position + Vector2(3, 0), Pal.U_K)

## 市场里的 NPC 摊位：雨棚 → 摊主 → 柜台 → 货。
func _draw_market_stalls(t: int) -> void:
	for i in MARKET.size():
		var s: Array = MARKET[i]
		var x := float(s[0])
		m.draw_texture(m.tex["stall_back_" + s[1]], Vector2(x, GROUND_Y - 40))
		var hop := -1.0 if _stall_hopping(i, t) else 0.0
		m.tex_frame("villager_%d" % int(s[3]), Vector2(x + 15, GROUND_Y - 27 + hop), (t / 900 + i) % 2, 2)
		m.draw_texture(m.tex["stall_front"], Vector2(x, GROUND_Y - 11))
		m.draw_texture(m.tex["goods_" + s[1]], Vector2(x + 5, GROUND_Y - 18))
		_draw_stall_deco(s[1], x)
		_plate(x + 23, GROUND_Y - 53, s[2])
	m.draw_texture(m.tex["ishidoro"], Vector2(float(MARKET[0][0]) - 13.0, GROUND_Y - 16))   # 市场口的石灯笼

## 摊位地面上的装饰：左边货箱、右边小黑板看板、再右边的缝里立一面招牌旗；每种摊位画法不同。
func _draw_stall_deco(kind: String, x: float) -> void:
	m.draw_texture(m.tex["deco_crate_" + kind], Vector2(x + 1, GROUND_Y - 9))
	m.draw_texture(m.tex["deco_board_" + kind], Vector2(x + 31, GROUND_Y - 12))
	m.draw_texture(m.tex["deco_nobori_" + kind], Vector2(x + 46, GROUND_Y - 32))

## 逛市场的顾客：走一圈，在摊位前停下，付钱，拿到货拎着走。
func _draw_shoppers(t: int) -> void:
	for k in SHOPPERS.size():
		var s := shopper_at(k, t)
		var pos := Vector2(float(s["x"]), GROUND_Y - 19)
		var name := "villager_%d" % int(SHOPPERS[k][0])
		var frame := 0 if s["dwell"] else (t / 220) % 2
		if s["facing_right"]:
			m.tex_frame_flipped(name, pos, frame, 2)
		else:
			m.tex_frame(name, pos, frame, 2)
		var hand := Vector2(pos.x + (11.0 if s["facing_right"] else -3.0), GROUND_Y - 11)
		if s["dwell"]:
			var d: float = s["d"]
			var si: int = s["stall"]
			var stall_pt := Vector2(float(MARKET[si][0]) + 20.0, GROUND_Y - 20)
			if d >= BUY_AT_MS and d < BUY_AT_MS + 900.0:       # 货飞到手里，硬币飞向摊主
				var p := (d - BUY_AT_MS) / 900.0
				m.draw_texture(m.tex["ico_" + MARKET[si][1]], stall_pt.lerp(hand, p).round())
				if p < 0.6:
					m.draw_texture(m.tex["coin"], Vector2(hand.x, hand.y - 6.0).lerp(stall_pt + Vector2(0, -4), p / 0.6).round())
			elif d >= BUY_AT_MS + 900.0:
				m.draw_texture(m.tex["ico_" + MARKET[si][1]], hand.round())
		elif s["carry"] != "":
			m.draw_texture(m.tex["ico_" + s["carry"]], hand.round())

## 码头边的浅滩：水变清变浅，能看见沙质的水底；入口处有一对红白禁钓浮标。
func _sand_depth(u: float) -> float:
	var e: float = u * u * (3.0 - 2.0 * u)
	return lerpf(64.0, 8.0, pow(e, 0.8))        # 水深：入口很深（沙在画面外），慢慢抬到岸边 8 像素

func _draw_shoal(left: float, right: float, bottom: float, t: int) -> void:
	var x0: float = float(m.game.journey.cfg_dock_x()) - float(m.game._cfg.get("town", {}).get("dock_no_fish", 70)) - 30.0
	if right <= x0 or left >= SHORE_X:
		return
	var span: float = SHORE_X - x0
	var floor_bottom: float = maxf(bottom, WATER_Y + 80)
	var xx: float = floorf(maxf(left, x0) / 2.0) * 2.0
	while xx < minf(right, SHORE_X):
		var u: float = clampf((xx - x0) / span, 0.0, 1.0)
		var top: float = WATER_Y + 6.0 + _sand_depth(u)
		# 清澈的浅水：从入口一点点变亮，没有硬边
		var wash: float = 0.05 + 0.5 * u * u
		m.draw_rect(Rect2(xx, WATER_Y + 6, 2, top - WATER_Y - 6), Color(Pal.L_C, wash))
		# 沙底：水线一圈泡沫 → 湿沙 → 干沙，越深颜色越暗，加一点颗粒
		var col_i: int = int(xx / 2.0)
		m.draw_rect(Rect2(xx, top, 2, 1), Pal.L_W)
		m.draw_rect(Rect2(xx, top + 1, 2, 2), Pal.L_N)
		m.draw_rect(Rect2(xx, top + 3, 2, floor_bottom - top - 3), Pal.L_H)
		if col_i % 3 == 0:
			m.draw_rect(Rect2(xx, top + 5 + (col_i * 7) % 6, 1, 1), Pal.L_N)
		if col_i % 4 == 1:
			m.draw_rect(Rect2(xx, top + 9 + (col_i * 5) % 9, 1, 1), Pal.U_H)
		if top < bottom - 20:                          # 下面一层阴影，沙看起来有厚度
			m.draw_rect(Rect2(xx, top + 20, 2, floor_bottom - top - 20), Pal.L_N)
			if col_i % 3 == 2:
				m.draw_rect(Rect2(xx, top + 24 + (col_i * 11) % 12, 1, 1), Pal.U_H)
		xx += 2.0
	# 沙面上的细波纹线
	for i in 6:
		var rx: float = x0 + 40.0 + float(i) * (span - 60.0) / 5.0
		var ru: float = clampf((rx - x0) / span, 0.0, 1.0)
		var ry: float = WATER_Y + 6.0 + _sand_depth(ru) + 6.0
		if rx > left - 12 and rx < right + 12:
			m.draw_rect(Rect2(rx, ry, 6, 1), Pal.L_N)
			m.draw_rect(Rect2(rx + 2, ry + 1, 4, 1), Pal.U_H)
	# 水面下晃动的光纹
	for i in 9:
		var cx: float = x0 + 44.0 + i * (span - 70.0) / 8.0
		var u2: float = clampf((cx - x0) / span, 0.0, 1.0)
		var cy: float = WATER_Y + 6.0 + _sand_depth(u2) - 5.0
		var sway: float = roundf(sin(float(t) / 700.0 + i * 1.7) * 2.0)
		if cx > left - 8 and cx < right + 8:
			m.draw_rect(Rect2(cx + sway, cy, 5, 1), Color(Pal.L_W, 0.45 + 0.2 * u2))
	# 水底的小石子和海草
	for i in 8:
		var px: float = x0 + 36.0 + float(i * 29 % int(span - 50.0))
		var u3: float = clampf((px - x0) / span, 0.0, 1.0)
		var py: float = WATER_Y + 6.0 + _sand_depth(u3)
		if px > left - 8 and px < right + 8:
			if i % 2 == 0:
				m.draw_rect(Rect2(px, py - 1, 3, 2), Pal.U_H)
				m.draw_rect(Rect2(px, py - 1, 1, 1), Pal.L_N)
			else:
				var wave: float = roundf(sin(float(t) / 500.0 + i) * 1.0)
				m.draw_rect(Rect2(px, py - 6, 1, 6), Pal.L_G)
				m.draw_rect(Rect2(px + 1 + wave, py - 8, 1, 4), Pal.U_G)
	# 禁钓浮标
	var bx: float = float(m.game.journey.cfg_dock_x()) - float(m.game._cfg.get("town", {}).get("dock_no_fish", 70))
	if bx > left - 6 and bx < right + 6:
		var bob: int = 1 if (t / 650) % 2 == 0 else 0
		m.draw_rect(Rect2(bx, WATER_Y - 9 + bob, 1, 6), Pal.U_K)
		m.draw_rect(Rect2(bx + 1, WATER_Y - 9 + bob, 3, 2), Pal.L_R)
		m.draw_rect(Rect2(bx - 2, WATER_Y - 3 + bob, 5, 3), Pal.L_W)
		m.draw_rect(Rect2(bx - 2, WATER_Y - 3 + bob, 5, 1), Pal.L_R)
		m.draw_rect(Rect2(bx - 2, WATER_Y - 1 + bob, 5, 1), Pal.U_K)


## 码头桩脚：木桩一直插进沙里，水下的部分偏暗蓝，入水处有一圈涟漪，沙面上有小沙堆。
func _draw_pier_feet(left: float, right: float, t: int) -> void:
	var x0: float = float(m.game.journey.cfg_dock_x()) - float(m.game._cfg.get("town", {}).get("dock_no_fish", 70)) - 30.0
	var span: float = SHORE_X - x0
	for off in [5, 30, 55]:
		var px: float = float(PIER_X + off)
		if px + 3 < left or px > right:
			continue
		var u: float = clampf((px - x0) / span, 0.0, 1.0)
		var top: float = WATER_Y + 6.0 + _sand_depth(u)
		var pier_bottom: float = GROUND_Y + 28.0
		if top + 3.0 > pier_bottom:                       # 沙面比桩脚还低：接一段木桩下去
			m.draw_rect(Rect2(px, pier_bottom, 3, top + 3.0 - pier_bottom), Pal.U_O)
			m.draw_rect(Rect2(px, pier_bottom, 1, top + 3.0 - pier_bottom), Pal.L_O)
		# 水下的那一段染成偏暗的蓝色
		m.draw_rect(Rect2(px, WATER_Y + 6, 3, minf(top + 3.0, maxf(pier_bottom, top + 3.0)) - WATER_Y - 6), Color(Pal.U_B, 0.45))
		# 沙堆
		m.draw_rect(Rect2(px - 2, top - 1, 7, 2), Pal.L_H)
		m.draw_rect(Rect2(px - 1, top - 2, 5, 1), Pal.L_W)
		# 入水涟漪
		var rp: int = (t / 450 + off) % 3
		m.draw_rect(Rect2(px - 1 - rp, WATER_Y + 6, 5 + rp * 2, 1), Color(Pal.L_W, 0.7 - 0.2 * rp))


## 水域最左侧的浪区：浪头高出海面，越往左越高，白色的浪尖不停翻滚；小船划进去会被推回来。
func _draw_waves(left: float, right: float, bottom: float, t: int) -> void:
	var wz: Vector2 = m.game.wave_zone()
	var wend: float = wz.x + 18.0
	if left >= wend:
		return
	var x: float = floorf(maxf(left, 0.0) / 2.0) * 2.0
	while x < minf(right, wend):
		var k: float = clampf((wend - x) / (wend - wz.y + 20.0), 0.0, 1.0)      # 越靠左 k 越大
		var ph: float = x * 0.11 - float(t) / 380.0          # 相位随时间减小：波形从左往右传
		var h: float = roundf(k * (3.0 + 2.0 * sin(ph) + 1.0 * sin(ph * 2.3 + 1.0)))
		if h > 0.0:
			m.draw_rect(Rect2(x, WATER_Y + 4 - h, 2, h + 2), Pal.L_B)           # 浪体
			if h > 3.0:
				m.draw_rect(Rect2(x, WATER_Y + 4 - h + 3, 2, 1), Pal.L_C)
			m.draw_rect(Rect2(x, WATER_Y + 4 - h, 2, 1), Pal.L_W)               # 浪尖
			if h > 2.0:
				m.draw_rect(Rect2(x, WATER_Y + 5 - h, 2, 1), Pal.L_C)
		x += 2.0
	# 水面以下一排排白色的浪纹，会向右滚
	for row in 4:
		var wy: float = WATER_Y + 9.0 + float(row) * 8.0
		var off: float = fposmod(float(t) / (90.0 + row * 25.0) + row * 7.0, 14.0)
		var cx: float = off - 14.0
		while cx < wend:
			var kk: float = clampf((wend - cx) / (wend - wz.y + 20.0), 0.0, 1.0)
			if cx + 8 > left and cx < right and kk > 0.05:
				m.draw_rect(Rect2(cx, wy, 6, 1), Color(Pal.L_W, 0.35 + 0.45 * kk))
				m.draw_rect(Rect2(cx + 1, wy - 1, 3, 1), Color(Pal.L_W, 0.25 + 0.35 * kk))
			cx += 14.0
	# 浪区深处整体压暗一点，看着更凶
	m.draw_rect(Rect2(maxf(left, 0.0), WATER_Y + 6, minf(right, wz.y + 20.0) - maxf(left, 0.0), maxf(0.0, bottom - WATER_Y - 6)), Color(Pal.U_B, 0.12))


## 市场入口：拱门、招牌、彩旗。
func _draw_market_gate(left: float, right: float) -> void:
	m.draw_texture(m.tex["market_gate"], Vector2(GATE_X, GROUND_Y - 50))
	_plate(GATE_X + 24, GROUND_Y - 49, "市场")
	var cols := [Pal.L_R, Pal.L_Y, Pal.L_B, Pal.L_G]
	var x0 := GATE_X + 48
	var i := 0
	while x0 + i * 7 < WORLD_END - 6:
		var fx := float(x0 + i * 7)
		if fx > left - 8 and fx < right + 8:
			var sag := absf(fposmod(float(i) / 8.0, 1.0) - 0.5) * 2.0       # 绳子在每 8 面旗之间微微下垂
			var fy := float(GROUND_Y - 62) + roundf((1.0 - sag) * 3.0)
			m.draw_rect(Rect2(fx, fy, 7, 1), Pal.U_K)
			m.draw_rect(Rect2(fx + 1, fy + 1, 4, 3), cols[i % 4])
			m.draw_rect(Rect2(fx + 2, fy + 4, 2, 1), cols[i % 4])
		i += 1

func on_sale(fish_id: String) -> void:
	var f: Dictionary = m.game.fish_by_id.get(fish_id, {})
	leaving.append({"kind": customer_kind, "t0": Time.get_ticks_msec(), "x0": float(STALL_X + 50), "fish": f.get("sprite", ""), "v": maxf(1.0, m.game.time_scale)})
	approach_visible = false

## 这一单的顾客：每单换一位（不连续重复），在这一单的后半段从右边走过来。
## 如果顾客走到一半小猫离开了摊位（被玩家带走、或进入休息），顾客空手掉头回去，而不是凭空消失。
func _update_customer(now: int) -> void:
	var g = m.game
	var j: Journey = g.journey
	var selling: bool = j.activity() == Journey.Activity.VENDING and not g.pomodoro.is_break() and not g.state.basket.is_empty()
	if not selling:
		if approach_visible:
			leaving.append({"kind": customer_kind, "t0": Time.get_ticks_msec(), "x0": approach_x, "fish": "", "v": maxf(1.0, m.game.time_scale)})
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
	var left := cam.x
	var right := cam.x + view.x
	var bottom := cam.y + view.y

	if not mini:
		_draw_sky(cam, view, t)
		_draw_sky_birds(cam, view, t)
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
	# 水域着色：深水区偏暗，浅滩偏亮；分界处各漂一个浮标
	if not mini:
		var zones: Array = m.game.zone_bounds(SHORE_X)
		# 水域颜色在分界处慢慢过渡（每 4 像素一列，按距离分界线的远近淡入淡出），不再是一刀切
		var x := floorf(left / 4.0) * 4.0
		while x < sea_right:
			for tint in _zone_tints(x + 2.0, zones):
				m.draw_rect(Rect2(x, WATER_Y, 4, maxf(0, bottom - WATER_Y)), tint)
			x += 4.0
		for z in zones:
			var bx := float(z["x1"])
			if z["id"] != "shallow" and bx > left - 4 and bx < right + 4:
				var bob := 1 if (t / 700 + int(bx)) % 2 == 0 else 0
				# 水域分界浮标：黄色浮筒 + 竖杆 + 小旗，和钓鱼的红白浮漂区分开
				m.draw_rect(Rect2(bx, WATER_Y - 9 + bob, 1, 6), Pal.U_K)
				m.draw_rect(Rect2(bx + 1, WATER_Y - 9 + bob, 3, 2), Pal.L_Y)
				m.draw_rect(Rect2(bx - 2, WATER_Y - 3 + bob, 5, 3), Pal.L_Y)
				m.draw_rect(Rect2(bx - 2, WATER_Y - 2 + bob, 5, 1), Pal.U_K)
	_draw_shoal(left, sea_right, bottom, t)
	_draw_waves(left, sea_right, bottom, t)
	# 地面
	var land_left := maxf(left, SHORE_X)
	if land_left < right:
		_tile_row("ground", 0, 1, GROUND_Y, land_left, right)
		m.draw_rect(Rect2(land_left, GROUND_Y + 16, right - land_left, maxf(0, bottom - GROUND_Y - 16)), Pal.L_N)
	m.draw_texture(m.tex["pier"], Vector2(PIER_X, GROUND_Y))
	_draw_pier_feet(left, right, t)

	for d in DOORS:      # 门楣上的木招牌
		var w: float = m.label_width(d[1]) + 5
		var plate := Rect2(roundf(float(d[0]) - w / 2), GROUND_Y - 39, w, 12)
		m.draw_rect(plate.grow(1), Pal.U_K)
		m.draw_rect(plate, Pal.L_N)
		m.draw_rect(Rect2(plate.position.x, plate.end.y - 2, plate.size.x, 2), Pal.L_O)
		m.label(d[1], plate.position + Vector2(3, 0), Pal.U_K)
	# 摊位（后半）→ 摆摊的小猫 → 柜台 → 路过的居民、顾客、走动中的小猫（都在摊位前面）
	_draw_market_gate(left, right)
	_draw_market_stalls(t)
	_plate(STALL_X + 23, GROUND_Y - 53, "鱼摊")
	m.draw_texture(m.tex["stall_back"], Vector2(STALL_X, GROUND_Y - 40))
	var in_town: bool = not j.on_boat()
	var bob_y := boat_y(t)
	var behind_counter: bool = act == Journey.Activity.VENDING or act == Journey.Activity.SOLD_OUT or walk_behind
	if in_town and behind_counter:
		_draw_town_cat(act, on_break, now, t)
	for px in [2.0, 40.0]:     # 两根立柱在猫前面：小猫从柜台后面走过时被立柱挡一下
		m.draw_texture_rect_region(m.tex["stall_back"], Rect2(STALL_X + px, GROUND_Y - 30, 4, 32), Rect2(px, 10, 4, 32))
	m.draw_texture(m.tex["stall_front"], Vector2(STALL_X, GROUND_Y - 11))
	_draw_stall_deco("fish", float(STALL_X))
	if act == Journey.Activity.VENDING:
		_draw_stall_goods()
	if act == Journey.Activity.SOLD_OUT:
		var sb := bubble_rect(t)
		if sb.size.x > 0:
			m.draw_texture(m.tex["bubble_sold"], sb.position)
	_draw_strollers(t)
	_draw_shoppers(t)
	_draw_customer(t)
	_draw_leaving(t)
	if in_town and not behind_counter:
		_draw_town_cat(act, on_break, now, t)
	_draw_chat(t)
	# 市场拱门的右立柱在人物前面：往市场里走时从柱子后面钻过去
	m.draw_texture_rect_region(m.tex["market_gate"], Rect2(GATE_X + 38, GROUND_Y - 42, 10, 42), Rect2(38, 8, 10, 42))

	# 船：鱼篓在船舱里、小猫背后（先画）→ 小猫 → 船身（盖住鱼篓和小猫的下半截）→ 龙头 → 吃水线和水纹
	_draw_boat_basket(bob_y, not in_town)
	if not in_town:
		_draw_boat_cat(act, on_break, now, t)
	m.draw_texture(m.tex["boat_%d" % clampi(int(m.game.state.boat_level), 0, 3)] if m.game.state.boat_level > 0 else m.tex["boat"], Vector2(boat_x, bob_y))
	m.draw_texture(m.tex["boat_head"], Vector2(boat_x - 2, bob_y - 17))
	_draw_waterline(bob_y, t)
	if not in_town:
		_draw_boat_extras(act, on_break, now, t)
		_draw_bird(t, bob_y)

# ------------------------------------------------------------------ 鸟和船上的东西
const BASKET_SLOTS := 12

## 船舱里的鱼篓（在小猫背后、龙头旁边，下半截被船身盖住）；鱼按篓子装了多少堆起来，满了堆成小山。
## 人在镇上时鱼在猫身上，船上的篓子是空的。
func _draw_boat_basket(bob_y: float, show_fish: bool) -> void:
	var o := Vector2(boat_x + 9, bob_y - 3)
	m.draw_texture(m.tex["boat_basket_back"], o + Vector2(0, -4))
	var g = m.game
	var size: int = g.state.basket.size() if show_fish else 0
	if size > 0:
		var slots: int = clampi(ceili(float(BASKET_SLOTS) * float(g.economy.basket_percent(g.state)) / 100.0), 1, BASKET_SLOTS)
		for s in slots:
			var fish_id: String = g.state.basket[(s * size) / slots]
			var p := Vector2(o.x + 2 + (s % 4) * 3 + (s / 4) % 2, o.y - 3 - (s / 4) * 2)
			var col := _fish_color(fish_id)
			m.draw_rect(Rect2(p.x, p.y, 3, 2), col)
			m.draw_rect(Rect2(p.x, p.y + 1, 3, 1), col.darkened(0.25))
	m.draw_texture(m.tex["boat_basket"], o)

## 水域染色：返回世界坐标 cx 处叠在海上的半透明色（分界处前后 ZONE_BLEND 像素内淡入淡出）。
func _zone_tints(cx: float, zones: Array) -> Array:
	var out: Array = []
	for zi in zones.size():
		var z: Dictionary = zones[zi]
		var base := Color(0, 0, 0, 0)
		if z["id"] == "deep":
			base = Color(Pal.U_K, 0.22)
		elif z["id"] == "shallow":
			base = Color(Pal.L_C, 0.2)
		if base.a <= 0.0:
			continue
		var w := 1.0
		if zi > 0:
			w *= _ease(clampf((cx - (float(z["x0"]) - ZONE_BLEND)) / (2.0 * ZONE_BLEND), 0.0, 1.0))
		if zi < zones.size() - 1:
			w *= 1.0 - _ease(clampf((cx - (float(z["x1"]) - ZONE_BLEND)) / (2.0 * ZONE_BLEND), 0.0, 1.0))
		if w > 0.01:
			base.a *= w
			out.append(base)
	return out

## 船吃水：水面盖住船底，水线上一圈起伏的白沫；船头船尾向外荡开水纹，划船时船尾拖出尾迹。
func _draw_waterline(bob_y: float, t: int) -> void:
	var x0 := boat_x - 1.0
	var w := 66.0
	var top := float(WATER_Y + 2)          # 水线和浮漂入水的位置持平，船身只露出水面以上的部分
	var zones: Array = m.game.zone_bounds(SHORE_X)
	# 盖住船底的水：颜色要和这里的海一致（含水域染色），按 3 像素一列画
	var cx := x0
	while cx < x0 + w:
		var col: Color = Pal.L_B
		for tint in _zone_tints(cx + 1.5, zones):
			col = col.lerp(Color(tint, 1.0), tint.a)
		var rel := cx - x0
		var y0 := top + (1.0 if rel < 3.0 or rel > w - 6.0 else 0.0)
		m.draw_rect(Rect2(cx, y0, minf(3.0, x0 + w - cx), float(WATER_Y + 10) - y0), col)
		cx += 3.0
	for k in int((w - 12.0) / 3.0):                                 # 水线上的白沫，一格格错开起伏
		var wave := (k + t / 260) % 2 == 0
		m.draw_rect(Rect2(x0 + 6.0 + k * 3.0, top - (1 if wave else 0) + 1, 3, 1), Pal.L_W if wave else Pal.L_C)
	m.draw_rect(Rect2(x0 + 6.0, WATER_Y + 3, 14, 1), Pal.L_C)    # 船身下面透出的水纹
	m.draw_rect(Rect2(x0 + 30.0 + float((t / 500) % 3) * 2.0, WATER_Y + 5, 12, 1), Pal.L_C)
	_draw_ripples(t)

# ------------------------------------------------------------------ 水纹
## 水纹都钉在世界坐标上，船开走以后留在原地慢慢散开：
##   静止时船头船尾各荡开一圈圈横向水纹；划船/航行时船尾一路留下"V"形尾迹（越往后越宽），船越快越宽越长。
## 每一道水纹的透明度都是 半透明 → 不透明 → 半透明，最后散掉。
var _ripples: Array = []
var _wk_prev_x: float = -1.0
var _wk_prev_t: int = 0
var _wk_dist: float = 0.0
var _wk_ring_at: int = 0
var _wk_moved_t: int = -100000
var _wk_ring_k: int = 0
var boat_speed: float = 0.0            # 船的实际速度（像素/秒，平滑过）

func _update_wake(t: int) -> void:
	if _wk_prev_x < 0.0 or t - _wk_prev_t > 400:
		_wk_prev_x = boat_x
		_wk_prev_t = t
		return
	var dt := maxi(1, t - _wk_prev_t)
	var dx := boat_x - _wk_prev_x
	_wk_prev_x = boat_x
	_wk_prev_t = t
	boat_speed = lerpf(boat_speed, absf(dx) / float(dt) * 1000.0, 0.12)
	if absf(dx) > 0.01:
		_wk_moved_t = t
		_wk_dist += absf(dx)
		var dir := 1.0 if dx > 0.0 else -1.0
		var v := boat_speed
		while _wk_dist >= 4.0:
			_wk_dist -= 4.0
			_ripples.append({"k": "wake", "x": (boat_x + 65.0) if dir > 0.0 else (boat_x - 1.0), "y": float(WATER_Y + 4),
					"t0": t, "life": 1100 + int(minf(v, 90.0) * 14.0), "spread": clampf(1.0 + v / 16.0, 1.0, 3.4),
					"len": 4.0 + minf(v / 7.0, 9.0), "dir": dir})
	elif t - _wk_moved_t > 300 and t >= _wk_ring_at:        # 停着：每隔一会儿荡开一圈
		_wk_ring_at = t + 870
		var y := float(WATER_Y + 1 + (_wk_ring_k % 3) * 2)
		_wk_ring_k += 1
		_ripples.append({"k": "ring", "x": boat_x + 2.0, "y": y, "t0": t, "life": 2600, "side": -1.0})
		_ripples.append({"k": "ring", "x": boat_x + 62.0, "y": y, "t0": t, "life": 2600, "side": 1.0})

func _draw_ripples(t: int) -> void:
	var keep: Array = []
	for r in _ripples:
		var age := t - int(r["t0"])
		var life: int = r["life"]
		if age >= life or _ripples.size() > 120:
			continue
		keep.append(r)
		var f := float(age) / float(life)
		var col := Color(Pal.L_W, 0.2 + 0.7 * sin(PI * f))
		if r["k"] == "ring":
			var wd: float = float(r.get("w", 6.0)) + f * float(r.get("w", 6.0)) * 0.6
			var x: float = float(r["x"]) + float(r["side"]) * f * float(r.get("span", 14.0))
			m.draw_rect(Rect2(x if r["side"] > 0.0 else x - wd, float(r["y"]), wd, 1), col)
		else:
			var dir: float = r["dir"]
			var len: float = float(r["len"]) * (0.6 + 0.4 * f)
			var xc: float = float(r["x"]) - dir * f * 10.0
			var x0 := xc if dir < 0.0 else xc - len
			var sp := roundf(float(r["spread"]) * f)
			var y: float = float(r["y"])
			m.draw_rect(Rect2(x0, y - sp, len, 1), col)
			if sp > 0.0:
				m.draw_rect(Rect2(x0, y + sp, len, 1), col)
	_ripples = keep
	_draw_drops(t)

## ---- 浮漂处的水花：圈圈涟漪 + 飞起来又落回水里的小水珠 ----
var _drops: Array = []
var _fx_prev_fs: int = -1
var _fx_dip_up: bool = false
var _fx_wait_ring_at: int = 0
var _fx_retract_t: int = -1

func _bobber_ring(x: float, t: int, span: float, w: float, delay: int = 0, life: int = 1500) -> void:
	for side in [-1.0, 1.0]:
		_ripples.append({"k": "ring", "x": x, "y": float(WATER_Y + 1), "t0": t + delay, "life": life, "side": side, "span": span, "w": w})

func _bobber_drops(p: Vector2, n: int, power: float, t: int) -> void:
	for i in n:
		var ang := randf_range(-PI * 0.88, -PI * 0.12)
		var v := Vector2(cos(ang), sin(ang)) * power * randf_range(0.45, 1.0)
		_drops.append({"p": p + Vector2(randf_range(-2.0, 2.0), 0), "v": v, "t0": t, "big": randf() < 0.35})

func _draw_drops(t: int) -> void:
	var keep: Array = []
	for d in _drops:
		var age := float(t - int(d["t0"])) / 1000.0
		if age < 0.0:
			keep.append(d)
			continue
		var pos: Vector2 = d["p"] + d["v"] * age + Vector2(0, 0.5 * 190.0 * age * age)
		if pos.y > WATER_Y + 1 or age > 1.2:
			continue
		keep.append(d)
		var col: Color = Pal.L_W if int(age * 20.0) % 3 != 0 else Pal.L_C
		m.draw_rect(Rect2(roundf(pos.x), roundf(pos.y), 2 if d["big"] else 1, 2 if d["big"] else 1), col)
	_drops = keep

## 浮漂水面上的各种动静：落水、漂动、咬钩、拉鱼、空军收线时的涟漪和水花。
func _bobber_fx(fs: int, rest: Vector2, t: int) -> void:
	var cx := rest.x + 2.0
	var at := Vector2(cx, float(WATER_Y))
	if fs != _fx_prev_fs:
		match fs:
			Fishing.State.WAITING:
				if _fx_prev_fs == Fishing.State.CASTING:       # 浮漂落水
					_bobber_ring(cx, t, 13.0, 5.0)
					_bobber_ring(cx, t, 9.0, 4.0, 180)
					_bobber_ring(cx, t, 5.0, 3.0, 360)
					_bobber_drops(at, 9, 75.0, t)
				_fx_wait_ring_at = t + 1800
			Fishing.State.HOOKED:                              # 咬钩：猛地往下一拽
				_bobber_ring(cx, t, 15.0, 6.0)
				_bobber_ring(cx, t, 10.0, 5.0, 200)
				_bobber_drops(at, 9, 85.0, t)
			Fishing.State.REELING:                             # 拉鱼：水面炸开一片水花
				_bobber_ring(cx, t, 18.0, 7.0)
				_bobber_drops(at, 12, 105.0, t)
			Fishing.State.TANGLED:                             # 空军：竿一提，浮漂离水
				_bobber_ring(cx, t, 10.0, 5.0)
				_bobber_drops(at, 7, 65.0, t)
		_fx_prev_fs = fs
	if fs == Fishing.State.WAITING and t >= _fx_wait_ring_at:      # 静静漂着时偶尔荡开一圈很小的涟漪
		_bobber_ring(cx, t, 6.0, 3.0, 0, 1900)
		_fx_wait_ring_at = t + 2300 + (t / 7) % 700

## 收杆时浮漂离开水面的那一下。
func _retract_fx(prog: float, t: int) -> void:
	if prog > 0.18 and _fx_retract_t != retract_t0:
		_fx_retract_t = retract_t0
		var r := bobber_rest()
		_bobber_ring(r.x + 2.0, t, 11.0, 5.0)
		_bobber_drops(Vector2(r.x + 2.0, float(WATER_Y)), 8, 70.0, t)

var _fish_colors: Dictionary = {}
func _fish_color(fish_id: String) -> Color:
	if not _fish_colors.has(fish_id):
		var f: Dictionary = m.game.fish_by_id.get(fish_id, {})
		var col := Pal.L_A
		if m.tex.has(f.get("sprite", "")):
			col = m.tex[f["sprite"]].get_image().get_pixel(9, 5)
		_fish_colors[fish_id] = col
	return _fish_colors[fish_id]

const BIRD_HOP_MS := 600
const BIRD_SPOTS := ["basket", "bow", "stern"]

## 鸟最后停在哪儿决定它干什么：鱼篓 = 偷鱼，船头 = 送礼，船尾（小猫面前）= 什么也不做。
## 起点随机，中途换 0~2 次位置，所以看它一开始停哪儿猜不出结果。
func bird_start(kind: String, item: String, t: int) -> void:
	var final: String = {"steal": "basket", "gift": "bow"}.get(kind, "stern")
	var spots: Array = [final]
	for i in randi() % 3:
		var opts: Array = BIRD_SPOTS.filter(func(n): return n != spots[0])
		spots.push_front(opts[randi() % opts.size()])
	bird = {"kind": kind, "item": item, "t0": t, "d": 0.0, "last": t, "spots": spots}

func _bird_spot(name: String, bob_y: float) -> Vector2:
	match name:
		"basket":
			return Vector2(boat_x + 12, bob_y - 18)
		"bow":
			return Vector2(boat_x - 1, bob_y - 27)
	return Vector2(boat_x + 52, bob_y - 7)

## 来访的鸟：飞来 → 停下张望（可能换几个位置）→ 在最后的位置送礼 / 叼走一条鱼 / 什么也不做 → 飞走。
## 鸟的时间按游戏加速走（和游戏里"到点生效"的时刻对得上），不然加速时画面和结算会错开。
func _draw_bird(t: int, bob_y: float) -> void:
	if bird.is_empty():
		return
	bird["d"] = float(bird["d"]) + float(clampi(t - int(bird["last"]), 0, 100)) * maxf(1.0, m.game.time_scale)
	bird["last"] = t
	var d := int(bird["d"])
	var act: int = m.game.bird_act_after_ms()      # 鸟停多久才送礼/偷鱼
	var steal: bool = bird["kind"] == "steal"
	var spots: Array = bird["spots"]
	# 船开动了（划船 / 自动航行）：鸟被惊飞，从它此刻在世界里的位置飞走，不会像贴在船上一样跟着船
	var sailing: bool = m.game.journey.activity() == Journey.Activity.SAIL_OUT or m.game.journey.activity() == Journey.Activity.SAIL_BACK
	if (boat_moving or sailing) and not bird.has("flee"):
		bird["flee"] = d
		bird["from"] = bird.get("pos", _bird_spot(spots[0], bob_y))
		bird["carry"] = d >= act and steal
	if bird.has("flee"):
		var fe := float(d - int(bird["flee"])) / 1800.0
		if fe > 1.0:
			bird = {}
			return
		var fpos: Vector2 = bird["from"] + Vector2(-120.0 * fe, -70.0 * fe - 25.0 * fe * fe)
		m.tex_frame("bird_fly", (fpos + Vector2(-1, 1)).round(), (d / 90) % 2, 2)
		var fitem: Dictionary = m.game.fish_by_id.get(bird["item"], {})
		if bird["carry"] and m.tex.has(fitem.get("sprite", "")):
			m.draw_texture(m.tex[fitem["sprite"]], (fpos + Vector2(-4, 8)).round())
		return
	var hops := spots.size() - 1
	var perch := _bird_spot(spots[hops], bob_y)
	if d > act + 3500:
		bird = {}
		return
	var item: Dictionary = m.game.fish_by_id.get(bird["item"], {}) if steal else m.game.inventory.by_id.get(bird["item"], {})
	var item_tex: String = item.get("sprite", "")
	const ARRIVE := 2500
	if d < ARRIVE:
		var first := _bird_spot(spots[0], bob_y)
		var k := _ease(float(d) / float(ARRIVE))
		var pos := (first + Vector2(170, -70)).lerp(first, k) + Vector2(0, roundf(sin(d / 150.0) * (1.0 - k) * 3.0))
		bird["pos"] = pos
		m.tex_frame("bird_fly", (pos + Vector2(-1, 1)).round(), (d / 110) % 2, 2)
	elif d < act:
		var seg := maxi(1, (act - ARRIVE - hops * BIRD_HOP_MS) / (hops + 1))
		var u := d - ARRIVE
		var idx := mini(u / (seg + BIRD_HOP_MS), hops)
		var within := u - idx * (seg + BIRD_HOP_MS)
		if idx < hops and within >= seg:                    # 换位置：飞过去
			var a := _bird_spot(spots[idx], bob_y)
			var b := _bird_spot(spots[idx + 1], bob_y)
			var k := float(within - seg) / float(BIRD_HOP_MS)
			var pos := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 8.0)
			bird["pos"] = pos
			if b.x > a.x:
				m.tex_frame_flipped("bird_fly", (pos + Vector2(-1, 1)).round(), (d / 90) % 2, 2)
			else:
				m.tex_frame("bird_fly", (pos + Vector2(-1, 1)).round(), (d / 90) % 2, 2)
		else:
			var here := _bird_spot(spots[idx], bob_y)
			bird["pos"] = here
			if (d / 1300) % 3 == 2:
				m.tex_frame_flipped("bird_perch", here, 0, 1)        # 回头张望
			else:
				m.draw_texture(m.tex["bird_perch"], here)
	else:
		var e := float(d - act) / 3500.0
		if not steal and m.tex.has(item_tex) and d < act + 700:       # 东西掉进船里
			var fall := float(d - act) / 700.0
			m.draw_texture(m.tex[item_tex], perch.lerp(Vector2(boat_x + 26, bob_y - 4), fall * fall).round())
		var pos := perch + Vector2(-120.0 * e, -70.0 * e - 25.0 * e * e)
		bird["pos"] = pos
		m.tex_frame("bird_fly", (pos + Vector2(-1, 1)).round(), (d / 100) % 2, 2)
		if steal and m.tex.has(item_tex):                        # 叼着鱼飞走
			m.draw_texture(m.tex[item_tex], (pos + Vector2(-4, 8)).round())

## 天上远远飞过的海鸟（只在白天、不下雨时出现），和云一样随镜头慢慢错位。
func _draw_sky_birds(cam: Vector2, view: Vector2, t: int) -> void:
	var sky: Dictionary = m.game.sky()
	if float(sky["dark"]) > 0.5 or m.game.is_raining():
		return
	for k in 3:
		var dirn := 1.0 if k % 2 == 0 else -1.0
		var span := view.x + 80.0
		var sx := fposmod(float(t) / 1000.0 * (14.0 + k * 5.0) * dirn + k * 173.0 - cam.x * 0.5, span) - 40.0
		var y := cam.y + 30.0 + k * 24.0 + roundf(sin(float(t) / 500.0 + k * 2.0) * 2.0)
		var pos := Vector2(cam.x + sx, y).round()
		if dirn > 0:
			m.tex_frame_flipped("bird_fly", pos, (t / 170 + k) % 2, 2)
		else:
			m.tex_frame("bird_fly", pos, (t / 170 + k) % 2, 2)

## 像素风的实心圆（一行行矩形拼出来，边缘没有抗锯齿）。
func _disc(c: Vector2, r: int, color: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(sqrt(float(r * r - dy * dy)) + 0.5)
		m.draw_rect(Rect2(c.x - half, c.y + dy, half * 2 + 1, 1), color)

func _draw_sky(cam: Vector2, view: Vector2, t: int) -> void:
	var g = m.game
	var sky: Dictionary = g.sky()
	var dark: float = sky["dark"]
	var raining: bool = g.is_raining()
	var overcast: bool = raining or bool(sky["cloudy"])
	var warm: float = float(sky["warm"]) * (0.35 if overcast else 1.0)
	var dawn: bool = sky["dawn"]
	var sky_h := WATER_Y - 26 - cam.y
	var horizon_y := WATER_Y - 20.0
	m.draw_rect(Rect2(cam, view), Pal.L_C)
	# 天空分成一条条色带（像素风的渐变）：白天一色；日出日落越靠近地平线越红越亮；夜里深蓝
	if warm > 0.01 or dark > 0.01:
		var dusk := [Pal.U_A, Pal.U_A.lerp(Pal.L_P, 0.5), Pal.L_P, Pal.L_R.lerp(Pal.L_P, 0.4), Pal.L_F, Pal.L_Y]
		var night := [Pal.U_K, Pal.U_K, Pal.U_K.lerp(Pal.U_B, 0.3), Pal.U_K.lerp(Pal.U_B, 0.5), Pal.U_B.lerp(Pal.U_K, 0.35), Pal.U_B.lerp(Pal.U_K, 0.2)]
		var n := dusk.size()
		for i in n:
			var y0 := cam.y + sky_h * float(i) / n
			var y1 := cam.y + sky_h * float(i + 1) / n
			var c: Color = Pal.L_C.lerp(dusk[i], clampf(warm * 1.05, 0.0, 1.0))
			c = c.lerp(night[i], clampf(dark * 1.1, 0.0, 1.0))
			m.draw_rect(Rect2(cam.x, roundf(y0), view.x, roundf(y1) - roundf(y0) + 1), c)
	var haze := Pal.U_W.lerp(Pal.L_P if dawn else Pal.L_F, clampf(warm, 0.0, 1.0) * 0.7)
	m.draw_rect(Rect2(cam.x, WATER_Y - 26, view.x, 26), haze.lerp(Pal.U_B.lerp(Pal.U_K, 0.3), clampf(dark * 1.1, 0.0, 1.0)))
	# 星星：夜里才有，阴天和下雨看不见；位置固定，闪烁
	if dark > 0.35 and not overcast:
		var star_a := clampf((dark - 0.35) / 0.4, 0.0, 1.0)
		for i in 70:
			var sx := cam.x + fposmod(float(Weather._h(i * 5 + 1) % 4096) / 4096.0 * (view.x + 40.0) - cam.x * 0.05, view.x)
			var sy := cam.y + float(Weather._h(i * 5 + 2) % 4096) / 4096.0 * (sky_h - 12.0)
			var tw := 0.55 + 0.45 * sin(t / (350.0 + (i % 5) * 120.0) + i)
			m.draw_rect(Rect2(roundf(sx), roundf(sy), 1, 1), Color(Pal.U_W, star_a * tw))
			if i % 9 == 0:   # 少数亮星画成小十字
				m.draw_rect(Rect2(roundf(sx) - 1, roundf(sy), 3, 1), Color(Pal.U_W, star_a * tw * 0.5))
				m.draw_rect(Rect2(roundf(sx), roundf(sy) - 1, 1, 3), Color(Pal.U_W, star_a * tw * 0.5))
	if not overcast:
		var amp := clampf(sky_h * 0.8, 40.0, 150.0)
		# 太阳：沿一天里的轨迹走，冬天低、夏天高；日出前和日落后沉到山后
		var su: float = sky["sun_u"]
		if su > -1.0 and su < 2.0:
			var peak: float = clampf(float(sky["sun_peak"]) / 70.0, 0.3, 1.0)
			var u := clampf(su, -0.12, 1.12)
			var sx := cam.x + view.x * lerpf(0.1, 0.9, u)
			var sy: float
			if su >= 0.0 and su <= 1.0:
				sy = horizon_y - amp * peak * sin(PI * u)
			else:
				sy = horizon_y + minf(1.0, absf(su - clampf(su, 0.0, 1.0)) * 8.0) * 22.0
			var sa := 1.0 - clampf(dark * 1.2, 0.0, 1.0) * 0.6
			_disc(Vector2(roundf(sx), roundf(sy)), 15, Color(Pal.L_Y, 0.22 * sa))
			_disc(Vector2(roundf(sx), roundf(sy)), 11, Color(Pal.L_F.lerp(Pal.L_Y, 1.0 - warm), sa))
			_disc(Vector2(roundf(sx), roundf(sy)), 8, Color(Pal.L_Y, sa))
		# 月亮：按月相画亮的那一边；位置按"月亮几点过中天"推（满月整夜都在，新月几乎看不到）
		var mu: float = sky["moon_u"]
		if mu > -1.0 and mu < 2.0:
			var phase: float = sky["moon_phase"]
			var mx := cam.x + view.x * lerpf(0.1, 0.9, clampf(mu, -0.1, 1.1))
			var my: float
			if mu >= 0.0 and mu <= 1.0:
				my = horizon_y - amp * 0.8 * sin(PI * mu)
			else:
				my = horizon_y + 14.0
			var moon_a := clampf(0.25 + dark * 0.9, 0.0, 1.0)     # 白天的月亮很淡
			_moon(Vector2(roundf(mx), roundf(my)), 6, phase, g.lat < 0.0, moon_a)
	# 远景视差：云最慢，山其次；日落时云被烧红，阴天变灰，夜里变暗
	var cloud_tint := Color.WHITE.lerp(Pal.L_R.lerp(Pal.L_F, 0.35), clampf(warm * 1.1, 0.0, 0.85))
	cloud_tint = cloud_tint.lerp(Pal.L_A, 0.45 if bool(sky["cloudy"]) else 0.0)
	cloud_tint = cloud_tint.lerp(Pal.U_A, clampf(dark * 0.8, 0.0, 0.8))
	# 云按"世界编号"取高度：编号随云一起滑过屏幕，不会在循环回绕的那一刻换高度（以前按屏幕里的第几朵取，回绕时云会上下一跳）
	var cloud_base := cam.x * 0.85 - t / 500.0
	var cloud_k0 := floori(cloud_base / 150.0)
	for n in range(cloud_k0 - 1, cloud_k0 + int(view.x / 150) + 3):
		var cx := cam.x + n * 150 - cloud_base
		m.draw_texture(m.tex["cloud"], Vector2(roundf(cx + 20), cam.y + 14 + posmod(n * 37, 23) + maxf(0, view.y - 180) * 0.5), cloud_tint)
		m.draw_texture(m.tex["cloud"], Vector2(roundf(cx + 95), cam.y + 40 + posmod(n * 53, 17) + maxf(0, view.y - 180) * 0.5), cloud_tint)
	var hill_shift := fposmod(cam.x * 0.4, 64.0)
	for i in range(-1, int(view.x / 64) + 2):
		m.draw_texture(m.tex["hills"], Vector2(roundf(cam.x - hill_shift + i * 64), WATER_Y - 22))

## 月亮：先画一圈淡淡的暗面，再画亮的部分。phase 0 新月 / 0.25 上弦 / 0.5 满月 / 0.75 下弦；
## 北半球盈月亮在右边，南半球左右相反（south = true）。
func _moon(c: Vector2, r: int, phase: float, south: bool, alpha: float) -> void:
	_disc(c, r, Color(Pal.U_A, 0.35 * alpha))
	var k := cos(TAU * phase)
	for dy in range(-r, r + 1):
		var half := int(sqrt(float(r * r - dy * dy)) + 0.5)
		var term := roundi(half * (k if phase < 0.5 else -k))      # 明暗分界线的 x
		var x0: int
		var x1: int
		if phase < 0.5:
			x0 = term; x1 = half          # 盈：亮在右边
		else:
			x0 = -half; x1 = term         # 亏：亮在左边
		if south:
			var nx0 := -x1
			x1 = -x0
			x0 = nx0
		if x1 >= x0:
			m.draw_rect(Rect2(c.x + x0, c.y + dy, x1 - x0 + 1, 1), Color(Pal.U_W, alpha))

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
		Journey.Activity.VENDING, Journey.Activity.SOLD_OUT:
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
			m.draw_texture(m.tex[f["sprite"]], Vector2(STALL_X + 29 - (n - 1 - i) * 3, GROUND_Y - 20 - (n - 1 - i) * 3))

## 正走向摊位的顾客（位置在 update 里算好）。
func _draw_customer(t: int) -> void:
	if approach_visible:
		var arrived := approach_x <= STALL_X + 50
		m.tex_frame("villager_%d" % customer_kind, Vector2(approach_x, GROUND_Y - 19), 0 if arrived else (t / 200) % 2, 2)

## 离开的顾客：买到鱼的拎着鱼走；没买成的（小猫被玩家带走了）空手掉头回去。
func _draw_leaving(t: int) -> void:
	var keep: Array = []
	for c in leaving:
		var age: float = float(t - int(c["t0"])) * float(c.get("v", 1.0))      # 加速时离开得也快，免得几位顾客叠在一起
		var x: float = float(c["x0"]) + roundf(age * 0.028)
		if age < 6000.0 and x < STALL_X + 190:
			keep.append(c)
			if m.tex.has(c["fish"]):      # 鱼先画，人在鱼前面
				m.draw_texture(m.tex[c["fish"]], Vector2(x + 6, GROUND_Y - 12))
			m.tex_frame_flipped("villager_%d" % int(c["kind"]), Vector2(x, GROUND_Y - 19), (t / 200) % 2, 2)
	leaving = keep

func _draw_boat_cat(act: int, on_break: bool, now: int, t: int) -> void:
	var frame := (t / 700) % 2
	var pos := cat_pos
	var flip := act == Journey.Activity.SAIL_BACK or (boat_moving and boat_dir < 0)
	if on_break:
		frame = 2 + (t / 1100) % 2
	elif m.game.angry():
		frame = (t / 700) % 2                  # 被鸟偷了鱼：醒着，气鼓鼓
	elif act == Journey.Activity.IDLE_FULL:
		if t - eat_t0 < 1600:
			frame = 2
			pos.y -= 1 if (t / 200) % 2 == 0 else 0
		elif _idle_sleeping(now):
			frame = 2 + (t / 1100) % 2
	elif m.game.fishing.state == Fishing.State.TANGLED and act == Journey.Activity.FISHING:
		frame = 2   # 空军：垂头丧气
	elif t - hop_t0 < 600:
		frame = 2   # 钓到鱼：眯眼开心跳一下
		pos.y -= 2 if t - hop_t0 < 140 else (1 if t - hop_t0 < 280 else 0)
	m.draw_cat(pos, frame, flip)

func _idle_sleeping(now: int) -> bool:
	return (now / 40000) % 2 == 0

const RETRACT_MS := 380

## 划船前的快速收杆：浮漂被提回竿梢，竿子抬起来。
func _draw_retract(t: int) -> void:
	var prog := clampf(float(t - retract_t0) / float(RETRACT_MS), 0.0, 1.0)
	var tip := TIP_WAIT.lerp(TIP_IDLE, prog)
	_retract_fx(prog, t)
	var tip_abs := (cat_pos + tip).round()
	m.pixel_line(cat_pos + HAND, tip_abs, Pal.U_O)
	var b := bobber_rest().lerp(tip_abs + Vector2(-2, 0), prog * prog).round() + Vector2(0, roundf(-6.0 * sin(prog * PI)))
	m.pixel_line(tip_abs, b + Vector2(2, 0), Pal.L_W)
	m.draw_texture(m.tex["bobber"], b)

func _draw_boat_extras(act: int, on_break: bool, now: int, t: int) -> void:
	if on_break:
		m.draw_texture(m.tex["zzz"], cat_pos + Vector2(32, -2 - (t / 500) % 3))
		return
	if m.game.angry() and not boat_moving:
		m.draw_texture(m.tex["anger"], (cat_pos + Vector2(9 + (t / 90) % 2, -12)).round())
		if act == Journey.Activity.IDLE_FULL:
			return
	if t - retract_t0 < RETRACT_MS and not boat_moving:
		_draw_retract(t)
		return
	if boat_moving and (act == Journey.Activity.FISHING or act == Journey.Activity.IDLE_FULL):
		_draw_rowing(boat_dir, t)
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
			if m.game.journey.progress(now) < 0.9:       # 快到了：收起船桨，靠惯性滑过去
				_draw_rowing(-1.0 if act == Journey.Activity.SAIL_BACK else 1.0, t)

## 划桨动画：dir 是船前进的方向（1 向右 / -1 向左）。
func _draw_rowing(dir: float, t: int) -> void:
	# 划桨：桨叶沿一个扁椭圆连续转动，没有突变，所以看起来是顺的。
	#   椭圆下半圈在水面以下 = 划水：桨叶从船头一侧推向船尾一侧，入水溅水花，身后留水纹
	#   椭圆上半圈在水面以上 = 回桨：桨叶贴着水面收回船头一侧（只抬高几个像素）
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
	_bobber_fx(fs, rest, t)
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
		Fishing.State.BAITING:
			tip = TIP_IDLE
		Fishing.State.WAITING:
			tip = TIP_WAIT
			bobber = rest + Vector2(0, (t / 800) % 2)
		Fishing.State.TWITCH:
			# 浮漂动一下：往下点两次，每次点下去溅起一圈小水纹——可能是鱼，也可能只是虚惊一场
			tip = TIP_WAIT + Vector2(0, 1 if sin(prog * TAU * 2.0) > 0.4 else 0)
			var dip := maxf(0.0, sin(prog * TAU * 2.0))
			bobber = rest + Vector2(0, roundf(dip * 3.0))
			if dip > 0.5:
				m.tex_frame("splash", rest + Vector2(-3, 3), 1, 2)
				if not _fx_dip_up:                        # 每点一下水，荡出一圈涟漪、溅几滴水
					_fx_dip_up = true
					_bobber_ring(rest.x + 2.0, t, 8.0, 4.0)
					_bobber_drops(Vector2(rest.x + 2.0, float(WATER_Y)), 4, 45.0, t)
			elif dip < 0.2:
				_fx_dip_up = false
		Fishing.State.TANGLED:
			# 空军：把竿提起来，线缠成一团，头顶冒出一团乱麻
			tip = TIP_WAIT.lerp(TIP_IDLE, clampf(prog * 3.0, 0.0, 1.0))
			if prog < 0.3:
				bobber = (rest.lerp(cat_pos + tip, prog / 0.3)).round()
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
	if fs == Fishing.State.BAITING:
		_draw_baiting(tip_abs, prog)
	if fs == Fishing.State.TANGLED and prog > 0.25:
		m.draw_texture(m.tex["tangle"], (cat_pos + Vector2(11, -7 + roundf(sin(float(t) / 140.0) * 1.0))).round())
	if fs == Fishing.State.SETTLEMENT and m.game.fishing.hooked_size > 0:
		_draw_size_tag(fish_pos, m.game.fishing.hooked_size)
	if t - splash_t0 < 360:
		m.tex_frame("splash", rest + Vector2(-3, 3), 0 if t - splash_t0 < 180 else 1, 2)

## 每次甩钩前的上饵：钩子垂在竿梢下面，小猫把一小团饵从手边送到钩上，装好闪一下。
func _draw_baiting(tip_abs: Vector2, prog: float) -> void:
	var hook := tip_abs + Vector2(0, 9)
	m.pixel_line(tip_abs, hook, Pal.L_W)
	m.draw_rect(Rect2(hook.x - 1, hook.y, 2, 1), Pal.L_A)
	var col: Color = Pal.L_W
	if bait_id == "bait_worm":
		col = Pal.L_P
	elif bait_id == "bait_shrimp":
		col = Pal.L_R
	var from := cat_pos + HAND + Vector2(-3, -3)
	var k := _ease(clampf(prog / 0.6, 0.0, 1.0))
	var pos := from.lerp(hook, k).round()
	m.draw_rect(Rect2(pos.x - 1, pos.y - 1 + (1 if prog < 0.6 and int(prog * 12.0) % 2 == 0 else 0), 3, 3), col)
	m.draw_rect(Rect2(pos.x - 1, pos.y + 1, 3, 1), col.darkened(0.2))
	if prog > 0.6:
		m.tex_frame("sparkle", hook + Vector2(-2, -2), 0 if prog < 0.8 else 1, 2)

## 钓上来的鱼旁边标出大小（厘米）。
func _draw_size_tag(fish_pos: Vector2, size: int) -> void:
	var col: Color = Pal.L_W if float(m.game.sky()["dark"]) > 0.35 else Pal.U_K
	m.text("%dcm" % size, fish_pos + Vector2(2, -9), col)

func _hooked_tex() -> Texture2D:
	if m.game.fishing.hooked_fish == Fishing.CHEST:
		return null      # 宝箱是两帧的图，由 _draw_hooked 单独画
	var hf: String = m.game.fishing.hooked_fish
	if hf.begins_with(Fishing.JUNK_PREFIX):          # 杂物：画物品图标，不是鱼
		var jd: Dictionary = m.game.inventory.by_id.get(hf.substr(Fishing.JUNK_PREFIX.length()), {})
		return m.tex.get(jd.get("sprite", ""), null)
	var f: Dictionary = m.game.fish_by_id.get(hf, {})
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
	"tackle": {"keeper": 1, "wall": "h", "spots": [[150, "shop"], [118, "quest"]]},
	"tailor": {"keeper": 0, "wall": "w", "spots": [[128, "hats"], [172, "quest"]]},
	"shipyard": {"keeper": 2, "wall": "w", "spots": [[150, "boats"]]},
	"home": {"keeper": -1, "wall": "w", "spots": [[46, "storage"], [84, "dex"], [106, "piggy"], [128, "stats"], [172, "bed"]]},
}
const SPOT_HINT := {"exit": "空格键出门", "quest": "空格键和店主聊聊", "shop": "空格键看货", "hats": "空格键看衣帽", "dex": "空格键看图鉴", "stats": "空格键看统计", "bed": "空格键小睡", "storage": "空格键开仓库", "piggy": "空格键存取钱", "boats": "空格键升级船"}

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
			m.draw_texture(m.tex["noren_tackle"], Vector2(ox + ROOM_DOOR_X - 9, fy - 29))
			m.draw_texture(m.tex["shelf_tackle"], Vector2(ox + 76, fy - 62))
			m.draw_texture(m.tex["wall_bobbers"], Vector2(ox + 138, fy - 72))
			m.draw_texture(m.tex["specimen_0"], Vector2(ox + 184, fy - 68))
			m.draw_texture(m.tex["specimen_1"], Vector2(ox + 184, fy - 52))
			m.draw_texture(m.tex["lantern"], Vector2(ox + 112 + roundf(sin(float(t) / 900.0)), fy - ROOM_H))
			m.draw_texture(m.tex["barrel_rods"], Vector2(ox + 62, fy - 26))
			m.draw_texture(m.tex["barrel_rods"], Vector2(ox + 94, fy - 26))
			m.draw_texture(m.tex["barrel_rods"], Vector2(ox + 184, fy - 26))
			m.draw_texture(m.tex["barrel_rods"], Vector2(ox + 199, fy - 24))
			m.draw_texture(m.tex["bait_jars"], Vector2(ox + 112, fy - 14))
			keeper_pos = Vector2(ox + 156, fy - 31)      # 店主站在柜台后的踏板上，露出上半身
			_draw_keeper(int(room["keeper"]), keeper_pos, ox)
			m.draw_texture(m.tex["counter"], Vector2(ox + 134, fy - 17))
			m.draw_texture(m.tex["fish_bass"], Vector2(ox + 135, fy - 26))
		"tailor":
			m.draw_texture(m.tex["noren_tailor"], Vector2(ox + ROOM_DOOR_X - 9, fy - 29))
			m.draw_texture(m.tex["wall_hats"], Vector2(ox + 56, fy - 64))
			m.draw_texture(m.tex["wall_clothes"], Vector2(ox + 100, fy - 66))
			m.draw_texture(m.tex["lantern"], Vector2(ox + 96 + roundf(sin(float(t) / 900.0)), fy - ROOM_H))
			m.draw_texture(m.tex["hat_stand"], Vector2(ox + 54, fy - 28))
			m.draw_texture(m.tex["mannequin"], Vector2(ox + 74, fy - 30))
			m.draw_texture(m.tex["mannequin"], Vector2(ox + 94, fy - 30))
			m.draw_texture(m.tex["fabric_rolls"], Vector2(ox + 192, fy - 16))
			m.draw_texture(m.tex["shelf_hats"], Vector2(ox + 150, fy - 62))
			m.draw_texture(m.tex["mirror"], Vector2(ox + 120, fy - 32))
			m.draw_texture(m.tex["rug"], Vector2(ox + 108, fy + 3))
			keeper_pos = Vector2(ox + 176, fy - 21)
			_draw_keeper(int(room["keeper"]), keeper_pos, ox)
		"shipyard":
			m.draw_texture(m.tex["noren_ship"], Vector2(ox + ROOM_DOOR_X - 9, fy - 29))
			m.draw_texture(m.tex["blueprint"], Vector2(ox + 54, fy - 62))
			m.draw_texture(m.tex["blueprint"], Vector2(ox + 80, fy - 60))
			m.draw_texture(m.tex["anchor"], Vector2(ox + 110, fy - 50))
			m.draw_rect(Rect2(ox + 172, fy - 38, 36, 3), Pal.L_O)
			m.draw_texture(m.tex["ship_model"], Vector2(ox + 177, fy - 56))
			m.draw_texture(m.tex["lantern"], Vector2(ox + 134 + roundf(sin(float(t) / 900.0)), fy - ROOM_H))
			m.draw_texture(m.tex["barrel_rods"], Vector2(ox + 190, fy - 26))
			m.draw_texture(m.tex["barrel_rods"], Vector2(ox + 62, fy - 26))
			keeper_pos = Vector2(ox + 156, fy - 31)
			_draw_keeper(int(room["keeper"]), keeper_pos, ox)
			m.draw_texture(m.tex["counter"], Vector2(ox + 134, fy - 17))
		"home":
			m.draw_texture(m.tex["storage"], Vector2(ox + 35, fy - 18))
			m.draw_texture(m.tex["bookshelf"], Vector2(ox + 70, fy - 39))
			m.draw_texture(m.tex["calendar"], Vector2(ox + 120, fy - 50))
			m.draw_texture(m.tex["bed"], Vector2(ox + 160, fy - 19))
			m.draw_texture(m.tex["piggy"], Vector2(ox + 99, fy - 11))      # 存钱罐
			m.draw_texture(m.tex["rug"], Vector2(ox + 96, fy + 3))
	if kind == "tackle" or kind == "tailor":
		_draw_room_customer(kind, ox, fy, keeper_pos, t)
	# 小猫
	var pos := Vector2(ox + roundf(room_x), fy - 30)
	if napping and kind == "home":
		m.draw_cat(Vector2(ox + 162, fy - 34), 2 + (t / 700) % 2, false)
		var zy := (t / 400) % 3
		m.label("Z", Vector2(ox + 150 + zy * 3, fy - 52 - zy * 4), Pal.U_K)
	else:
		var flip := room_flip
		if not room_moving and keeper_pos != Vector2.INF and room_spot(kind) == "quest":
			flip = keeper_pos.x + 8.0 < ox + room_x + 16.0      # 站在任务点：小猫面对店主
		m.draw_cat(pos, (4 + (t / 180) % 2) if room_moving else 4, flip)
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


## 店主：始终朝着小猫（小猫在店主右边就转向右，否则朝左）。
func _draw_keeper(kind: int, pos: Vector2, ox: float) -> void:
	if ox + room_x + 16.0 > pos.x + 8.0:
		m.tex_frame_flipped("villager_%d" % kind, pos, 0, 2)
	else:
		m.tex_frame("villager_%d" % kind, pos, 0, 2)


## 店里偶尔进来一位顾客：从门口走到柜台前买东西（硬币飞给店主、商品飞回来），再走出去。
## 一个周期 30 秒，只有前 11 秒有人；谁来（兔子/小熊/狐狸）按周期序号轮换。
const CUSTOMER_CYCLE := 30000
func _draw_room_customer(kind: String, ox: float, fy: float, keeper_pos: Vector2, t: int) -> void:
	var cyc := t / CUSTOMER_CYCLE
	var ph := t % CUSTOMER_CYCLE
	if ph > 11000 or (cyc + (0 if kind == "tackle" else 1)) % 2 == 1:
		return                                  # 两间店错开，隔一个周期才来一位
	var door_x := ox + ROOM_DOOR_X - 8.0
	var stand_x := ox + (118.0 if kind == "tackle" else 150.0)
	var x := stand_x
	var moving := false
	if ph < 3000:
		x = lerpf(door_x, stand_x, float(ph) / 3000.0)
		moving = true
	elif ph > 8000:
		x = lerpf(stand_x, door_x, float(ph - 8000) / 3000.0)
		moving = true
	var name := "villager_%d" % ((cyc / 2) % 3)
	var pos := Vector2(roundf(x), fy - 21)
	var frame := (t / 200) % 2 if moving else 0
	var facing_right := ph < 8000                # 进来和买东西时朝店主，出门时朝门
	if facing_right:
		m.tex_frame_flipped(name, pos, frame, 2)
	else:
		m.tex_frame(name, pos, frame, 2)
	if ph >= 3000 and ph < 8000:                 # 买东西：硬币飞去柜台，商品飞回来
		var k := float(ph - 3000) / 5000.0
		var hand := Vector2(pos.x + 14, pos.y + 10)
		var counter := Vector2(keeper_pos.x - 4, fy - 20)
		if k < 0.45:
			m.draw_texture(m.tex["coin"], hand.lerp(counter, k / 0.45).round())
		elif k < 0.55:
			m.tex_frame("sparkle", counter + Vector2(0, -6), (t / 120) % 2, 2)
		else:
			var item := "bobber" if kind == "tackle" else "ico_fruit"
			m.draw_texture(m.tex[item], counter.lerp(hand, (k - 0.55) / 0.45).round())
