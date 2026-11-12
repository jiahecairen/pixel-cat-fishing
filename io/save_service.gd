extends RefCounted
## 存档服务。原子写入：先写临时文件 → 旧档改名为 .bak → 临时文件改名为正式档。
## 任何一步失败，磁盘上至少保留一份完整的旧档；读档时主档损坏会自动回退 .bak。

var path: String

func _init(save_path: String = "user://save.json") -> void:
	path = save_path

func save(data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("存档失败，无法写入: " + tmp)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	# 写完读回来校验一次，确认临时文件完整
	if _read(tmp).is_empty():
		return false
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if dir.file_exists(path):
		dir.remove(path + ".bak")
		if dir.rename(path, path + ".bak") != OK:
			return false
	return dir.rename(tmp, path) == OK

## 返回存档字典；没有存档或全部损坏时返回空字典。
func load_data() -> Dictionary:
	var d := _read(path)
	if d.is_empty():
		d = _read(path + ".bak")
	return d

func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var json := JSON.new()   # 用实例解析：损坏的存档属于预期情况，不刷引擎报错
	if json.parse(FileAccess.get_file_as_string(p)) != OK:
		return {}
	if json.data is Dictionary and json.data.has("save_version"):
		return json.data
	return {}
