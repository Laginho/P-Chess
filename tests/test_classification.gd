extends "res://tests/run.gd".Test

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const AFTER_E4 := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"
const Board = preload("res://core/board.gd")
const Repertoire = preload("res://bot/repertoire.gd")


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
	assert_eq(second[0].class, "Good", "PV2 score overrides the noisy subsequent position")


func _one(move: String, first: Dictionary, second: Dictionary, after: Dictionary) -> Dictionary:
	var board = Board.from_fen(START)
	board.make_move(move)
	return {"positions": [{"fen": START, "best_move": first.moves[0], "pv": [first, second]},
			{"fen": board.to_fen(), "pv": [after], "best_move": after.moves[0]}]}


func test_loss_bands_and_score_clamping_for_both_colours():
	var classification = load("res://core/classification.gd")
	var first := {"moves": ["e2e4"], "cp": 0}
	var second := {"moves": ["d2d4"], "cp": -10}
	for sample in [[0, "Excellent"], [10, "Excellent"], [40, "Good"],
			[100, "Inaccuracy"], [200, "Mistake"], [400, "Blunder"], [5000, "Blunder"]]:
		var data := _one("c2c4", first, second, {"moves": ["e7e5"], "cp": sample[0]})
		var result: Array = classification.evaluate(PackedStringArray(["c2c4"]), data, [], [], "w", false)
		assert_eq(result[0].class, sample[1], "opponent score %d" % sample[0])
	var data := _one("c2c4", first, second, {"moves": ["e7e5"], "cp": 5000})
	var loss: float = classification.evaluate(PackedStringArray(["c2c4"]), data, [], [], "w", false)[0].loss
	assert_true(absf(loss - 0.47545) < 0.0001, "cp is clamped at -1000 for the mover")


func test_book_and_repertoire_override_engine_and_exit_marker_survives():
	var classification = load("res://core/classification.gd")
	var study = Repertoire.new()
	assert_eq(study.parse("1. e4 e5 2. Nf3 *", "w"), "")
	var data := _one("e2e4", {"moves": ["e2e4"], "cp": 0},
			{"moves": ["d2d4"], "cp": -10}, {"moves": ["e7e5"], "cp": 0})
	var result: Array = classification.evaluate(PackedStringArray(["e2e4"]), data, study.lines, study.lines, "w", true)
	assert_eq(result[0].class, "Repertoire")
	result = classification.evaluate(PackedStringArray(["e2e4"]), data, study.lines, [], "w", false)
	assert_eq(result[0].class, "Book")
	data = _one("d2d4", {"moves": ["e2e4"], "cp": 0},
			{"moves": ["d2d4"], "cp": -10}, {"moves": ["e7e5"], "cp": 0})
	result = classification.evaluate(PackedStringArray(["d2d4"]), data, [], study.lines, "w", true)
	assert_true(result[0].left_repertoire)
	assert_eq(result[0].expected, PackedStringArray(["e4"]))


func test_mate_rules_and_lenient_blunders():
	var classification = load("res://core/classification.gd")
	var second := {"moves": ["d2d4"], "cp": 0}
	for sample in [
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "mate": -2}, "Best"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "mate": -5}, "Excellent"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "mate": -6}, "Good"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "cp": -800}, "Excellent"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "cp": -400}, "Good"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "cp": -200}, "Inaccuracy"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "cp": 0}, "Mistake"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "cp": 100}, "Blunder"],
			[{"moves": ["e2e4"], "cp": 100}, {"moves": ["g1f3"], "mate": 2}, "Blunder"],
			[{"moves": ["e2e4"], "cp": 100}, {"moves": ["g1f3"], "mate": 5}, "Mistake"],
			[{"moves": ["e2e4"], "cp": 100}, {"moves": ["g1f3"], "mate": 6}, "Inaccuracy"],
			[{"moves": ["e2e4"], "cp": 1000}, {"moves": ["g1f3"], "cp": -600}, "Inaccuracy"],
			[{"moves": ["e2e4"], "cp": -600}, {"moves": ["g1f3"], "cp": 1000}, "Inaccuracy"]]:
		var data := _one("c2c4", sample[0], second, sample[1])
		var result: Array = classification.evaluate(PackedStringArray(["c2c4"]), data, [], [], "w", false)
		assert_eq(result[0].class, sample[2], str(sample))


