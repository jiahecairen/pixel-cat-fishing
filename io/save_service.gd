extends RefCounted
## 存档服务。原子写入：先写临时文件 → 旧档改名为 .bak → 临时文件改名为正式档。
## 任何一步失败，磁盘上至少保留一份完整的旧档；读档时主档损坏会自动回退 .bak。
## v1.00 起把「这次读的到底是哪一份」「为什么没写进去」如实报给上层——丢进度可以，悄悄丢不行。

var path: String
var last_source := ""    # 最近一次读档读到了什么："main"=正式档 / "bak"=回退到备份 / ""=一份都没读到
var last_error := ""     # 最近一次写盘失败的原因；写成功时清空

func _init(save_path: String = "user://save.json") -> void:
	path = save_path

func save(data: Dictionary) -> bool:
	last_error = ""
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "写不了临时文件 %s（%s）" % [tmp, error_string(FileAccess.get_open_error())]
		push_error("存档失败，无法写入: " + tmp)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	# 写完读回来校验一次，确认临时文件完整
	var dir := DirAccess.open(path.get_base_dir())
	if _read(tmp).is_empty():
		last_error = "临时文件回读是空的或坏的，没敢替换旧档"
		if dir != null:
			dir.remove(tmp)
		return false
	if dir == null:
		last_error = "打不开存档目录 " + path.get_base_dir()
		return false
	var has_main := dir.file_exists(path)
	if has_main:
		# 改名顺序很关键：先试着把正式档挪成 .bak，挪不动（备份已存在等）才删掉旧备份再挪。
		# 老代码是「先删 .bak 再改名」，万一改名失败，唯一的备份已经被自己删了。
		if dir.rename(path, path + ".bak") != OK:
			if dir.remove(path + ".bak") != OK or dir.rename(path, path + ".bak") != OK:
				last_error = "旧档没能挪成 .bak，正式档原样保留"
				dir.remove(tmp)
				return false
	if dir.rename(tmp, path) != OK:
		# 新档没能上位：把刚挪走的旧档放回原位，正式位置不能空着
		last_error = "新档没能替换正式存档，旧档已放回原处"
		if has_main:
			dir.rename(path + ".bak", path)
		return false
	return true

## 返回存档字典；没有存档或全部损坏时返回空字典。
## 读到了哪一份记在 last_source：回退到 .bak 等于少了一段进度，上层必须告诉玩家。
func load_data() -> Dictionary:
	last_source = ""
	last_error = ""
	var d := _read(path)
	if not d.is_empty():
		last_source = "main"
		return d
	if FileAccess.file_exists(path):
		push_warning("主存档读不出来，回退到备份: " + path)
	d = _read(path + ".bak")
	if not d.is_empty():
		last_source = "bak"
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
