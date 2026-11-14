extends RefCounted
## 矿山岛的矿井（纯逻辑，不碰节点）。见 docs/MINE_ISLAND.md。
## 结构：洞穴大厅（矿车）→ 矿井（1 号通畅，2 号铁路坏了）。每次坐矿车下井是一"局"（run）：
##   - 侧面的矿脉每局重新生成（种子换），中间竖井和梯子是永久的（挖过的竖井、装好的梯子下次还在）。
##   - 开局、开宝箱时从 3 个随机"天赋"里选 1 个，只在这一局有效；出矿井就清零。
##   - 偶尔落石把退路堵上，富矿脉区域矿物多。
## 挖掘是主动的：按住方向键才挖，进度按时间戳算，松手后裂痕留着（partial），不会离线自己挖。
## 竖井列只有它能往下挖，往下挖需要梯子够长；花岗岩（两边）挖不动。
const GameState := preload("res://core/game_state.gd")
const Inventory := preload("res://core/inventory.gd")
const MoneyC := preload("res://core/money.gd")

const HOUR_MS := 3600000

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

## 第一次进矿：建好存档里的永久部分。
func ensure(now_ms: int) -> void:
	var d := m()
	if not d.has("shafts"):
		d["shafts"] = {"1": {"ladder": int(_c.get("start_ladder", 1)), "open": 0, "best": 0}, "2": {"fixed": 0}}
		d["rope"] = int(_c.get("rope", {}).get("start", 2))
		d["rope_ms"] = now_ms
		d["runs"] = 0
		d["dish"] = ""
		d["run"] = {}

## ---- 永久：镐 / 灯 ----
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

## 雾灯岛管理员完成任务后送的第一把镐子。
func give_first_pick() -> bool:
	if pick() >= 1:
		return false
	m()["pick"] = 1
	return true

## ---- 矿井（1 / 2 号） ----
func shaft_state(id: int) -> Dictionary:
	var sh: Dictionary = m().get("shafts", {})
	return sh.get(str(id), {})

func shaft_ok(id: int) -> bool:
	return id == 1 or int(shaft_state(id).get("fixed", 0)) > 0

## 2 号井的修复条件（以后实现：要更大的船把工人送来）。
func repair_need() -> Dictionary:
	return _c.get("repair2", {})

## ---- 一局（run） ----
func run() -> Dictionary:
	return m().get("run", {})

func in_run() -> bool:
	return not run().is_empty()

func shaft_id() -> int:
	return int(run().get("shaft", 1))

func begin_run(id: int, now_ms: int) -> bool:
	if not shaft_ok(id) or in_run():
		return false
	var runs := int(m().get("runs", 0)) + 1
	m()["runs"] = runs
	var dish := str(m().get("dish", ""))
	m()["dish"] = ""
	m()["run"] = {
		"shaft": id, "seed": 1 + absi(hash([now_ms, runs, _s.next_seq])) % 2000000000,
		"x": shaft(), "y": 0, "dug": {}, "partial": {}, "rubble": {}, "perks": {}, "dish": dish,
		"dig": {}, "dir": [0, 0], "n": 0, "draft": [], "best": 0,
	}
	_roll_draft()
	return true

func end_run() -> void:
	m()["run"] = {}

func seed_() -> int:
	return int(run().get("seed", 1))

func pos() -> Vector2i:
	var r := run()
	return Vector2i(int(r.get("x", shaft())), int(r.get("y", 0)))

func ladder() -> int:
	return int(shaft_state(shaft_id()).get("ladder", 0))

func open_depth() -> int:
	return int(shaft_state(shaft_id()).get("open", 0))

func dish_def() -> Dictionary:
	return dish_by_id(str(run().get("dish", "")))

func dish_by_id(id: String) -> Dictionary:
	for d in _c.get("dishes", []):
		if str(d["id"]) == id:
			return d
	return {}

## ---- 天赋（只在这一局有效） ----
func perk_def(id: String) -> Dictionary:
	for p in _c.get("perks", []):
		if str(p["id"]) == id:
			return p
	return {}

func perk_count(id: String) -> int:
	return int(run().get("perks", {}).get(id, 0))

## 当前待选的 3 个天赋（没有就是空）。
func draft() -> Array:
	return run().get("draft", [])

func _roll_draft() -> void:
	var r := run()
	var n := int(r.get("n", 0))
	r["n"] = n + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), n, "perk"])
	var ids: Array = []
	for p in _c.get("perks", []):
		ids.append(str(p["id"]))
	var out: Array = []
	while out.size() < 3 and not ids.is_empty():
		out.append(ids.pop_at(rng.randi() % ids.size()))
	r["draft"] = out

