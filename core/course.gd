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
	return _save_progress(func(next: Dictionary) -> bool:
		next.rating = {"number": number, "site": site}
		return true)


func _save_progress(update: Callable) -> bool:
	# Read again so a failed read or a prior update cannot silently discard progress.
	var result := _read()
	if not result.ok:
		return false
	var next: Dictionary = result.data
	if not update.call(next):
		return false
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
			if check is Dictionary:
				if check.get("missed", false) == true:
					needs_review = true
					break
				if check.get("done", true) != false and (check.has("passed") or check.has("missed")):
					needs_review = check.get("passed", true) == false
					break
	var theory: bool = saved.get("theory_opened", false) == true
	var status := "needs review" if needs_review else ("mastered" if mastered else ("in progress" if theory or committed > 0 or (playouts is Dictionary and not playouts.is_empty()) or not attempts.is_empty() else "new"))
	var rate := "–" if committed == 0 else "%d%% (%d of %d)" % [roundi(100.0 * first / committed), first, committed]
	return {"status": status, "theory_done": theory, "solved": solved, "total": total,
			"playouts_passed": passed, "test": test, "first_try": rate, "solving_done": total > 0 and solved == total}


func add_from_game(unit: Dictionary, position: Dictionary) -> bool:
	var unit_id: String = unit.get("id", "")
	var fen: String = position.get("fen", "")
	if unit_id.is_empty() or fen.is_empty():
		return false
	return _save_progress(func(next: Dictionary) -> bool:
		var all_units = next.get("units", {})
		if not all_units is Dictionary:
			return false
		var saved = all_units.get(unit_id, {})
		if not saved is Dictionary:
			return false
		var positions = saved.get("from_your_game", [])
		if not positions is Array:
			return false
		for existing in positions:
			if existing is Dictionary and existing.get("fen", "") == fen:
				return true
		var entry := position.duplicate(true)
		entry.id = "from-game-" + fen.sha256_text()
		entry.from_your_game = true
		positions.append(entry)
		saved.from_your_game = positions
		all_units[unit_id] = saved
		next.units = all_units
		return true)


func practice_positions(unit: Dictionary) -> Array:
	var result := []
	for position in unit.get("positions", []):
		if position is Dictionary and position.get("pool") == "practice":
			result.append(position)
	var all_units = _progress.get("units", {})
	var saved = all_units.get(unit.get("id", ""), {}) if all_units is Dictionary else {}
	var from_games = saved.get("from_your_game", []) if saved is Dictionary else []
	if from_games is Array:
		for position in from_games:
			if position is Dictionary:
				var entry: Dictionary = position.duplicate()
				entry.from_your_game = true
				result.append(entry)
	return result


func test_attempts(unit: Dictionary) -> Array:
	var all_units = _progress.get("units", {})
	var saved = all_units.get(unit.get("id", ""), {}) if all_units is Dictionary else {}
	var attempts = saved.get("test_attempts", []) if saved is Dictionary else []
	return attempts.duplicate(true) if attempts is Array else []


# Convert an instant to a wall-clock timestamp so mastery dates and the current
# day use the same local calendar. The caller supplies the current UTC offset.
static func local_calendar_time(now: int, offset_minutes: int) -> int:
	return now + offset_minutes * 60


func continue_target(now: int) -> Dictionary:
	for unit in units():
		var all_units = _progress.get("units", {})
		var saved = all_units.get(unit.id, {}) if all_units is Dictionary else {}
		if not saved is Dictionary:
			continue
		var date := str(saved.get("mastered_date", ""))
		if date.is_empty():
			continue
		var mastered_at := int(Time.get_unix_time_from_datetime_string(date + "T00:00:00"))
		var checks = saved.get("review_checks", [])
		if not checks is Array:
			checks = []
		for day in [7, 30]:
			var completed := false
			for check in checks:
				if check is Dictionary and int(check.get("day", 0)) == day and check.get("done", false):
					completed = true
			if not completed and now >= mastered_at + day * 86400:
				var positions := []
				for position in unit.get("positions", []):
					if position is Dictionary and position.get("pool") in ["practice", "test"]:
						positions.append(position)
				positions.shuffle()
				return {"kind": "review", "unit": unit, "day": day, "elapsed_days": int((now - mastered_at) / 86400), "positions": positions.slice(0, 3)}
	for unit in units():
		for position in practice_positions(unit):
			if position.get("from_your_game", false) and not practice_result(unit, position).get("solved", false):
				return {"kind": "from_game", "unit": unit, "position": position}
	for unit in units():
		var progress := unit_progress(unit)
		if not progress.theory_done:
			return {"kind": "theory", "unit": unit}
		if not progress.solving_done:
			return {"kind": "solving", "unit": unit, "position": next_practice_position(unit)}
		for position in unit.get("playouts", []):
			if not playout_passed(unit, position):
				return {"kind": "playouts", "unit": unit, "position": position}
		if progress.test != "passed":
			return {"kind": "test", "unit": unit}
	return {"kind": "done"}


func record_review_check(unit: Dictionary, day: int, passed: bool, done := true) -> bool:
	var id: String = unit.get("id", "")
	if id.is_empty() or day not in [7, 30]:
		return false
	return _save_progress(func(next: Dictionary) -> bool:
		var all_units = next.get("units", {})
		if not all_units is Dictionary:
			return false
		var saved = all_units.get(id, {})
		if not saved is Dictionary or str(saved.get("mastered_date", "")).is_empty():
			return false
		var checks = saved.get("review_checks", [])
		if not checks is Array:
			return false
		checks.append({"day": day, "done": done, "passed": passed, "missed": not passed})
		saved.review_checks = checks
		all_units[id] = saved
		next.units = all_units
		return true)


