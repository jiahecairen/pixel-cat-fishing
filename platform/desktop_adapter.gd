extends "res://platform/platform_adapter.gd"
## 桌面悬浮窗实现（macOS 为主，Windows/Linux 走同一套 Godot API）。
## 采用已在技术探针中人工验证过的方案：polygon 局部穿透 + 系统原生拖动。

func is_overlay() -> bool:
	return true

func pixel_scale(preferred: int) -> int:
	# Retina 屏下 Godot 的窗口尺寸以物理像素计，需要乘上屏幕缩放才不会显得太小
	var s := DisplayServer.screen_get_scale(DisplayServer.window_get_current_screen())
	return max(1, preferred) * max(1, int(round(s)))

func setup_window(window: Window, art_size: Vector2i, scale: int) -> void:
	window.borderless = true
	window.transparent = true
	window.transparent_bg = true
	window.always_on_top = true
	window.unresizable = true
	window.size = art_size * scale

func set_interactive_polygon(window: Window, points: PackedVector2Array) -> void:
	# 注意：不能同时打开 mouse_passthrough=true，那会整窗穿透并覆盖 polygon
	window.mouse_passthrough = false
	window.mouse_passthrough_polygon = points

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
