extends "res://platform/platform_adapter.gd"
## 桌面实现（macOS 为主，Windows/Linux 走同一套 Godot API）。
## 迷你悬浮窗采用已人工验证过的方案：polygon 局部穿透 + 系统原生拖动。

func is_overlay() -> bool:
	return true

func screen_scale() -> int:
	return max(1, int(round(DisplayServer.screen_get_scale(DisplayServer.window_get_current_screen()))))

func pixel_scale(preferred: int) -> int:
	# Retina 屏下 Godot 的窗口尺寸以物理像素计，需要乘上屏幕缩放才不会显得太小
	return max(1, preferred) * screen_scale()

func enter_mini(window: Window, size: Vector2i) -> void:
	window.mode = Window.MODE_WINDOWED
	window.borderless = true
	window.transparent = true
	window.transparent_bg = true
	window.always_on_top = true
	window.unresizable = true
	window.min_size = Vector2i.ZERO
	window.size = size

func enter_full(window: Window, size: Vector2i) -> void:
	window.mouse_passthrough_polygon = PackedVector2Array()
	window.always_on_top = false
	window.transparent = false
	window.transparent_bg = false
	window.borderless = false
	window.unresizable = false
	window.min_size = Vector2i(480, 300)
	var r := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	size = Vector2i(mini(size.x, r.size.x), mini(size.y, r.size.y - 40))
	window.size = size
	window.position = r.position + (r.size - size) / 2

func set_interactive_polygon(window: Window, points: PackedVector2Array) -> void:
	# 注意：不能同时打开 mouse_passthrough=true，那会整窗穿透并覆盖 polygon
	window.mouse_passthrough = false
	window.mouse_passthrough_polygon = points

func set_passthrough_all(window: Window, on: bool) -> void:
	window.mouse_passthrough = on

func mouse_over_polygon(window: Window, points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var local := Vector2(DisplayServer.mouse_get_position() - window.position)
	return Geometry2D.is_point_in_polygon(local, points)

func timezone_name() -> String:
	# macOS / Linux：/etc/localtime 是指向 zoneinfo/地区/城市 的符号链接
	var d := DirAccess.open("/etc")
	var link := d.read_link("/etc/localtime") if d != null else ""
	var i := link.find("zoneinfo/")
	if i >= 0:
		return link.substr(i + 9)
	return OS.get_environment("TZ")

func start_window_drag(window: Window) -> bool:
	window.start_drag()
	return true

func default_position(window: Window) -> Vector2i:
	var r := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	return r.position + r.size - window.size - Vector2i(40, 20)

func clamp_position(window: Window, pos: Vector2i) -> Vector2i:
	# 存档里的位置可能来自已拔掉的显示器，找不到所在屏幕就回到默认位置
	for i in DisplayServer.get_screen_count():
		var r := DisplayServer.screen_get_usable_rect(i).grow(-20)
		if r.intersects(Rect2i(pos, window.size)):
			return pos
	return default_position(window)

func notify(title: String, body: String) -> void:
	if OS.get_name() == "macOS":
		var script := 'display notification "%s" with title "%s"' % [_esc(body), _esc(title)]
		OS.create_process("/usr/bin/osascript", ["-e", script])
	else:
		DisplayServer.window_request_attention()

static func _esc(s: String) -> String:
	return s.replace("\\", "\\\\").replace('"', '\\"')
