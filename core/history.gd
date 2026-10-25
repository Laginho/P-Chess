extends RefCounted

# Finished games and per-level/control results (§9.4). A different root isolates tests.
const Pgn = preload("res://core/pgn.gd")

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
func save(game, clocks: Array, settings: Dictionary, opening_name := "", target_id := "") -> String:
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
	file.store_string(Pgn.write(Pgn.finished_game(game, clocks, settings, opening_name)))
	file.flush()
	status = file.get_error()
	file.close()
	if status != OK:
		error = "Could not write game PGN (%s)." % error_string(status)
		return ""
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
		error = "Could not save history stats (%s)." % error_string(status)
		return ""
	return path


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
