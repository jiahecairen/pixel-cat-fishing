extends RefCounted
## 矿山岛的矿井（纯逻辑，不碰节点）。见 docs/MINE_ISLAND.md。
## 结构：洞穴大厅（矿车）→ 矿井（1 号通畅，2 号铁路坏了）。每次坐矿车下井是一"局"（run）：
##   - 一层一层往下：每层是一张随机小地图（宽 width × 高 height 格），入口是顶部一格台阶，
##     出口（往下的洞）埋在某块石头下面，挖开它再走上去才能下一层。每局种子不同，每层地图不同。
##   - 四个方向都能自由地挖，没有梯子、绳子这类限制；外圈是挖不动的花岗岩。
##   - 炸弹一次炸一片；炸药桶会连锁爆炸；金矿、金属矿连成一片时一起碎。
##   - 挖到的东西先装进背包（有上限），回到地面（走回第 1 层入口，或在整 5 层的入口坐电梯）才换成钱和材料。
##   - 开局、开宝箱时从 3 个随机"天赋"里选 1 个，只在这一局有效。
## 挖掘是主动的：按住方向键才挖，进度按时间戳算，松手后裂痕留着（partial），不会离线自己挖。
const GameState := preload("res://core/game_state.gd")
const Inventory := preload("res://core/inventory.gd")
const MoneyC := preload("res://core/money.gd")

const CHAIN_ORES := ["gold", "metal"]

var _s: GameState
var _inv: Inventory
var _c: Dictionary
var _lay: Dictionary = {}                 # 每层的洞穴形状缓存（由种子算出来，不存档）

func _init(s: GameState, inv: Inventory, cfg: Dictionary) -> void:
	_s = s
	_inv = inv
	_c = cfg

func cfg() -> Dictionary:
	return _c

func m() -> Dictionary:
	return _s.mine

func width() -> int:
	return int(_c.get("width", 15))

func height() -> int:
	return int(_c.get("height", 10))

func checkpoint_every() -> int:
	return maxi(1, int(_c.get("checkpoint_every", 5)))

## 第一次进矿：建好存档里的永久部分。
func ensure(now_ms: int) -> void:
	var d := m()
	if not d.has("shafts"):
		d["shafts"] = {"1": {"cp": 1, "best": 0}, "2": {"fixed": 0, "cp": 1, "best": 0}}
		d["runs"] = 0
		d["dish"] = ""
		d["run"] = {}
	if not d.has("bombs"):
		d["bombs"] = int(_c.get("bomb", {}).get("start", 0))
	if not d.has("bag_lv"):
		d["bag_lv"] = 0
	if in_run() and not run().has("floor"):       # 旧版（竖井梯子）留下的一局：作废
		d["run"] = {}
	if in_run() and not run().has("sta"):          # v0.72 的存档里没有体力：补满
		run()["sta"] = stamina_max()
	for sid in [1, 2]:
		if not m()["shafts"].has(str(sid)):
			m()["shafts"][str(sid)] = {"fixed": 0, "cp": 1, "best": 0}
		if not shaft_state(sid).has("cp"):
			shaft_state(sid)["cp"] = 1

## ---- 永久：镐 / 灯 / 背包 / 炸弹 ----
func pick() -> int:
	return int(m().get("pick", 0))

func lamp() -> int:
	return int(m().get("lamp", 0))

func bag_lv() -> int:
	return int(m().get("bag_lv", 0))

func bombs() -> int:
	return int(m().get("bombs", 0))

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
	return id == 1 or (id == 2 and int(shaft_state(id).get("fixed", 0)) > 0)

func shaft_count() -> int:
	return int(_c.get("shafts", 5))

## "ok" 能下 / "broken" 铁路坏了能修 / "locked" 还没开放
func shaft_status(id: int) -> String:
	if shaft_ok(id):
		return "ok"
	return "broken" if id == 2 else "locked"

## 2 号井的修复条件。
func repair_need() -> Dictionary:
	return _c.get("repair2", {})

func crew() -> int:
	return int(_s.effects.get("workers", 0))

## 还缺什么：[[名称, 缺几个]]，空 = 都够了。
func repair_missing() -> Array:
	var need := repair_need()
	var out: Array = []
	for id in ["metal", "stone"]:
		var lack := int(need.get(id, 0)) - _inv.count(_s, id)
		if lack > 0:
			out.append([id, lack])
	var lack_w := int(need.get("crew", 0)) - crew()
	if lack_w > 0:
		out.append(["crew", lack_w])
	return out

