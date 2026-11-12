extends RefCounted
## 唯一权威游戏状态（纯数据）。任何系统都只通过它读写进度。

const SAVE_VERSION := 1
const MAX_PROCESSED_IDS := 300

var save_version: int = SAVE_VERSION
var revision: int = 0
var wallet_gold: int = 0
var basket_capacity: int = 10
var basket: Array = []            # 自由挂机钓到的鱼 id
var session_haul: Array = []      # 当前专注番茄内钓到的鱼 id
var processed_catch_ids: Array = []
var processed_sale_ids: Array = []
var next_seq: int = 1
var pomodoro: Dictionary = {"phase": 0, "phase_end_ms": 0, "cycle_done": 0}
var stats: Dictionary = {"total_pomodoros": 0, "daily": {}, "total_fish": 0, "fish_counts": {}}
var settings: Dictionary = {"pixel_scale": 3}
var window: Dictionary = {"has_pos": false, "x": 0, "y": 0}

func new_id(prefix: String) -> String:
	var id := "%s%d" % [prefix, next_seq]
	next_seq += 1
	return id

func to_dict() -> Dictionary:
	return {
		"save_version": save_version, "revision": revision,
		"wallet_gold": wallet_gold, "basket_capacity": basket_capacity,
		"basket": basket.duplicate(), "session_haul": session_haul.duplicate(),
		"processed_catch_ids": processed_catch_ids.duplicate(),
		"processed_sale_ids": processed_sale_ids.duplicate(),
		"next_seq": next_seq, "pomodoro": pomodoro.duplicate(true),
		"stats": stats.duplicate(true), "settings": settings.duplicate(true),
		"window": window.duplicate(true),
	}

## 从字典恢复。字段缺失或类型不对时保留默认值；版本不认识则返回 false。
func from_dict(d: Dictionary) -> bool:
	if int(d.get("save_version", -1)) != SAVE_VERSION:
		return false
	revision = int(d.get("revision", 0))
	wallet_gold = max(0, int(d.get("wallet_gold", 0)))
	basket_capacity = max(1, int(d.get("basket_capacity", 10)))
	basket = _str_array(d.get("basket"))
	session_haul = _str_array(d.get("session_haul"))
	processed_catch_ids = _str_array(d.get("processed_catch_ids"))
	processed_sale_ids = _str_array(d.get("processed_sale_ids"))
	next_seq = max(1, int(d.get("next_seq", 1)))
	_merge(pomodoro, d.get("pomodoro"))
	_merge(stats, d.get("stats"))
	_merge(settings, d.get("settings"))
	_merge(window, d.get("window"))
	# JSON 数字读回来是 float，统一成 int
	for k in ["phase", "phase_end_ms", "cycle_done"]:
		pomodoro[k] = int(pomodoro[k])
	return true

static func _str_array(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(str(x))
	return out

static func _merge(target: Dictionary, src) -> void:
	if not src is Dictionary:
		return
	for k in target.keys():
		if not src.has(k):
			continue
		var want := typeof(target[k])
		var got := typeof(src[k])
		var numeric := [TYPE_INT, TYPE_FLOAT]
		if want == got:
			target[k] = src[k]
		elif want in numeric and got in numeric:
			target[k] = int(src[k])
