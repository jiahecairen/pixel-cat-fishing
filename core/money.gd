class_name Money
extends RefCounted
## 货币：内部一律用铜币计数（wallet_gold 就是铜币数）。10 铜 = 1 银，10 银 = 1 金（100 铜 = 1 金）。
## 显示只写最高的一档，去尾：8 铜显示 8 铜，19 铜显示 1 银，189 铜显示 1 金。钱包最多 999 金。

const PER_SILVER := 10
const PER_GOLD := 100
const WALLET_CAP := 99900      # 999 金

## 返回 ["copper"|"silver"|"gold", 数量]。
static func tier(copper: int) -> Array:
	if copper >= PER_GOLD:
		return ["gold", copper / PER_GOLD]
	if copper >= PER_SILVER:
		return ["silver", copper / PER_SILVER]
	return ["copper", copper]

## 对应的图标名。
static func icon(copper: int) -> String:
	match tier(copper)[0]:
		"gold": return "coin"
		"silver": return "coin_silver"
	return "coin_copper"

## 完整写法：[[档位, 数量], ...]，从大到小，数量为 0 的档不写；一分钱都没有就是 [["copper", 0]]。
## 189 铜 → [["gold", 1], ["silver", 8], ["copper", 9]]。商品价格和状态页的钱包都用这个。
static func parts(copper: int) -> Array:
	var out: Array = []
	var g := copper / PER_GOLD
	var s := (copper % PER_GOLD) / PER_SILVER
	var c := copper % PER_SILVER
	if g > 0:
		out.append(["gold", g])
	if s > 0:
		out.append(["silver", s])
	if c > 0 or out.is_empty():
		out.append(["copper", c])
	return out

static func icon_of(tier_name: String) -> String:
	match tier_name:
		"gold": return "coin"
		"silver": return "coin_silver"
	return "coin_copper"