## 修好 2 号井：扣材料，工人要先在雾灯岛酒馆雇好。
func repair_shaft() -> String:
	if shaft_ok(2):
		return "done"
	var miss := repair_missing()
	if not miss.is_empty():
		return "crew" if miss[miss.size() - 1][0] == "crew" and miss.size() == 1 else "mat"
	var need := repair_need()
	for id in ["metal", "stone"]:
		_inv.remove(_s, id, int(need.get(id, 0)))
	shaft_state(2)["fixed"] = 1
	_s.revision += 1
	return ""

## 能从哪几层开始下井：第 1 层，和这口井已经到过的整 5 层。
func start_floors(id: int = 1) -> Array:
	var out: Array = [1]
	var cp := int(shaft_state(id).get("cp", 1))
	var f := checkpoint_every()
	while f <= cp:
		out.append(f)
		f += checkpoint_every()
	return out

## ---- 一局（run） ----
func run() -> Dictionary:
	return m().get("run", {})

func in_run() -> bool:
	return not run().is_empty()

func shaft_id() -> int:
	return int(run().get("shaft", 1))

func floor_n() -> int:
	return int(run().get("floor", 1))

func begin_run(id: int, now_ms: int, start_floor: int = 1) -> bool:
	if not shaft_ok(id) or in_run():
		return false
	if not start_floors(id).has(start_floor):
		return false
	var runs := int(m().get("runs", 0)) + 1
	m()["runs"] = runs
	var dish := str(m().get("dish", ""))
	m()["dish"] = ""
	m()["run"] = {
		"shaft": id, "seed": 1 + absi(hash([now_ms, runs, _s.next_seq])) % 2000000000,
		"floor": start_floor, "x": 0, "y": 0, "dug": {}, "partial": {}, "perks": {}, "dish": dish,
		"dig": {}, "dir": [0, 0], "n": 0, "draft": [], "best": start_floor, "booms": [],
		"bag": {"n": 0, "coins": 0, "stone": 0, "metal": 0}, "sta": 0,
	}
	run()["sta"] = stamina_max()
	var en := entrance(start_floor)
	run()["x"] = en.x
	run()["y"] = en.y
	_roll_draft()
	return true

## 结束这一局：背包里的东西换成钱和材料。返回 {"coins","stone","metal","lost"}。
func end_run() -> Dictionary:
	var res := cash_out()
	m()["run"] = {}
	return res

func seed_() -> int:
	return int(run().get("seed", 1))

func pos() -> Vector2i:
	var r := run()
	return Vector2i(int(r.get("x", 0)), int(r.get("y", 0)))

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
	if id == "tough":
		run()["sta"] = stamina() + int(perk_def("tough").get("v", 15))
	run()["draft"] = []
	return id

## 体力：每挖开一格（自己动手，炸弹不算）扣一点，越深越费；用完就挖不动了，只能走、放炸弹、回地面。
func stamina_max() -> int:
	var sc: Dictionary = _c.get("stamina", {})
	var v := int(sc.get("start", 45)) + int(sc.get("per_pick", 10)) * maxi(0, pick() - 1)
	v += int(float(perk_def("tough").get("v", 15)) * float(perk_count("tough")))
	return v + int(dish_def().get("stamina", 0))

func stamina() -> int:
	return int(run().get("sta", 0))

func dig_cost(_x: int, _y: int) -> int:
	return int(layer(floor_n()).get("cost", 1))

func speed_mul() -> float:
	var sp := float(perk_def("swift").get("v", 0.25)) * float(perk_count("swift"))
	return 1.0 + sp + float(dish_def().get("speed", 0.0))

func light_radius() -> float:
	return float(lamp_def().get("radius", 1.6)) + float(perk_def("bright").get("v", 1.0)) * float(perk_count("bright")) + float(dish_def().get("light", 0.0))

func luck_mul() -> float:
	return 1.0 + float(perk_def("lucky").get("v", 0.5)) * float(perk_count("lucky")) + float(dish_def().get("luck", 0.0))

func blast_radius() -> int:
	return int(_c.get("bomb", {}).get("radius", 1)) + perk_count("boom")

