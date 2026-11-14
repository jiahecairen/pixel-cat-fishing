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
	if not d.has("sta"):                           # 体力是跨局的：第一次进矿是满的
		d["sta"] = float(stamina_max())
	run().erase("sta")
	run().erase("draft")
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
		"bag": {"n": 0, "coins": 0, "stone": 0, "metal": 0},
	}
	if int(dish_by_id(dish).get("stamina", 0)) > 0:      # 出发前吃的菜：体力加成（可以超过上限）
		m()["sta"] = minf(float(stamina_max()) * float(_c.get("stamina", {}).get("cap_mult", 1.3)), stamina_f() + float(dish_by_id(dish).get("stamina", 0)))
	var en := entrance(start_floor)
	run()["x"] = en.x
	run()["y"] = en.y
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

func perk_count(_id: String) -> int:
	return 0

## 当前待选的 3 个天赋（没有就是空）。
func draft() -> Array:
	return []                           # v0.78：取消了下井和宝箱的技能选择，不再有肉鸽技能

## 体力（跨局保存）：挖的时候按时间一点点消耗，越深越费；用完就挖不动了，只能走、放炸弹、回地面。
## 钓鱼、买东西只会非常慢地恢复；回家睡觉补满；旅店更快，高档房还能超过上限（最多 130%）。
func stamina_max() -> int:
	var sc: Dictionary = _c.get("stamina", {})
	return int(sc.get("start", 45)) + int(sc.get("per_pick", 10)) * maxi(0, pick() - 1)

func stamina_f() -> float:
	return float(m().get("sta", float(stamina_max())))

func stamina() -> int:
	return int(ceil(stamina_f() - 0.001))

func stamina_cap() -> float:
	return float(stamina_max()) * float(_c.get("stamina", {}).get("cap_mult", 1.3))

## 缓慢恢复（钓鱼、买东西）：不会超过上限。
func recover(n: float) -> void:
	if stamina_f() < float(stamina_max()):
		m()["sta"] = minf(float(stamina_max()), stamina_f() + n)

## 吃东西：回体力，不超过上限。已经满了返回 false（不消耗）。
func eat(n: float) -> bool:
	if stamina_f() >= float(stamina_max()):
		return false
	m()["sta"] = minf(float(stamina_max()), stamina_f() + n)
	return true

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

## ---- 背包：就是物品栏（挖到的东西直接进物品栏，放不下就带不走） ----
func bag_cap() -> int:
	return _s.bag_slots

func bag_n() -> int:
	return _inv.slots_used(_s)

func bag_full() -> bool:
	return _inv.room_for(_s, "stone", 1) < 1 and _inv.room_for(_s, "metal", 1) < 1 and _inv.room_for(_s, "gold_ore", 1) < 1

func bag() -> Dictionary:
	return {}

## 以前回地面才结算背包；现在东西直接进物品栏，这里什么都不用发。
func cash_out() -> Dictionary:
	return {"coins": 0, "stone": 0, "metal": 0, "lost": 0}

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
	rk[ex.y * W + ex.x] = 0                                 # 出口是个洞，不是石头
	for oy in range(-1, 2):                                  # 洞口一圈被石头堵着：到下一层至少要挖几块
		for ox in range(-1, 2):
			var gx := ex.x + ox
			var gy := ex.y + oy
			if (ox != 0 or oy != 0) and gx > 0 and gy > 0 and gx < W and gy < H and fl[gy * W + gx] == 1:
				rk[gy * W + gx] = 1
	# 补给木箱：地面上空着的地方，一层 1-3 个
	var ck := PackedByteArray()
	ck.resize(W * H)
	var n_chest: int = 1 + rng.randi() % 3
	var tries := 0
	while n_chest > 0 and tries < 200:
		tries += 1
		var cx: int = 2 + rng.randi() % maxi(1, W - 4)
		var cy: int = 6 + rng.randi() % maxi(1, H - 8)
		var far_ex := absi(cx - ex.x) > 2 or absi(cy - ex.y) > 2
		if fl[cy * W + cx] == 1 and rk[cy * W + cx] == 0 and far_ex and absi(cx - en.x) + cy > 8 and ck[cy * W + cx] == 0:
			ck[cy * W + cx] = 1
			n_chest -= 1
	var out := {"floor": fl, "rock": rk, "exit": ex, "chest": ck}
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
	if Vector2i(x, y) == exit_pos(floor_n()):
		return "pit"
	if is_dug(x, y):
		return ""
	if _layout(floor_n())["chest"][y * width() + x] == 1:
		return "chest"
	if not has_rock(x, y):
		return ""
	return str(layer(floor_n()).get("block", "deep"))

## 富矿脉：以 4×4 为一块，按种子有些块的矿物特别多。
func rich(x: int, y: int, f: int = -1) -> bool:
	return absi(hash([seed_(), floor_n() if f < 0 else f, x / 4, y / 4, "rich"])) % 5 == 0