func test_great_requires_only_good_move_and_respects_exclusions():
	var classification = load("res://core/classification.gd")
	var first := {"moves": ["e2e4"], "cp": 100}
	var second := {"moves": ["d2d4"], "cp": -100}
	var data := _one("e2e4", first, second, {"moves": ["e7e5"], "cp": -100})
	var result: Array = classification.evaluate(PackedStringArray(["e2e4"]), data, [], [], "w", false)
	assert_eq(result[0].class, "Great")
	first.cp = 1000
	second.cp = 700
	result = classification.evaluate(PackedStringArray(["e2e4"]), data, [], [], "w", false)
	assert_eq(result[0].class, "Best", "PV2 remains at least +700")
	first.cp = -10
	second.cp = -500
	result = classification.evaluate(PackedStringArray(["e2e4"]), data, [], [], "w", false)
	assert_eq(result[0].class, "Best", "mover remains below 0.5 EP")


func _position(fen: String, move: String, pv: Array, alt: String, end_score := -100) -> Dictionary:
	var board = Board.from_fen(fen)
	board.make_move(move)
	return {"positions": [{"fen": fen, "best_move": move, "pv": [
			{"moves": pv, "cp": 100}, {"moves": [alt], "cp": -100}]},
			{"fen": board.to_fen(), "best_move": "", "pv": [{"moves": ["g8h8"], "cp": end_score}]}]}


func test_brilliant_material_sacrifice_and_existing_deficit():
	var classification = load("res://core/classification.gd")
	var fen := "3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1"
	var data := _position(fen, "d1d7", ["d1d7", "d8d7"], "d1a1")
	var result: Array = classification.evaluate(PackedStringArray(["d1d7"]), data, [], [], "w", false)
	assert_eq(result[0].class, "Brilliant", "a queen is sacrificed on the continuation")
	fen = "3r2k1/8/8/8/8/8/8/6K1 w - - 0 1"
	data = _position(fen, "g1f1", ["g1f1"], "g1h1")
	result = classification.evaluate(PackedStringArray(["g1f1"]), data, [], [], "w", false)
	assert_eq(result[0].class, "Great", "an existing deficit alone is not a sacrifice")


func test_great_excludes_check_promotion_and_free_capture():
	var classification = load("res://core/classification.gd")
	for sample in [
			["4r1k1/8/8/8/8/8/8/R3K3 w - - 0 1", "e1d1", "a1a2", "check"],
			["6k1/P7/8/8/8/8/8/6K1 w - - 0 1", "a7a8q", "g1f1", "promotion"],
			["6k1/3p4/8/8/8/8/8/3Q2K1 w - - 0 1", "d1d7", "d1a1", "free capture"]]:
		var data := _position(sample[0], sample[1], [sample[1]], sample[2])
		var result: Array = classification.evaluate(PackedStringArray([sample[1]]), data, [], [], "w", false)
		assert_eq(result[0].class, "Best", sample[3])


func test_forced_and_terminal_scores_override_engine_noise():
	var classification = load("res://core/classification.gd")
	var fen := "7k/8/6K1/8/8/8/8/7R b - - 0 1"
	var board = Board.from_fen(fen)
	var move: String = board.legal_moves()[0]
	board.make_move(move)
	var data := {"positions": [{"fen": fen, "best_move": move,
			"pv": [{"moves": [move], "cp": 0}]},
			{"fen": board.to_fen(), "pv": [], "terminal_score": 0}]}
	var result: Array = classification.evaluate(PackedStringArray([move]), data, [], [], "b", false)
	assert_eq(result[0].class, "Forced")
	assert_eq(result[0].after_ep, 0.5)