## ---- 背包（装满了回地面才换钱） ----
func bag_cap() -> int:
	var sizes: Array = _c.get("bag", {}).get("sizes", [24])
	return int(sizes[clampi(bag_lv(), 0, sizes.size() - 1)]) + int(perk_def("bigbag").get("v", 8)) * perk_count("bigbag")

func bag() -> Dictionary:
	return run().get("bag", {})

func bag_n() -> int:
	return int(bag().get("n", 0))

func bag_full() -> bool:
	return bag_n() >= bag_cap()

## 把背包里的东西发出去。物品栏放不下的算丢掉。
func cash_out() -> Dictionary:
	var res := {"coins": 0, "stone": 0, "metal": 0, "lost": 0}
	if not in_run():
		return res
	var b: Dictionary = bag()
	var coins := int(b.get("coins", 0))
	if coins > 0:
		_s.wallet_gold = mini(MoneyC.WALLET_CAP, _s.wallet_gold + coins)
	res["coins"] = coins
	for id in ["stone", "metal"]:
		var n := int(b.get(id, 0))
		for _i in n:
			if _inv.add(_s, id, 1):
				res[id] = int(res[id]) + 1
			else:
				res["lost"] = int(res["lost"]) + 1
	run()["bag"] = {"n": 0, "coins": 0, "stone": 0, "metal": 0}
	return res

## ---- 每层的地图（由种子和层数决定，不用存） ----
func entrance(f: int) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), f, "in"])
	return Vector2i(2 + rng.randi() % maxi(1, width() - 4), 0)

func exit_pos(f: int) -> Vector2i:
	return _layout(f)["exit"]

## 这一层的洞穴：自然地面（可走）、岩壁（挖不动）、地面上散落的石块（要挖）。
## 形状由种子和层数决定：几个椭圆形的"房间"用走廊连起来，边缘参差不齐。
func _layout(f: int) -> Dictionary:
	var key := "%d:%d:%d:%d" % [seed_(), f, width(), height()]
	if _lay.has(key):
		return _lay[key]
	var W := width()
	var H := height()
	var lc: Dictionary = _c.get("layout", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), f, "lay"])
	var fl := PackedByteArray()
	fl.resize(W * H)
	var en := entrance(f)
	var centers: Array = [Vector2i(en.x, 4)]
	var rr: Array = lc.get("rooms", [5, 8])
	var n_rooms: int = int(rr[0]) + rng.randi() % maxi(1, int(rr[1]) - int(rr[0]) + 1)
	for _i in n_rooms:
		centers.append(Vector2i(4 + rng.randi() % maxi(1, W - 8), 5 + rng.randi() % maxi(1, H - 8)))
	for i in centers.size():
		var c: Vector2i = centers[i]
		var rw := 3 + rng.randi() % 4
		var rh := 2 + rng.randi() % 3
		for y in range(c.y - rh - 1, c.y + rh + 2):
			for x in range(c.x - rw - 1, c.x + rw + 2):
				if x < 1 or y < 1 or x > W - 2 or y > H - 2:
					continue
				var dx := float(x - c.x) / float(rw)
				var dy := float(y - c.y) / float(rh)
				var noise := float(absi(hash([seed_(), f, x, y, "n"])) % 100) / 100.0
				if dx * dx + dy * dy <= 0.75 + 0.45 * noise:
					fl[y * W + x] = 1
		if i > 0:
			var a: Vector2i = centers[i - 1]
			var step := 1 if c.x >= a.x else -1
			for x in range(a.x, c.x + step, step):
				for oy in 2:
					var yy := clampi(a.y + oy, 1, H - 2)
					fl[yy * W + clampi(x, 1, W - 2)] = 1
			var stepy := 1 if c.y >= a.y else -1
			for y in range(a.y, c.y + stepy, stepy):
				for ox in 2:
					fl[clampi(y, 1, H - 2) * W + clampi(c.x + ox, 1, W - 2)] = 1
	for y in range(0, 5):                                  # 入口：顶上的缺口，一条路通到第一个房间
		fl[y * W + en.x] = 1
		fl[y * W + clampi(en.x + 1, 1, W - 2)] = 1 if y > 0 else fl[y * W + clampi(en.x + 1, 1, W - 2)]
	# 出口：从入口走过去最远的那一批地面里挑一个
	var dist := {}
	var q: Array = [en]
	dist[en] = 0
	var far := 0
	var order: Array = []
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		order.append(cur)
		far = maxi(far, int(dist[cur]))
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + dv
			if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or dist.has(n) or fl[n.y * W + n.x] == 0:
				continue
			dist[n] = int(dist[cur]) + 1
			q.append(n)
	var cands: Array = []
	for cell in order:
		if int(dist[cell]) >= int(float(far) * float(lc.get("exit_far", 0.7))) and cell != en:
			cands.append(cell)
	var ex: Vector2i = cands[rng.randi() % cands.size()] if not cands.is_empty() else order[order.size() - 1]
	# 石块：地面上一簇一簇的，出口一定埋在石块底下
	var rk := PackedByteArray()
	rk.resize(W * H)
	for y in H:
		for x in W:
			if fl[y * W + x] == 0 or (absi(x - en.x) <= 1 and y <= 5):
				continue
			var pr := float(lc.get("rock_rich", 0.5)) if rich(x, y, f) else float(lc.get("rock", 0.1))
			if rng.randf() < pr:
				rk[y * W + x] = 1
	rk[ex.y * W + ex.x] = 1
	var out := {"floor": fl, "rock": rk, "exit": ex}
	_lay[key] = out
	return out

