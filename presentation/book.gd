extends RefCounted
## 图鉴册（只在完整窗口里有，迷你窗不显示）：三页——图鉴、最高纪录、统计。
## 统计页左边是当月每天完成的番茄数折线图，右边是选中那一天每个小时的专注分钟柱状图。
## 和 bag.gd 一样借用主节点 m 的绘制方法，坐标是界面坐标。

const Pal := preload("res://presentation/palette.gd")

const PAGES := ["图鉴", "最高纪录", "统计", "任务"]
const NPC_NAMES := {"tackle": "渔具店", "tailor": "裁缝铺"}

var open: bool = false
var page: int = 0
var dex_page: int = 0
var sel_y: int = 2026
var sel_m: int = 1
var sel_d: int = 1
var m

func _init(main) -> void:
	m = main

func rect() -> Rect2:
	var top_left: Vector2 = Vector2(4, 33) - m.ui_off
	return Rect2(top_left, Vector2(m.view.x - 8, m.view.y - 39))

func _close_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 13, r.position.y + 2, 11, 11)

func _tab_rect(i: int) -> Rect2:
	var r := rect()
	return Rect2(r.position.x + 5 + i * 50, r.position.y + 2, 48, 11)

func open_page(i: int) -> void:
	open = true
	page = clampi(i, 0, PAGES.size() - 1)
	var today: String = m.clock.today_key()
	sel_y = int(today.substr(0, 4))
	sel_m = int(today.substr(5, 2))
	sel_d = int(today.substr(8, 2))

static func days_in_month(y: int, mo: int) -> int:
	if mo == 2:
		return 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28
	return 30 if mo in [4, 6, 9, 11] else 31

func _key(y: int, mo: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, mo, d]

func _today_ymd() -> Array:
	var t: String = m.clock.today_key()
	return [int(t.substr(0, 4)), int(t.substr(5, 2)), int(t.substr(8, 2))]

## 选中的日期换到前/后 delta 天（不会越过今天）。
func shift_day(delta: int) -> void:
	var y := sel_y
	var mo := sel_m
	var d := sel_d + delta
	while d < 1:
		mo -= 1
		if mo < 1:
			mo = 12
			y -= 1
		d += days_in_month(y, mo)
	while d > days_in_month(y, mo):
		d -= days_in_month(y, mo)
		mo += 1
		if mo > 12:
			mo = 1
			y += 1
	var t := _today_ymd()
	if _key(y, mo, d) > _key(t[0], t[1], t[2]):
		return
	sel_y = y
	sel_m = mo
	sel_d = d

func shift_month(delta: int) -> void:
	var y := sel_y
	var mo := sel_m + delta
	if mo < 1:
		mo = 12
		y -= 1
	elif mo > 12:
		mo = 1
		y += 1
	var t := _today_ymd()
	if y * 12 + mo > int(t[0]) * 12 + int(t[1]):
		return
	sel_y = y
	sel_m = mo
	sel_d = mini(sel_d, days_in_month(y, mo))
	if _key(y, mo, sel_d) > _key(t[0], t[1], t[2]):
		sel_d = int(t[2])

# ------------------------------------------------------------------ 图鉴翻页
## 一页放几行（每行 3 条）：窗口矮就少放，保证最后一行不会压到边框。
func dex_rows() -> int:
	return maxi(1, int((rect().size.y - 20.0 - 15.0) / 38.0))

func dex_per_page() -> int:
	return dex_rows() * 3

func dex_pages() -> int:
	return maxi(1, int(ceil(float(m.game.fish_list.size()) / float(dex_per_page()))))

func dex_turn(delta: int) -> void:
	dex_page = clampi(dex_page + delta, 0, dex_pages() - 1)

func _dex_prev_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 52, r.end.y - 14, 11, 11)

func _dex_next_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 15, r.end.y - 14, 11, 11)

# ------------------------------------------------------------------ 输入
func _chart_rect() -> Rect2:
	var r := rect()
	return Rect2(r.position.x + 12, r.position.y + 40, r.size.x * 0.5 - 22, clampf(r.size.y - 52.0, 24.0, 66.0))

func _prev_month_rect() -> Rect2:
	var r := rect()
	return Rect2(r.position.x + 6, r.position.y + 17, 11, 11)

func _next_month_rect() -> Rect2:
	var r := rect()
	return Rect2(r.position.x + 52, r.position.y + 17, 11, 11)

func _prev_day_rect() -> Rect2:
	var r := rect()
	return Rect2(r.position.x + r.size.x * 0.5 + 8, r.position.y + 17, 11, 11)

func _next_day_rect() -> Rect2:
	var r := rect()
	return Rect2(r.position.x + r.size.x * 0.5 + 46, r.position.y + 17, 11, 11)

