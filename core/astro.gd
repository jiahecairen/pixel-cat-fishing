class_name Astro
extends RefCounted
## 天文计算：太阳高度、日出日落、月相、月亮的位置。全是纯函数（输入经纬度和 UTC 秒数）。
## 太阳用常见的低精度公式，日出日落误差在几分钟内；月亮的位置是简化模型（见 moon_u 的注释），
## 只用来决定"月亮大概在天上哪里"，不是星历。

const DEG := PI / 180.0
const SYNODIC_S := 29.530588853 * 86400.0
const NEW_MOON_REF := 947182440          # 2000-01-06 18:14 UTC 的新月
const HORIZON_ALT := -0.833              # 日出日落时太阳中心的高度（含大气折射和日面半径）

## 太阳高度角（度）。lat 北正，lon 东正。
static func sun_altitude(lat: float, lon: float, utc_s: float) -> float:
	var d := utc_s / 86400.0 - 10957.5                       # 距 J2000.0 的天数
	var l := fposmod(280.460 + 0.9856474 * d, 360.0)
	var g := fposmod(357.528 + 0.9856003 * d, 360.0) * DEG
	var lam := (l + 1.915 * sin(g) + 0.020 * sin(2.0 * g)) * DEG
	var eps := (23.439 - 0.0000004 * d) * DEG
	var dec := asin(sin(eps) * sin(lam))
	var ra := atan2(cos(eps) * sin(lam), cos(lam))
	var gmst := fposmod(280.46061837 + 360.98564736629 * d, 360.0)
	var ha := (gmst + lon) * DEG - ra
	return asin(sin(lat * DEG) * sin(dec) + cos(lat * DEG) * cos(dec) * cos(ha)) / DEG

## 当地平太阳时（0..24）。
static func solar_hour(lon: float, utc_s: float) -> float:
	return fposmod(utc_s / 3600.0 + lon / 15.0, 24.0)

## 当地"太阳日"的起点（UTC 秒）：当地平太阳时 0 点。
static func solar_day_start(lon: float, utc_s: float) -> float:
	var shift := lon / 15.0 * 3600.0
	return floorf((utc_s + shift) / 86400.0) * 86400.0 - shift

## 这一个太阳日里的日出、日落（UTC 秒，没有则 -1：极昼/极夜）和当天太阳最高高度。
static func sun_day(lat: float, lon: float, day_start: float) -> Dictionary:
	var rise := -1.0
	var sset := -1.0
	var peak := -90.0
	var step := 1200.0
	var prev := sun_altitude(lat, lon, day_start) - HORIZON_ALT
	peak = prev + HORIZON_ALT
	for i in range(1, 73):
		var t := day_start + i * step
		var cur := sun_altitude(lat, lon, t) - HORIZON_ALT
		peak = maxf(peak, cur + HORIZON_ALT)
		if prev < 0.0 and cur >= 0.0 and rise < 0.0:
			rise = _bisect(lat, lon, t - step, t)
		elif prev >= 0.0 and cur < 0.0 and sset < 0.0:
			sset = _bisect(lat, lon, t - step, t)
		prev = cur
	return {"rise": rise, "set": sset, "peak": peak}

static func _bisect(lat: float, lon: float, a: float, b: float) -> float:
	var fa := sun_altitude(lat, lon, a) - HORIZON_ALT
	for _i in 14:
		var m := (a + b) * 0.5
		var fm := sun_altitude(lat, lon, m) - HORIZON_ALT
		if (fa < 0.0) == (fm < 0.0):
			a = m
			fa = fm
		else:
			b = m
	return (a + b) * 0.5

## 月相：0 = 新月，0.5 = 满月，0.25 = 上弦（盈），0.75 = 下弦（亏）。
static func moon_phase(utc_s: float) -> float:
	return fposmod((utc_s - NEW_MOON_REF) / SYNODIC_S, 1.0)

## 月亮在天上的位置：0..1 表示从升起到落下的进度，-9 表示不在天上附近。
## 简化：月亮过中天的当地太阳时 = 12 点 + 月相 × 24 小时（满月午夜过中天、上弦傍晚过中天），
## 在天上停留约 12 小时。
static func moon_u(lon: float, utc_s: float) -> float:
	var transit := fposmod(12.0 + moon_phase(utc_s) * 24.0, 24.0)
	var delta := solar_hour(lon, utc_s) - transit
	delta = fposmod(delta + 12.0, 24.0) - 12.0                # 折到 -12..12
	if absf(delta) > 6.8:
		return -9.0
	return 0.5 + delta / 12.0            # <0 或 >1：刚落到地平线下（画面里让它沉下去）
