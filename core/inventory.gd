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
	var cap := int(by_id[id].get("max_stack", 0))      # 鱼饵最多 99 个，其他物品没有上限
	var total := count(s, id) + n
	if cap > 0:
		total = mini(total, cap)
		if total <= count(s, id):
			return false
	s.inventory[id] = total
	s.revision += 1
	return true

## ---- 家里的仓库 ----
func count_w(s: GameState, id: String) -> int:
	return int(s.warehouse.get(id, 0))

func owned_w(s: GameState) -> Array:
	var out: Array = []
	for d in defs:
		if count_w(s, d["id"]) > 0:
			out.append(d["id"])
	return out

## 把物品栏里的 n 个存进仓库（不够就存剩下的），返回实际存了几个。仓库没有数量上限。
func stash(s: GameState, id: String, n: int = 1) -> int:
	var moved := mini(n, count(s, id))
	if not by_id.has(id) or moved <= 0:
		return 0
	var left := count(s, id) - moved
	if left > 0:
		s.inventory[id] = left
	else:
		s.inventory.erase(id)
		if s.equipped_bait == id:
			s.equipped_bait = ""      # 装着的鱼饵都存走了，换回面团
	s.warehouse[id] = count_w(s, id) + moved
	s.revision += 1
	return moved

## 从仓库取 n 个回物品栏（受鱼饵 99 个上限限制，放不下的留在仓库），返回实际取了几个。
func fetch(s: GameState, id: String, n: int = 1) -> int:
	var moved := mini(n, count_w(s, id))
	if not by_id.has(id) or moved <= 0:
		return 0
	var cap := int(by_id[id].get("max_stack", 0))
	if cap > 0:
		moved = mini(moved, cap - count(s, id))
		if moved <= 0:
			return 0
	var left := count_w(s, id) - moved
	if left > 0:
		s.warehouse[id] = left
	else:
		s.warehouse.erase(id)
	s.inventory[id] = count(s, id) + moved
	s.revision += 1
	return moved

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

## 按权重抽一种物品。drop 不空时只在 drop 字段等于它的物品里抽（宝箱用 "chest"）；空 = 全部（鸟送礼）。
func roll(rng: RandomNumberGenerator, drop: String = "") -> String:
	var pool: Array = []
	var total := 0.0
	for d in defs:
		if drop != "" and str(d.get("drop", "")) != drop:
			continue
		pool.append(d)
		total += float(d.get("weight", 0))
	if total <= 0.0 or pool.is_empty():
		return ""
	var r := rng.randf() * total
	for d in pool:
		r -= float(d.get("weight", 0))
		if r < 0.0:
			return d["id"]
	return pool[-1]["id"]

## 直接扣掉 n 个（任务交付用，不看物品能不能"使用"）。数量不够返回 false，什么也不扣。
func remove(s: GameState, id: String, n: int = 1) -> bool:
	if n <= 0 or count(s, id) < n:
		return false
	var left := count(s, id) - n
	if left > 0:
		s.inventory[id] = left
	else:
		s.inventory.erase(id)
	s.revision += 1
	return true
