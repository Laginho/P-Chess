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


func test_recorded_fathom_transcript_is_parsed_without_live_tables():
	var setup := _setup()
	if setup.is_empty():
		return
	var received := []
	setup.probe.probe(RES_FEN, func(answer): received.append(answer))
	var lines := []
	for line in FileAccess.get_file_as_string("res://tests/fixtures/tablebase/res001.txt").split("\n"):
		if line.begins_with("info ") or line.begins_with("bestmove"):
			lines.append(line)
	setup.bridge.output(lines)
	assert_eq(received.size(), 1)
	if received.size() == 1:
		assert_true(received[0].ok)
		assert_eq(received[0].best, "a1h1")
		assert_eq(received[0].result, "win")
		assert_eq(received[0].dtz, 1)
		assert_eq(received[0].moves.size(), 18)
		assert_eq(received[0].moves.a1a5, {"result": "draw", "dtz": 0})
		assert_eq(received[0].moves.a1a3, {"result": "loss", "dtz": 3})
	_cleanup(setup)


func test_ranking_keeps_five_wdl_classes_and_uses_distance_then_uci_order():
	var setup := _setup()
	if setup.is_empty():
		return
	var cases := [
		[["loss", 2], {"a1a2": ["win", 3], "a1a3": ["win", 7]}, "a1a2", "win", 3],
		[["loss", 2], {"a1a2": ["win", 3], "a1a3": ["win", 3]}, "a1a2", "win", 3],
		[["loss", 2], {"a1a2": ["loss", 8], "a1a3": ["loss", 8]}, "a1a2", "loss", 8],
		[["draw", 0], {"a1a3": ["cursed-win", 7], "a1a2": ["cursed-win", 3]}, "a1a2", "draw", 3],
		[["loss", 2], {"a1a3": ["blessed-loss", 7], "a1a2": ["blessed-loss", 3]}, "a1a3", "draw", 7],
		[["blessed-loss", 5], {"a1a3": ["draw", 0]}, "a1a3", "draw", 0],
		[["cursed-win", 5], {"a1a3": ["win", 9]}, "a1a3", "win", 9],
		[["draw", 0], {}, "a1a2", "draw", 0]]
	for case in cases:
		var changes := {}
		for move in Board.from_fen(RES_FEN).legal_moves():
			changes[move] = case[0]
		changes.merge(case[1], true)
		var received := []
		setup.probe.probe(RES_FEN, func(answer): received.append(answer))
		_answer(setup, changes)
		assert_eq(received.size(), 1)
		if received.size() == 1:
			assert_eq(received[0].best, case[2], str(case))
			assert_eq(received[0].result, case[3])
			assert_eq(received[0].dtz, case[4])
	_cleanup(setup)


func test_terminal_and_invalid_positions_never_send_a_search():
	var setup := _setup()
	if setup.is_empty():
		return
	var before: String = setup.bridge.sent()
	for case in [["7k/6Q1/5K2/8/8/8/8/8 b - - 0 1", "loss"],
			["7k/5Q2/5K2/8/8/8/8/8 b - - 0 1", "draw"]]:
		var received := []
		setup.probe.probe(case[0], func(answer): received.append(answer))
		assert_eq(received, [{"ok": true, "result": case[1], "dtz": 0, "best": "", "moves": {}}])
	for fen in ["8/8/8/4k3/8/4K3/4P3/R6r w K - 0 1", "bad fen", "8/8/8/8/8/8/8/8 w - - 0 1"]:
		var received := []
		setup.probe.probe(fen, func(answer): received.append(answer))
		assert_eq(received.size(), 1, fen)
		if received.size() == 1:
			assert_eq(received[0].ok, false, fen)
	assert_eq(setup.bridge.sent(), before)
	_cleanup(setup)


func test_unparseable_errors_and_incomplete_move_sets_fail_closed():
	for lines in [["info string tberror missing KRPvKR.rtbz", "bestmove (none)"],
			["info string tbmove a1h1 win -1", "bestmove a1h1"],
			["info string tbmove a1h1 win 1 extra", "bestmove a1h1"],
			["info string tbmove a1h1 maybe 1", "bestmove a1h1"],
			["info string tbmove a1h1 draw 1", "bestmove a1h1"],
			["info string tbmove a1h1 win 9999999999999999999999", "bestmove a1h1"],
			["info string tbmove", "bestmove a1h1"],
			["info depth 1 score cp 999 pv a1h1", "bestmove a1h1"],
			["info string tbmove a1h1 win 1", "bestmove a1h1"],
			["bestmove (none)"], ["bestmove"],
			["info string tbmove a1h1 win 1", "info string tbmove a1h1 win 1", "bestmove a1h1"]]:
		var setup := _setup()
		if setup.is_empty():
			return
		var received := []
		setup.probe.probe(RES_FEN, func(answer): received.append(answer))
		setup.bridge.output(lines)
		assert_eq(received.size(), 1, str(lines))
		if received.size() == 1:
			assert_eq(received[0].ok, false, str(lines))
			assert_true(not received[0].get("error", "").is_empty())
		_cleanup(setup)


