extends RefCounted
## 关键事件日志：一行一条 JSON，写在 user://logs/events.log。
## 用来事后排查"小猫刚才干了什么"，也是长时间运行验收的依据。
## 文件超过 max_bytes 时轮转为 .1（只保留一份旧的），所以不会无限变大。

var path: String
var max_bytes: int
var enabled: bool = true

func _init(log_path: String = "user://logs/events.log", limit_bytes: int = 512 * 1024) -> void:
	path = log_path
	max_bytes = limit_bytes
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

func write(type: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var entry := {"time": Time.get_datetime_string_from_system(), "type": type}
	entry.merge(data)
	_rotate_if_needed()
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		enabled = false          # 写不了就安静地停用，日志不能拖垮游戏
		push_warning("无法写入事件日志: " + path)
		return
	f.store_line(JSON.stringify(entry))
	f.close()

func _rotate_if_needed() -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var size := f.get_length()
	f.close()
	if size < max_bytes:
		return
	var dir := DirAccess.open(path.get_base_dir())
	if dir != null:
		dir.remove(path + ".1")
		dir.rename(path, path + ".1")