func click(p: Vector2) -> bool:
	if not open or not rect().has_point(p):
		return false
	if _close_rect().has_point(p):
		open = false
		m.play("click")
		m.on_panel_toggled()
		return true
	for i in PAGES.size():
		if _tab_rect(i).has_point(p):
			if page != i:
				page = i
				m.play("click")
			return true
	if page == 0:
		if _dex_prev_rect().has_point(p):
			dex_turn(-1)
			m.play("click")
		elif _dex_next_rect().has_point(p):
			dex_turn(1)
			m.play("click")
	if page == 2:
		if _prev_month_rect().has_point(p):
			shift_month(-1)
			m.play("click")
		elif _next_month_rect().has_point(p):
			shift_month(1)
			m.play("click")
		elif _prev_day_rect().has_point(p):
			shift_day(-1)
			m.play("click")
		elif _next_day_rect().has_point(p):
			shift_day(1)
			m.play("click")
		else:
			var cr := _chart_rect()
			if Rect2(cr.position.x - 3, cr.position.y - 4, cr.size.x + 6, cr.size.y + 8).has_point(p):
				var n := days_in_month(sel_y, sel_m)
				var d := clampi(int(round((p.x - cr.position.x) / cr.size.x * float(n - 1))) + 1, 1, n)
				var t := _today_ymd()
				if _key(sel_y, sel_m, d) <= _key(t[0], t[1], t[2]):
					sel_d = d
					m.play("click")
	return true

func key(keycode: int) -> bool:
	match keycode:
		KEY_TAB:
			page = (page + 1) % PAGES.size()
		KEY_1:
			page = 0
		KEY_2:
			page = 1
		KEY_3:
			page = 2
		KEY_4:
			page = 3
		KEY_LEFT, KEY_A:
			if page == 2:
				shift_day(-1)
			elif page == 0:
				dex_turn(-1)
		KEY_RIGHT, KEY_D:
			if page == 2:
				shift_day(1)
			elif page == 0:
				dex_turn(1)
		KEY_UP, KEY_W:
			if page == 2:
				shift_month(-1)
		KEY_DOWN, KEY_S:
			if page == 2:
				shift_month(1)
		_:
			return false
	return true

# ------------------------------------------------------------------ 绘制
func draw() -> void:
	if not open:
		return
	var r := rect()
	m.draw_rect(r, Pal.U_A)
	m.draw_rect(r.grow(-1), Pal.U_K)
	for i in PAGES.size():
		var tr := _tab_rect(i)
		m.draw_rect(tr, Pal.L_Y if page == i else Pal.U_A)
		m.draw_rect(tr.grow(-1), Pal.L_A if page == i else Pal.U_K)
		m.label_centered(PAGES[i], tr.position.x + tr.size.x / 2, tr.position.y, Pal.U_K if page == i else Pal.L_A)
	m.tex_frame("btn_close", _close_rect().position, 0, 2)
	match page:
		0: _draw_dex(r)
		1: _draw_records(r)
		2: _draw_stats(r)
		3: _draw_quests(r)

## 任务页：进行中的任务在前（店名、每项要求 有几个/要几个、奖励），已完成的灰着排在后面。
func _draw_quests(r: Rect2) -> void:
	var g = m.game
	var y := r.position.y + 19
	var x := r.position.x + 8
	var shown := 0
	for pass_state in ["active", "done"]:
		for q in g._quest_cfg_list():
			var id := str(q["id"])
			if g.quest_state(id) != pass_state:
				continue
			shown += 1
			var active: bool = pass_state == "active"
			m.label(NPC_NAMES.get(str(q.get("npc", "")), ""), Vector2(x, y), Pal.L_Y if active else Pal.L_A)
			m.label("进行中" if active else "已完成", Vector2(x + 52, y), Pal.L_G if not active else Pal.L_W)
			y += 11.0
			if active:
				for n in g.quest_needs(id):
					var it: Dictionary = g.inventory.by_id.get(str(n[0]), {})
					var enough: bool = int(n[1]) >= int(n[2])
					m.label(str(it.get("name", "")), Vector2(x + 6, y), Pal.L_W)
					m.text_right("%d/%d" % [int(n[1]), int(n[2])], x + 82, y + 3, Pal.L_G if enough else Pal.L_R)
					y += 10.0
			m.label("奖励", Vector2(x + 6, y), Pal.L_A)
			m.label(str(q.get("reward_name", "")), Vector2(x + 30, y), Pal.L_W if active else Pal.L_A)
			y += 14.0
	if shown == 0:
		m.label("暂无任务", Vector2(x, y), Pal.L_A)
		m.label("打开漂流瓶看看", Vector2(x, y + 12), Pal.L_A)

