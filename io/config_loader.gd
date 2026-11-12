extends RefCounted
## 读取并校验 data/ 下的 JSON 配置。配置非法时返回空字典并报错，调用方决定如何处理。

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("配置文件不存在: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("配置文件不是合法 JSON 对象: " + path)
		return {}
	return parsed

static func load_fish(path: String = "res://data/fish.json") -> Array:
	var out: Array = []
	var seen := {}
	for f in load_json(path).get("fish", []):
		if not (f is Dictionary and f.has("id") and f.has("price") and f.has("weight") and f.has("sprite")):
			push_error("鱼配置缺字段: " + str(f))
			return []
		if seen.has(f["id"]) or float(f["weight"]) <= 0.0 or float(f["price"]) < 0.0:
			push_error("鱼配置非法(重复 id / 权重<=0 / 价格<0): " + str(f))
			return []
		seen[f["id"]] = true
		out.append(f)
	return out

static func load_balance(path: String = "res://data/balance.json") -> Dictionary:
	var b := load_json(path)
	if not (b.get("fishing") is Dictionary and b.get("pomodoro") is Dictionary):
		push_error("balance.json 缺少 fishing / pomodoro")
		return {}
	var f: Dictionary = b["fishing"]
	if float(f.get("bite_min_ms", 0)) <= 0 or float(f.get("bite_max_ms", 0)) < float(f.get("bite_min_ms", 0)):
		push_error("balance.json 咬钩时间范围非法")
		return {}
	var town = b.get("town")
	if not town is Dictionary:
		push_error("balance.json 缺少 town")
		return {}
	for k in ["sail_ms", "walk_ms", "sale_min_ms", "sale_max_ms", "eat_min_ms", "eat_max_ms"]:
		if float(town.get(k, 0)) <= 0:
			push_error("balance.json town.%s 必须 > 0" % k)
			return {}
	for k in ["focus_min", "short_break_min", "long_break_min", "cycle_length"]:
		if float(b["pomodoro"].get(k, 0)) <= 0:
			push_error("balance.json pomodoro.%s 必须 > 0" % k)
			return {}
	return b

static func load_cat(path: String = "res://data/cat.json") -> Dictionary:
	var c := load_json(path)
	for list_name in ["furs", "patterns", "hats"]:
		if not (c.get(list_name) is Array) or c[list_name].is_empty():
			push_error("cat.json 缺少 " + list_name)
			return {}
		for item in c[list_name]:
			if not (item is Dictionary and item.has("name")):
				push_error("cat.json %s 里有条目缺 name" % list_name)
				return {}
	for f in c["furs"]:
		if not (f.has("base") and f.has("shade") and f.has("light")):
			push_error("cat.json 毛色缺 base/shade/light: " + str(f))
			return {}
	return c
