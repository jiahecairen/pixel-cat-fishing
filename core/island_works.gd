extends RefCounted
## 雾灯岛的修理厂和酒馆：修理项目（投入材料，等工人干完）、雇佣岛民（花钱和材料）。
## 纯逻辑，不碰节点；时间用传进来的毫秒时间戳。数据在 balance.json 的 "works"。
##
## 存档：effects["rp_<项目id>"]：0 = 还没开工；大于 1 = 完工的时间戳；1 = 已完工。effects["workers"] = 雇了几位。

const GameState := preload("res://core/game_state.gd")
const Inventory := preload("res://core/inventory.gd")

var _state: GameState
var _cfg: Dictionary
var _inv: Inventory

func _init(state: GameState, cfg: Dictionary, inventory: Inventory) -> void:
	_state = state
	_cfg = cfg
	_inv = inventory

func projects() -> Array:
	return _cfg.get("projects", [])

func project(id: String) -> Dictionary:
	for p in projects():
		if str(p["id"]) == id:
			return p
	return {}

func _key(id: String) -> String:
	return "rp_%s" % id

func workers() -> int:
	return int(_state.effects.get("workers", 0))

func max_workers() -> int:
	return (_cfg.get("workers", []) as Array).size()

## "locked"（前置没做完）/"idle"（可以开工）/"building"/"done"
func status(id: String) -> String:
	var v := int(_state.effects.get(_key(id), 0))
	var fl := str(project(id).get("flag", ""))
	if v == 1 or (fl != "" and int(_state.effects.get(fl, 0)) == 1):
		return "done"
	if v > 1:
		return "building"
	var req := str(project(id).get("requires", ""))
	if req != "" and status(req) != "done":
		return "locked"
	return "idle"

func is_done(id: String) -> bool:
	return status(id) == "done"

func ends_ms(id: String) -> int:
	return int(_state.effects.get(_key(id), 0))

## 开工到完工要几分钟：基础时间 /（1 + 工人数 × 0.5）。
func duration_min(id: String) -> float:
	return float(project(id).get("minutes", 20)) / (1.0 + 0.5 * float(workers()))

func needs_workers(id: String) -> int:
	return int(project(id).get("workers", 0))

## 材料够不够：返回缺的 [[物品, 缺几个], ...]，空数组 = 够了。
func missing(id: String) -> Array:
	var out: Array = []
	for c in project(id).get("cost", []):
		var have: int = _inv.count(_state, str(c[0]))
		if have < int(c[1]):
			out.append([str(c[0]), int(c[1]) - have])
	return out

func can_start(id: String) -> bool:
	return status(id) == "idle" and workers() >= needs_workers(id) and missing(id).is_empty()

func start(id: String, now_ms: int) -> bool:
	if not can_start(id):
		return false
	for c in project(id).get("cost", []):
		_inv.remove(_state, str(c[0]), int(c[1]))
	_state.effects[_key(id)] = now_ms + int(duration_min(id) * 60000.0)
	_state.revision += 1
	return true

## 到点的项目转成"已完工"，返回这次刚完工的项目 id。
func update(now_ms: int) -> Array:
	var done: Array = []
	for p in projects():
		var id := str(p["id"])
		var v := int(_state.effects.get(_key(id), 0))
		if v > 1 and now_ms >= v:
			_state.effects[_key(id)] = 1
			if str(p.get("flag", "")) != "":
				_state.effects[str(p["flag"])] = 1
			done.append(id)
	if not done.is_empty():
		_state.revision += 1
	return done

# ------------------------------------------------------------------ 酒馆：雇佣
func worker_def(i: int) -> Dictionary:
	var l: Array = _cfg.get("workers", [])
	return l[i] if i >= 0 and i < l.size() else {}

func next_worker() -> Dictionary:
	return worker_def(workers())

func hire_missing() -> Array:
	var w := next_worker()
	var out: Array = []
	if w.is_empty():
		return out
	if _state.wallet_gold < int(w.get("copper", 0)):
		out.append(["copper", int(w["copper"]) - _state.wallet_gold])
	for c in w.get("items", []):
		var have: int = _inv.count(_state, str(c[0]))
		if have < int(c[1]):
			out.append([str(c[0]), int(c[1]) - have])
	return out

func can_hire() -> bool:
	return not next_worker().is_empty() and hire_missing().is_empty()

func hire() -> bool:
	if not can_hire():
		return false
	var w := next_worker()
	_state.wallet_gold -= int(w.get("copper", 0))
	for c in w.get("items", []):
		_inv.remove(_state, str(c[0]), int(c[1]))
	_state.effects["workers"] = workers() + 1
	_state.revision += 1
	return true

## 酒馆里按行雇佣：只能按顺序雇，所以第 i 行必须正好是下一位。
func hire_one(i: int) -> bool:
	return i == workers() and hire()
