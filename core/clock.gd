extends RefCounted
## 时间源。core 层所有计时都经由这里，测试时可替换为假时钟。
## 使用系统墙上时间（毫秒），因此不依赖帧率，重启后番茄钟仍能接续。

## 仅调试用：人为加速时间时累加的偏移量（正式运行恒为 0）。
var debug_offset_ms: float = 0.0

func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0 + debug_offset_ms)

func today_key() -> String:
	return Time.get_date_string_from_system()