## 自然地面（岩壁以外的地方，包括上面还压着石块的）。
func is_floor(x: int, y: int) -> bool:
	return in_map(x, y) and _layout(floor_n())["floor"][y * width() + x] == 1

func has_rock(x: int, y: int) -> bool:
	return in_map(x, y) and _layout(floor_n())["rock"][y * width() + x] == 1

func _key(x: int, y: int, f: int = -1) -> String:
	return "%d:%d,%d" % [floor_n() if f < 0 else f, x, y]

func in_map(x: int, y: int) -> bool:
	return x >= 0 and x < width() and y >= 0 and y < height()

func is_dug(x: int, y: int) -> bool:
	if not in_map(x, y):
		return false
	if Vector2i(x, y) == entrance(floor_n()):
		return true
	return run().get("dug", {}).has(_key(x, y))

func layer(f: int) -> Dictionary:
	for l in _c.get("layers", []):
		if f <= int(l["to"]):
			return l
	return {}

## 格子的样子："" = 空地；"granite" = 岩壁（挖不动）；否则是压在这格上的石块（这一层的材质）。
func block(x: int, y: int) -> String:
	if not in_map(x, y) or not is_floor(x, y):
		return "granite"
	if is_dug(x, y) or not has_rock(x, y):
		return ""
	return str(layer(floor_n()).get("block", "deep"))

## 富矿脉：以 4×4 为一块，按种子有些块的矿物特别多。
func rich(x: int, y: int, f: int = -1) -> bool:
	return absi(hash([seed_(), floor_n() if f < 0 else f, x / 4, y / 4, "rich"])) % 5 == 0

## 格子里埋着什么："exit"（往下的洞）/ "tnt" / "gold" / "metal" / "chest" / "stone" / ""。
func ore(x: int, y: int) -> String:
	if not in_map(x, y) or Vector2i(x, y) == entrance(floor_n()) or not has_rock(x, y):
		return ""
	if Vector2i(x, y) == exit_pos(floor_n()):
		return "exit"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), floor_n(), x, y])
	var r := rng.randf() * float(_c.get("layout", {}).get("ore_scale", 0.4))
	var k := luck_mul() * (2.2 if rich(x, y) else 1.0)
	var acc := 0.0
	for o in _c.get("ores", []):
		if floor_n() < int(o.get("min_y", 0)):
			continue
		var ch := float(o.get("chance", 0.0)) + float(o.get("deep_bonus", 0.0)) * float(floor_n())
		acc += ch * (k if str(o["id"]) in ["gold", "metal", "chest"] else 1.0)
		if r < acc:
			return str(o["id"])
	return ""

func ore_def(id: String) -> Dictionary:
	for o in _c.get("ores", []):
		if str(o["id"]) == id:
			return o
	return {}

func need_tool(_x: int, _y: int) -> int:
	return int(layer(floor_n()).get("tool", 1))

