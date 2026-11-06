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


func test_settled_node_result_is_frozen_and_cached_for_the_line():
	var bridge := FakeBridge.new()
	var live = load("res://engine/live_analysis.gd").new(bridge)
	assert_true(live.has_method("result"), "settled positions are available by FEN")
	if not live.has_method("result"):
		live.free()
		bridge.free()
		return
	live.search(START)
	var budget: int = load("res://core/tunables.gd").ANALYSIS_NODES
	bridge.callbacks[0].call("info depth 15 multipv 1 score cp 30 nodes %d pv e2e4" % (budget - 1))
	bridge.callbacks[0].call("info depth 15 multipv 2 score cp 10 nodes %d pv d2d4" % (budget - 1))
	assert_true(live.result(START).is_empty(), "below budget remains undecided")
	bridge.callbacks[0].call("info depth 16 multipv 1 score cp 35 nodes %d pv e2e4" % budget)
	assert_true(live.result(START).is_empty(), "wait for the second line of the completed depth")
	bridge.callbacks[0].call("info depth 16 multipv 2 score cp 15 nodes %d pv d2d4" % budget)
	var result: Dictionary = live.result(START)
	assert_eq(result.get("fen"), START)
	assert_eq(result.get("best_move"), "e2e4")
	assert_eq(result.get("pv", []).size(), 2)
	bridge.callbacks[0].call("info depth 17 multipv 1 score cp 900 nodes 4000000 pv g1f3")
	assert_eq(live.result(START), result, "later unlimited updates do not change the class input")
	result.clear()
	assert_true(not live.result(START).is_empty(), "callers cannot mutate cached analysis")
	live.stop()
	assert_true(live.result(START).is_empty(), "leaving the line releases its cache")
	live.free()
	bridge.free()


func test_completed_depths_converge_early_and_one_legal_move_needs_only_pv1():
	for fen in [START, "7k/8/6K1/8/8/8/8/7R b - - 0 1"]:
		var bridge := FakeBridge.new()
		var live = load("res://engine/live_analysis.gd").new(bridge)
		live.search(fen)
		var forced: bool = fen != START
		var move := "h8g8" if forced else "e2e4"
		for depth in [10, 11, 12]:
			bridge.callbacks[0].call("info depth %d multipv 1 score cp 30 nodes 1000 pv %s" % [depth, move])
			assert_true(live.result(fen).is_empty() or (forced and depth == 12), "unfinished two-PV depths cannot converge")
			if not forced:
				bridge.callbacks[0].call("info depth %d multipv 2 score cp 10 nodes 1000 pv d2d4" % depth)
		assert_eq(live.result(fen).get("best_move"), move, "three stable completed depths settle before the node budget")
		assert_eq(live.result(fen).get("pv", []).size(), 1 if forced else 2)
		live.stop()
		live.free()
		bridge.free()


func test_required_position_finishes_before_shown_then_cache_is_reused_and_pruned():
	var bridge := FakeBridge.new()
	var live = load("res://engine/live_analysis.gd").new(bridge)
	assert_true(live.has_method("retain"), "line replacement can drop removed FENs")
	if not live.has_method("retain"):
		live.free()
		bridge.free()
		return
	var updates := []
	live.updated.connect(func(fen, _position): updates.append(fen))
	live.search(START)
	bridge.callbacks[0].call("info depth 10 multipv 1 score cp 30 nodes 1000 pv e2e4")
	live.search(AFTER, [START])
	assert_eq(bridge.searches_stopped, 0, "finish the needed before-position instead of cancelling it")
	bridge.callbacks[0].call("info depth 14 multipv 1 score cp 30 nodes 3000000 pv e2e4")
	bridge.callbacks[0].call("info depth 14 multipv 2 score cp 10 nodes 3000000 pv d2d4")
	assert_eq(updates, [START], "prerequisite results cannot masquerade as shown-position updates")
	assert_eq(bridge.searches_stopped, 1)
	bridge.callbacks[0].call("bestmove e2e4")
	assert_eq(bridge.callbacks.size(), 2)
	assert_true("position fen " + AFTER in bridge.commands)
	bridge.callbacks[1].call("info depth 14 multipv 1 score cp -30 nodes 3000000 pv e7e5")
	bridge.callbacks[1].call("info depth 14 multipv 2 score cp -40 nodes 3000000 pv c7c5")
	live.search(START)
	bridge.callbacks[1].call("bestmove e7e5")
	assert_eq(bridge.callbacks.size(), 3, "returning restarts only the shown-position live search")
	assert_eq(updates.back(), START, "cached PV is available on return")
	live.retain([AFTER])
	assert_true(live.result(START).is_empty(), "overwritten positions are dropped")
	assert_true(not live.result(AFTER).is_empty(), "retained positions keep their results")
	live.stop()
	live.free()
	bridge.free()


