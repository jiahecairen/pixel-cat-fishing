extends RefCounted
## 唯一权威游戏状态（纯数据）。任何系统都只通过它读写进度。

const SAVE_VERSION := 1
const MAX_PROCESSED_IDS := 300

var save_version: int = SAVE_VERSION
var revision: int = 0
var wallet_gold: int = 0
var basket_capacity: int = 10
var basket: Array = []            # 自由挂机钓到的鱼 id
var session_haul: Array = []      # 当前专注番茄内钓到的鱼 id（"木箱"，不限量）
var processed_catch_ids: Array = []
var processed_sale_ids: Array = []
var next_seq: int = 1
var pomodoro: Dictionary = {"phase": 0, "phase_end_ms": 0, "cycle_done": 0}
## 钓鱼断点（见 FishingSystem.checkpoint）
var fishing_checkpoint: Dictionary = {"state": 0, "state_start_ms": 0, "deadline_ms": 0, "hooked_fish": ""}
## 物品栏：物品 id → 数量
var inventory: Dictionary = {}
## 物品效果：幸运鱼饵的到期时刻、招财铃剩余的单数
var effects: Dictionary = {"lucky_until_ms": 0, "bell_sales": 0, "napped_end_ms": 0, "bird_next_ms": 0, "bird_act_ms": 0}
var journey: Dictionary = {"activity": 0, "phase_start_ms": 0, "phase_end_ms": 0, "next_eat_ms": 0, "paused_at_ms": 0, "sales": 0, "roam_x": 0, "walk_from": -1, "boat_x": 260, "line_out": 1}
var stats: Dictionary = {"total_pomodoros": 0, "daily": {}, "total_fish": 0, "fish_counts": {}, "chests": 0, "fish_best": {}, "empty_casts": 0}
## 时长设置为 0 表示"使用 balance.json 的默认值"
## view_mode: 0 = 桌面迷你悬浮窗，1 = 全画面窗口
var settings: Dictionary = {"view_mode": 1, "pixel_scale": 3, "sfx_volume": 2, "real_weather": 0, "focus_min": 0, "short_break_min": 0, "long_break_min": 0}
var upgrades: Dictionary = {"rod": 0, "bait": 0, "basket": 0}
## 鱼钩上装的鱼饵（物品 id）；空字符串 = 面团（无限量，不占物品栏）
var equipped_bait: String = ""
## 小猫形象：各项是 data/cat.json 里对应列表的下标；created=false 时首次启动会弹出捏猫面板
var cat: Dictionary = {"fur": 0, "pattern": 1, "hat": 1, "created": false}
var window: Dictionary = {"has_pos": false, "x": 0, "y": 0}

func new_id(prefix: String) -> String:
	var id := "%s%d" % [prefix, next_seq]
	next_seq += 1
	return id

func to_dict() -> Dictionary:
	return {
		"save_version": save_version, "revision": revision,
		"wallet_gold": wallet_gold, "basket_capacity": basket_capacity,
		"journey": journey.duplicate(true), "inventory": inventory.duplicate(true), "effects": effects.duplicate(true), "fishing_checkpoint": fishing_checkpoint.duplicate(true),
		"basket": basket.duplicate(), "session_haul": session_haul.duplicate(),
		"processed_catch_ids": processed_catch_ids.duplicate(),
		"processed_sale_ids": processed_sale_ids.duplicate(),
		"next_seq": next_seq, "pomodoro": pomodoro.duplicate(true),
		"stats": stats.duplicate(true), "settings": settings.duplicate(true),
		"upgrades": upgrades.duplicate(true), "cat": cat.duplicate(true), "equipped_bait": equipped_bait,
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
	_merge(fishing_checkpoint, d.get("fishing_checkpoint"))
	for k in ["state", "state_start_ms", "deadline_ms"]:
		fishing_checkpoint[k] = int(fishing_checkpoint[k])
	inventory = {}
	if d.get("inventory") is Dictionary:
		for k in d["inventory"]:
			if int(d["inventory"][k]) > 0:
				inventory[str(k)] = int(d["inventory"][k])
	_merge(effects, d.get("effects"))
	for k in effects.keys():
		effects[k] = int(effects[k])
	_merge(journey, d.get("journey"))
	for k in journey.keys():
		journey[k] = int(journey[k])
	_merge(stats, d.get("stats"))
	_merge(settings, d.get("settings"))
	_merge(window, d.get("window"))
	_merge(upgrades, d.get("upgrades"))
	_merge(cat, d.get("cat"))
	equipped_bait = str(d.get("equipped_bait", ""))
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
