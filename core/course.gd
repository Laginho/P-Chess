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


func _read_data(file_path: String):
	if not FileAccess.file_exists(file_path):
		return null
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data


func stage() -> Dictionary:
	if rating().is_empty():
		return {}
	var index = _read_data(index_path)
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
		var unit = _read_data(index_path.get_base_dir().path_join(filename))
		if unit is Dictionary and not unit.get("id", "").is_empty():
			result.append(unit)
	return result


func unit_progress(unit: Dictionary) -> Dictionary:
	var all_units = _progress.get("units", {})
	var saved = all_units.get(unit.get("id", ""), {}) if all_units is Dictionary else {}
	if not saved is Dictionary:
		saved = {}
	var practice = saved.get("practice", {})
	if not practice is Dictionary:
		practice = {}
	var total := 0
	var solved := 0
	var committed := 0
	var first := 0
	for position in unit.get("positions", []):
		if not position is Dictionary or position.get("pool") != "practice":
			continue
		total += 1
		var result = practice.get(position.get("id", ""), {})
		if result is Dictionary and not result.is_empty():
			committed += 1
			if result.get("solved", false):
				solved += 1
			if result.get("first_try", false):
				first += 1
	var playouts = saved.get("playouts", {})
	var passed := 0
	if playouts is Dictionary:
		for value in playouts.values():
			if value == true:
				passed += 1
	var attempts = saved.get("test_attempts", [])
	if not attempts is Array:
		attempts = []
	var mastered: bool = not str(saved.get("mastered_date", "")).is_empty()
	for attempt in attempts:
		if attempt is Dictionary and attempt.get("passed", false) == true:
			mastered = true
	var test := "passed" if mastered else ("not passed" if not attempts.is_empty() else "not taken")
	var checks = saved.get("review_checks", [])
	var needs_review := false
	if mastered and checks is Array:
		for i in range(checks.size() - 1, -1, -1):
			var check = checks[i]
			if check is Dictionary and (check.has("passed") or check.has("missed")):
				needs_review = check.get("missed", false) == true or check.get("passed", true) == false
				break
	var theory: bool = saved.get("theory_opened", false) == true
	var status := "needs review" if needs_review else ("mastered" if mastered else ("in progress" if theory or committed > 0 or (playouts is Dictionary and not playouts.is_empty()) or not attempts.is_empty() else "new"))
	var rate := "–" if committed == 0 else "%d%% (%d of %d)" % [roundi(100.0 * first / committed), first, committed]
	return {"status": status, "theory_done": theory, "solved": solved, "total": total,
			"playouts_passed": passed, "test": test, "first_try": rate}


func clock_choice() -> String:
	return "none" if _progress.get("clock") == "none" else "5+5"


func save_clock_choice(choice: String) -> bool:
	if choice not in ["5+5", "none"]:
		return false
	var result := _read()
	if not result.ok:
		return false
	var next: Dictionary = result.data
	next.clock = choice
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
