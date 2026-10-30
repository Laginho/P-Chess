extends "res://tests/run.gd".Test

const Analyser = preload("res://engine/analyser.gd")
const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const AFTER := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"

class FakeBridge extends RefCounted:
	var engine_id := "Stockfish 19"
	var searches := []
	var callback := Callable()
	var stops := 0
	func request_search(commands: PackedStringArray, next: Callable) -> void:
		searches.append(Array(commands))
		callback = next
	func stop_search() -> void:
		stops += 1
	func answer() -> void:
		callback.call("info depth 12 multipv 1 score cp 32 pv e7e5 g1f3")
		callback.call("info depth 12 multipv 2 score cp 10 pv c7c5")
		callback.call("bestmove e7e5")


func test_reverse_order_progress_persistence_and_staleness():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	var progress := []
	analyser.progress.connect(func(done, total): progress.append([done, total]))
	var path := "user://rev002-test.json"
	DirAccess.remove_absolute(path)
	assert_true(analyser.analyse([START, AFTER], path, false))
	assert_true("position fen " + AFTER in bridge.searches[0])
	assert_true("setoption name MultiPV value 2" in bridge.searches[0])
	assert_true("setoption name Threads value 1" in bridge.searches[0])
	assert_true("ucinewgame" in bridge.searches[0])
	assert_true("go nodes 3000000" in bridge.searches[0])
	bridge.answer()
	assert_true("position fen " + START in bridge.searches[1])
	bridge.answer()
	assert_eq(progress, [[1, 2], [2, 2]])
	var result: Dictionary = Analyser.read_analysis(path, "Stockfish 19", 3000000)
	assert_eq(result.state, "analysed")
	assert_eq(result.data.positions[1].best_move, "e7e5")
	assert_eq(result.data.positions[1].pv.size(), 2)
	assert_eq(Analyser.read_analysis(path, "Stockfish 20", 3000000).state, "stale")
	assert_eq(Analyser.read_analysis(path, "Stockfish 19", 1).state, "stale")
	DirAccess.remove_absolute(path)
	assert_eq(Analyser.read_analysis(path, "Stockfish 19", 3000000).state, "not analysed")
	analyser.free()


func test_invalid_fen_sends_nothing_and_cancellation_writes_nothing():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	var path := "user://rev002-cancel.json"
	DirAccess.remove_absolute(path)
	assert_true(not analyser.analyse([START, "invalid"], path, true))
	assert_true(bridge.searches.is_empty())
	assert_true(analyser.analyse([START], path, true))
	analyser.cancel()
	bridge.answer()
	assert_eq(bridge.stops, 1)
	assert_true(not FileAccess.file_exists(path))
	analyser.free()


func test_convergence_requires_three_stable_completed_depths_at_depth_twelve():
	var script = load("res://engine/analyser.gd")
	if script == null:
		assert_true(false, "analyser is missing")
		return
	var stable := [
		{"depth": 10, "move": "e2e4", "cp": 30},
		{"depth": 11, "move": "e2e4", "cp": 31},
		{"depth": 12, "move": "e2e4", "cp": 32},
	]
	assert_true(script.converged(stable), "stable depths 10-12")
	assert_true(not script.converged(stable.slice(0, 2)), "only two depths")
	var early := stable.duplicate(true)
	early[2].depth = 11
	assert_true(not script.converged(early), "depth below 12")
	var changed := stable.duplicate(true)
	changed[1].move = "d2d4"
	assert_true(not script.converged(changed), "different best move")
	changed = stable.duplicate(true)
	changed[2].cp = 200
	assert_true(not script.converged(changed), "expected points changed")
