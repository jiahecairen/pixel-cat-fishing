extends RefCounted
## 金币升级。每项升级的价格表和效果数值都来自 balance.json 的 "upgrades" 段。
##   rod    鱼竿：自由挂机的等待倍率逐级降低（最快也只到正常的 20–60 秒，不会更快）
##   bait   鱼饵：稀有鱼的出现权重提高
##   basket 鱼篓：容量增加

const GameState := preload("res://core/game_state.gd")

var _cfg: Dictionary

func _init(cfg: Dictionary) -> void:
	_cfg = cfg

func has(id: String) -> bool:
	return _cfg.get(id) is Dictionary and _cfg[id].get("costs") is Array

func level(s: GameState, id: String) -> int:
	return clampi(int(s.upgrades.get(id, 0)), 0, max_level(id))

func max_level(id: String) -> int:
	return _cfg[id]["costs"].size() if has(id) else 0

## 下一级的价格；已满级或不存在返回 -1。
func next_cost(s: GameState, id: String) -> int:
	if not has(id) or level(s, id) >= max_level(id):
		return -1
	return int(_cfg[id]["costs"][level(s, id)])

func can_buy(s: GameState, id: String) -> bool:
	var cost := next_cost(s, id)
	return cost >= 0 and s.wallet_gold >= cost

func buy(s: GameState, id: String) -> bool:
	if not can_buy(s, id):
		return false
	s.wallet_gold -= next_cost(s, id)
	s.upgrades[id] = level(s, id) + 1
	s.revision += 1
	return true

## 读取某项升级的数值参数（如 capacity_per_level）。
func param(id: String, key: String, default_value: float) -> float:
	if has(id):
		return float(_cfg[id].get(key, default_value))
	return default_value