func test_extra_or_incorrect_best_moves_are_rejected():
	for bad_best in ["a1a1", "(none)", "a1h1 extra"]:
		var setup := _setup()
		if setup.is_empty():
			return
		var received := []
		setup.probe.probe(RES_FEN, func(answer): received.append(answer))
		_answer(setup, {}, bad_best)
		assert_eq(received.size(), 1)
		if received.size() == 1:
			assert_eq(received[0].ok, false, bad_best)
		_cleanup(setup)
	var setup := _setup()
	if setup.is_empty():
		return
	var received := []
	setup.probe.probe(RES_FEN, func(answer): received.append(answer))
	setup.bridge.output(["info string tbmove a1a1 draw 0"])
	_answer(setup)
	assert_eq(received.size(), 1)
	if received.size() == 1:
		assert_eq(received[0].ok, false)
	_cleanup(setup)


func test_requests_queue_and_callback_reentry_preserves_the_next_answer():
	var setup := _setup()
	if setup.is_empty():
		return
	var received := []
	setup.probe.probe(RES_FEN, func(answer):
		received.append(answer)
		setup.probe.probe(RES_FEN, func(next): received.append(next)))
	_answer(setup, {"a1h1": ["win", 1]})
	assert_eq(received.size(), 1)
	_answer(setup, {"a1a3": ["win", 2]})
	assert_eq(received.size(), 2)
	if received.size() == 2:
		assert_eq(received[0].best, "a1h1")
		assert_eq(received[1].best, "a1a3")
	_cleanup(setup)


func test_stop_error_and_free_finish_all_pending_callbacks_once():
	for reason in ["crash", "error", "free"]:
		var setup := _setup()
		if setup.is_empty():
			return
		var received := []
		for i in 3:
			setup.probe.probe(RES_FEN, func(answer): received.append(answer))
		if reason == "free":
			setup.probe.free()
		elif reason == "error":
			setup.bridge.output(["error tablebase files not found in ../tablebase"])
		else:
			# Exercise the stopped signal at the UCI seam; UCI owns process detection.
			setup.bridge._report_stopped("Tablebase probe crashed.")
		assert_eq(setup.bridge.available, false, reason)
		assert_eq(received.size(), 3, reason)
		if reason != "free":
			assert_eq(setup.probe.available, false, reason)
			setup.probe.probe(RES_FEN, func(answer): received.append(answer))
			assert_eq(received.size(), 4, reason)
			setup.probe.free()
		for answer in received:
			assert_eq(answer.ok, false)
			assert_true(not answer.error.is_empty())
		setup.bridge.cleanup()
		setup.bridge.free()
		_remove(setup.root)


func _live():
	if OS.get_name() != "Linux" or not FileAccess.file_exists("res://engine/tablebase/KRPvKR.rtbz"):
		print("SKIP tablebase real-file checks: requires the Linux tablebase installation")
		return null
	var script = _script()
	if script == null:
		return null
	var probe = script.new()
	assert_true(probe.start(), probe.error)
	return probe


func _probe(probe, fen: String) -> Dictionary:
	var received := []
	probe.probe(fen, func(answer): received.append(answer))
	var deadline := Time.get_ticks_msec() + 5000
	while received.is_empty() and Time.get_ticks_msec() < deadline:
		probe.poll()
		OS.delay_msec(1)
	assert_eq(received.size(), 1, "one answer within 5 s: " + fen)
	return received[0] if received else {"ok": false, "error": "test timeout"}


func test_real_res001_move_values_and_complete_move_set():
	var probe = _live()
	if probe == null:
		return
	var answer := _probe(probe, RES_FEN)
	assert_true(answer.ok, answer.get("error", ""))
	if answer.ok:
		assert_eq(answer.result, "win")
		assert_eq(answer.best, "a1h1")
		assert_eq(answer.dtz, 1)
		assert_eq(answer.moves.size(), 18)
		assert_eq(answer.moves.a1h1, {"result": "win", "dtz": 1})
		assert_eq(answer.moves.a1a5, {"result": "draw", "dtz": 0})
		assert_eq(answer.moves.a1a3, {"result": "loss", "dtz": 3})
		var expected := Array(Board.from_fen(RES_FEN).legal_moves())
		var actual: Array = answer.moves.keys()
		expected.sort()
		actual.sort()
		assert_eq(actual, expected)
	probe.free()


