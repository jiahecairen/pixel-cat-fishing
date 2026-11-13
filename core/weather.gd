class_name Weather
extends RefCounted
## 天气与昼夜。全是"本地时间 → 结果"的纯函数：同一时刻永远得到同一结果，
## 所以不需要存档，重启游戏、换设备（同一时区）看到的都是同样的天气。
## 参数 local_s 是本地时间的秒数（Unix 秒 + 时区偏移）。

const BLOCK_S := 7200            # 每 2 小时一个"时段"，每个时段按概率决定要不要下雨

## 整数哈希（结果在 0..2^31-1），只靠位运算，不依赖随机数状态。
static func _h(n: int) -> int:
	var x: int = n * 0x1E3779B97F4A7C15
	x = (x ^ (x >> 29)) * 0x3F58476D1CE4E5B9
	x = x ^ (x >> 32)
	return x & 0x7fffffff

## 这一刻在不在下雨。被选中的时段里下 60–90 分钟，起止时刻也由哈希定。
static func is_raining(local_s: int, block_chance: float) -> bool:
	var block := floori(local_s / float(BLOCK_S))
	if float(_h(block * 2 + 1) % 10000) / 10000.0 >= block_chance:
		return false
	var length := 3600 + _h(block * 2 + 2) % 1801
	var start := _h(block * 3 + 7) % (BLOCK_S - length + 1)
	var off := local_s - block * BLOCK_S
	return off >= start and off < start + length

## 本地钟点（0..24 的小数）。
static func hour(local_s: int) -> float:
	return float(posmod(local_s, 86400)) / 3600.0

## 昼夜：dark 0..1（夜里 1），warm 0..1（日出/日落前后的暖色），dawn 表示暖色是清晨的还是傍晚的。
static func daylight(local_s: int) -> Dictionary:
	var h := float(posmod(local_s, 86400)) / 3600.0
	var dark := 0.0
	if h >= 20.0 or h < 5.0:
		dark = 1.0
	elif h < 7.0:
		dark = (7.0 - h) / 2.0
	elif h >= 18.0:
		dark = (h - 18.0) / 2.0
	var warm := maxf(0.0, 1.0 - absf(h - 6.0) / 1.5)
	var dusk_warm := maxf(0.0, 1.0 - absf(h - 18.5) / 1.5)
	return {"dark": dark, "warm": maxf(warm, dusk_warm), "dawn": h < 12.0}
