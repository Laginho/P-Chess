extends SceneTree

const Pgn = preload("res://core/pgn.gd")
const Uci = preload("res://engine/uci.gd")
const Analyser = preload("res://engine/analyser.gd")

var _bridge
var _started := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not FileAccess.file_exists(args[0]):
		_fail("Usage: godot --headless -s scripts/analyse.gd -- <pgn>")
		return
	var parsed: Dictionary = Pgn.parse(FileAccess.get_file_as_string(args[0]))
	if parsed.error != "" or parsed.games.size() != 1:
		_fail("Expected one valid game: " + parsed.error)
		return
	var positions := Analyser.positions_from_game(parsed.games[0])
	if positions.is_empty():
		_fail("Invalid game positions")
		return
	_bridge = Uci.new("engine/stockfish/stockfish.exe", "Stockfish")
	root.add_child(_bridge)
	_bridge.stopped.connect(func(): _fail(_bridge.error))
	var dirs := Uci.search_dirs()
	dirs.append(ProjectSettings.globalize_path("res://"))
	if not _bridge.start(dirs):
		_fail(_bridge.error)
		return
	var analyser = Analyser.new(_bridge)
	root.add_child(analyser)
	analyser.progress.connect(func(done, total): print("%d/%d positions" % [done, total]))
	analyser.finished.connect(_finished)
	var output := "user://analysis".path_join(args[0].get_file() + ".json")
	_started = Time.get_ticks_msec()
	if not analyser.analyse(positions, output, true, parsed.games[0].result == "1/2-1/2"):
		_fail("Could not start analysis")


func _finished(success: bool, error: String) -> void:
	if not success:
		_fail(error)
		return
	print("Analysis saved in %.1f s" % ((Time.get_ticks_msec() - _started) / 1000.0))
	quit(0)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