func dig_ms(x: int, y: int) -> int:
	var p := float(pick_def().get("power", 0.0))
	if p <= 0.0:
		return -1
	var hard := float(layer(floor_n()).get("hard_s", 1.0)) * float(ore_def(ore(x, y)).get("hard_mul", 1.0))
	return maxi(120, int(hard * 1000.0 / (p * speed_mul())))

## 能不能朝 (dx, dy) 挖。""=可以，"open"=已经空了，"granite"=花岗岩，"notool"=没镐，"tool"=镐不够好。
func dig_block_reason(dx: int, dy: int) -> String:
	var p := pos()
	var tx := p.x + dx
	var ty := p.y + dy
	var b := block(tx, ty)
	if b == "":
		return "open"
	if b == "granite":
		return "granite"
	if pick() <= 0:
		return "notool"
	if pick() < need_tool(tx, ty):
		return "tool"
	if stamina() < dig_cost(tx, ty):
		return "tired"
	return ""

func digging() -> bool:
	return not run().get("dig", {}).is_empty()

func dig_target() -> Vector2i:
	var d: Dictionary = run().get("dig", {})
	return Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))

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

## 加速（测试用）：把挖掘的截止时刻和炸弹的引线平移 delta_ms（负数 = 往前拉）。
func shift(delta_ms: int) -> void:
	var d: Dictionary = run().get("dig", {})
	if not d.is_empty():
		d["t0"] = int(d["t0"]) + delta_ms
		d["t1"] = int(d["t1"]) + delta_ms
	for b in run().get("booms", []):
		b["t1"] = int(b["t1"]) + delta_ms

## ---- 顺滑走动：位置是小数（以格为单位，格子中心是 x+0.5），碰撞盒比一格小 ----
const HB := Vector2(0.3, 0.28)

## 小猫脚下的精确位置。存的整数格变了（下楼、测试直接改）就以整数格中心为准。
func fpos() -> Vector2:
	var r := run()
	var x := int(r.get("x", 0))
	var y := int(r.get("y", 0))
	if r.has("fx"):
		var f := Vector2(float(r["fx"]), float(r["fy"]))
		if int(floor(f.x)) == x and int(floor(f.y)) == y:
			return f
	return Vector2(x + 0.5, y + 0.5)

func _free_at(p: Vector2) -> bool:
	for cy in range(int(floor(p.y - HB.y)), int(floor(p.y + HB.y)) + 1):
		for cx in range(int(floor(p.x - HB.x)), int(floor(p.x + HB.x)) + 1):
			if block(cx, cy) != "":
				return false
	return true

## 按方向走一小段（单位：格）。撞墙就停；差一点对齐时自动往格子中间挪，好钻进一格宽的路。
func walk(dx: float, dy: float) -> bool:
	if not in_run():
		return false
	var p := fpos()
	var p0 := p
	if dx != 0.0:
		var q := Vector2(p.x + dx, p.y)
		if _free_at(q):
			p = q
		else:
			var off: float = (floor(p.y) + 0.5) - p.y
			if absf(off) < 0.4 and absf(off) > 0.001:
				var q2 := Vector2(p.x, p.y + signf(off) * minf(absf(off), absf(dx)))
				if _free_at(q2):
					p = q2
	if dy != 0.0:
		var q := Vector2(p.x, p.y + dy)
		if _free_at(q):
			p = q
		else:
			var off: float = (floor(p.x) + 0.5) - p.x
			if absf(off) < 0.4 and absf(off) > 0.001:
				var q2 := Vector2(p.x + signf(off) * minf(absf(off), absf(dy)), p.y)
				if _free_at(q2):
					p = q2
	if p == p0:
		return false
	var r := run()
	r["fx"] = p.x
	r["fy"] = p.y
	r["x"] = int(floor(p.x))
	r["y"] = int(floor(p.y))
	return true

## 走进相邻的空格（四个方向都行；一格一格走，测试和旧逻辑用）。
func move(dx: int, dy: int, now_ms: int = 0) -> bool:
	var p := pos()
	var tx := p.x + dx
	var ty := p.y + dy
	if block(tx, ty) != "":
		return false
	if digging():
		stop_dig(now_ms)
	run()["x"] = tx
	run()["y"] = ty
	run().erase("fx")
	run().erase("fy")
	return true

## ---- 出口和台阶 ----
func on_entrance() -> bool:
	return in_run() and pos() == entrance(floor_n())