func choose_perk(i: int) -> String:
	var d := draft()
	if i < 0 or i >= d.size():
		return ""
	var id: String = d[i]
	var perks: Dictionary = run()["perks"]
	perks[id] = int(perks.get(id, 0)) + 1
	run()["draft"] = []
	return id

func speed_mul() -> float:
	var sp := float(perk_def("swift").get("v", 0.25)) * float(perk_count("swift"))
	return 1.0 + sp + float(dish_def().get("speed", 0.0))

func light_radius() -> float:
	return float(lamp_def().get("radius", 1.6)) + float(perk_def("bright").get("v", 1.0)) * float(perk_count("bright")) + float(dish_def().get("light", 0.0))

func luck_mul() -> float:
	return 1.0 + float(perk_def("lucky").get("v", 0.5)) * float(perk_count("lucky")) + float(dish_def().get("luck", 0.0))

## ---- 格子 ----
func is_dug(x: int, y: int) -> bool:
	if y <= 0:
		return x > 0 and x < width() - 1
	if x == shaft() and y <= open_depth():
		return true
	return run().get("dug", {}).has("%d,%d" % [x, y])

func layer(y: int) -> Dictionary:
	for l in _c.get("layers", []):
		if y <= int(l["to"]):
			return l
	return {}

## 格子的样子："" = 空；"granite" = 两边的花岗岩；"rubble" = 落石；否则是层带的块。
func block(x: int, y: int) -> String:
	if x <= 0 or x >= width() - 1:
		return "granite"
	if is_dug(x, y):
		return ""
	if run().get("rubble", {}).has("%d,%d" % [x, y]):
		return "rubble"
	return str(layer(y).get("block", "deep"))

## 富矿脉：以 5×5 为一块，按种子有些块的矿物特别多。
func rich(x: int, y: int) -> bool:
	return absi(hash([seed_(), x / 5, y / 5, "rich"])) % 5 == 0

## 格子里埋着什么（由这一局的种子决定）："gold" / "metal" / "chest" / "stone" / ""。
func ore(x: int, y: int) -> String:
	if y <= 0 or x <= 0 or x >= width() - 1:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), x, y])
	var r := rng.randf()
	var k := luck_mul() * (2.2 if rich(x, y) else 1.0)
	var acc := 0.0
	for o in _c.get("ores", []):
		if y < int(o.get("min_y", 0)):
			continue
		var ch := float(o.get("chance", 0.0)) + float(o.get("deep_bonus", 0.0)) * float(y)
		acc += ch * (k if str(o["id"]) != "stone" else 1.0)
		if r < acc:
			return str(o["id"])
	return ""

func ore_def(id: String) -> Dictionary:
	for o in _c.get("ores", []):
		if str(o["id"]) == id:
			return o
	return {}

func need_tool(x: int, y: int) -> int:
	if block(x, y) == "rubble":
		return 1
	return int(layer(y).get("tool", 1))

func dig_ms(x: int, y: int) -> int:
	var p := float(pick_def().get("power", 0.0))
	if p <= 0.0:
		return -1
	var hard := float(layer(y).get("hard_s", 1.0)) * float(ore_def(ore(x, y)).get("hard_mul", 1.0))
	if block(x, y) == "rubble":
		hard = float(_c.get("rubble_s", 0.35))
	return maxi(120, int(hard * 1000.0 / (p * speed_mul())))

## 能不能朝 (dx, dy) 挖。""=可以，"open"=已经空了，"granite"=花岗岩，"notool"=没镐，
## "tool"=镐不够好，"ladder"=梯子不够长，"shaft"=只有竖井能往下挖，"up"=不能往上挖。
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
	if pick() < need_tool(tx, ty):
		return "tool"
	if dy > 0 and ladder() < ty:
		return "ladder"
	return ""

func digging() -> bool:
	return not run().get("dig", {}).is_empty()

func dig_target() -> Vector2i:
	var d: Dictionary = run().get("dig", {})
	return Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))

func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

## 这一格已经挖了多少（0..1）：正在挖的按时间算，停下的记在 partial 里。
func progress_at(x: int, y: int, now_ms: int) -> float:
	var d: Dictionary = run().get("dig", {})
	if not d.is_empty() and int(d["x"]) == x and int(d["y"]) == y:
		return clampf(float(now_ms - int(d["t0"])) / float(maxi(1, int(d["t1"]) - int(d["t0"]))), 0.0, 1.0)
	return float(run().get("partial", {}).get(_key(x, y), 0.0))

