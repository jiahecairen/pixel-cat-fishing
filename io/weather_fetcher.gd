class_name WeatherFetcher
extends Node
## 真实天气（可选）：设置里打开后，每 30 分钟向 Open-Meteo（免费，不需要账号）问一次当前天气。
## 只发送取整到 0.1°（约 10 公里）的坐标；失败 5 分钟后重试；断网太久游戏会自动退回模拟天气。

const URL := "https://api.open-meteo.com/v1/forecast?latitude=%.1f&longitude=%.1f&current=weather_code,cloud_cover"
const OK_INTERVAL_MS := 30 * 60 * 1000
const RETRY_MS := 5 * 60 * 1000

var game
var log
var _http: HTTPRequest
var _next_ms: int = 0
var _busy: bool = false

func setup(g, event_log) -> void:
	game = g
	log = event_log
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_done)

func _process(_dt: float) -> void:
	if game == null or _busy or not game.real_weather_on():
		return
	var now := Time.get_ticks_msec()
	if now < _next_ms:
		return
	_busy = true
	_next_ms = now + RETRY_MS
	var err := _http.request(URL % [game.lat, game.lon])
	if err != OK:
		_busy = false

func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		log.write("real_weather_failed", {"result": result, "code": code})
		return
	var w := parse(body.get_string_from_utf8())
	if w.is_empty():
		log.write("real_weather_failed", {"reason": "parse"})
		return
	game.set_real_weather(w["raining"], w["cloudy"])
	_next_ms = Time.get_ticks_msec() + OK_INTERVAL_MS
	log.write("real_weather", w)

## 解析 Open-Meteo 的返回。WMO 天气码：51–67 毛毛雨/雨，80–82 阵雨，95–99 雷雨 → 下雨；
## 3、45、48 或云量 ≥ 80% → 阴天。解析失败返回空字典。
static func parse(body: String) -> Dictionary:
	var d = JSON.parse_string(body)
	if not (d is Dictionary) or not (d.get("current") is Dictionary):
		return {}
	var cur: Dictionary = d["current"]
	if not cur.has("weather_code"):
		return {}
	var code := int(cur["weather_code"])
	var raining := (code >= 51 and code <= 67) or (code >= 80 and code <= 82) or (code >= 95 and code <= 99)
	var cloudy := code == 3 or code == 45 or code == 48 or float(cur.get("cloud_cover", 0)) >= 80.0
	return {"raining": raining, "cloudy": cloudy, "code": code}
