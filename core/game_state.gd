extends RefCounted
## 唯一权威游戏状态（纯数据）。任何系统都只通过它读写进度。

const SAVE_VERSION := 1
const MAX_PROCESSED_IDS := 300

var save_version: int = SAVE_VERSION
var revision: int = 0
var wallet_gold: int = 0          # 铜币数（显示时换算成金/银/铜，见 core/money.gd）
var islands: Array = []            # 已经到过的岛屿 id
var boat_level: int = 0           # 船坞里升到第几级的船
var basket_sizes: Array = []        # 和 basket 一一对应的尺寸（厘米），被偷/被吃时播报用
var cat_name: String = ""           # 玩家给小猫起的名字（空 = 还没起）
var piggy: int = 0                # 家里存钱罐里的铜币
var basket_capacity: float = 10.0    # 鱼篓容量（单位，每种鱼占的单位不同，见 fish.json 的 units）
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
var warehouse: Dictionary = {}      # 家里仓库：和物品栏一样 {物品 id: 数量}
## 物品效果：幸运鱼饵的到期时刻、招财铃剩余的单数
var effects: Dictionary = {"lucky_until_ms": 0, "bell_sales": 0, "napped_end_ms": 0, "bird_next_ms": 0, "bird_act_ms": 0, "drift_0": 0, "drift_1": 0, "drift_2": 0, "signal_ready_ms": 0, "drift_3": 0, "drift_4": 0, "drift_5": 0, "pot_0": 0, "pot_1": 0, "pot_2": 0, "bridge": 0, "west_chest": 0}
var journey: Dictionary = {"activity": 0, "phase_start_ms": 0, "phase_end_ms": 0, "next_eat_ms": 0, "paused_at_ms": 0, "sales": 0, "roam_x": 0, "walk_from": -1, "boat_x": 260, "line_out": 1}
var stats: Dictionary = {"total_pomodoros": 0, "daily": {}, "total_fish": 0, "fish_counts": {}, "chests": 0, "fish_best": {}, "empty_casts": 0, "focus_hours": {}}
## 时长设置为 0 表示"使用 balance.json 的默认值"
## view_mode: 0 = 桌面迷你悬浮窗，1 = 全画面窗口
var settings: Dictionary = {"view_mode": 1, "pixel_scale": 3, "sfx_volume": 2, "real_weather": 0, "focus_min": 0, "short_break_min": 0, "long_break_min": 0}
## 物品栏格子数（每种物品占一格）
var bag_slots: int = 8
## 身上装备的鱼竿/鱼线/鱼钩的档位；-1 = 老存档还没初始化（Game 启动时按升级档位补上）
var gear: Dictionary = {"rod": -1, "line": -1, "hook": -1}
var upgrades: Dictionary = {"rod": 0, "bait": 0, "basket": 0, "hook": 0}
## 支线任务：{任务 id: "active" / "done"}
var quests: Dictionary = {}
## 鱼钩上装的鱼饵（物品 id）；空字符串 = 面团（无限量，不占物品栏）
var equipped_bait: String = ""
## 小猫形象：各项是 data/cat.json 里对应列表的下标；created=false 时首次启动会弹出捏猫面板
var cat: Dictionary = {"fur": 0, "pattern": 1, "hat": 1, "outfit": 0, "own_hats": [0, 1], "own_outfits": [0], "created": false}
var window: Dictionary = {"has_pos": false, "x": 0, "y": 0}

func new_id(prefix: String) -> String:
	var id := "%s%d" % [prefix, next_seq]
	next_seq += 1
	return id

func to_dict() -> Dictionary:
	return {
		"save_version": save_version, "revision": revision,
		"wallet_gold": wallet_gold, "piggy": piggy, "boat_level": boat_level, "cat_name": cat_name, "islands": islands.duplicate(), "basket_capacity": basket_capacity,
		"journey": journey.duplicate(true), "inventory": inventory.duplicate(true), "warehouse": warehouse.duplicate(true), "effects": effects.duplicate(true), "fishing_checkpoint": fishing_checkpoint.duplicate(true),
		"basket": basket.duplicate(), "basket_sizes": basket_sizes.duplicate(), "session_haul": session_haul.duplicate(),
		"processed_catch_ids": processed_catch_ids.duplicate(),
		"processed_sale_ids": processed_sale_ids.duplicate(),
		"next_seq": next_seq, "pomodoro": pomodoro.duplicate(true),
		"stats": stats.duplicate(true), "settings": settings.duplicate(true),
		"upgrades": upgrades.duplicate(true), "quests": quests.duplicate(true), "bag_slots": bag_slots, "gear": gear.duplicate(true), "cat": cat.duplicate(true), "equipped_bait": equipped_bait,
		"window": window.duplicate(true),
	}

## 从字典恢复。字段缺失或类型不对时保留默认值；版本不认识则返回 false。
func from_dict(d: Dictionary) -> bool:
	if int(d.get("save_version", -1)) != SAVE_VERSION:
		return false
	revision = int(d.get("revision", 0))
	wallet_gold = max(0, int(d.get("wallet_gold", 0)))
	piggy = max(0, int(d.get("piggy", 0)))
	islands = _str_array(d.get("islands"))
	cat_name = str(d.get("cat_name", "")).strip_edges().substr(0, 6)
	boat_level = clampi(int(d.get("boat_level", 0)), 0, 99)
	basket_capacity = maxf(1.0, float(d.get("basket_capacity", 10.0)))
	basket = _str_array(d.get("basket"))
	basket_sizes = []
	var raw_sizes = d.get("basket_sizes", [])
	for i in basket.size():
		basket_sizes.append(int(raw_sizes[i]) if raw_sizes is Array and i < raw_sizes.size() else 0)
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
	warehouse = {}
	if d.get("warehouse") is Dictionary:
		for k in d["warehouse"]:
			if int(d["warehouse"][k]) > 0:
				warehouse[str(k)] = int(d["warehouse"][k])
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
	bag_slots = clampi(int(d.get("bag_slots", 8)), 1, 99)
	_merge(gear, d.get("gear"))
	quests.clear()
	if d.get("quests") is Dictionary:
		for k in d["quests"]:
			quests[str(k)] = str(d["quests"][k])
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
