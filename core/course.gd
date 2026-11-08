extends RefCounted

# Progress is shared with future course features; preserve fields we do not own.
var path: String
var _progress := {}
var index_path: String


func _init(file := "user://course.json", index := "res://data/course/course.json") -> void:
	path = file
	index_path = index
	var result := _read()
	_progress = result.data


func _read() -> Dictionary:
	if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):
		return {"ok": true, "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}}
	var length := file.get_length()
	var bytes := file.get_buffer(length)
	if file.get_error() != OK or bytes.size() != length:
		return {"ok": false, "data": {}}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"ok": false, "data": {}}
	return {"ok": true, "data": json.data}


static func valid_rating(number, site: String) -> bool:
	return typeof(number) == TYPE_INT and number >= 100 and number <= 3500 and site in ["chess.com", "lichess"]


func rating() -> Dictionary:
	var value = _progress.get("rating", {})
	if not value is Dictionary:
		return {}
	var number = value.get("number")
	if typeof(number) == TYPE_FLOAT and is_finite(number) and number == floor(number):
		number = int(number)
	var site = value.get("site", "")
	if not site is String or not valid_rating(number, site):
		return {}
	return {"number": number, "site": site}


func chess_com_rating() -> int:
	var value := rating()
	return 0 if value.is_empty() else value.number - (300 if value.site == "lichess" else 0)


func maia_level() -> String:
	return "maia-%d" % clampi(int(floor((chess_com_rating() + 350) / 100.0)) * 100, 1100, 1900)


func save_rating(number, site: String) -> bool:
	if not valid_rating(number, site):
		return false
	# Read again so a failed read or a prior update cannot silently discard progress.
	var result := _read()
	if not result.ok:
		return false
	var next: Dictionary = result.data
	next.rating = {"number": number, "site": site}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(next, "\t"))
	file.flush()
	var error := file.get_error()
	file = null
	if error != OK or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	_progress = next
	return true


func stage() -> Dictionary:
	if rating().is_empty():
		return {}
	var index = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not index is Dictionary or not index.get("stages", []) is Array:
		return {}
	var value := chess_com_rating()
	for item in index.stages:
		if item is Dictionary and value >= item.get("min_rating", 0) and value <= item.get("max_rating", -1):
			return item
	return {}


func units() -> Array:
	var result := []
	for filename in stage().get("units", []):
		if not filename is String:
			continue
		var unit = JSON.parse_string(FileAccess.get_file_as_string(index_path.get_base_dir().path_join(filename)))
		if unit is Dictionary and not unit.get("id", "").is_empty():
			result.append(unit)
	return result