func _draw_dex(r: Rect2) -> void:
	var g = m.game
	var counts: Dictionary = g.state.stats["fish_counts"]
	var best: Dictionary = g.state.stats["fish_best"]
	var cw := (r.size.x - 12.0) / 3.0
	dex_page = clampi(dex_page, 0, dex_pages() - 1)
	var per := dex_per_page()
	for k in per:
		var i := dex_page * per + k
		if i >= g.fish_list.size():
			break
		var f: Dictionary = g.fish_list[i]
		var c := r.position + Vector2(6.0 + (k % 3) * cw, 20.0 + (k / 3) * 38.0)
		var n := int(counts.get(f["id"], 0))
		m.draw_rect(Rect2(c, Vector2(cw - 4, 35)), Pal.U_A)
		m.draw_rect(Rect2(c + Vector2(1, 1), Vector2(cw - 6, 33)), Pal.U_B if n > 0 else Pal.U_K)
		m.draw_texture(m.tex[f["sprite"]], c + Vector2(5, 11), Color.WHITE if n > 0 else Color(0.25, 0.25, 0.35))
		m.label(f["name"] if n > 0 else "？？？", c + Vector2(28, 5), Pal.L_W if n > 0 else Pal.L_A)
		if n > 0:
			m.text("x%d" % n, c + Vector2(28, 19), Pal.L_W)
			var b := int(best.get(f["id"], 0))
			if b > 0:
				m.text("%dcm" % b, c + Vector2(28, 26), Pal.L_Y)
	m.label("共钓到", r.position + Vector2(6, r.size.y - 13), Pal.L_A)
	m.text(str(int(g.state.stats["total_fish"])), r.position + Vector2(40, r.size.y - 10), Pal.L_W)
	if dex_pages() > 1:
		m.tex_frame("btn_left", _dex_prev_rect().position, 0 if dex_page > 0 else 1, 2)
		m.tex_frame("btn_right", _dex_next_rect().position, 0 if dex_page < dex_pages() - 1 else 1, 2)
		var ps := "%d/%d" % [dex_page + 1, dex_pages()]
		m.text(ps, Vector2(r.end.x - 33.0 - ps.length() * 2.0, r.end.y - 11), Pal.L_W)

func _draw_records(r: Rect2) -> void:
	var g = m.game
	var best: Dictionary = g.state.stats["fish_best"]
	var x := r.position.x + 8
	var y := r.position.y + 19
	m.label("钓过的鱼", Vector2(x, y), Pal.L_A)
	var biggest := ""
	var biggest_cm := 0
	for i in g.fish_list.size():
		var f: Dictionary = g.fish_list[i]
		var b := int(best.get(f["id"], 0))
		var ry: float = y + 13.0 + i * 11.0
		if b > 0:
			m.label(f["name"], Vector2(x, ry), Pal.L_W)
			m.text_right("%dcm" % b, x + 84, ry + 3, Pal.L_Y)
			if b > biggest_cm:
				biggest_cm = b
				biggest = f["name"]
		else:
			m.label("？？？", Vector2(x, ry), Pal.U_A)
	var x2 := r.position.x + r.size.x * 0.5 + 6
	var daily: Dictionary = g.state.stats["daily"]
	var busiest := 0
	for k in daily:
		busiest = maxi(busiest, int(daily[k]))
	var rows := [
		["共钓到", str(int(g.state.stats["total_fish"]))],
		["宝箱", str(int(g.state.stats.get("chests", 0)))],
		["空军", str(int(g.state.stats.get("empty_casts", 0)))],
		["累计", str(int(g.state.stats["total_pomodoros"]))],
		["最忙的一天", str(busiest)],
	]
	m.label("最高纪录", Vector2(x2, y), Pal.L_A)
	for i in rows.size():
		var ry: float = y + 13.0 + i * 13.0
		m.label(rows[i][0], Vector2(x2, ry), Pal.L_W)
		m.text_right(rows[i][1], x2 + 96, ry + 3, Pal.L_Y)
	var by: float = y + 13.0 + rows.size() * 13.0 + 3.0
	m.label("最大的鱼", Vector2(x2, by), Pal.L_W)
	if biggest_cm > 0:
		m.label(biggest, Vector2(x2, by + 12), Pal.L_Y)
		m.text_right("%dcm" % biggest_cm, x2 + 96, by + 15, Pal.L_Y)
	else:
		m.label("暂无记录", Vector2(x2, by + 12), Pal.U_A)