func draw_test_positions(unit: Dictionary) -> Array:
	var fresh := []
	var previous := []
	var attempts := test_attempts(unit)
	if not attempts.is_empty() and attempts.back() is Dictionary:
		for result in attempts.back().get("positions", []):
			if result is Dictionary:
				var position = result.get("position", result)
				if position is Dictionary:
					previous.append(position.get("id", ""))
	var used := []
	for position in unit.get("positions", []):
		if position is Dictionary and position.get("pool") == "test":
			if position.get("id", "") in previous:
				used.append(position)
			else:
				fresh.append(position)
	fresh.shuffle()
	used.shuffle()
	fresh.append_array(used)
	return fresh.slice(0, preload("res://core/tunables.gd").COURSE_TEST_POSITIONS)


func record_test_attempt(unit: Dictionary, positions: Array, playouts: Array, date: String) -> bool:
	var id: String = unit.get("id", "")
	var tunables = preload("res://core/tunables.gd")
	if id.is_empty() or date.is_empty() or positions.size() != tunables.COURSE_TEST_POSITIONS or playouts.size() != 2:
		return false
	var score := 0
	for result in positions:
		if not result is Dictionary:
			return false
		if result.get("solved", false) == true:
			score += 1
	var passed: bool = score >= tunables.COURSE_TEST_PASS and playouts[0] == true and playouts[1] == true
	return _save_progress(func(next: Dictionary) -> bool:
		var all_units = next.get("units", {})
		if not all_units is Dictionary:
			return false
		var saved = all_units.get(id, {})
		if not saved is Dictionary:
			return false
		var attempts = saved.get("test_attempts", [])
		if not attempts is Array:
			return false
		attempts.append({"date": date, "positions": positions.duplicate(true), "playouts": playouts.duplicate(true), "score": score, "passed": passed})
		saved.test_attempts = attempts
		if passed and str(saved.get("mastered_date", "")).is_empty():
			saved.mastered_date = date
		all_units[id] = saved
		next.units = all_units
		return true)


func practice_result(unit: Dictionary, position: Dictionary) -> Dictionary:
	var all_units = _progress.get("units", {})
	var saved = all_units.get(unit.get("id", ""), {}) if all_units is Dictionary else {}
	var practice = saved.get("practice", {}) if saved is Dictionary else {}
	var result = practice.get(position.get("id", ""), {}) if practice is Dictionary else {}
	return result if result is Dictionary else {}


func next_practice_position(unit: Dictionary) -> Dictionary:
	var positions := practice_positions(unit)
	for from_game in [true, false]:
		for position in positions:
			if bool(position.get("from_your_game", false)) == from_game and not practice_result(unit, position).get("solved", false):
				return position
	return positions[0] if not positions.is_empty() else {}


func clock_choice() -> String:
	return "none" if _progress.get("clock") == "none" else "5+5"


func playout_passed(unit: Dictionary, position: Dictionary) -> bool:
	var all_units = _progress.get("units", {})
	var saved = all_units.get(unit.get("id", ""), {}) if all_units is Dictionary else {}
	var playouts = saved.get("playouts", {}) if saved is Dictionary else {}
	return playouts is Dictionary and playouts.get(position.get("id", ""), false) == true


func record_playout_pass(unit: Dictionary, position: Dictionary) -> bool:
	var id: String = unit.get("id", "")
	var position_id: String = position.get("id", "")
	if id.is_empty() or position_id.is_empty():
		return false
	return _save_progress(func(next: Dictionary) -> bool:
		var all_units = next.get("units", {})
		if not all_units is Dictionary:
			return false
		var saved = all_units.get(id, {})
		if not saved is Dictionary:
			return false
		var playouts = saved.get("playouts", {})
		if not playouts is Dictionary:
			return false
		playouts[position_id] = true
		saved.playouts = playouts
		all_units[id] = saved
		next.units = all_units
		return true)


func save_clock_choice(choice: String) -> bool:
	if choice not in ["5+5", "none"]:
		return false
	return _save_progress(func(next: Dictionary) -> bool:
		next.clock = choice
		return true)


func open_theory(unit: Dictionary) -> bool:
	var id = unit.get("id", "")
	if not id is String or id.is_empty():
		return false
	return _save_progress(func(next: Dictionary) -> bool:
		var all_units = next.get("units", {})
		if not all_units is Dictionary:
			return false
		var saved = all_units.get(id, {})
		if not saved is Dictionary:
			return false
		saved.theory_opened = true
		all_units[id] = saved
		next.units = all_units
		return true)


func record_commit(unit: Dictionary, position: Dictionary, solved: bool) -> bool:
	var id: String = unit.get("id", "")
	var position_id: String = position.get("id", "")
	if id.is_empty() or position_id.is_empty():
		return false
	return _save_progress(func(next: Dictionary) -> bool:
		var all_units = next.get("units", {})
		if not all_units is Dictionary:
			return false
		var saved = all_units.get(id, {})
		if not saved is Dictionary:
			return false
		var practice = saved.get("practice", {})
		if not practice is Dictionary:
			return false
		var result = practice.get(position_id, {})
		if not result is Dictionary:
			return false
		var first: bool = result.is_empty()
		result.first_try = solved if first else result.get("first_try", false)
		result.solved = solved or result.get("solved", false)
		result.commits = int(result.get("commits", 0 if first else 1)) + 1
		practice[position_id] = result
		saved.practice = practice
		all_units[id] = saved
		next.units = all_units
		return true)
