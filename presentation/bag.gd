extends RefCounted
## 物品栏面板。全画面里占据画面大部分；迷你悬浮窗里是缩小版（格子更小更少）。
## 和 menu.gd 一样借用主节点 m 的绘制方法，坐标是界面坐标。

const Pal := preload("res://presentation/palette.gd")

var open: bool = false
var wh: bool = false      # 在家里仓库打开的：多了"身上 / 仓库"两页，按钮变成存入 / 取出
var tab: int = 0          # 仓库模式下：0 = 身上，1 = 仓库
var sel: int = 0          # 选中的是"手里有的物品"列表里的第几个
var m

func _init(main) -> void:
	m = main

# ---- 布局：全部从面板矩形推出来，两种视图共用一套代码 ----
func rect() -> Rect2:
	if m.mini:
		return Rect2(15, 28, 110, 66)
	# 左右各留 4 像素，上面留给 HUD，下面留 6 像素
	var top_left: Vector2 = Vector2(4, 33) - m.ui_off
	return Rect2(top_left, Vector2(m.view.x - 8, m.view.y - 39))

func _step() -> int:
	return 19 if m.mini else 26

func _top() -> int:
	return (15 if wh else 3) if m.mini else 16

func _rows() -> int:
	return 2 if m.mini else 3

func _cols() -> int:
	return maxi(1, int((rect().size.x - 8 - (14 if m.mini else 0)) / _step()))

func _slot_pos(i: int) -> Vector2:
	var r := rect()
	return r.position + Vector2(4 + (i % _cols()) * _step(), _top() + (i / _cols()) * _step())

func _close_rect() -> Rect2:
	var r := rect()
	return Rect2(r.end.x - 13, r.position.y + 2, 11, 11)

func _detail_y() -> float:
	return rect().position.y + _top() + _rows() * _step() + (1 if m.mini else 4)

func _use_rect() -> Rect2:
	var r := rect()
	if m.mini:
		return Rect2(r.end.x - 31, _detail_y(), 28, 12)
	return Rect2(r.end.x - 46, _detail_y() + 4, 38, 13)

func _owned() -> Array:
	if wh and tab == 1:
		return m.game.inventory.owned_w(m.game.state)
	return m.game.inventory.owned(m.game.state)

func _cnt(id: String) -> int:
	if wh and tab == 1:
		return m.game.inventory.count_w(m.game.state, id)
	return m.game.inventory.count(m.game.state, id)

func _tab_rect(i: int) -> Rect2:
	var r := rect()
	return Rect2(r.position.x + (46 if not m.mini else 4) + i * 34, r.position.y + 2, 32, 11)

func _all_rect() -> Rect2:
	var u := _use_rect()
	return Rect2(u.position.x - u.size.x - 3, u.position.y, u.size.x, u.size.y)

func open_warehouse() -> void:
	open = true
	wh = true
	tab = 0
	sel = 0

func switch_tab() -> void:
	tab = 1 - tab
	sel = 0
	m.play("click")

## 仓库里搬东西：存入 / 取出 1 个，或整堆。
func move_selected(all: bool) -> void:
	var owned := _owned()
	if sel >= owned.size():
		m.play("deny")
		return
	var id: String = owned[sel]
	var n: int = m.game.stash_item(id, all) if tab == 0 else m.game.fetch_item(id, all)
	if n <= 0:
		m.play("deny")
		return
	m.play("buy")
	m.log.write("stash" if tab == 0 else "fetch", {"item": id, "n": n})
	sel = clampi(sel, 0, maxi(0, _owned().size() - 1))

func toggle() -> void:
	wh = false
	tab = 0
	open = not open
	sel = clampi(sel, 0, maxi(0, _owned().size() - 1))

# ------------------------------------------------------------------ 输入
func click(p: Vector2) -> bool:
	if not open or not rect().has_point(p):
		return false
	if _close_rect().has_point(p):
		open = false
		wh = false
		m.play("click")
		m.on_panel_toggled()
		return true
	if wh:
		for i in 2:
			if _tab_rect(i).has_point(p):
				if tab != i:
					switch_tab()
				return true
	var owned := _owned()
	for i in mini(owned.size(), _cols() * _rows()):
		if Rect2(_slot_pos(i), Vector2(_step() - 2, _step() - 2)).has_point(p):
			sel = i
			m.play("click")
			return true
	if wh:
		if _use_rect().has_point(p):
			move_selected(false)
		elif _all_rect().has_point(p):
			move_selected(true)
	elif _use_rect().has_point(p):
		use_selected()
	return true

## 方向键移动选中格，返回是否处理了这个按键。
func key(keycode: int) -> bool:
	var n := _owned().size()
	match keycode:
		KEY_LEFT, KEY_A:
			sel = maxi(0, sel - 1)
		KEY_RIGHT, KEY_D:
			sel = mini(maxi(0, n - 1), sel + 1)
		KEY_UP, KEY_W:
			if sel - _cols() >= 0:
				sel -= _cols()
		KEY_DOWN, KEY_S:
			if sel + _cols() < n:
				sel += _cols()
		KEY_SPACE, KEY_ENTER, KEY_E:
			if wh:
				move_selected(false)
			else:
				use_selected()
		_:
			return false
	return true

func use_selected() -> void:
	var owned := _owned()
	if sel >= owned.size():
		m.play("deny")
		return
	var id: String = owned[sel]
	var res: Dictionary = m.game.use_item(id)
	if not res["ok"]:
		m.play("deny")
		return
	m.log.write("use_item", {"item": id, "gold": res["gold"]})
	m.play("coin" if res["gold"] > 0 else "buy")
	if res["gold"] > 0:
		gain_text = "+%d" % int(res["gold"])
		gain_t0 = Time.get_ticks_msec()
	sel = clampi(sel, 0, maxi(0, _owned().size() - 1))

