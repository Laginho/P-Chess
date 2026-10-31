extends RefCounted

# Finished games and per-level/control results (§9.4). A different root isolates tests.
const Pgn = preload("res://core/pgn.gd")
const Game = preload("res://core/game.gd")

var error := ""
# Shared loaded catalog; recognition applies in every mode, independently of its checks.
var book
var _root: String
var _results := ConfigFile.new()
var _load_error := OK


func _init(root := "user://") -> void:
	_root = root
	_load_error = _results.load(_root.path_join("stats.cfg"))


# clocks contains the moving side's remaining milliseconds after each played move.
# Returns the PGN path, or "" with a reportable error. An explicit Opening overrides recognition.
# Main supplies the selected target only once, with its completed-game save.
func save(game, clocks: Array, settings: Dictionary, opening_name := "", target_id := "",
		repertoire: Array = [], repertoire_colour := "") -> String:
	error = ""
	if _load_error not in [OK, ERR_FILE_NOT_FOUND]:
		error = "Could not read history stats (%s)." % error_string(_load_error)
		return ""
	if not game.is_over() or clocks.size() != game.moves.size():
		error = "History needs a finished game and one clock per move."
		return ""
	if opening_name.is_empty() and book != null:
		opening_name = book.opening_name(game.moves)
	var folder := _root.path_join("games")
	var status := DirAccess.make_dir_recursive_absolute(folder)
	if status != OK:
		error = "Could not create game history folder (%s)." % error_string(status)
		return ""
	var stem := "%s_%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()]
	var path := folder.path_join(stem + ".pgn")
	var suffix := 1
	while FileAccess.file_exists(path):
		path = folder.path_join("%s_%d.pgn" % [stem, suffix])
		suffix += 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		error = "Could not save game PGN (%s)." % error_string(FileAccess.get_open_error())
		return ""
	file.store_string(Pgn.write(Pgn.finished_game(game, clocks, settings, opening_name, target_id)))
	file.flush()
	status = file.get_error()
	file.close()
	if status != OK:
		error = "Could not write game PGN (%s)." % error_string(status)
		return ""
	if not repertoire.is_empty():
		var snapshot := FileAccess.open(path.trim_suffix(".pgn") + ".repertoire.json", FileAccess.WRITE)
		if snapshot == null:
			error = "Could not save repertoire snapshot (%s)." % error_string(FileAccess.get_open_error())
		else:
			var lines := []
			for line in repertoire:
				lines.append({"id": line.id, "moves": Array(line.moves), "positions": Array(line.positions)})
			snapshot.store_string(JSON.stringify({"colour": repertoire_colour, "lines": lines}))
			snapshot.flush()
			status = snapshot.get_error()
			snapshot.close()
			if status != OK:
				error = "Could not write repertoire snapshot (%s)." % error_string(status)
	var counts := stats(settings.level, settings.control)
	if game.result == "1/2-1/2":
		counts.draws += 1
	else:
		var won: bool = game.result == ("1-0" if settings.colour == "w" else "0-1")
		counts["wins" if won else "losses"] += 1
		if game.reason == "time":
			counts["flag_wins" if won else "flag_losses"] += 1
	_results.set_value(settings.level, settings.control, counts)
	var practiced: int = practice_counts().get(target_id, 0)
	if not target_id.is_empty():
		_results.set_value("practice", target_id, practiced + 1)
	status = _results.save(_root.path_join("stats.cfg"))
	if status != OK:
		if not target_id.is_empty():
			_results.set_value("practice", target_id, practiced)
		error += ("\n" if not error.is_empty() else "") + "Could not save history stats (%s)." % error_string(status)
		return ""
	return path


func read_repertoire(path: String) -> Dictionary:
	var snapshot_path := path.trim_suffix(".pgn") + ".repertoire.json"
	if not FileAccess.file_exists(snapshot_path):
		return {"colour": "", "lines": []}
	var data = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
	if not data is Dictionary or not data.get("lines") is Array or not data.get("colour") is String:
		return {"colour": "", "lines": []}
	for line in data.lines:
		if not line is Dictionary or not line.get("moves") is Array or not line.get("positions") is Array:
			return {"colour": "", "lines": []}
		line.moves = PackedStringArray(line.moves)
		line.positions = PackedStringArray(line.positions)
	return data


