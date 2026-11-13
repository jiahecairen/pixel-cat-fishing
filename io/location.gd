class_name Location
extends RefCounted
## 位置：按电脑的时区推算所在城市（离线、不发送任何数据）。
## 找不到对应城市时，用时区偏移估一个经度（偏移 ×15°），纬度取 40°。

const PATH := "res://data/cities.json"

static func load_table() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Dictionary else {}

## tz_name：IANA 时区名（如 "Europe/Dublin"），可为空；bias_s：本地时间比 UTC 快多少秒。
static func resolve(tz_name: String, bias_s: int, table: Dictionary) -> Dictionary:
	for c in table.get("cities", []):
		if c["tz"] == tz_name:
			return {"name": c["name"], "lat": float(c["lat"]), "lon": float(c["lon"]), "source": "tz"}
	if tz_name == "" and bias_s == 0 and table.has("default"):
		var d: Dictionary = table["default"]
		return {"name": d["name"], "lat": float(d["lat"]), "lon": float(d["lon"]), "source": "default"}
	return {"name": "", "lat": 40.0, "lon": clampf(bias_s / 3600.0 * 15.0, -180.0, 180.0), "source": "bias"}
