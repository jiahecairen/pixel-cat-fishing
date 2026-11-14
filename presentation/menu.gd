extends RefCounted
## 菜单面板（商店 / 图鉴 / 统计 / 设置）。打开时盖在猫和船上方。
## 自己不是节点：绘制时借用主节点 m 的 draw_* 方法，所以只能在 m._draw() 里调用 draw()。

const Pal := preload("res://presentation/palette.gd")

const RECT := Rect2(15, 28, 98, 68)
const BOOK_NAMES := {"tackle": "渔具店", "tailor": "裁缝铺"}
const TABS := ["商店", "图鉴", "统计", "设置", "状态", "任务"]
const UPGRADES := [
	["rod", "鱼竿", "自由挂机钓得更快"],
	["bait", "鱼饵", "稀有鱼更容易上钩"],
	["basket", "鱼篓", "鱼篓容量加二"],
]
const SETTINGS := [["focus_min", "专注"], ["short_break_min", "短休"], ["long_break_min", "长休"]]
## 第 4 行放两个"点一下换一档"的设置：[键, 标签, 标签x, 数值x, 按钮x]
const CYCLES := [["pixel_scale", "大小", 19, 40, 50], ["sfx_volume", "音效", 66, 87, 99]]
## 第 5 行：开关 [键, 标签, 标签x, 状态x, 按钮x]
const TOGGLES := [["real_weather", "真实天气", 19, 66, 99]]
const CLOSE_RECT := Rect2(100, 30, 11, 11)   # 面板右上角的关闭按钮
const ROW_Y := 44
const ROW_H := 12
const SET_ROW_Y := 43      # 设置页有 5 行，行距收紧到 10
const SET_ROW_H := 10

var open: bool = false
var tab: int = 0
var shop_page: int = 0    # 商店：0 装备升级，1 鱼饵
var hover := Vector2(-1, -1)
var m   # 主节点 (presentation/main.gd)

func _init(main) -> void:
	m = main

func _tab_rect(i: int) -> Rect2:
	return Rect2(17 + i * 23, 30, 23, 12)

## 面板范围：完整窗口里状态页高一点（钱写全了要占位置，"钓到"另起一行）。
func _panel_rect() -> Rect2:
	if tab == 4 and not m.mini:
		return Rect2(RECT.position, RECT.size + Vector2(0, 11))
	return RECT

func _book_btn_rect() -> Rect2:      # 状态页标题右边：任务、图鉴两个文字按钮（没有边框）
	return Rect2(68, 31, 24, 10)

func _quest_btn_rect() -> Rect2:
	return Rect2(42, 31, 24, 10)

func _shop_tab_rect(i: int) -> Rect2:
	return Rect2(44 + i * 24, 31, 22, 10)

func _plus_rect(row: int, x: float = 99) -> Rect2:
	return Rect2(x, ROW_Y + row * ROW_H - 1, 11, 11)

func _set_rect(row: int, x: float = 99) -> Rect2:
	return Rect2(x, SET_ROW_Y + row * SET_ROW_H - 1, 11, 11)

# ------------------------------------------------------------------ 输入
## 处理点击。返回 true 表示点在了菜单上（主节点不应再把它当成拖动）。
func click(p: Vector2) -> bool:
	if not open or not _panel_rect().has_point(p):
		return false
	if CLOSE_RECT.has_point(p):
		open = false
		m.play("click")
		m.on_panel_toggled()
		return true
	# 面板一次只显示一页：商店/图鉴/统计要走进镇上对应的房子才能打开，设置从面板上的齿轮按钮打开
	match tab:
		0:
			for i in 2:
				if _shop_tab_rect(i).has_point(p):
					if shop_page != i:
						shop_page = i
						m.play("click")
					return true
			if shop_page == 1:
				var baits: Array = m.game.shop_baits()
				for i in baits.size():
					if _plus_rect(i).has_point(p):
						m.play("buy" if m.game.buy_bait(baits[i]) else "deny")
				return true
			for i in UPGRADES.size():
				if _plus_rect(i).has_point(p):
					m.play("buy" if m.game.buy_upgrade(UPGRADES[i][0]) else "deny")
		4:
			if _book_btn_rect().has_point(p):
				m.play("click")
				if m.mini:
					tab = 1                  # 迷你窗用小面板里的图鉴
				else:
					m.open_book(0)
			elif _quest_btn_rect().has_point(p):
				m.play("click")
				if m.mini:
					tab = 5
				else:
					m.open_book(3)
		3:
			for i in SETTINGS.size():
				var dir := 0
				if _set_rect(i, 58).has_point(p):
					dir = -1
				elif _set_rect(i, 99).has_point(p):
					dir = 1
				if dir != 0:
					m.game.adjust_duration(SETTINGS[i][0], dir)
					m.play("click")
			for c in CYCLES:
				if _set_rect(3, c[4]).has_point(p):
					m.cycle_setting(c[0])
					m.play("click")
			for c in TOGGLES:
				if _set_rect(4, c[4]).has_point(p):
					m.cycle_setting(c[0])
					m.play("click")
	return true

