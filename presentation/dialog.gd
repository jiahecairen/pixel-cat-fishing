extends RefCounted
## 对话框系统。两种样子：
##   think（图一）：黑底，说话的人在左边，右上角一张场景小图，下面是深色对话框——小猫自己想事情、旁白用。
##   talk（图二）：左右两个人站在场景前，说话的亮着，没说话的灰蒙蒙；米色对话框，名字牌在说话的人那一侧。
## 对话内容在 data/dialogs.json：每段对话有若干节点，节点可以带选项（选项能设标记、能按标记显示/隐藏）。
## 文字用运行时的像素字体现画（dyn_text），所以对话内容不用进图集。
##
## 节点字段：
##   who      说话的人：cat / keeper / tavern / mole ... ；空 = 旁白（think 样式）
##   mode     可选，覆盖这段对话的样式（think / talk）
##   text     一句话；也可以是数组，点一下翻一句
##   scene    think 样式右上角的场景图（贴图名）
##   set      进入这个节点时设的标记 {名字: 数值}
##   next     下一个节点；空 = 结束
##   choices  选项 [{text, next, set, if:[条件], once:true}]；条件 "x" = 标记 x > 0，"!x" = 标记 x == 0
##   action   对话结束后交给主界面做的事（open_quest / open_repair / open_tavern ...）

const Pal := preload("res://presentation/palette.gd")
const CHAR_MS := 32
const MAX_CHOICES := 5

var m
var open: bool = false
var data: Dictionary = {}
var _d: Dictionary = {}
var _id: String = ""
var _node: String = ""
var _page: int = 0
var _t0: int = 0
var _sel: int = 0
var _pending_action: String = ""
var last_action: String = ""       # 对话结束后，主界面来取：要不要接着做什么

