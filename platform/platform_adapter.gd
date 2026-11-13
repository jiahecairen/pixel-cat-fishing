extends RefCounted
## 平台适配接口。core 和 presentation 只通过这里接触"窗口/系统"能力。
## 移植到新平台 = 新写一个子类并在 platform.gd 里登记，其余代码不动。
## 基类给出"普通全屏应用"的默认行为，手机和主机可直接用（它们没有迷你悬浮窗）。

## 本平台是否支持桌面迷你悬浮窗（透明、置顶、可穿透）。
func is_overlay() -> bool:
	return false

## 迷你悬浮窗里每个美术像素放大成多少个屏幕像素。
func pixel_scale(_preferred: int) -> int:
	return max(1, _preferred)

## 屏幕缩放（Retina 为 2）。
func screen_scale() -> int:
	return 1

## 切到迷你悬浮窗：无边框、透明、置顶、固定大小。
func enter_mini(_window: Window, _size: Vector2i) -> void:
	pass

## 切到全画面窗口：普通带标题栏的窗口，可调整大小。
func enter_full(_window: Window, _size: Vector2i) -> void:
	pass

## 设置窗口内可交互区域（窗口像素坐标）；区域外鼠标穿透到后面的应用。传空数组 = 整窗可交互。
func set_interactive_polygon(_window: Window, _points: PackedVector2Array) -> void:
	pass

## 整窗鼠标穿透开关（隐藏迷你窗时用，打开后窗口完全不拦截点击）。
func set_passthrough_all(_window: Window, _on: bool) -> void:
	pass

## 当前鼠标是否落在窗口的可交互多边形内（屏幕坐标，窗口没焦点也能判断）。
func mouse_over_polygon(_window: Window, _points: PackedVector2Array) -> bool:
	return false

## 让系统接管窗口拖动。返回 false 表示本平台不支持。
func start_window_drag(_window: Window) -> bool:
	return false

func default_position(_window: Window) -> Vector2i:
	return Vector2i.ZERO

func clamp_position(_window: Window, pos: Vector2i) -> Vector2i:
	return pos

func notify(_title: String, _body: String) -> void:
	pass

func set_fps(fps: int) -> void:
	Engine.max_fps = fps