## 格子里埋着什么："exit"（往下的洞）/ "tnt" / "gold" / "metal" / "chest" / "stone" / ""。
func ore(x: int, y: int) -> String:
	if not in_map(x, y) or Vector2i(x, y) == entrance(floor_n()) or not has_rock(x, y):
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), floor_n(), x, y])
	var r := rng.randf() * float(_c.get("layout", {}).get("ore_scale", 0.4))
	var k := luck_mul() * (2.2 if rich(x, y) else 1.0)
	var acc := 0.0
	for o in _c.get("ores", []):
		if floor_n() < int(o.get("min_y", 0)):
			continue
		var ch := float(o.get("chance", 0.0)) + float(o.get("deep_bonus", 0.0)) * float(floor_n())
		acc += ch * (k if str(o["id"]) in ["gold", "metal"] else 1.0)
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

## 面朝 (dx, dy) 伸手够得到的那一格：从脚下往前探 REACH 格，落在哪一格就是哪一格（不要求对齐）。
const REACH := 0.62
func target(dx: int, dy: int) -> Vector2i:
	var q := fpos() + Vector2(dx, dy) * REACH
	return Vector2i(int(floor(q.x)), int(floor(q.y)))

## 能不能朝 (dx, dy) 挖。""=可以，"open"=前面是空地，"granite"=岩壁，"pit"=下一层的洞，"chest"=补给箱（要打开不是挖），
## "notool"=没镐，"tool"=镐不够好，"tired"=没体力。
func dig_block_reason(dx: int, dy: int) -> String:
	var t := target(dx, dy)
	var tx := t.x
	var ty := t.y
	var b := block(tx, ty)
	if b == "":
		return "open"
	if b in ["granite", "pit", "chest"]:
		return b
	if pick() <= 0:
		return "notool"
	if pick() < need_tool(tx, ty):
		return "tool"
	if stamina_f() <= 0.05:
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
	var t := target(dx, dy)
	var tx := t.x
	var ty := t.y
	if digging() and dig_target() == Vector2i(tx, ty):
		return ""
	stop_dig(now_ms)
	var ms := dig_ms(tx, ty)
	var done := float(run().get("partial", {}).get(_key(tx, ty), 0.0))
	var t0 := now_ms - int(done * float(ms))
	run()["dig"] = {"x": tx, "y": ty, "t0": t0, "t1": t0 + ms, "ts": now_ms}
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
		d["ts"] = int(d.get("ts", 0)) + delta_ms
	for b in run().get("booms", []):
		b["t1"] = int(b["t1"]) + delta_ms
	var rs: Dictionary = m().get("rest", {})
	if not rs.is_empty():
		rs["t0"] = int(rs["t0"]) + delta_ms
		rs["t1"] = int(rs["t1"]) + delta_ms

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

## 石头只占格子正中一小块（比画出来的石头略小一点），木箱占大半格，洞口、岩壁占满一格。
const ROCK_HALF := 0.26
const CRATE_HALF := 0.4
func _free_at(p: Vector2) -> bool:
	for cy in range(int(floor(p.y - HB.y)), int(floor(p.y + HB.y)) + 1):
		for cx in range(int(floor(p.x - HB.x)), int(floor(p.x + HB.x)) + 1):
			var b := block(cx, cy)
			if b == "":
				continue
			if b in ["granite", "pit"]:
				return false
			var hf := CRATE_HALF if b == "chest" else ROCK_HALF
			if absf(p.x - (float(cx) + 0.5)) < hf + HB.x and absf(p.y - (float(cy) + 0.5)) < hf + HB.y:
				return false
	return true

## 按方向走一小段（单位：格）。撞墙就停；横竖分开处理，贴着墙能顺着滑（不会自动对齐到格子中间）。
func walk(dx: float, dy: float) -> bool:
	if not in_run():
		return false
	var p := fpos()
	var p0 := p
	if dx != 0.0 and _free_at(Vector2(p.x + dx, p.y)):
		p.x += dx
	if dy != 0.0 and _free_at(Vector2(p.x, p.y + dy)):
		p.y += dy
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

## 面朝 (dx, dy) 够得到的是不是下一层的洞。
func exit_ahead(dx: int, dy: int) -> bool:
	return in_run() and target(dx, dy) == exit_pos(floor_n())

func has_elevator() -> bool:
	return floor_n() % checkpoint_every() == 0

## 面朝下一层的洞、确认后：下到下一层。
func descend(dx: int = 0, dy: int = 0) -> bool:
	if not exit_ahead(dx, dy):
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
	if not d.is_empty():
		# 体力按时间一点点扣：整块石头的体力 = 这一层的体力价 × 挖了的比例（挥空不扣）
		var upto := mini(now_ms, int(d["t1"]))
		var span := float(maxi(1, int(d["t1"]) - int(d["t0"])))
		var drain := dig_cost(int(d["x"]), int(d["y"])) * float(maxi(0, upto - int(d.get("ts", upto)))) / span
		d["ts"] = upto
		if drain >= stamina_f():
			m()["sta"] = 0.0
			stop_dig(now_ms)
			ev.append({"type": "tired"})
			d = {}
		else:
			m()["sta"] = stamina_f() - drain
	if not d.is_empty() and now_ms >= int(d["t1"]):
		var x := int(d["x"])
		var y := int(d["y"])
		var dir: Array = run().get("dir", [0, 0])
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
	return b != "" and b not in ["granite", "pit", "chest"]