func test_return_to_settled_fen_keeps_latest_live_pv_and_resumes_unlimited_updates():
	var bridge := FakeBridge.new()
	var live = load("res://engine/live_analysis.gd").new(bridge)
	var updates := []
	var settled := []
	live.updated.connect(func(fen, position): updates.append([fen, position]))
	live.settled.connect(func(fen, _position): settled.append(fen))
	live.search(START)
	bridge.callbacks.back().call("info depth 16 multipv 1 score cp 30 nodes 3000000 pv e2e4")
	bridge.callbacks.back().call("info depth 16 multipv 2 score cp 10 nodes 3000000 pv d2d4")
	var frozen: Dictionary = live.result(START)
	bridge.callbacks.back().call("info depth 24 multipv 1 score cp 80 nodes 6000000 pv g1f3")
	bridge.callbacks.back().call("info depth 24 multipv 2 score cp 60 nodes 6000000 pv d2d4")
	live.search(AFTER, [START])
	bridge.callbacks.back().call("bestmove g1f3")
	bridge.callbacks.back().call("info depth 16 multipv 1 score cp -30 nodes 3000000 pv e7e5")
	bridge.callbacks.back().call("info depth 16 multipv 2 score cp -40 nodes 3000000 pv c7c5")
	live.search(START, [AFTER])
	assert_eq(updates.back()[0], START)
	assert_eq(updates.back()[1].pv[0].depth, 24, "return preserves the latest PV rather than the settlement snapshot")
	assert_eq(updates.back()[1].best_move, "g1f3")
	bridge.callbacks.back().call("bestmove e7e5")
	assert_eq(bridge.callbacks.size(), 3, "settled class inputs do not suppress the unlimited shown search")
	assert_eq(bridge.commands.back(), "go infinite")
	assert_eq(bridge.commands[-2], "position fen " + START)
	live.search(START, [AFTER])
	live._process(0.0)
	assert_eq(bridge.callbacks.size(), 3, "repeated scheduling keeps the same live search")
	bridge.callbacks.back().call("info depth 8 multipv 1 score cp 0 nodes 1000 pv e2e4")
	assert_eq(updates.back()[1].pv[0].depth, 24, "a restarted search must catch up before replacing newer PVs")
	bridge.callbacks.back().call("info depth 25 multipv 1 score cp 95 nodes 7000000 pv b1c3")
	assert_eq(updates.back()[1].pv[0].depth, 25)
	assert_eq(updates.back()[1].best_move, "b1c3")
	assert_eq(live.result(START), frozen, "live restarts never replace frozen classification inputs")
	assert_eq(settled, [START, AFTER], "returning never settles the same class input again")
	live.retain([AFTER])
	live.search(AFTER)
	bridge.callbacks.back().call("bestmove b1c3")
	var count: int = updates.size()
	live.search(START)
	assert_eq(updates.size(), count, "pruning also drops the removed position's live PV")
	live.stop()
	live.free()
	bridge.free()
