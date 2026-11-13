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