# ------------------------------------------------------------------ 绘制
func draw() -> void:
	if not open:
		return
	m.draw_rect(_panel_rect(), Pal.U_A)
	m.draw_rect(_panel_rect().grow(-1), Pal.U_K)
	var r := _tab_rect(0)
	m.label(TABS[tab], r.position + Vector2(2, 0), Pal.L_W)
	m.draw_rect(Rect2(r.position.x + 2, 41, 19, 1), Pal.L_R)
	m.tex_frame("btn_close", CLOSE_RECT.position, 0, 2)
	match tab:
		0: _draw_shop()
		1: _draw_dex()
		2: _draw_stats()
		3: _draw_settings()
		4: _draw_status()
		5: _draw_quests()

func _draw_shop() -> void:
	var g = m.game
	for i in 2:
		var tr := _shop_tab_rect(i)
		m.draw_rect(tr, Pal.L_Y if shop_page == i else Pal.U_A)
		m.draw_rect(tr.grow(-1), Pal.L_A if shop_page == i else Pal.U_K)
		m.label_centered("装备" if i == 0 else "鱼饵", tr.position.x + tr.size.x / 2, tr.position.y - 1, Pal.U_K if shop_page == i else Pal.L_A)
	if shop_page == 1:
		_draw_bait_shop()
		return
	var desc := "金币可以升级装备"
	for i in UPGRADES.size():
		var id: String = UPGRADES[i][0]
		var y: int = ROW_Y + i * ROW_H
		if Rect2(RECT.position.x, y - 1, RECT.size.x, ROW_H).has_point(hover):
			desc = UPGRADES[i][2]
		m.label(UPGRADES[i][1], Vector2(19, y), Pal.L_W)
		var lv: int = g.upgrades.level(g.state, id)
		var cost: int = g.upgrades.next_cost(g.state, id)
		# 价格写全（几金几银几铜）可能很宽：放不下的行不画等级点，免得叠在一起
		if cost < 0 or 98.0 - m.money_full_width(cost) >= 42.0 + float(g.upgrades.max_level(id)) * 5.0 + 3.0:
			for k in g.upgrades.max_level(id):
				m.tex_frame("pips", Vector2(42 + k * 5, y + 3), 1 if k < lv else 0, 2)
		if cost < 0:
			m.label("已满级", Vector2(72, y), Pal.L_Y)
		else:
			var ok: bool = g.upgrades.can_buy(g.state, id)
			m.money_full_right(cost, 98, y + 3, Pal.L_Y if ok else Pal.L_A)
			m.tex_frame("btn_plus", _plus_rect(i).position, 0, 2, Color.WHITE if ok else Color(1, 1, 1, 0.35))
	m.label(desc, Vector2(19, 81), Pal.L_A)

## 渔具店的鱼饵：名字、手里有几个、价格和买按钮。没解锁的整行变灰，按钮位置换成小锁，鼠标放上去提示"未解锁"。
func _draw_bait_shop() -> void:
	var g = m.game
	var baits: Array = g.shop_baits()
	var desc := "买来的鱼饵每竿用 1 个"
	for i in baits.size():
		var id: String = baits[i]
		var d: Dictionary = g.inventory.by_id[id]
		var y: int = ROW_Y + i * ROW_H
		var open: bool = g.bait_unlocked(id)
		var row := Rect2(RECT.position.x, y - 1, RECT.size.x, ROW_H)
		if row.has_point(hover):
			desc = String(d.get("desc", "")) if open else "未解锁"
		m.label(String(d["name"]), Vector2(19, y), Pal.L_W if open else Pal.U_A)
		if open:
			m.text("x%d" % g.inventory.count(g.state, id), Vector2(44, y + 3), Pal.L_A)
			var ok: bool = g.can_buy_bait(id)
			m.money_full_right(int(d["price"]), 98, y + 3, Pal.L_Y if ok else Pal.L_A)
			m.tex_frame("btn_plus", _plus_rect(i).position, 0, 2, Color.WHITE if ok else Color(1, 1, 1, 0.35))
		else:
			m.draw_texture(m.tex["lock"], Vector2(99, y), Color(1, 1, 1, 0.8))
	m.label(desc, Vector2(19, 81), Pal.L_A)