## 炸弹爆炸：半径内的石头全碎（镐等级最多高 1 级）。
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
	if false:
		pass
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
	var e := {"type": "dug", "x": x, "y": y, "ore": o, "gold": 0, "item": "", "n": 0, "lost": false, "chest": false, "tnt": false, "chain": false}
	var od := ore_def(o)
	if od.is_empty():
		return e
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), floor_n(), x, y, "g"])
	var item := ""
	var cnt := 0
	if od.has("item"):
		item = str(od["item"])
		cnt = 1
	if item == "":
		return e
	if _inv.room_for(_s, item, cnt) < cnt:
		e["lost"] = true
		e["item"] = item
		e["n"] = cnt
		return e
	_inv.add(_s, item, cnt)
	e["item"] = item
	e["n"] = cnt
	return e

## ---- 补给木箱 ----
## 面朝木箱按空格打开：里面是能吃的补给（进物品栏）或者一点钱。物品栏放不下就打不开。
func open_chest(dx: int, dy: int) -> Dictionary:
	var t := target(dx, dy)
	if not in_run() or block(t.x, t.y) != "chest":
		return {"ok": false, "why": "none"}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_(), floor_n(), t.x, t.y, "box"])
	var loot: Array = _c.get("chest_loot", [])
	var total := 0
	for l in loot:
		total += int(l.get("w", 1))
	var pick_i := rng.randi() % maxi(1, total)
	var chosen: Dictionary = {}
	for l in loot:
		pick_i -= int(l.get("w", 1))
		if pick_i < 0:
			chosen = l
			break
	var res := {"ok": true, "item": "", "n": 0, "gold": 0}
	if chosen.has("gold"):
		var g: Array = chosen["gold"]
		res["gold"] = int(round(float(rng.randi_range(int(g[0]), int(g[1]))) * (1.0 + 0.1 * float(floor_n()))))
	else:
		var n: int = int((chosen.get("n", [1, 1]) as Array)[0]) + rng.randi() % (int((chosen.get("n", [1, 1]) as Array)[1]) - int((chosen.get("n", [1, 1]) as Array)[0]) + 1)
		if _inv.room_for(_s, str(chosen.get("item", "")), n) < n:
			return {"ok": false, "why": "full"}
		_inv.add(_s, str(chosen["item"]), n)
		res["item"] = str(chosen["item"])
		res["n"] = n
	run()["dug"][_key(t.x, t.y)] = 1
	if int(res["gold"]) > 0:
		_s.wallet_gold = mini(MoneyC.WALLET_CAP, _s.wallet_gold + int(res["gold"]))
	res["x"] = t.x
	res["y"] = t.y
	return res

## ---- 休息：旅店 / 回家 ----
## 设计时长在 balance.json 的 rest；测试期间 rest.test_ms > 0 时全部只要这么多毫秒。
func inn_rooms() -> Array:
	return _c.get("rest", {}).get("rooms", [])

func rest_cfg() -> Dictionary:
	return _c.get("rest", {})

func resting() -> bool:
	return not m().get("rest", {}).is_empty()

func rest_info() -> Dictionary:
	return m().get("rest", {})

## kind："home" 或旅店房间 id。返回 ""=开始了，"gold"=钱不够，"busy"=已经在休息，"full"=已经满了（家里睡不会超过上限）。
func rest_start(kind: String, now_ms: int) -> String:
	if resting():
		return "busy"
	var room: Dictionary = {}
	if kind == "home":
		room = rest_cfg().get("home", {})
	else:
		for r in inn_rooms():
			if str(r["id"]) == kind:
				room = r
	if room.is_empty():
		return "none"
	var to := float(stamina_max()) * float(room.get("mult", 1.0))
	if stamina_f() >= to - 0.01:
		return "full"
	if _s.wallet_gold < int(room.get("price", 0)):
		return "gold"
	_s.wallet_gold -= int(room.get("price", 0))
	var ms := int(rest_cfg().get("test_ms", 0))
	if ms <= 0:
		ms = int(float(room.get("minutes", 10)) * 60000.0)
	m()["rest"] = {"kind": kind, "t0": now_ms, "t1": now_ms + ms, "from": stamina_f(), "to": to}
	return ""

func rest_progress(now_ms: int) -> float:
	var r := rest_info()
	if r.is_empty():
		return 0.0
	return clampf(float(now_ms - int(r["t0"])) / float(maxi(1, int(r["t1"]) - int(r["t0"]))), 0.0, 1.0)

## 休息中体力一点点涨；到点结束，返回 true。
func rest_update(now_ms: int) -> bool:
	var r := rest_info()
	if r.is_empty():
		return false
	var k := rest_progress(now_ms)
	m()["sta"] = lerpf(float(r["from"]), float(r["to"]), k)
	if now_ms >= int(r["t1"]):
		m()["sta"] = float(r["to"])
		m()["rest"] = {}
		return true
	return false

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
