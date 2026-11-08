extends "res://tests/run.gd".Test

const UCI = preload("res://engine/uci.gd")
const Board = preload("res://core/board.gd")
const RES_FEN := "8/8/8/4k3/8/4K3/4P3/R6r w - - 0 1"
const MATERIALS := ["KBvK", "KNvK", "KPvK", "KQRvK", "KQRvKR", "KQvK", "KQvKR",
		"KRBvK", "KRBvKR", "KRNvK", "KRNvKR", "KRPvK", "KRPvKR", "KRRvK", "KRRvKR",
		"KRvK", "KRvKB", "KRvKN", "KRvKP", "KRvKR"]

# The real UCI queue and parser, with stdout injected as in test_uci.gd.
class FakeUCI extends UCI:
	var commands := "user://tb-commands-%d.txt" % Time.get_ticks_usec()
	var child := {}
	func start(_dirs := search_dirs()) -> bool:
		child = OS.execute_with_pipe(OS.get_executable_path(), ["--headless", "--path",
				ProjectSettings.globalize_path("res://"), "-s", "res://tests/fixtures/idle_child.gd"], false)
		pid = child.pid
		_stdio = FileAccess.open(commands, FileAccess.WRITE_READ)
		available = true
		_queue(["uci"], "uciok")
		return true
	func output(lines: Array) -> void:
		_lines.append_array(lines)
		poll()
	func sent() -> String:
		_stdio.flush()
		return FileAccess.get_file_as_string(commands)
	func cleanup() -> void:
		child.stdio.close()
		child.stderr.close()
		DirAccess.remove_absolute(commands)


func _script():
	assert_true(ResourceLoader.exists("res://engine/tablebase.gd"), "tablebase probe is missing")
	return load("res://engine/tablebase.gd") if ResourceLoader.exists("res://engine/tablebase.gd") else null


func _installation() -> String:
	var root := OS.get_user_data_dir().path_join("tb-install-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(root.path_join("engine/tbprobe"))
	DirAccess.make_dir_recursive_absolute(root.path_join("engine/tablebase"))
	var binary := "tbprobe.exe" if OS.get_name() == "Windows" else "tbprobe"
	FileAccess.open(root.path_join("engine/tbprobe/" + binary), FileAccess.WRITE).close()
	for material in MATERIALS:
		for suffix in [".rtbw", ".rtbz"]:
			FileAccess.open(root.path_join("engine/tablebase/" + material + suffix), FileAccess.WRITE).close()
	return root


func _remove(root: String) -> void:
	for file in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(file))
	for dir in DirAccess.get_directories_at(root):
		_remove(root.path_join(dir))
	DirAccess.remove_absolute(root)


func _setup() -> Dictionary:
	var script = _script()
	if script == null:
		return {}
	var bridge := FakeUCI.new("engine/tbprobe/tbprobe", "Tablebase probe")
	var probe = script.new(bridge)
	var root := _installation()
	assert_true(probe.start(PackedStringArray([root])), probe.error)
	bridge.output(["id name P-Chess tbprobe (Fathom test)", "uciok", "readyok"])
	return {"probe": probe, "bridge": bridge, "root": root}


func _cleanup(setup: Dictionary) -> void:
	setup.probe.free()
	setup.bridge.cleanup()
	setup.bridge.free()
	_remove(setup.root)


func _answer(setup: Dictionary, changes := {}, best := "a1h1", fen := RES_FEN) -> void:
	var lines := []
	for move in Board.from_fen(fen).legal_moves():
		var value: Array = changes.get(move, ["draw", 0])
		lines.append("info string tbmove %s %s %d" % [move, value[0], value[1]])
	lines.append("bestmove " + best)
	setup.bridge.output(lines)


func test_start_checks_the_helper_and_each_required_table():
	var script = _script()
	if script == null:
		return
	var probe = script.new()
	assert_eq(probe.start(PackedStringArray(["user://no-tb-install"])), false)
	assert_eq(probe.available, false)
	assert_eq(probe.error, "Tablebase probe is missing (engine/tbprobe/tbprobe.exe). Run scripts/build-tbprobe.ps1 to build it.")
	probe.free()
	var root := _installation()
	for material in MATERIALS:
		for suffix in [".rtbw", ".rtbz"]:
			var path := root.path_join("engine/tablebase/" + material + suffix)
			DirAccess.remove_absolute(path)
			probe = script.new()
			assert_eq(probe.start(PackedStringArray([root])), false)
			assert_true(material + suffix in probe.error, probe.error)
			assert_true("scripts/fetch-engine.ps1" in probe.error, probe.error)
			probe.free()
			FileAccess.open(path, FileAccess.WRITE).close()
	_remove(root)


func test_start_sets_a_relative_path_and_probe_returns_every_move_once():
	var setup := _setup()
	if setup.is_empty():
		return
	assert_eq(setup.bridge.sent(), "uci\nsetoption name SyzygyPath value ../tablebase\nisready\n")
	var received := []
	setup.probe.probe(RES_FEN, func(answer): received.append(answer))
	assert_eq(received.size(), 0, "waits for the helper without blocking")
	_answer(setup, {"a1h1": ["win", 1], "a1a3": ["loss", 3]})
	assert_eq(received.size(), 1)
	if received.size() == 1:
		assert_eq(received[0].ok, true)
		assert_eq(received[0].result, "win")
		assert_eq(received[0].dtz, 1)
		assert_eq(received[0].best, "a1h1")
		assert_eq(received[0].moves.size(), 18)
		assert_eq(received[0].moves.a1h1, {"result": "win", "dtz": 1})
		assert_eq(received[0].moves.a1a3, {"result": "loss", "dtz": 3})
	_cleanup(setup)