func dig_progress(now_ms: int) -> float:
	var t := dig_target()
	return progress_at(t.x, t.y, now_ms)

func start_dig(dx: int, dy: int, now_ms: int) -> String:
	var why := dig_block_reason(dx, dy)
	if why != "":
		return why
	var p := pos()
	var tx := p.x + dx
	var ty := p.y + dy
	if digging() and dig_target() == Vector2i(tx, ty):
		return ""
	stop_dig(now_ms)
	var ms := dig_ms(tx, ty)
	var done := float(run().get("partial", {}).get(_key(tx, ty), 0.0))
	var t0 := now_ms - int(done * float(ms))
	run()["dig"] = {"x": tx, "y": ty, "t0": t0, "t1": t0 + ms}
	run()["dir"] = [dx, dy]
	return ""

## 松手：已经挖的进度留在块上（裂痕不消失）。
func stop_dig(now_ms: int) -> void:
	if not in_run():
		return
	var d: Dictionary = run().get("dig", {})
	if not d.is_empty():
		var f := progress_at(int(d["x"]), int(d["y"]), now_ms)
		if f > 0.01 and f < 1.0:
			run()["partial"][_key(int(d["x"]), int(d["y"]))] = f
	run()["dig"] = {}
	run()["dir"] = [0, 0]

## 加速（测试用）：把挖掘的截止时刻和绳子补货的计时平移 delta_ms（负数 = 往前拉）。
func shift(delta_ms: int) -> void:
	var d: Dictionary = run().get("dig", {})
	if not d.is_empty():
		d["t0"] = int(d["t0"]) + delta_ms
		d["t1"] = int(d["t1"]) + delta_ms
	if m().has("rope_ms"):
		m()["rope_ms"] = int(m()["rope_ms"]) + delta_ms

## 走进相邻的空格：横走任意行；上下只能在竖井里、且在梯子范围内。
func move(dx: int, dy: int, now_ms: int = 0) -> bool:
	var p := pos()
	var tx := p.x + dx
	var ty := p.y + dy
	if ty < 0 or block(tx, ty) != "":
		return false
	if dy != 0 and (p.x != shaft() or ty > ladder()):
		return false
	if digging():
		stop_dig(now_ms)
	run()["x"] = tx
	run()["y"] = ty
	return true

## 推进时间：挖开的格子发奖励、小猫走进去。返回事件：
## {"type":"dug","x","y","ore","gold","item","lost","chest","cavein"}
func update(now_ms: int) -> Array:
	var ev: Array = []
	var d: Dictionary = run().get("dig", {})
	if d.is_empty() or now_ms < int(d["t1"]):
		return ev
	var x := int(d["x"])
	var y := int(d["y"])
	var dir: Array = run().get("dir", [0, 0])
	ev.append(_finish(x, y, int(dir[0]), int(dir[1])))
	run()["x"] = x
	run()["y"] = y
	run()["dig"] = {}
	run()["dir"] = [0, 0]
	return ev

func _add_copper(n: int) -> void:
	_s.wallet_gold = mini(MoneyC.WALLET_CAP, _s.wallet_gold + n)