func _draw_dex() -> void:
	# 九宫格：每格一条鱼的图和钓到的数量；鼠标放上去，底部显示名字和价格
	var g = m.game
	var counts: Dictionary = g.state.stats["fish_counts"]
	var tip := ""
	var tip_price := 0
	var tip_count := 0
	for i in g.fish_list.size():
		var f: Dictionary = g.fish_list[i]
		var cx: int = 17 + (i % 3) * 32
		var cy: int = ROW_Y + (i / 3) * 14
		var n := int(counts.get(f["id"], 0))
		m.draw_texture(m.tex[f["sprite"]], Vector2(cx, cy), Color.WHITE if n > 0 else Color(0.25, 0.25, 0.35))
		if Rect2(cx - 1, cy - 1, 31, 14).has_point(hover):
			tip = f["name"] if n > 0 else "？？？"
			tip_price = int(g.state.stats["fish_best"].get(f["id"], 0)) if n > 0 else 0      # 这里放这种鱼钓到过的最大尺寸
			tip_count = n
	if tip != "":
		m.label(tip, Vector2(19, 82), Pal.L_W)
		if tip_count > 0:
			m.text("x%d" % tip_count, Vector2(60, 85), Pal.L_W)      # 鼠标放上去才显示数量，免得和旁边的鱼图叠在一起
		if tip_price > 0:
			m.text_right("%dcm" % tip_price, 110, 85, Pal.L_Y)         # 这种鱼钓到过的最大尺寸
	else:
		m.label("共钓到", Vector2(19, 82), Pal.L_A)
		m.text(str(int(g.state.stats["total_fish"])), Vector2(52, 85), Pal.L_W)
		m.label("宝箱", Vector2(74, 82), Pal.L_A)
		m.text(str(int(g.state.stats.get("chests", 0))), Vector2(97, 85), Pal.L_Y)

func _draw_stats() -> void:
	var g = m.game
	var daily: Dictionary = g.state.stats["daily"]
	var days: Array = []
	var peak := 4
	for i in 7:
		var n := int(daily.get(m.clock.day_key(6 - i), 0))
		days.append(n)
		peak = maxi(peak, n)
	m.label("今日", Vector2(19, ROW_Y), Pal.L_W)
	m.draw_texture(m.tex["tomato"], Vector2(40, ROW_Y - 1))
	m.text(str(days[6]), Vector2(52, ROW_Y + 3), Pal.L_W)
	m.label("累计", Vector2(68, ROW_Y), Pal.L_W)
	m.text(str(int(g.state.stats["total_pomodoros"])), Vector2(90, ROW_Y + 3), Pal.L_W)
	var base_y := 80
	m.draw_rect(Rect2(19, base_y, 88, 1), Pal.U_A)
	for i in 7:
		var x := 22 + i * 12
		var h := int(round(days[i] * 16.0 / peak))
		if days[i] > 0:
			h = maxi(h, 1)
			m.draw_rect(Rect2(x, base_y - h, 8, h), Pal.L_R if i == 6 else Pal.L_A)
			var s := str(days[i])
			m.text(s, Vector2(x + 4 - s.length() * 2, base_y - h - 6), Pal.L_W)
	m.label("近七日", Vector2(19, 82), Pal.L_A)

