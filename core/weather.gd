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

## 由太阳高度（度）得到天色：dark 0..1（夜里 1，太阳在 +2° 以上为 0，-10° 以下为 1），
## warm 0..1（日出日落前后的暖色，太阳在 +1.5° 附近最浓）。dawn 表示上午（太阳在升）。
static func light(sun_alt: float, dawn: bool) -> Dictionary:
	return {
		"dark": clampf((2.0 - sun_alt) / 12.0, 0.0, 1.0),
		"warm": maxf(0.0, 1.0 - absf(sun_alt - 1.5) / 7.0),
		"dawn": dawn,
	}