func _draw_stats(r: Rect2) -> void:
	var g = m.game
	var daily: Dictionary = g.state.stats["daily"]
	var t := _today_ymd()
	var n := days_in_month(sel_y, sel_m)
	var cr := _chart_rect()
	# ---- 左：当月每天的番茄数折线图 ----
	m.tex_frame("btn_left", _prev_month_rect().position, 0, 2)
	m.text("%04d-%02d" % [sel_y, sel_m], Vector2(r.position.x + 22, r.position.y + 21), Pal.L_W)
	m.tex_frame("btn_right", _next_month_rect().position, 0, 2)
	m.label("每月番茄", Vector2(r.position.x + 68, r.position.y + 18), Pal.L_A)
	var counts: Array = []
	var peak := 4
	for d in range(1, n + 1):
		var c := int(daily.get(_key(sel_y, sel_m, d), 0))
		counts.append(c)
		peak = maxi(peak, c)
	m.draw_rect(Rect2(cr.position.x, cr.end.y, cr.size.x, 1), Pal.U_A)
	m.draw_rect(Rect2(cr.position.x, cr.position.y, 1, cr.size.y), Pal.U_A)
	for g_i in 3:                                         # 横向参考线
		var gy := cr.end.y - cr.size.y * float(g_i + 1) / 3.0
		m.draw_rect(Rect2(cr.position.x + 1, gy, cr.size.x - 1, 1), Color(Pal.U_A, 0.45))
	m.text(str(peak), Vector2(cr.position.x - 8 - (str(peak).length() - 1) * 4, cr.position.y - 2), Pal.L_A)
	var sx := cr.position.x + cr.size.x * float(sel_d - 1) / float(n - 1)
	m.draw_rect(Rect2(sx, cr.position.y, 1, cr.size.y), Color(Pal.L_Y, 0.5))
	var prev := Vector2.INF
	for i in n:
		if _key(sel_y, sel_m, i + 1) > _key(t[0], t[1], t[2]):
			break
		var p := Vector2(roundf(cr.position.x + cr.size.x * float(i) / float(n - 1)), roundf(cr.end.y - cr.size.y * float(counts[i]) / float(peak)))
		if prev != Vector2.INF:
			m.pixel_line(prev, p, Pal.L_C)
		prev = p
	for i in n:
		if _key(sel_y, sel_m, i + 1) > _key(t[0], t[1], t[2]):
			break
		var p := Vector2(roundf(cr.position.x + cr.size.x * float(i) / float(n - 1)), roundf(cr.end.y - cr.size.y * float(counts[i]) / float(peak)))
		var on := i + 1 == sel_d
		m.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Pal.L_Y if on else Pal.L_W)
	for d in [1, 10, 20, n]:
		var lx := cr.position.x + cr.size.x * float(d - 1) / float(n - 1)
		var s := str(d)
		m.text(s, Vector2(lx - s.length() * 2, cr.end.y + 3), Pal.L_A)
	# ---- 右：选中那天每小时的专注分钟 ----
	var rx := r.position.x + r.size.x * 0.5
	var hours: Array = g.focus_hours_live(_key(sel_y, sel_m, sel_d))
	var total := 0
	for h in 24:
		total += int(hours[h])
	m.tex_frame("btn_left", _prev_day_rect().position, 0, 2)
	m.text("%02d-%02d" % [sel_m, sel_d], Vector2(rx + 23, r.position.y + 21), Pal.L_W)
	m.tex_frame("btn_right", _next_day_rect().position, 0, 2)
	m.label("当日专注", Vector2(rx + 62, r.position.y + 18), Pal.L_A)
	var by := cr.end.y
	var bx := rx + 12.0
	var bh := cr.size.y
	var pitch := clampi(int((r.end.x - 6.0 - bx) / 24.0), 2, 5)         # 窗口窄时柱子挤一点，保证 24 小时都画得下
	m.draw_rect(Rect2(bx - 1, by, 24 * pitch + 1, 1), Pal.U_A)
	m.draw_rect(Rect2(bx - 1, by - bh, 1, bh), Pal.U_A)
	for h in 24:
		var mins := float(hours[h]) / 60.0
		var hh := int(round(minf(mins, 60.0) * bh / 60.0))
		if mins > 0.0:
			hh = maxi(hh, 1)
			m.draw_rect(Rect2(bx + h * pitch, by - hh, maxi(1, pitch - 1), hh), Pal.L_R if (h == int(m.clock.local_s() % 86400 / 3600) and _key(sel_y, sel_m, sel_d) == m.clock.today_key()) else Pal.L_G)
	for h in [0, 6, 12, 18]:
		var s := str(h)
		m.text(s, Vector2(bx + h * pitch, by + 3), Pal.L_A)
	m.text("60", Vector2(bx - 12, by - bh - 2), Pal.L_A)
	if total <= 0:
		var has_old := int(daily.get(_key(sel_y, sel_m, sel_d), 0)) > 0
		m.label("当天没有小时记录" if has_old else "这天还没有专注", Vector2(bx + 14, by - bh / 2 - 5), Pal.L_A)
	m.text(str(int(round(total / 60.0))), Vector2(rx + 14, by + 12), Pal.L_Y)
	m.label("分钟", Vector2(rx + 14 + str(int(round(total / 60.0))).length() * 4 + 3, by + 9), Pal.L_A)