var gain_text: String = ""      # 刚用物品得到的金币，在面板里闪一下
var gain_t0: int = -100000

# ------------------------------------------------------------------ 绘制
func draw() -> void:
	if not open:
		return
	var g = m.game
	var r := rect()
	var step := _step()
	var size := step - 2
	m.draw_rect(r, Pal.U_A)
	m.draw_rect(r.grow(-1), Pal.U_K)
	if not m.mini:
		m.label("仓库" if wh else "物品栏", r.position + Vector2(5, 3), Pal.L_W)
		m.draw_rect(Rect2(r.position.x + 5, r.position.y + 14, 29, 1), Pal.L_R)
	if wh:
		for i in 2:
			var tr := _tab_rect(i)
			m.draw_rect(tr, Pal.L_Y if tab == i else Pal.U_A)
			m.draw_rect(tr.grow(-1), Pal.L_A if tab == i else Pal.U_K)
			m.label_centered("身上" if i == 0 else "仓库", tr.position.x + tr.size.x / 2, tr.position.y + 0, Pal.U_K if tab == i else Pal.L_A)
	m.tex_frame("btn_close", _close_rect().position, 0, 2)
	var owned := _owned()
	var cells := _cols() * _rows()
	for i in cells:
		var p := _slot_pos(i)
		# 格子：选中的描金边
		m.draw_rect(Rect2(p, Vector2(size, size)), Pal.L_Y if (i == sel and i < owned.size()) else Pal.U_A)
		m.draw_rect(Rect2(p + Vector2(1, 1), Vector2(size - 2, size - 2)), Pal.U_K)
		m.draw_rect(Rect2(p + Vector2(2, 2), Vector2(size - 4, size - 4)), Pal.L_A)
		if i < owned.size():
			var d: Dictionary = g.inventory.by_id[owned[i]]
			m.draw_texture(m.tex[d["sprite"]], p + Vector2((size - 16) / 2, (size - 16) / 2))
			var n: int = _cnt(owned[i])
			if n > 1:
				var s := str(n)
				m.draw_rect(Rect2(p.x + size - s.length() * 4 - 2, p.y + size - 7, s.length() * 4 + 1, 6), Pal.U_K)
				m.text(s, Vector2(p.x + size - s.length() * 4 - 1, p.y + size - 6), Pal.L_W)
	var dy := _detail_y()
	if owned.is_empty():
		m.label("空空如也", Vector2(r.position.x + 5, dy), Pal.L_A)
		if not m.mini and not wh:
			m.label("去钓宝箱吧", Vector2(r.position.x + 5, dy + 11), Pal.L_A)
		return
	var id: String = owned[clampi(sel, 0, owned.size() - 1)]
	var def: Dictionary = g.inventory.by_id[id]
	var can: bool = g.inventory.can_use(g.state, id)
	var usable: bool = str(def.get("use", "")) != ""
	var tx := r.position.x + 5
	if not m.mini:
		m.draw_texture(m.tex[def["sprite"]], Vector2(tx, dy + 2))
		tx += 20
	m.label(def["name"], Vector2(tx, dy), Pal.L_W)
	m.label(def.get("desc", ""), Vector2(tx, dy + 11), Pal.L_A)
	# 生效中的效果
	var status := ""
	if id == "lucky_bait" and g.lucky_active():
		var secs := int(ceil(g.lucky_remaining_ms() / 1000.0))
		status = "%02d:%02d" % [secs / 60, secs % 60]
	elif id == "bell" and int(g.state.effects["bell_sales"]) > 0:
		status = "x%d" % int(g.state.effects["bell_sales"])
	if not m.mini:
		var need: int = g.inventory.need(id)
		if need > 1:
			m.text("%d/%d" % [_cnt(id), need], Vector2(tx, dy + 24), Pal.L_Y if can else Pal.L_A)
		if status != "":
			m.label("生效中", Vector2(tx + (30 if need > 1 else 0), dy + 21), Pal.L_G)
			m.text(status, Vector2(tx + (30 if need > 1 else 0) + 32, dy + 24), Pal.L_G)
	elif status != "":
		m.text(status, Vector2(tx + m.label_width(def["name"]) + 3, dy + 3), Pal.L_G)
	if wh:
		var bu := [[_use_rect(), "存入" if tab == 0 else "取出"], [_all_rect(), "全部"]]
		for b in bu:
			var br: Rect2 = b[0]
			m.draw_rect(br, Pal.L_G)
			m.draw_rect(Rect2(br.position.x, br.end.y - 2, br.size.x, 2), Pal.U_G)
			m.label_centered(b[1], br.position.x + br.size.x / 2, br.position.y + (0 if m.mini else 1), Pal.U_K)
	elif usable:
		var u := _use_rect()
		m.draw_rect(u, Pal.L_G if can else Pal.U_A)
		m.draw_rect(Rect2(u.position.x, u.end.y - 2, u.size.x, 2), Pal.U_G if can else Pal.U_K)
		m.label_centered("装上" if str(g.inventory.by_id[id].get("use", "")) == "bait" else "使用", u.position.x + u.size.x / 2, u.position.y + (0 if m.mini else 1), Pal.U_K if can else Pal.L_A)
	var t := Time.get_ticks_msec()
	if t - gain_t0 < 1800 and gain_text != "":
		var gp := Vector2(_use_rect().position.x - 4 - gain_text.length() * 4 - 10, _use_rect().position.y + 2 - (t - gain_t0) / 300)
		m.draw_texture(m.tex["coin"], gp + Vector2(0, -2))
		m.text(gain_text, gp + Vector2(11, 0), Pal.L_Y)
