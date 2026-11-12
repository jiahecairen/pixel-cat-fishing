extends RefCounted
## 经济规则：鱼获入篓、出售、番茄结算。全部幂等——同一个 id 重复提交不会重复生效。

const GameState := preload("res://core/game_state.gd")

var _prices: Dictionary = {}

func _init(fish_table: Array) -> void:
	for f in fish_table:
		_prices[f["id"]] = int(f["price"])

func price_of(fish_id: String) -> int:
	return int(_prices.get(fish_id, 0))

func value_of(fish_ids: Array) -> int:
	var total := 0
	for id in fish_ids:
		total += price_of(id)
	return total

func basket_full(s: GameState) -> bool:
	return s.basket.size() >= s.basket_capacity

## 记录一次鱼获。to_haul=true 进入番茄渔获（不限量），否则进鱼篓（受容量限制）。
func add_catch(s: GameState, catch_id: String, fish_id: String, to_haul: bool) -> bool:
	if catch_id in s.processed_catch_ids or not _prices.has(fish_id):
		return false
	if not to_haul and basket_full(s):
		return false
	_remember(s.processed_catch_ids, catch_id)
	if to_haul:
		s.session_haul.append(fish_id)
	else:
		s.basket.append(fish_id)
	s.stats["total_fish"] = int(s.stats["total_fish"]) + 1
	var counts: Dictionary = s.stats["fish_counts"]
	counts[fish_id] = int(counts.get(fish_id, 0)) + 1
	s.revision += 1
	return true

## 卖掉鱼篓里所有的鱼，返回获得的金币。
func sell_basket(s: GameState, sale_id: String) -> int:
	if sale_id in s.processed_sale_ids or s.basket.is_empty():
		return 0
	var gold := value_of(s.basket)
	_remember(s.processed_sale_ids, sale_id)
	s.basket.clear()
	s.wallet_gold += gold
	s.revision += 1
	return gold

## 结算番茄渔获。multiplier/bonus 由番茄钟是否完成决定。
func settle_haul(s: GameState, sale_id: String, multiplier: float, bonus: int) -> int:
	if sale_id in s.processed_sale_ids:
		return 0
	var gold := int(round(value_of(s.session_haul) * multiplier)) + bonus
	_remember(s.processed_sale_ids, sale_id)
	s.session_haul.clear()
	s.wallet_gold += gold
	s.revision += 1
	return gold

static func _remember(list: Array, id: String) -> void:
	list.append(id)
	while list.size() > GameState.MAX_PROCESSED_IDS:
		list.pop_front()