func delete(path: String) -> bool:
	error = ""
	if _load_error not in [OK, ERR_FILE_NOT_FOUND] or not FileAccess.file_exists(path):
		error = "Could not read game or history stats."
		return false
	var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty() or parsed.games.size() != 1:
		error = "Could not read game PGN."
		return false
	var game: Dictionary = parsed.games[0]
	var headers: Dictionary = game.headers
	var human := "w" if headers.get("White", "") == "You" else "b"
	var opponent: String = headers.get("Black" if human == "w" else "White", "")
	var level := "maia-" + opponent.trim_prefix("Maia ")
	var controls := {"60+0": "1+0", "180+2": "3+2", "300+0": "5+0"}
	var control: String = controls.get(headers.get("TimeControl", ""), "")
	var counts := stats(level, control)
	var previous := counts.duplicate()
	var key := "draws" if game.result == "1/2-1/2" else ("wins" if (game.result == "1-0") == (human == "w") else "losses")
	counts[key] = maxi(0, counts[key] - 1)
	if key != "draws" and reason(game) == "time":
		var flag := "flag_wins" if key == "wins" else "flag_losses"
		counts[flag] = maxi(0, counts[flag] - 1)
	var target: String = headers.get("PracticeTarget", "")
	var practiced: int = practice_counts().get(target, 0)
	var paths := [path, path.trim_suffix(".pgn") + ".repertoire.json", "user://analysis".path_join(path.get_file() + ".json")]
	var moved := []
	var contents := {}
	for source in paths:
		if not FileAccess.file_exists(source):
			continue
		var file := FileAccess.open(source, FileAccess.READ)
		if file == null:
			for item in moved:
				DirAccess.rename_absolute(item + ".deleting", item)
			error = "Could not read game files."
			return false
		contents[source] = file.get_buffer(file.get_length())
		file.close()
		var backup: String = source + ".deleting"
		if FileAccess.file_exists(backup) or DirAccess.rename_absolute(source, backup) != OK:
			for item in moved:
				DirAccess.rename_absolute(item + ".deleting", item)
			error = "Could not delete game files."
			return false
		moved.append(source)
	for item in moved:
		if DirAccess.remove_absolute(item + ".deleting") != OK:
			_restore_deleted_files(moved, contents)
			error = "Could not delete game files."
			return false
	_results.set_value(level, control, counts)
	if not target.is_empty():
		_results.set_value("practice", target, maxi(0, practiced - 1))
	if _results.save(_root.path_join("stats.cfg")) != OK:
		_results.set_value(level, control, previous)
		if not target.is_empty():
			_results.set_value("practice", target, practiced)
		_restore_deleted_files(moved, contents)
		error = "Could not save history stats."
		return false
	return true


func _restore_deleted_files(paths: Array, contents: Dictionary) -> void:
	for path in paths:
		if FileAccess.file_exists(path + ".deleting"):
			DirAccess.rename_absolute(path + ".deleting", path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(contents[path])
				file.close()


func games() -> Array:
	var folder := _root.path_join("games")
	var result := []
	if not DirAccess.dir_exists_absolute(folder):
		return result
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".pgn"):
			continue
		var path := folder.path_join(file)
		var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
		if parsed.error.is_empty() and parsed.games.size() == 1:
			result.append({"path": path, "game": parsed.games[0], "modified": FileAccess.get_modified_time(path)})
	result.sort_custom(func(a, b): return a.modified > b.modified if a.modified != b.modified else a.path > b.path)
	return result


func thumbnail(moves: PackedStringArray) -> Dictionary:
	var endings := {}
	var positions := {}
	if book != null:
		for entry in book.entries:
			for key in entry.positions:
				positions[key] = true
			endings[entry.positions[-1]] = entry.name
	var game = Game.new()
	var match_ply := 0
	var opening := ""
	for i in moves.size():
		if not game.play(moves[i]):
			break
		var key: String = game.board.position_key()
		if positions.has(key):
			match_ply = i + 1
		if endings.has(key):
			opening = endings[key]
	return {"ply": match_ply if match_ply > 0 else mini(10, moves.size()), "opening": opening}


func reason(game: Dictionary) -> String:
	var headers: Dictionary = game.headers
	if not headers.get("Reason", "").is_empty():
		return headers.Reason
	if headers.get("Termination", "") == "Time forfeit":
		return "time"
	var replay = Game.new(headers.get("FEN", Pgn.START))
	for move in game.moves:
		if not replay.play(move.uci):
			break
	if replay.reason in ["checkmate", "stalemate", "insufficient material", "50-move"]:
		return replay.reason
	if game.result in ["1-0", "0-1"] and headers.get("Termination", "") == "Normal":
		return "resignation"
	return ""


# Counters are from the human's perspective; flag results are subsets of wins/losses.
# A corrupt record counts as zero and reports through the same error shown by Main.
func stats(level: String, control: String) -> Dictionary:
	var empty := {"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0}
	var counts = _results.get_value(level, control, empty)
	var valid: bool = counts is Dictionary
	if valid:
		for counter in empty:
			if not counts.has(counter) or typeof(counts[counter]) != TYPE_INT or counts[counter] < 0:
				valid = false
				break
	if not valid:
		_report_corrupt_stats(level, control)
		return empty
	return counts.duplicate()


# Shared warning path for corrupt values in stats.cfg, including practice counts.
func _report_corrupt_stats(section: String, key: String) -> void:
	var warning := "Corrupt history stats (%s/%s); invalid counters reset to zero." % [section, key]
	if not error.contains(warning):
		error += ("\n" if not error.is_empty() else "") + warning


# Invalid stored counts are zero for target selection; retain every valid line.
func practice_counts() -> Dictionary:
	var counts := {}
	if _results.has_section("practice"):
		for id in _results.get_section_keys("practice"):
			var count = _results.get_value("practice", id, 0)
			if typeof(count) != TYPE_INT or count < 0:
				_report_corrupt_stats("practice", id)
				count = 0
			counts[id] = count
	return counts