func _draw_settings() -> void:
	var g = m.game
	for i in SETTINGS.size():
		var y: int = SET_ROW_Y + i * SET_ROW_H
		m.label(SETTINGS[i][1], Vector2(19, y), Pal.L_W)
		m.tex_frame("btn_minus", _set_rect(i, 58).position, 0, 2)
		m.tex_frame("btn_plus", _set_rect(i, 99).position, 0, 2)
		var s := str(g.duration(SETTINGS[i][0]))
		m.text(s, Vector2(84 - s.length() * 2, y + 3), Pal.L_W)
	var y4: int = SET_ROW_Y + 3 * SET_ROW_H
	for c in CYCLES:
		m.label(c[1], Vector2(c[2], y4), Pal.L_W)
		var v := int(g.state.settings.get(c[0], 0))
		m.text(("x%d" % v) if c[0] == "pixel_scale" else str(v), Vector2(c[3], y4 + 3), Pal.L_W)
		m.tex_frame("btn_plus", _set_rect(3, c[4]).position, 0, 2)
	var y5: int = SET_ROW_Y + 4 * SET_ROW_H
	for c in TOGGLES:
		m.label(c[1], Vector2(c[2], y5), Pal.L_W)
		var on := int(g.state.settings.get(c[0], 0)) == 1
		m.label("开" if on else "关", Vector2(c[3], y5), Pal.L_G if on else Pal.L_A)
		m.tex_frame("btn_plus", _set_rect(4, c[4]).position, 0, 2)

## 小猫状态：左边是小猫，右边装备栏（鱼竿、鱼线、鱼钩、鱼饵），底下一行金币、钓到的鱼、完成的番茄。
## 没有血量、攻击力这类数值——这是个钓鱼游戏。
const EQUIP := [["鱼竿", "rod"], ["鱼线", "line"], ["鱼钩", "hook"]]

func _draw_status() -> void:
	var g = m.game
	var qr := _quest_btn_rect()
	m.label_centered("任务", qr.position.x + qr.size.x / 2, qr.position.y - 1, Pal.L_Y)
	var br := _book_btn_rect()
	m.label_centered("图鉴", br.position.x + br.size.x / 2, br.position.y - 1, Pal.L_Y)
	m.draw_rect(Rect2(17, 42, 34, 34), Pal.U_A)
	m.draw_rect(Rect2(18, 43, 32, 32), Pal.U_B)
	m.draw_cat(Vector2(18, 44), 0)
	for i in EQUIP.size():                         # 直接写装备名，不加"鱼竿/鱼线/鱼钩"前缀
		m.label(g.equipment_name(EQUIP[i][1]), Vector2(56, 43 + i * 10), Pal.L_W)
	var bid: String = g.state.equipped_bait       # 装上的饵；没装就是面团（无限量）
	if bid == "" or not g.inventory.by_id.has(bid):
		m.label("面团", Vector2(56, 73), Pal.L_W)
	else:
		var nm := String(g.inventory.by_id[bid]["name"])
		m.label(nm, Vector2(56, 73), Pal.L_Y)
		m.text("x%d" % g.inventory.count(g.state, bid), Vector2(56 + m.label_width(nm) + 3, 76), Pal.L_W)
	m.draw_rect(Rect2(17, 84, 94, 1), Pal.U_A)
	m.draw_money_full(g.state.wallet_gold, Vector2(19, 85), Pal.L_Y)
	var fish_x: float = 19.0 if not m.mini else 19.0 + m.money_full_width(g.state.wallet_gold) + 5.0
	var fish_y: float = 96.0 if not m.mini else 85.0
	if not m.mini or fish_x + 32.0 <= 110.0:      # 迷你窗里钱写得太宽就不显示"钓到"（图鉴里有）
		m.label("钓到", Vector2(fish_x, fish_y), Pal.L_A)
		m.text(str(int(g.state.stats["total_fish"])), Vector2(fish_x + 21.0, fish_y + 3.0), Pal.L_W)


## 迷你窗里的任务页：进行中的任务和每项要求（有几个/要几个），最多 4 行。
func _draw_quests() -> void:
	var g = m.game
	var y := 44
	var rows := 0
	for q in g._quest_cfg_list():
		var id := str(q["id"])
		if g.quest_state(id) != "active" or rows >= 4:
			continue
		m.label(BOOK_NAMES.get(str(q.get("npc", "")), ""), Vector2(19, y), Pal.L_Y)
		m.label(str(q.get("reward_name", "")), Vector2(62, y), Pal.L_A)
		y += 10
		rows += 1
		for n in g.quest_needs(id):
			if rows >= 4:
				break
			var it: Dictionary = g.inventory.by_id.get(str(n[0]), {})
			var enough: bool = int(n[1]) >= int(n[2])
			m.label(str(it.get("name", "")), Vector2(25, y), Pal.L_W)
			m.text_right("%d/%d" % [int(n[1]), int(n[2])], 100, y + 3, Pal.L_G if enough else Pal.L_R)
			y += 10
			rows += 1
	if rows == 0:
		m.label("暂无任务", Vector2(19, 46), Pal.L_A)