func _finish(x: int, y: int, dx: int, dy: int) -> Dictionary:
	var key := _key(x, y)
	var dug: Dictionary = run()["dug"]
	var e := {"type": "dug", "x": x, "y": y, "ore": "", "gold": 0, "item": "", "n": 0, "lost": false, "chest": false, "cavein": false}
	if dug.has(key) or is_dug(x, y):
		return e
	dug[key] = 1
	run()["partial"].erase(key)
	run()["rubble"].erase(key)
	if x == shaft():
		var st: Dictionary = shaft_state(shaft_id())
		st["open"] = maxi(int(st.get("open", 0)), y)
		st["best"] = maxi(int(st.get("best", 0)), y)
	run()["best"] = maxi(int(run().get("best", 0)), y)
	var o := ore(x, y)
	e["ore"] = o
	var od := ore_def(o)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), x, y, "g"])
	if od.has("gold"):
		var g: Array = od["gold"]
		var n := int(round(float(rng.randi_range(int(g[0]), int(g[1]))) * (1.0 + 0.04 * float(y))))
		e["gold"] = n
		_add_copper(n)
	if od.has("item"):
		var cnt := 1
		if perk_count("loot") > 0 and rng.randf() < float(perk_def("loot").get("v", 0.3)) * float(perk_count("loot")):
			cnt = 2
		e["item"] = str(od["item"])
		e["n"] = cnt
		if not _inv.add(_s, e["item"], cnt):
			e["lost"] = true
	if o == "chest":
		e["chest"] = true
		if draft().is_empty():
			_roll_draft()
	# 震波：邻格先裂开一截
	var sh := float(perk_def("shock").get("v", 0.3)) * float(perk_count("shock"))
	if sh > 0.0:
		for dv in [Vector2i(dx, dy), Vector2i(dy, dx), Vector2i(-dy, -dx)]:
			if dv == Vector2i.ZERO:
				continue
			var nx: int = x + dv.x
			var ny: int = y + dv.y
			if block(nx, ny) != "" and block(nx, ny) != "granite" and ny > 0 and not (dv.y > 0 and x != shaft()):
				var k2 := _key(nx, ny)
				run()["partial"][k2] = minf(0.9, float(run()["partial"].get(k2, 0.0)) + sh)
	# 落石：横着挖到深处，偶尔把身后堵上（竖井不会）
	if dx != 0 and x != shaft() and y >= int(_c.get("cavein_min_y", 3)) and perk_count("helmet") == 0:
		var r2 := RandomNumberGenerator.new()
		r2.seed = hash([seed_(), x, y, "cave"])
		if r2.randf() < float(_c.get("cavein_chance", 0.05)):
			for k in range(1, 3):
				var bx := x - dx * k
				if bx != shaft() and is_dug(bx, y) and run().get("dug", {}).has(_key(bx, y)):
					run()["dug"].erase(_key(bx, y))
					run()["rubble"][_key(bx, y)] = 1
			e["cavein"] = true
	return e

## 竖井底部、梯子到头、包里有梯子：问要不要延长。
func can_extend() -> bool:
	return _inv.count(_s, "ladder") > 0

func at_ladder_end() -> bool:
	var p := pos()
	return p.x == shaft() and p.y == ladder() and p.y > 0

func extend_ladder() -> bool:
	if not in_run() or not _inv.remove(_s, "ladder", 1):
		return false
	var st: Dictionary = shaft_state(shaft_id())
	st["ladder"] = ladder() + int(_c.get("ladder_rows", 3))
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
	var price := int(_c.get("rope", {}).get("price", 30))
	if int(m()["rope"]) <= 0:
		return "soldout"
	if _s.wallet_gold < price:
		return "gold"
	if not _inv.add(_s, "rope", 1):
		return "bag"
	_s.wallet_gold -= price
	m()["rope"] = int(m()["rope"]) - 1
	return ""

## 下一级要什么：{"gold": 铜币, "items": {id: n}}；已经最高级返回空。
func next_cost(kind: String) -> Dictionary:
	var arr: Array = _c.get("picks" if kind == "pick" else "lamps", [])
	var lv := (pick() if kind == "pick" else lamp()) + 1
	if lv >= arr.size():
		return {}
	return {"gold": int(arr[lv].get("price", 0)), "items": arr[lv].get("items", {})}

func buy_level(kind: String) -> String:
	var c := next_cost(kind)
	if c.is_empty():
		return "max"
	if kind == "pick" and pick() < 1:
		return "nopick"                                  # 第一把镐子是管理员送的
	if _s.wallet_gold < int(c["gold"]):
		return "gold"
	for id in c["items"]:
		if _inv.count(_s, str(id)) < int(c["items"][id]):
			return "mat"
	_s.wallet_gold -= int(c["gold"])
	for id in c["items"]:
		_inv.remove(_s, str(id), int(c["items"][id]))
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

## ---- 饭店：消耗鱼和钱做一道菜，下一局生效 ----
func dishes() -> Array:
	return _c.get("dishes", [])

## 返回 ""=做好了，"have"=已经有一道没吃，"gold"=钱不够，"fish"=鱼不够（稀有鱼不会被拿去做菜）。
func cook(dish_id: String, econ) -> String:
	var d := dish_by_id(dish_id)
	if d.is_empty():
		return "none"
	if str(m().get("dish", "")) != "":
		return "have"
	if _s.wallet_gold < int(d.get("price", 0)):
		return "gold"
	var need := int(d.get("fish", 1))
	var have := 0
	var tmp: Array = _s.basket.duplicate()
	for f in tmp:
		if int(econ._rarity.get(f, 0)) < 2:
			have += 1
	if have < need:
		return "fish"
	for _i in need:
		econ.eat_cheapest(_s)
	_s.wallet_gold -= int(d.get("price", 0))
	m()["dish"] = dish_id
	return ""
