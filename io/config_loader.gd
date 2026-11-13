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
	# 宝箱是可选的；写了就要写对
	var chest = b.get("chest", {})
	if chest is Dictionary and chest.has("tiers"):
		if float(chest.get("chance", -1)) < 0.0 or float(chest.get("chance", 2)) > 1.0 or not chest["tiers"] is Array:
			push_error("balance.json chest.chance 必须在 0–1 之间，tiers 必须是数组")
			return {}
		for t in chest["tiers"]:
			if not (t is Dictionary) or float(t.get("weight", 0)) <= 0 or int(t.get("gold_min", -1)) < 0 or int(t.get("gold_max", -1)) < int(t.get("gold_min", 0)):
				push_error("balance.json chest.tiers 有非法条目: " + str(t))
				return {}
	var seen_items := {}
	for it in b.get("items", []):
		if not (it is Dictionary and it.has("id") and it.has("name") and it.has("sprite")) or seen_items.has(it.get("id")):
			push_error("balance.json items 有缺字段或重复 id 的条目: " + str(it))
			return {}
		seen_items[it["id"]] = true
		var use := str(it.get("use", ""))
		if not use in ["", "gold", "lucky", "bell"]:
			push_error("balance.json items.%s 的 use 不认识: %s" % [it["id"], use])
			return {}
		if use == "gold" and int(it.get("gold_max", -1)) < int(it.get("gold_min", 0)):
			push_error("balance.json items.%s 的金币范围非法" % it["id"])
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
