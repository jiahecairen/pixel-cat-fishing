extends RefCounted
## 按当前操作系统挑选适配器。新增平台只改这里。

const Base := preload("res://platform/platform_adapter.gd")
const Desktop := preload("res://platform/desktop_adapter.gd")

static func create() -> Base:
	if DisplayServer.get_name() == "headless":
		return Base.new()
	match OS.get_name():
		"macOS", "Windows", "Linux":
			return Desktop.new()
	return Base.new()   # iOS / Android / 主机：全屏应用形态
