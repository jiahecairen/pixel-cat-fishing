extends RefCounted
## 物品栏：物品从宝箱里开出来，同种叠加，没有容量上限。
## 物品定义来自 balance.json 的 "items"：
##   id / name / desc / sprite   基本信息
##   weight                      宝箱里开出它的权重
##   use                         "" 不能用；"gold" 得金币；"lucky" 一段时间内更走运；"bell" 接下来几单翻倍
##   need                        使用一次消耗几个（默认 1；藏宝图碎片是 4）
## 这里只管"有几个、能不能用、扣掉"，使用后的效果由 Game.use_item 负责。

const GameState := preload("res://core/game_state.gd")

var defs: Array = []
var by_id: Dictionary = {}

func _init(item_defs: Array) -> void:
	defs = item_defs
	for d in defs:
		by_id[d["id"]] = d

func count(s: GameState, id: String) -> int:
	return int(s.inventory.get(id, 0))

func add(s: GameState, id: String, n: int = 1) -> bool:
	if not by_id.has(id) or n <= 0:
		return false
	s.inventory[id] = count(s, id) + n
	s.revision += 1
	return true

## 玩家手里有的物品 id，按定义顺序排列。
func owned(s: GameState) -> Array:
	var out: Array = []
	for d in defs:
		if count(s, d["id"]) > 0:
			out.append(d["id"])
	return out

func need(id: String) -> int:
	return maxi(1, int(by_id.get(id, {}).get("need", 1)))

func can_use(s: GameState, id: String) -> bool:
	return by_id.has(id) and str(by_id[id].get("use", "")) != "" and count(s, id) >= need(id)

## 扣掉使用一次所需的数量。
func consume(s: GameState, id: String) -> bool:
	if not can_use(s, id):
		return false
	var left := count(s, id) - need(id)
	if left > 0:
		s.inventory[id] = left
	else:
		s.inventory.erase(id)
	s.revision += 1
	return true

## 按权重抽一种物品（宝箱用）。
func roll(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for d in defs:
		total += float(d.get("weight", 0))
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for d in defs:
		r -= float(d.get("weight", 0))
		if r < 0.0:
			return d["id"]
	return defs[-1]["id"]
