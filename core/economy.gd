extends RefCounted
## 经济规则：鱼获入篓、出售、番茄结算。全部幂等——同一个 id 重复提交不会重复生效。

const GameState := preload("res://core/game_state.gd")

var _prices: Dictionary = {}
var _rarity: Dictionary = {}
var _units: Dictionary = {}       # 每种鱼占鱼篓多少单位（大鱼多、小鱼少）

func _init(fish_table: Array) -> void:
	for f in fish_table:
		_prices[f["id"]] = int(f["price"])
		_rarity[f["id"]] = int(f.get("rarity", 0))
		_units[f["id"]] = float(f.get("units", 1.0))

func price_of(fish_id: String) -> int:
	return int(_prices.get(fish_id, 0))

func value_of(fish_ids: Array) -> int:
	var total := 0
	for id in fish_ids:
		total += price_of(id)
	return total

func units_of(fish_id: String) -> float:
	return float(_units.get(fish_id, 1.0))

## 鱼篓里的鱼一共占了多少单位。
func basket_used(s: GameState) -> float:
	var total := 0.0
	for id in s.basket:
		total += units_of(id)
	return total

## 鱼篓装了百分之几（0..100，最多显示 100；最后一条大鱼可以超出一点，算 100）。
func basket_percent(s: GameState) -> int:
	return clampi(int(basket_used(s) / maxf(0.1, s.basket_capacity) * 100.0), 0, 100)

## 装满了：占用的单位达到容量。最后一条鱼可以超出一点点，所以大鱼不会被"卡在门外"。
func basket_full(s: GameState) -> bool:
	return basket_used(s) >= s.basket_capacity - 0.0001

## 记录一次鱼获。to_haul=true 进入番茄渔获（不限量），否则进鱼篓（受容量限制）。
var last_removed_size: int = 0      # 刚被拿走（偷/吃/卖）的那条鱼的尺寸

func add_catch(s: GameState, catch_id: String, fish_id: String, to_haul: bool, size: int = 0) -> bool:
	if catch_id in s.processed_catch_ids or not _prices.has(fish_id):
		return false
	if not to_haul and basket_full(s):
		return false
	_remember(s.processed_catch_ids, catch_id)
	if to_haul:
		s.session_haul.append(fish_id)
	else:
		s.basket.append(fish_id)
		s.basket_sizes.append(size)
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
	s.basket_sizes.clear()
	s.wallet_gold += gold
	s.revision += 1
	return gold

## 打开钓上来的宝箱：金币直接入账，不占鱼篓也不进木箱。同一个 id 只生效一次。
func open_chest(s: GameState, chest_id: String, gold: int) -> bool:
	if chest_id in s.processed_catch_ids or gold < 0:
		return false
	_remember(s.processed_catch_ids, chest_id)
	s.wallet_gold += gold
	s.stats["chests"] = int(s.stats.get("chests", 0)) + 1
	s.revision += 1
	return true

## 发一笔铜币奖励（任务、信号台、拾到的钱）：同一个 id 只生效一次。
func grant_gold(s: GameState, grant_id: String, gold: int) -> bool:
	if grant_id in s.processed_catch_ids or gold <= 0:
		return false
	_remember(s.processed_catch_ids, grant_id)
	s.wallet_gold += gold
	s.revision += 1
	return true

## 摆摊卖出鱼篓里的一条鱼。返回 {"fish_id", "gold"}；没卖成返回空字典。
func sell_one(s: GameState, sale_id: String, multiplier: float = 1.0) -> Dictionary:
	if sale_id in s.processed_sale_ids or s.basket.is_empty():
		return {}
	var fish_id: String = s.basket.pop_front()
	last_removed_size = int(s.basket_sizes.pop_front()) if not s.basket_sizes.is_empty() else 0
	var gold := int(round(price_of(fish_id) * multiplier))
	_remember(s.processed_sale_ids, sale_id)
	s.wallet_gold += gold
	s.revision += 1
	return {"fish_id": fish_id, "gold": gold}

## 小猫偷吃：吃掉鱼篓里最便宜的一条普通鱼（稀有鱼 rarity>=2 不吃）。返回被吃的鱼 id，没得吃返回 ""。
## 篓里最便宜的非稀有鱼（鸟会偷这一条）；没有返回空字符串。不改动篓子。
func cheapest_common(s: GameState) -> String:
	var best := -1
	for i in s.basket.size():
		var id: String = s.basket[i]
		if int(_rarity.get(id, 0)) >= 2:
			continue
		if best < 0 or price_of(id) < price_of(s.basket[best]):
			best = i
	return "" if best < 0 else s.basket[best]

func eat_cheapest(s: GameState) -> String:
	var best := -1
	for i in s.basket.size():
		var id: String = s.basket[i]
		if int(_rarity.get(id, 0)) >= 2:
			continue
		if best < 0 or price_of(id) < price_of(s.basket[best]):
			best = i
	if best < 0:
		return ""
	var eaten: String = s.basket[best]
	last_removed_size = int(s.basket_sizes[best]) if best < s.basket_sizes.size() else 0
	s.basket.remove_at(best)
	if best < s.basket_sizes.size():
		s.basket_sizes.remove_at(best)
	s.revision += 1
	return eaten

## 结算番茄渔获（木箱）。multiplier/bonus 由番茄钟是否完成决定。
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