func test_real_promotions_nonzeroing_distance_rule50_and_bare_kings():
	var probe = _live()
	if probe == null:
		return
	# Independent expected values: python-chess 1.11.2, outside this repository.
	var promotion := _probe(probe, "8/7P/8/8/2k5/8/8/1K6 w - - 0 1")
	assert_true(promotion.ok, promotion.get("error", ""))
	if promotion.ok:
		assert_eq(promotion.moves.h7h8q, {"result": "win", "dtz": 1})
		assert_eq(promotion.moves.h7h8r, {"result": "win", "dtz": 1})
		assert_eq(promotion.moves.h7h8b, {"result": "draw", "dtz": 0})
		assert_eq(promotion.moves.h7h8n, {"result": "draw", "dtz": 0})
	var win_fen := "8/8/8/4k3/8/4K3/8/R7 w - - 0 1"
	var win := _probe(probe, win_fen)
	var child := _probe(probe, "8/8/8/4k3/8/5K2/8/R7 b - - 1 1")
	var cursed := _probe(probe, win_fen.replace(" 0 1", " 98 1"))
	assert_true(win.ok and child.ok and cursed.ok, str([win, child, cursed]))
	if win.ok and child.ok and cursed.ok:
		assert_eq(win.result, "win")
		assert_eq(win.moves.e3f3, {"result": "win", "dtz": 27})
		assert_eq(child.dtz, 26)
		assert_eq(win.moves.e3f3.dtz, child.dtz + 1)
		assert_eq(cursed.result, "draw")
	# This is intrinsically cursed even with clock 0: raw DTZ50=102 means 2 plies.
	var intrinsic := _probe(probe, "7k/8/3Br3/8/3R2K1/8/8/8 w - - 0 1")
	assert_true(intrinsic.ok, intrinsic.get("error", ""))
	if intrinsic.ok:
		assert_eq(intrinsic.best, "g4f5")
		assert_eq(intrinsic.result, "draw")
		assert_eq(intrinsic.dtz, 2)
		assert_eq(intrinsic.moves.g4f5, {"result": "draw", "dtz": 2})
	var capture := _probe(probe, "8/8/8/4k3/8/8/1r6/1K6 w - - 0 1")
	assert_true(capture.ok, capture.get("error", ""))
	if capture.ok:
		assert_eq(capture.moves.b1b2, {"result": "draw", "dtz": 0})
	assert_eq(_probe(probe, "8/8/8/4k3/8/4K3/4P3/R5Rr w - - 0 1").ok, false)
	assert_eq(_probe(probe, RES_FEN.replace(" w - ", " w K ")).ok, false)
	probe.free()


func test_real_helper_protocol_and_missing_position_or_child_tables():
	if OS.get_name() != "Linux" or not FileAccess.file_exists("res://engine/tablebase/KRPvKR.rtbz"):
		print("SKIP native helper checks: requires the Linux tablebase installation")
		return
	var helper := ProjectSettings.globalize_path("res://engine/tbprobe/tbprobe")
	assert_true(FileAccess.file_exists(helper), "native helper is missing; run scripts/build-tbprobe.ps1")
	if not FileAccess.file_exists(helper):
		return
	var child := OS.execute_with_pipe(helper, [])
	child.stdio.store_string("uci\nsetoption name SyzygyPath value ../tablebase\nisready\nposition fen " + RES_FEN + "\ngo\n")
	assert_true(child.stdio.get_line().begins_with("id name P-Chess tbprobe (Fathom "))
	assert_eq(child.stdio.get_line(), "uciok")
	assert_eq(child.stdio.get_line(), "readyok")
	var count := 0
	var line: String = child.stdio.get_line()
	while line.begins_with("info string tbmove "):
		count += 1
		line = child.stdio.get_line()
	assert_eq(count, 18)
	assert_eq(line, "bestmove a1h1")
	for fen in [RES_FEN.replace(" w - ", " w K "), "bad fen",
			"8/8/8/4k3/8/4K3/4P3/R5Rr w - - 0 1"]:
		child.stdio.store_string("position fen " + fen + "\ngo\n")
		assert_true(child.stdio.get_line().begins_with("info string tberror "), fen)
		assert_eq(child.stdio.get_line(), "bestmove (none)")
	child.stdio.store_string("position fen 7k/6Q1/5K2/8/8/8/8/8 b - - 0 1\ngo\n")
	assert_eq(child.stdio.get_line(), "bestmove (none)")
	var root := OS.get_user_data_dir().path_join("tb-missing-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(root)
	for suffix in [".rtbw", ".rtbz"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://engine/tablebase/KRvK" + suffix), root.path_join("KRvK" + suffix))
	child.stdio.store_string("setoption name SyzygyPath value " + root + "\nposition fen " + RES_FEN + "\ngo\n")
	assert_true(child.stdio.get_line().begins_with("info string tberror "))
	assert_eq(child.stdio.get_line(), "bestmove (none)")
	# The position's own pair is present; a capturable rook leads to missing KRPvK.
	for suffix in [".rtbw", ".rtbz"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://engine/tablebase/KRPvKR" + suffix), root.path_join("KRPvKR" + suffix))
	child.stdio.store_string("setoption name SyzygyPath value " + root + "\nposition fen " + RES_FEN + "\ngo\n")
	assert_true(child.stdio.get_line().begins_with("info string tberror "))
	assert_eq(child.stdio.get_line(), "bestmove (none)")
	child.stdio.store_line("quit")
	child.stdio.close()
	child.stderr.close()
	_remove(root)
