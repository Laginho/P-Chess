extends "res://tests/run.gd".Test

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const AFTER := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"

class FakeBridge extends Node:
	signal stopped
	var engine_id := "Stockfish 19"
	var error := ""
	var starts := true
	var commands := []
	var callbacks := []
	var stops := 0
	var stop_events := []
	var searches_stopped := 0
	func start() -> bool:
		return starts
	func new_game() -> void:
		commands.append("ucinewgame")
	func request_search(lines: PackedStringArray, callback: Callable) -> void:
		commands.append_array(Array(lines))
		callbacks.append(callback)
	func stop_search() -> void:
		searches_stopped += 1
		commands.append("stop")
	func stop() -> void:
		stops += 1
		stop_events.append(true)


func test_live_search_sets_two_lines_and_max_threads_switches_without_stale_results():
	var script = load("res://engine/live_analysis.gd")
	assert_true(script != null and script.can_instantiate(), "live controller exists")
	if script == null or not script.can_instantiate():
		return
	var bridge := FakeBridge.new()
	var live = script.new(bridge)
	var updates := []
	live.updated.connect(func(fen, position): updates.append([fen, position]))
	assert_true(live.search(START))
	assert_true("setoption name Threads value %d" % maxi(1, OS.get_processor_count() - 1) in bridge.commands)
	assert_true("setoption name MultiPV value 2" in bridge.commands)
	assert_true("go infinite" in bridge.commands)
	bridge.callbacks[0].call("info depth 12 multipv 1 score cp 32 nodes 4500 pv e2e4 e7e5")
	assert_eq(updates.size(), 1)
	assert_eq(updates[0][0], START)
	assert_eq(updates[0][1].pv[0].cp, 32)
	assert_eq(updates[0][1].pv[0].nodes, 4500)
	assert_true(live.search(AFTER))
	assert_eq(bridge.searches_stopped, 1)
	bridge.callbacks[0].call("info depth 13 score cp 500 pv d2d4")
	assert_eq(updates.size(), 1, "old search cannot publish after switching")
	bridge.callbacks[0].call("bestmove e2e4")
	assert_true(bridge.commands.find("stop") < bridge.commands.find("position fen " + AFTER))
	assert_eq(bridge.callbacks.size(), 2)
	bridge.callbacks[1].call("info depth 14 multipv 1 score cp -20 pv e7e5")
	assert_eq(updates.back()[0], AFTER)
	assert_eq(updates.back()[1].best_move, "e7e5")
	live.stop()
	bridge.callbacks[1].call("info depth 15 score cp 300 pv c7c5")
	assert_eq(updates.size(), 2, "stop invalidates callbacks")
	assert_eq(bridge.stops, 1, "stop releases the engine process")
	live.free()
	bridge.free()


# An in-memory engine endpoint on the real UCI command queue. uciok is delayed
# independently of id name, just as the reader can deliver them on separate frames.
class HandshakingBridge extends "res://engine/uci.gd":
	var transcript_path := "user://rev008-handshake-%d.txt" % Time.get_ticks_usec()
	var child_script := transcript_path + ".gd"
	func start(_dirs := PackedStringArray()) -> bool:
		available = true
		# Godot's process monitor accepts only children it launched, not its own PID.
		var file := FileAccess.open(child_script, FileAccess.WRITE)
		file.store_string("extends SceneTree\n")
		file.close()
		pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
				"--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", ProjectSettings.globalize_path(child_script)]))
		_stdio = FileAccess.open(transcript_path, FileAccess.WRITE)
		_queue(["uci"], "uciok")
		deliver("id name Test Stockfish")
		return true
	func deliver(line: String) -> void:
		_lines.append(line)
		poll()
		_stdio.flush()
	func transcript() -> String:
		_stdio.flush()
		return FileAccess.get_file_as_string(transcript_path)
	func stop() -> void:
		super.stop()
		DirAccess.remove_absolute(transcript_path)
		DirAccess.remove_absolute(child_script)


func test_switch_before_uciok_still_stops_old_search_and_reaches_latest_fen():
	var bridge := HandshakingBridge.new()
	var live = load("res://engine/live_analysis.gd").new(bridge)
	var updates := []
	live.updated.connect(func(fen, position): updates.append([fen, position]))
	assert_true(live.search(START))
	assert_true(live.search(AFTER), "switch while old search is queued behind uciok")
	bridge.deliver("uciok")
	assert_true(bridge.transcript().contains("go infinite\nstop\n"), "queued old search is stopped when it finally starts")
	bridge.deliver("info depth 8 score cp 200 pv e2e4")
	assert_eq(updates.size(), 0)
	bridge.deliver("bestmove e2e4")
	assert_true(bridge.transcript().contains("position fen " + AFTER))
	bridge.deliver("info depth 9 score cp -20 pv e7e5")
	assert_eq(updates.back()[0], AFTER)
	live.stop()
	live.free()
	bridge.free()


func test_second_pv_first_never_becomes_the_primary_score_or_arrow():
	var bridge := FakeBridge.new()
	var live = load("res://engine/live_analysis.gd").new(bridge)
	var updates := []
	live.updated.connect(func(_fen, position): updates.append(position))
	assert_true(live.search(START))
	bridge.callbacks[0].call("info depth 10 multipv 2 score cp 10 pv d2d4")
	assert_true(updates.is_empty() or updates.back().pv.is_empty(), "PV2 cannot masquerade as PV1")
	bridge.callbacks[0].call("info depth 10 multipv 1 score cp 30 pv e2e4")
	assert_eq(updates.back().pv[0].cp, 30)
	assert_eq(updates.back().pv[1].cp, 10)
	bridge.callbacks[0].call("info depth 11 multipv 1 score cp 200 lowerbound pv e2e4")
	assert_eq(updates.back().pv[0].cp, 30, "a bound is not an exact score")
	live.stop()
	live.free()
	bridge.free()
