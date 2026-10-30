extends "res://tests/run.gd".Test

const Analyser = preload("res://engine/analyser.gd")
const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const AFTER := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"

class FakeBridge extends RefCounted:
	var engine_id := "Stockfish 19"
	var searches := []
	var callback := Callable()
	var stops := 0
	var new_games := 0
	func new_game() -> void:
		new_games += 1
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
	var landed := []
	analyser.progress.connect(func(done, total): progress.append([done, total]))
	analyser.position_ready.connect(func(index, position): landed.append([index, position.best_move]))
	var path := "user://rev002-test.json"
	DirAccess.remove_absolute(path)
	assert_true(analyser.analyse([START, AFTER], path, false))
	assert_true("position fen " + AFTER in bridge.searches[0])
	assert_true("setoption name MultiPV value 2" in bridge.searches[0])
	assert_true("setoption name Threads value 1" in bridge.searches[0])
	assert_eq(bridge.new_games, 1)
	assert_true("go nodes 3000000" in bridge.searches[0])
	bridge.answer()
	assert_true("position fen " + START in bridge.searches[1])
	bridge.answer()
	assert_eq(progress, [[1, 2], [2, 2]])
	assert_eq(landed, [[1, "e7e5"], [0, "e7e5"]])
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
	assert_true(not analyser.analyse([START, "8/8/8/8/8/8/8/8 w - - 0 1"], path, true), "missing kings")
	assert_true(bridge.searches.is_empty())
	assert_true(analyser.analyse([START], path, true))
	analyser.cancel()
	bridge.answer()
	assert_eq(bridge.stops, 1)
	assert_true(not FileAccess.file_exists(path))
	analyser.free()


func test_recorded_stockfish_transcript_keeps_both_lines():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	var path := "user://rev002-transcript.json"
	assert_true(analyser.analyse([START], path, false))
	var lines := FileAccess.get_file_as_string("res://tests/fixtures/analysis/stockfish19-start.txt").split("\n", false)
	for line in lines:
		bridge.callback.call(line)
	var data: Dictionary = Analyser.read_analysis(path, "Stockfish 19", 3000000).data
	assert_eq(data.positions[0].best_move, "e2e4")
	assert_eq(data.positions[0].pv[0].cp, 19)
	assert_eq(data.positions[0].pv[1].moves[0], "d2d4")
	DirAccess.remove_absolute(path)
	analyser.free()


func test_incomplete_depth_does_not_count_for_convergence():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	assert_true(analyser.analyse([START], "user://rev002-depth.json", false))
	for depth in [10, 11, 12]:
		bridge.callback.call("info depth %d multipv 1 score cp 30 pv e2e4" % depth)
		if depth != 11:
			bridge.callback.call("info depth %d multipv 2 score cp 10 pv d2d4" % depth)
	assert_eq(bridge.stops, 0, "depth 11 did not finish")
	analyser.cancel()
	bridge.callback.call("bestmove e2e4")
	analyser.free()


func test_cancelling_when_a_position_lands_does_not_stop_the_next_search():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	var path := "user://rev002-cancel-landed.json"
	DirAccess.remove_absolute(path)
	analyser.position_ready.connect(func(_index, _position): analyser.cancel())
	assert_true(analyser.analyse([START, AFTER], path, true))
	assert_true("setoption name Threads value %d" % maxi(1, OS.get_processor_count() - 1) in bridge.searches[0])
	bridge.answer()
	assert_eq(bridge.stops, 0)
	assert_eq(bridge.searches.size(), 1)
	assert_true(not FileAccess.file_exists(path))
	analyser.free()


func test_terminal_and_forced_positions_are_recorded():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	var path := "user://rev002-terminal.json"
	DirAccess.remove_absolute(path)
	var forced := "7k/8/6K1/8/8/8/8/7R b - - 0 1"
	var mate := "7k/6Q1/6K1/8/8/8/8/8 b - - 0 1"
	assert_true(analyser.analyse([forced, mate], path, false))
	assert_eq(bridge.searches.size(), 1, "terminal position is not sent")
	bridge.answer()
	var positions: Array = Analyser.read_analysis(path, "Stockfish 19", 3000000).data.positions
	assert_eq(positions[1].pv, [])
	assert_eq(positions[1].terminal_score, -1000)
	assert_eq(positions[0].pv.size(), 1)
	DirAccess.remove_absolute(path)
	analyser.free()


func test_terminal_only_game_still_starts_one_engine_game():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	var path := "user://rev002-terminal-only.json"
	assert_true(analyser.analyse(["7k/6Q1/6K1/8/8/8/8/8 b - - 0 1"], path, false))
	assert_eq(bridge.new_games, 1)
	assert_true(bridge.searches.is_empty())
	DirAccess.remove_absolute(path)
	analyser.free()


func test_drawn_game_has_terminal_zero_even_when_moves_remain():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	var path := "user://rev002-draw.json"
	assert_true(analyser.analyse([START], path, true, true))
	assert_true(bridge.searches.is_empty())
	var data: Dictionary = Analyser.read_analysis(path, "Stockfish 19", 3000000).data
	assert_eq(data.positions[0].terminal_score, 0)
	assert_eq(data.positions[0].pv, [])
	DirAccess.remove_absolute(path)
	analyser.free()


func test_stop_waits_for_completed_multipv_depth_and_fires_once():
	var bridge := FakeBridge.new()
	var analyser = Analyser.new(bridge)
	assert_true(analyser.analyse([START], "user://rev002-depth.json", false))
	for depth in [10, 11, 12]:
		bridge.callback.call("info depth %d multipv 1 score cp 30 pv e2e4" % depth)
		if depth == 12:
			assert_eq(bridge.stops, 0, "PV2 has not completed depth 12")
		bridge.callback.call("info depth %d multipv 2 score cp 10 pv d2d4" % depth)
	assert_eq(bridge.stops, 1)
	analyser.cancel()
	bridge.callback.call("bestmove e2e4")
	assert_eq(bridge.stops, 1, "cancelling a stopped search does not send stop twice")
	analyser.free()


func test_positions_from_pgn_include_start_and_every_move():
	var pgn = load("res://core/pgn.gd")
	var game: Dictionary = pgn.parse("1. e4 e5 *").games[0]
	var positions: Array = Analyser.positions_from_game(game)
	assert_eq(positions.size(), 3)
	assert_eq(positions[0], START)
	assert_eq(positions[1], AFTER)
	assert_eq(positions[2], "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2")


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
