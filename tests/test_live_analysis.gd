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