func on_exit() -> bool:
	return in_run() and pos() == exit_pos(floor_n()) and is_dug(pos().x, pos().y)

func has_elevator() -> bool:
	return floor_n() % checkpoint_every() == 0

## 站在挖开的出口上：下一层。
func descend() -> bool:
	if not on_exit():
		return false
	stop_dig(0)
	var f := floor_n() + 1
	run()["floor"] = f
	var en := entrance(f)
	run()["x"] = en.x
	run()["y"] = en.y
	run().erase("fx")
	run().erase("fy")
	run()["best"] = maxi(int(run().get("best", 1)), f)
	var st := shaft_state(shaft_id())
	st["best"] = maxi(int(st.get("best", 0)), f)
	if f % checkpoint_every() == 0:
		st["cp"] = maxi(int(st.get("cp", 1)), f)
	return true

## 站在入口台阶上：返回 "hall"，由界面（二次确认后）调用 end_run 回地面结算。
func ascend() -> String:
	if not on_entrance():
		return ""
	stop_dig(0)
	return "hall"

## ---- 炸弹 ----
func place_bomb(now_ms: int) -> String:
	if not in_run():
		return "none"
	if bombs() <= 0:
		return "empty"
	var p := pos()
	for b in run()["booms"]:
		if int(b["f"]) == floor_n() and int(b["x"]) == p.x and int(b["y"]) == p.y:
			return "busy"
	m()["bombs"] = bombs() - 1
	run()["booms"].append({"f": floor_n(), "x": p.x, "y": p.y, "t1": now_ms + int(_c.get("bomb", {}).get("fuse_ms", 1100))})
	return ""

func live_bombs() -> Array:
	var out: Array = []
	for b in run().get("booms", []):
		if int(b["f"]) == floor_n():
			out.append(b)
	return out

## ---- 推进时间 ----
## 事件：{"type":"dug","x","y","ore","gold","item","n","lost","chest","tnt","chain"}、{"type":"boom","x","y"}
func update(now_ms: int) -> Array:
	var ev: Array = []
	if not in_run():
		return ev
	var d: Dictionary = run().get("dig", {})
	if not d.is_empty() and now_ms >= int(d["t1"]):
		var x := int(d["x"])
		var y := int(d["y"])
		var dir: Array = run().get("dir", [0, 0])
		run()["sta"] = maxi(0, stamina() - dig_cost(x, y))
		_break_chain(x, y, int(dir[0]), int(dir[1]), ev, 0)
		run()["dig"] = {}
		run()["dir"] = [0, 0]
	var keep: Array = []
	var due: Array = []
	for b in run().get("booms", []):
		if now_ms >= int(b["t1"]):
			due.append(b)
		else:
			keep.append(b)
	run()["booms"] = keep
	for b in due:
		_detonate(int(b["f"]), int(b["x"]), int(b["y"]), ev)
	return ev

func _breakable(x: int, y: int) -> bool:
	var b := block(x, y)
	return b != "" and b != "granite"

## 炸弹爆炸：半径内的块全碎（镐等级最多高 1 级），炸药桶接着炸。
func _detonate(f: int, bx: int, by: int, ev: Array) -> void:
	if f != floor_n():
		return                          # 不在这一层：算哑弹
	ev.append({"type": "boom", "x": bx, "y": by})
	var r := blast_radius()
	for y in range(by - r, by + r + 1):
		for x in range(bx - r, bx + r + 1):
			if _breakable(x, y) and pick() + 1 >= need_tool(x, y):
				_break_chain(x, y, 0, 0, ev, 0)

## 挖开一格，处理连锁：炸药桶炸周围一圈；金矿、金属矿连成一片时一起碎。
func _break_chain(x: int, y: int, dx: int, dy: int, ev: Array, depth: int) -> void:
	if depth > 60:
		return
	var e := _break_cell(x, y)
	if e.is_empty():
		return
	ev.append(e)
	var o := str(e["ore"])
	if o == "tnt":
		ev.append({"type": "boom", "x": x, "y": y})
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if (ox != 0 or oy != 0) and _breakable(x + ox, y + oy):
					_break_chain(x + ox, y + oy, 0, 0, ev, depth + 1)
	elif o in CHAIN_ORES:
		var group := _vein(x, y, o)
		if group.size() + 1 >= int(_c.get("chain_min", 3)):
			for c in group:
				var e2 := _break_cell(c.x, c.y)
				if not e2.is_empty():
					e2["chain"] = true
					ev.append(e2)
	# 震波：只让前方那一格先裂开一截（最多到一半），免得一路连着挖穿
	var sh := float(perk_def("shock").get("v", 0.15)) * float(perk_count("shock"))
	if sh > 0.0 and depth == 0 and (dx != 0 or dy != 0) and _breakable(x + dx, y + dy):
		var k2 := _key(x + dx, y + dy)
		run()["partial"][k2] = minf(0.5, float(run()["partial"].get(k2, 0.0)) + sh)

