extends "res://tests/run.gd".Test

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const AFTER_E4 := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"


func test_best_and_played_second_line_use_movers_score():
	var classification = load("res://core/classification.gd")
	assert_true(classification != null, "classification module exists")
	if classification == null:
		return
	var analysis := {"positions": [
		{"fen": START, "best_move": "e2e4", "pv": [
			{"moves": ["e2e4"], "cp": 100}, {"moves": ["d2d4"], "cp": 70}]},
		{"fen": AFTER_E4, "best_move": "e7e5", "pv": [{"moves": ["e7e5"], "cp": -900}]}
	]}
	var best: Array = classification.evaluate(PackedStringArray(["e2e4"]), analysis, [], [], "w", false)
	assert_eq(best[0].class, "Best")
	var second: Array = classification.evaluate(PackedStringArray(["d2d4"]), analysis, [], [], "w", false)
	assert_eq(second[0].class, "Excellent", "PV2 score overrides the noisy subsequent position")
