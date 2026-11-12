extends RefCounted
## 菜单面板（商店 / 图鉴 / 统计 / 设置）。打开时盖在猫和船上方。
## 自己不是节点：绘制时借用主节点 m 的 draw_* 方法，所以只能在 m._draw() 里调用 draw()。

const Pal := preload("res://presentation/palette.gd")

const RECT := Rect2(15, 28, 98, 66)
const TABS := ["商店", "图鉴", "统计", "设置"]
const UPGRADES := [
	["rod", "鱼竿", "自由挂机钓得更快"],
	["bait", "鱼饵", "稀有鱼更容易上钩"],
	["basket", "鱼篓", "鱼篓容量加二"],
]
const SETTINGS := [
	["focus_min", "专注"], ["short_break_min", "短休"], ["long_break_min", "长休"], ["pixel_scale", "大小"],
]
const ROW_Y := 44
const ROW_H := 12

var open: bool = false
var tab: int = 0
var hover := Vector2(-1, -1)
var m   # 主节点 (presentation/main.gd)

func _init(main) -> void:
	m = main

func _tab_rect(i: int) -> Rect2:
	return Rect2(17 + i * 23, 30, 23, 12)

func _plus_rect(row: int, x: float = 99) -> Rect2:
	return Rect2(x, ROW_Y + row * ROW_H - 1, 11, 11)

# ------------------------------------------------------------------ 输入
## 处理点击。返回 true 表示点在了菜单上（主节点不应再把它当成拖动）。
func click(p: Vector2) -> bool:
	if not open or not RECT.has_point(p):
		return false
	for i in TABS.size():
		if _tab_rect(i).has_point(p):
			tab = i
			return true
	match tab:
		0:
			for i in UPGRADES.size():
				if _plus_rect(i).has_point(p):
					m.game.buy_upgrade(UPGRADES[i][0])
		3:
			for i in SETTINGS.size():
				var dir := 0
				if _plus_rect(i, 58).has_point(p):
					dir = -1
				elif _plus_rect(i, 99).has_point(p):
					dir = 1
				if dir != 0:
					if SETTINGS[i][0] == "pixel_scale":
						m.change_pixel_scale(dir)
					else:
						m.game.adjust_duration(SETTINGS[i][0], dir)
	return true

# ------------------------------------------------------------------ 绘制
func draw() -> void:
	if not open:
		return
	m.draw_rect(RECT, Pal.U_A)
	m.draw_rect(RECT.grow(-1), Pal.U_K)
	for i in TABS.size():
		var r := _tab_rect(i)
		m.label(TABS[i], r.position + Vector2(2, 0), Pal.L_W if i == tab else Pal.L_A)
		if i == tab:
			m.draw_rect(Rect2(r.position.x + 2, 41, 19, 1), Pal.L_R)
	match tab:
		0: _draw_shop()
		1: _draw_dex()
		2: _draw_stats()
		3: _draw_settings()

func _draw_shop() -> void:
	var g = m.game
	var desc := "金币可以升级装备"
	for i in UPGRADES.size():
		var id: String = UPGRADES[i][0]
		var y: int = ROW_Y + i * ROW_H
		if Rect2(RECT.position.x, y - 1, RECT.size.x, ROW_H).has_point(hover):
			desc = UPGRADES[i][2]
		m.label(UPGRADES[i][1], Vector2(19, y), Pal.L_W)
		var lv: int = g.upgrades.level(g.state, id)
		for k in g.upgrades.max_level(id):
			m.tex_frame("pips", Vector2(42 + k * 5, y + 3), 1 if k < lv else 0, 2)
		var cost: int = g.upgrades.next_cost(g.state, id)
		if cost < 0:
			m.label("已满级", Vector2(72, y), Pal.L_Y)
		else:
			var ok: bool = g.upgrades.can_buy(g.state, id)
			m.text_right(str(cost), 96, y + 3, Pal.L_Y if ok else Pal.L_A)
			m.tex_frame("btn_plus", _plus_rect(i).position, 0, 2, Color.WHITE if ok else Color(1, 1, 1, 0.35))
	m.label(desc, Vector2(19, 81), Pal.L_A)

func _draw_dex() -> void:
	var g = m.game
	var counts: Dictionary = g.state.stats["fish_counts"]
	for i in g.fish_list.size():
		var f: Dictionary = g.fish_list[i]
		var y: int = ROW_Y + i * 13
		var n := int(counts.get(f["id"], 0))
		m.draw_texture(m.tex[f["sprite"]], Vector2(18, y - 1), Color.WHITE if n > 0 else Color(0.25, 0.25, 0.35))
		if n > 0:
			m.label(f["name"], Vector2(39, y), Pal.L_W)
			m.text("x%d" % n, Vector2(72, y + 3), Pal.L_W)
			m.text_right(str(int(f["price"])), 110, y + 3, Pal.L_Y)
		else:
			m.label("？？？", Vector2(39, y), Pal.L_A)
	m.label("共钓到", Vector2(19, 82), Pal.L_A)
	m.text(str(int(g.state.stats["total_fish"])), Vector2(52, 85), Pal.L_W)

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
		var key: String = SETTINGS[i][0]
		var y: int = ROW_Y + i * ROW_H
		m.label(SETTINGS[i][1], Vector2(19, y), Pal.L_W)
		m.tex_frame("btn_minus", _plus_rect(i, 58).position, 0, 2)
		m.tex_frame("btn_plus", _plus_rect(i, 99).position, 0, 2)
		var s := ("x%d" % int(g.state.settings["pixel_scale"])) if key == "pixel_scale" else str(g.duration(key))
		m.text(s, Vector2(84 - s.length() * 2, y + 3), Pal.L_W)
