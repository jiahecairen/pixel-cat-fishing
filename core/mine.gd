extends RefCounted
## 矿山岛的矿井（纯逻辑，不碰节点）。见 docs/MINE_ISLAND.md。
## 网格：x = 0..width-1（两边是花岗岩），y = 0 是洞口那一行（全通），往下越来越深。
## 竖井在中间一列：只有竖井能往下挖、上下爬，往下挖需要梯子够长。
## 挖掘按时间戳计（开始/结束毫秒），update(now) 补算离线进度；挖完一格自动沿同方向继续。
## 掉落以格子坐标为 id，挖过的格子记在 dug 里，所以同一格永远只发一次奖励。
const GameState := preload("res://core/game_state.gd")
const Inventory := preload("res://core/inventory.gd")

const HOUR_MS := 3600000
const MAX_CATCHUP := 400

var _s: GameState
var _inv: Inventory
var _c: Dictionary

func _init(s: GameState, inv: Inventory, cfg: Dictionary) -> void:
	_s = s
	_inv = inv
	_c = cfg

func cfg() -> Dictionary:
	return _c

func m() -> Dictionary:
	return _s.mine

func width() -> int:
	return int(_c.get("width", 13))

func shaft() -> int:
	return width() / 2

## 第一次进矿：定下矿脉种子，小猫站在洞口竖井上方。
func ensure(now_ms: int) -> void:
	var d := m()
	if int(d.get("seed", 0)) == 0:
		d["seed"] = 1 + absi(hash([now_ms, _s.next_seq])) % 2000000000
		d["x"] = shaft()
		d["y"] = 0
		d["ladder"] = int(_c.get("start_ladder", 1))
		d["rope"] = int(_c.get("rope", {}).get("start", 2))
		d["rope_ms"] = now_ms

func pos() -> Vector2i:
	return Vector2i(int(m().get("x", shaft())), int(m().get("y", 0)))

func ladder() -> int:
	return int(m().get("ladder", 0))

func pick() -> int:
	return int(m().get("pick", 0))

func lamp() -> int:
	return int(m().get("lamp", 0))

func pick_def(lv: int = -1) -> Dictionary:
	var arr: Array = _c.get("picks", [])
	var i := pick() if lv < 0 else lv
	return arr[clampi(i, 0, arr.size() - 1)]

func lamp_def(lv: int = -1) -> Dictionary:
	var arr: Array = _c.get("lamps", [])
	var i := lamp() if lv < 0 else lv
	return arr[clampi(i, 0, arr.size() - 1)]

func light_radius() -> float:
	return float(lamp_def().get("radius", 1.6))

func is_dug(x: int, y: int) -> bool:
	return y <= 0 and x > 0 and x < width() - 1 or m().get("dug", {}).has("%d,%d" % [x, y])

func layer(y: int) -> Dictionary:
	for l in _c.get("layers", []):
		if y <= int(l["to"]):
			return l
	return {}

## 格子的样子："" = 空（已挖开）；"granite" = 边上的花岗岩；否则是层带的块。
func block(x: int, y: int) -> String:
	if x <= 0 or x >= width() - 1:
		return "granite"
	if is_dug(x, y):
		return ""
	return str(layer(y).get("block", "deep"))

## 格子里埋着什么（由种子决定，玩家第一次看到前就定好了）："gem" / "metal" / "chest" / "stone" / ""。
func ore(x: int, y: int) -> String:
	if y <= 0 or x <= 0 or x >= width() - 1:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(m().get("seed", 1)), x, y])
	var r := rng.randf()
	var acc := 0.0
	for o in _c.get("ores", []):
		if y < int(o.get("min_y", 0)):
			continue
		acc += float(o.get("chance", 0.0)) + float(o.get("deep_bonus", 0.0)) * float(y)
		if r < acc:
			return str(o["id"])
	return ""

func ore_def(id: String) -> Dictionary:
	for o in _c.get("ores", []):
		if str(o["id"]) == id:
			return o
	return {}

func need_tool(y: int) -> int:
	return int(layer(y).get("tool", 1))