func _init(main) -> void:
	m = main
	var f := FileAccess.open("res://data/dialogs.json", FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			data = parsed

func has_dialog(id: String) -> bool:
	return data.has(id)

func start(id: String) -> bool:
	if not data.has(id):
		return false
	_d = data[id]
	_id = id
	_goto(str(_d.get("start", "start")))
	open = true
	last_action = ""
	return true

func close() -> void:
	open = false
	m.on_panel_toggled()

# ------------------------------------------------------------------ 节点
func _nodes() -> Dictionary:
	return _d.get("nodes", {})

func _cur() -> Dictionary:
	return _nodes().get(_node, {})

func _goto(id: String) -> void:
	if id == "" or not _nodes().has(id):
		_finish()
		return
	_node = id
	_page = 0
	_sel = 0
	_t0 = Time.get_ticks_msec()
	var sets: Dictionary = _cur().get("set", {})
	for k in sets:
		m.game.state.story[str(k)] = int(sets[k])
	m.game.state.revision += 1
	m.game.dirty = true
	if str(_cur().get("action", "")) != "":
		_pending_action = str(_cur()["action"])

func _finish() -> void:
	last_action = _pending_action
	_pending_action = ""
	open = false
	m.on_panel_toggled()

func _lines() -> Array:
	var t = _cur().get("text", "")
	return t if t is Array else [str(t)]

func _text() -> String:
	var l := _lines()
	return str(l[clampi(_page, 0, maxi(0, l.size() - 1))]) if not l.is_empty() else ""

func _cond_ok(conds: Array) -> bool:
	for c in conds:
		var k := str(c)
		if k.begins_with("!"):
			if int(m.game.state.story.get(k.substr(1), 0)) > 0:
				return false
		elif int(m.game.state.story.get(k, 0)) <= 0:
			return false
	return true

func _choices() -> Array:
	var out: Array = []
	for c in _cur().get("choices", []):
		if _cond_ok(c.get("if", [])):
			out.append(c)
	return out

func _typed() -> int:
	return int(float(Time.get_ticks_msec() - _t0) / float(CHAR_MS))

func _typing() -> bool:
	return _typed() < _text().length()

func _last_page() -> bool:
	return _page >= _lines().size() - 1

## 点一下 / 空格：打字没打完就补全；还有下一句就翻页；有选项就确认选项；否则去下一个节点。
func advance() -> void:
	if _typing():
		_t0 = Time.get_ticks_msec() - _text().length() * CHAR_MS
		return
	if not _last_page():
		_page += 1
		_t0 = Time.get_ticks_msec()
		m.play("click")
		return
	var ch := _choices()
	if not ch.is_empty():
		choose(_sel)
		return
	m.play("click")
	_goto(str(_cur().get("next", "")))

func choose(i: int) -> void:
	var ch := _choices()
	if i < 0 or i >= ch.size():
		return
	var c: Dictionary = ch[i]
	m.play("click")
	var sets: Dictionary = c.get("set", {})
	for k in sets:
		m.game.state.story[str(k)] = int(sets[k])
	if bool(c.get("once", false)):
		m.game.state.story["said_%s_%d" % [_node, i]] = 1
	_goto(str(c.get("next", "")))

# ------------------------------------------------------------------ 输入
func _frame() -> Rect2:
	return m.big_rect()

func _box() -> Rect2:
	var r := _frame()
	return Rect2(r.position.x + 6, r.end.y - 62, r.size.x - 12, 56)

func _choice_rects() -> Array:
	var ch := _choices()
	var b := _box()
	var out: Array = []
	var shown := mini(ch.size(), MAX_CHOICES)
	var first := clampi(_sel - MAX_CHOICES + 1, 0, maxi(0, ch.size() - MAX_CHOICES))
	var y := b.position.y - 4.0 - float(shown) * 13.0
	for i in ch.size():
		var vis := i >= first and i < first + MAX_CHOICES
		out.append(Rect2(b.position.x + 78, y + float(i - first) * 13.0, b.size.x - 150, 12) if vis else Rect2(-999, -999, 0, 0))
	return out

func _skip_rect() -> Rect2:
	var r := _frame()
	return Rect2(r.end.x - 34, r.position.y + 3, 30, 11)

func click(p: Vector2) -> bool:
	if not open:
		return false
	if _skip_rect().has_point(p):
		_pending_action = ""
		m.play("click")
		_finish()
		return true
	if not _typing() and _last_page():
		var rs := _choice_rects()
		for i in rs.size():
			if (rs[i] as Rect2).has_point(p) and (rs[i] as Rect2).size.x > 0:
				_sel = i
				choose(i)
				return true
		if not rs.is_empty():
			return true
	advance()
	return true

func key(keycode: int) -> bool:
	if not open:
		return false
	match keycode:
		KEY_UP, KEY_W:
			_sel = maxi(0, _sel - 1)
		KEY_DOWN, KEY_S:
			_sel = mini(maxi(0, _choices().size() - 1), _sel + 1)
		KEY_SPACE, KEY_ENTER, KEY_E:
			advance()
		KEY_ESCAPE:
			_pending_action = ""
			_finish()
		_:
			return true
	return true

# ------------------------------------------------------------------ 绘制
func _who_name(who: String) -> String:
	if who == "cat":
		return str(m.game.state.cat_name)
	return str(_d.get("names", {}).get(who, ""))

func _portrait(who: String, pos: Vector2, scale: float, lit: bool, flip: bool) -> void:
	var tint := Color.WHITE if lit else Color(0.5, 0.52, 0.62)
	var sc: float = 2.0 if who == "cat" else 3.0
	var xf := Transform2D(Vector2(sc * (-1.0 if flip else 1.0), 0), Vector2(0, sc), pos + m.ui_off)
	m.draw_set_transform_matrix(xf)
	if who == "cat":
		m.cat_tint = tint
		m.draw_cat(Vector2(-32 if flip else 0, 0), 0, false)
		m.cat_tint = Color.WHITE
	else:
		var tex_name := "villager_%d" % int(_d.get("faces", {}).get(who, 1))
		if m.tex.has(tex_name):
			m.tex_frame(tex_name, Vector2(-16 if flip else 0, 0), 0, 2, tint)
	m.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(0, 1), m.ui_off))

func _wrap(s: String, width: float) -> Array:
	var out: Array = []
	var cur := ""
	for i in s.length():
		var ch := s.substr(i, 1)
		if ch == "\n" or m.dyn_text_width(cur + ch) > width:
			out.append(cur)
			cur = "" if ch == "\n" else ch
		else:
			cur += ch
	out.append(cur)
	return out

