extends RefCounted
## 时间源。core 层所有计时都经由这里，测试时可替换为假时钟。
## 使用系统墙上时间（毫秒），因此不依赖帧率，重启后番茄钟仍能接续。

## 仅调试用：人为加速时间时累加的偏移量（正式运行恒为 0）。
var debug_offset_ms: float = 0.0

func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0 + debug_offset_ms)

## 本地时间的秒数（Unix 秒 + 时区偏移），天气和昼夜用。
func local_s() -> int:
	var bias_s: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return now_ms() / 1000 + bias_s

func today_key() -> String:
	return day_key(0)

## 本地日期字符串（YYYY-MM-DD）；days_ago=1 表示昨天。
func day_key(days_ago: int) -> String:
	var bias_s: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(now_ms() / 1000 + bias_s - days_ago * 86400)