func dig_ms(x: int, y: int) -> int:
	var p := float(pick_def().get("power", 0.0))
	if p <= 0.0:
		return -1
	var hard := float(layer(y).get("hard_s", 60)) * float(ore_def(ore(x, y)).get("hard_mul", 1.0))
	return int(hard * 1000.0 / p)

## 能不能朝 (dx, dy) 挖。返回原因：""=可以，"open"=那格已经空了，
## "granite"=花岗岩，"notool"=没有镐，"tool"=镐不够好，"ladder"=梯子不够长，"shaft"=只有竖井能往下挖，"up"=不能往上挖。
func dig_block_reason(dx: int, dy: int) -> String:
	var p := pos()
	var tx := p.x + dx
	var ty := p.y + dy
	if dy < 0:
		return "up"
	if dy > 0 and (p.x != shaft() or dx != 0):
		return "shaft"
	var b := block(tx, ty)
	if b == "":
		return "open"
	if b == "granite":
		return "granite"
	if pick() <= 0:
		return "notool"
	if pick() < need_tool(ty):
		return "tool"
	if dy > 0 and ladder() < ty:
		return "ladder"
	return ""

func digging() -> bool:
	return not m().get("dig", {}).is_empty()

func dig_target() -> Vector2i:
	var d: Dictionary = m().get("dig", {})
	return Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))

## 0..1 的挖掘进度（画裂痕用）。
func dig_progress(now_ms: int) -> float:
	var d: Dictionary = m().get("dig", {})
	if d.is_empty():
		return 0.0
	var t0 := int(d["t0"])
	var t1 := int(d["t1"])
	return clampf(float(now_ms - t0) / float(maxi(1, t1 - t0)), 0.0, 1.0)

func start_dig(dx: int, dy: int, now_ms: int) -> String:
	var why := dig_block_reason(dx, dy)
	if why != "":
		return why
	var p := pos()
	m()["dig"] = {"x": p.x + dx, "y": p.y + dy, "t0": now_ms, "t1": now_ms + dig_ms(p.x + dx, p.y + dy)}
	m()["dir"] = [dx, dy]
	return ""

func stop_dig() -> void:
	m()["dig"] = {}
	m()["dir"] = [0, 0]

## 走进相邻的空格：横走任意行；上下只能在竖井里、且在梯子范围内。
func move(dx: int, dy: int) -> bool:
	var p := pos()
	var tx := p.x + dx
	var ty := p.y + dy
	if ty < 0 or block(tx, ty) != "":
		return false
	if dy != 0 and (p.x != shaft() or ty > ladder()):
		return false
	if digging():
		stop_dig()
	m()["x"] = tx
	m()["y"] = ty
	return true

## 推进时间。返回事件列表：{"type": "dug", "x", "y", "ore", "gems", "item", "lost"} / {"type": "stop", "why"}。
func update(now_ms: int) -> Array:
	var ev: Array = []
	for _i in MAX_CATCHUP:
		var d: Dictionary = m().get("dig", {})
		if d.is_empty() or now_ms < int(d["t1"]):
			break
		var x := int(d["x"])
		var y := int(d["y"])
		ev.append(_finish(x, y))
		m()["x"] = x
		m()["y"] = y
		var dir: Array = m().get("dir", [0, 0])
		m()["dig"] = {}
		var why := dig_block_reason(int(dir[0]), int(dir[1]))
		if why == "":
			var nx := x + int(dir[0])
			var ny := y + int(dir[1])
			var t0 := int(d["t1"])
			m()["dig"] = {"x": nx, "y": ny, "t0": t0, "t1": t0 + dig_ms(nx, ny)}
		else:
			m()["dir"] = [0, 0]
			ev.append({"type": "stop", "why": why})
	return ev