func draw() -> void:
	if not open:
		return
	var node := _cur()
	var who := str(node.get("who", ""))
	var mode := str(node.get("mode", _d.get("mode", "talk")))
	if who == "":
		mode = "think"
	var r := _frame()
	var b := _box()
	var think: bool = mode == "think"
	m.draw_rect(r, Pal.U_K)
	if think:
		m.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color("#14122a"))
		var scene := str(node.get("scene", ""))
		var sp := Vector2(r.position.x + r.size.x * 0.5 - 6, r.position.y + 10)
		var sz := Vector2(r.size.x * 0.5 - 8, b.position.y - r.position.y - 22)
		m.draw_rect(Rect2(sp - Vector2(2, 2), sz + Vector2(4, 4)), Pal.U_W)
		m.draw_rect(Rect2(sp, sz), Pal.U_A)
		if scene != "" and m.tex.has(scene):
			var tx: Texture2D = m.tex[scene]
			var k := minf(sz.x / float(tx.get_width()), sz.y / float(tx.get_height()))
			var dsz := Vector2(tx.get_width(), tx.get_height()) * k
			m.draw_texture_rect(tx, Rect2(sp + (sz - dsz) / 2.0, dsz), false)
		var speaker := who if who != "" else str(_d.get("left", "cat"))
		_portrait(speaker, Vector2(r.position.x + 10, b.position.y - 4 - (64 if speaker == "cat" else 66)), 3.0, who != "", false)
	else:
		m.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color("#262a3f"))
		var left := str(_d.get("left", "cat"))
		var right := str(_d.get("right", "keeper"))
		_portrait(left, Vector2(r.position.x + 8, b.position.y - 4 - (64 if left == "cat" else 66)), 3.0, who == left, false)
		_portrait(right, Vector2(r.end.x - 8 - (64 if right == "cat" else 48), b.position.y - 4 - (64 if right == "cat" else 66)), 3.0, who == right, true)
		var place := str(_d.get("place", ""))
		if place != "":
			var pw: float = m.dyn_text_width(place) + 14.0
			m.draw_rect(Rect2(r.position.x + 5, r.position.y + 4, pw, 14), Pal.U_K)
			m.draw_rect(Rect2(r.position.x + 6, r.position.y + 5, pw - 2, 12), Pal.U_O)
			m.dyn_text(place, Vector2(r.position.x + 12, r.position.y + 6), Pal.L_W)
	# 跳过
	var sk := _skip_rect()
	m.draw_rect(sk, Pal.U_A)
	m.draw_rect(sk.grow(-1), Pal.U_K)
	m.dyn_text("跳过", sk.position + Vector2(4, 1), Pal.L_W)
	# 对话框
	var parchment: bool = not think
	m.draw_rect(b.grow(1), Pal.U_K if parchment else Pal.U_W)
	m.draw_rect(b, Pal.L_W if parchment else Color("#14183a"))
	m.draw_rect(Rect2(b.position.x, b.end.y - 2, b.size.x, 2), Pal.L_N if parchment else Color("#0e1030"))
	var txt_col: Color = Pal.U_K if parchment else Pal.L_W
	if who != "":
		var nm := _who_name(who)
		var nw: float = m.dyn_text_width(nm) + 16.0
		var on_right: bool = not think and who == str(_d.get("right", "keeper"))
		var nx: float = b.end.x - nw - 10.0 if on_right else b.position.x + 8.0
		var nrect := Rect2(nx, b.position.y - 13, nw, 14)
		m.draw_rect(nrect.grow(1), Pal.U_K if parchment else Pal.U_W)
		m.draw_rect(nrect, Pal.U_K if parchment else Color("#14183a"))
		m.dyn_text(nm, Vector2(nx + 8, b.position.y - 12), Pal.L_Y if parchment else Pal.L_P)
	var shown := _text().substr(0, mini(_typed(), _text().length()))
	var lines := _wrap(shown, b.size.x - 22.0)
	for i in mini(lines.size(), 4):
		m.dyn_text(str(lines[i]), Vector2(b.position.x + 8, b.position.y + 5 + i * 12), txt_col)
	if not _typing():
		if _last_page() and not _choices().is_empty():
			var rs := _choice_rects()
			var ch := _choices()
			for i in rs.size():
				var cr: Rect2 = rs[i]
				if cr.size.x <= 0:
					continue
				var on: bool = i == _sel
				m.draw_rect(cr.grow(1), Pal.U_K)
				m.draw_rect(cr, Pal.L_Y if on else Pal.L_N)
				m.dyn_text(str(ch[i].get("text", "")), cr.position + Vector2(5, -1), Pal.U_K)
		else:
			var by := b.end.y - 9.0 + float((Time.get_ticks_msec() / 350) % 2)
			m.draw_rect(Rect2(b.end.x - 14, by, 7, 1), txt_col)
			m.draw_rect(Rect2(b.end.x - 13, by + 1, 5, 1), txt_col)
			m.draw_rect(Rect2(b.end.x - 12, by + 2, 3, 1), txt_col)