## 和 (x, y) 相邻、同一种矿、还没挖的格子（不含自己，最多 8 个）。
func _vein(x: int, y: int, o: String) -> Array:
	var out: Array = []
	var seen := {Vector2i(x, y): true}
	var queue: Array = [Vector2i(x, y)]
	while not queue.is_empty() and out.size() < 8:
		var c: Vector2i = queue.pop_front()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if seen.has(n):
				continue
			seen[n] = true
			if _breakable(n.x, n.y) and ore(n.x, n.y) == o:
				out.append(n)
				queue.append(n)
	return out

## 挖开一格并发奖励（同一格只发一次）。已经挖开的返回空字典。
func _break_cell(x: int, y: int) -> Dictionary:
	if not _breakable(x, y):
		return {}
	var key := _key(x, y)
	run()["dug"][key] = 1
	run()["partial"].erase(key)
	var o := ore(x, y)
	var e := {"type": "dug", "x": x, "y": y, "ore": o, "gold": 0, "item": "", "n": 0, "lost": false, "chest": false, "tnt": o == "tnt", "chain": false}
	var od := ore_def(o)
	if od.is_empty():
		return e
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), floor_n(), x, y, "g"])
	var gold := 0
	var item := ""
	var cnt := 0
	if od.has("gold"):
		var g: Array = od["gold"]
		gold = int(round(float(rng.randi_range(int(g[0]), int(g[1]))) * (1.0 + 0.12 * float(floor_n()))))
	if od.has("item"):
		item = str(od["item"])
		cnt = 1
		if perk_count("loot") > 0 and rng.randf() < float(perk_def("loot").get("v", 0.3)) * float(perk_count("loot")):
			cnt = 2
	if o == "chest":
		e["chest"] = true
		if draft().is_empty():
			_roll_draft()
	if bag_full():
		e["lost"] = true
		e["gold"] = gold
		e["item"] = item
		e["n"] = cnt
		return e
	var b: Dictionary = run()["bag"]
	b["n"] = int(b["n"]) + 1
	b["coins"] = int(b["coins"]) + gold
	if item != "":
		b[item] = int(b.get(item, 0)) + cnt
	e["gold"] = gold
	e["item"] = item
	e["n"] = cnt
	return e

## ---- 工具店 ----
## 下一级要什么：{"gold": 铜币, "items": {id: n}}；已经最高级返回空。
func next_cost(kind: String) -> Dictionary:
	if kind == "bag":
		var b: Dictionary = _c.get("bag", {})
		var lv := bag_lv() + 1
		if lv >= (b.get("sizes", []) as Array).size():
			return {}
		return {"gold": int(b["prices"][lv]), "items": {}}
	var arr: Array = _c.get("picks" if kind == "pick" else "lamps", [])
	var lv2 := (pick() if kind == "pick" else lamp()) + 1
	if lv2 >= arr.size():
		return {}
	return {"gold": int(arr[lv2].get("price", 0)), "items": arr[lv2].get("items", {})}

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
	match kind:
		"pick": m()["pick"] = pick() + 1
		"lamp": m()["lamp"] = lamp() + 1
		"bag": m()["bag_lv"] = bag_lv() + 1
	return ""

func bomb_price() -> int:
	return int(_c.get("bomb", {}).get("price", 40))

func bomb_carry() -> int:
	return int(_c.get("bomb", {}).get("carry", 20))

func buy_bomb() -> String:
	if bombs() >= bomb_carry():
		return "full"
	if _s.wallet_gold < bomb_price():
		return "gold"
	_s.wallet_gold -= bomb_price()
	m()["bombs"] = bombs() + 1
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