func _finish(x: int, y: int) -> Dictionary:
	var key := "%d,%d" % [x, y]
	var dug: Dictionary = m().get("dug", {})
	var e := {"type": "dug", "x": x, "y": y, "ore": "", "gems": 0, "item": "", "lost": false}
	if dug.has(key):
		return e
	dug[key] = 1
	m()["dug"] = dug
	m()["deepest"] = maxi(int(m().get("deepest", 0)), y)
	var o := ore(x, y)
	e["ore"] = o
	var od := ore_def(o)
	if od.has("gems"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(m().get("seed", 1)), x, y, "g"])
		var g: Array = od["gems"]
		e["gems"] = rng.randi_range(int(g[0]), int(g[1]))
		_s.gems += int(e["gems"])
	if od.has("item"):
		e["item"] = str(od["item"])
		if not _inv.add(_s, e["item"], 1):
			e["lost"] = true
	return e

## 竖井底部、梯子到头、包里有梯子：问要不要延长。
func can_extend() -> bool:
	return _inv.count(_s, "ladder") > 0

func at_ladder_end() -> bool:
	var p := pos()
	return p.x == shaft() and p.y == ladder() and p.y > 0

func extend_ladder() -> bool:
	if not _inv.remove(_s, "ladder", 1):
		return false
	m()["ladder"] = ladder() + int(_c.get("ladder_rows", 3))
	return true

## ---- 工具店 ----
func rope_stock(now_ms: int) -> int:
	var r: Dictionary = _c.get("rope", {})
	var base := int(m().get("rope", 0))
	var since := int(m().get("rope_ms", now_ms))
	var add := maxi(0, (now_ms - since) / HOUR_MS) * int(r.get("per_hour", 2))
	return mini(int(r.get("cap", 6)), base + add)

func _settle_rope(now_ms: int) -> void:
	var since := int(m().get("rope_ms", now_ms))
	var hours := maxi(0, (now_ms - since) / HOUR_MS)
	m()["rope"] = rope_stock(now_ms)
	m()["rope_ms"] = since + hours * HOUR_MS

func buy_rope(now_ms: int) -> String:
	_settle_rope(now_ms)
	var price := int(_c.get("rope", {}).get("price", 3))
	if int(m()["rope"]) <= 0:
		return "soldout"
	if _s.gems < price:
		return "gems"
	if not _inv.add(_s, "rope", 1):
		return "bag"
	_s.gems -= price
	m()["rope"] = int(m()["rope"]) - 1
	return ""

func next_price(kind: String) -> int:
	var arr: Array = _c.get("picks" if kind == "pick" else "lamps", [])
	var lv := (pick() if kind == "pick" else lamp()) + 1
	return int(arr[lv]["price"]) if lv < arr.size() else -1

func buy_level(kind: String) -> String:
	var price := next_price(kind)
	if price < 0:
		return "max"
	if _s.gems < price:
		return "gems"
	_s.gems -= price
	m()[kind] = (pick() if kind == "pick" else lamp()) + 1
	return ""

## 工坊：绳子 + 木板 → 梯子。
func craft_ladder() -> String:
	var rc: Dictionary = _c.get("ladder_recipe", {})
	var need_r := int(rc.get("rope", 1))
	var need_p := int(rc.get("plank", 2))
	if _inv.count(_s, "rope") < need_r or _inv.count(_s, "plank") < need_p:
		return "mat"
	_inv.remove(_s, "rope", need_r)
	_inv.remove(_s, "plank", need_p)
	if not _inv.add(_s, "ladder", 1):
		_inv.add(_s, "rope", need_r)
		_inv.add(_s, "plank", need_p)
		return "bag"
	return ""

## 饭店收鱼：鱼篓里的鱼全部换成宝石（按鱼价折算，每条至少 1 颗）。sale_id 防重复提交。
func sell_fish(prices: Dictionary, sale_id: String) -> int:
	if sale_id in _s.processed_sale_ids:
		return 0
	var div := maxi(1, int(_c.get("fish_gem_div", 10)))
	var g := 0
	for f in _s.basket:
		g += maxi(1, int(prices.get(f, 0)) / div)
	if g <= 0:
		return 0
	_s.basket.clear()
	_s.basket_sizes.clear()
	_s.gems += g
	_s.processed_sale_ids.append(sale_id)
	if _s.processed_sale_ids.size() > GameState.MAX_PROCESSED_IDS:
		_s.processed_sale_ids.pop_front()
	return g
