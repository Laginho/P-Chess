extends RefCounted

# Finished games and per-level/control results (§9.4). A different root isolates tests.
const Pgn = preload("res://core/pgn.gd")
const Clock = preload("res://core/clock.gd")

var error := ""
var _root: String
var _results := ConfigFile.new()
var _load_error := OK


func _init(root := "user://") -> void:
	_root = root
	_load_error = _results.load(_root.path_join("stats.cfg"))


# clocks contains the moving side's remaining milliseconds after each played move.
# Returns the PGN path, or "" with a reportable error. opening_name is supplied by OPEN-002.
func save(game, clocks: Array, settings: Dictionary, opening_name := "") -> String:
	error = ""
	if _load_error not in [OK, ERR_FILE_NOT_FOUND]:
		error = "Could not read history stats (%s)." % error_string(_load_error)
		return ""
	if not game.is_over() or clocks.size() != game.moves.size():
		error = "History needs a finished game and one clock per move."
		return ""
	var maia_name: String = "Maia " + settings.level.trim_prefix("maia-")
	var control: Array = Clock.CONTROLS[settings.control]
	var headers := {
		"White": "You" if settings.colour == "w" else maia_name,
		"Black": maia_name if settings.colour == "w" else "You",
		"TimeControl": "%d+%d" % [control[0] / 1000, control[1] / 1000],
		"Result": game.result,
		"Termination": "Time forfeit" if game.reason == "time" else "Normal",
	}
	if opening_name:
		headers.Opening = opening_name
	var moves := []
	for i in game.moves.size():
		moves.append({"uci": game.moves[i], "clock_ms": clocks[i]})
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
	file.store_string(Pgn.write({"headers": headers, "moves": moves, "result": game.result}))
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
	status = _results.save(_root.path_join("stats.cfg"))
	if status != OK:
		error = "Could not save history stats (%s)." % error_string(status)
		return ""
	return path


# Counters are from the human's perspective; flag results are subsets of wins/losses.
func stats(level: String, control: String) -> Dictionary:
	return _results.get_value(level, control,
			{"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0}).duplicate()
