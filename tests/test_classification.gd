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
	var alternate = Board.from_fen(START)
	alternate.make_move("d2d4")
	analysis.positions[1].fen = alternate.to_fen()
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
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "mate": -3}, "Excellent"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "mate": -4}, "Excellent"],
			[{"moves": ["e2e4"], "mate": 3}, {"moves": ["g1f3"], "mate": -5}, "Good"],
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


func test_miss_replaces_blunder_after_opponents_blunder():
	var classification = load("res://core/classification.gd")
	var board = Board.from_fen(START)
	var first := {"fen": board.to_fen(), "best_move": "d2d4", "pv": [
			{"moves": ["d2d4"], "cp": 0}, {"moves": ["g1f3"], "cp": -10}]}
	board.make_move("e2e4")
	var second := {"fen": board.to_fen(), "best_move": "d7d5", "pv": [
			{"moves": ["d7d5"], "cp": 700}, {"moves": ["c7c5"], "cp": 0}]}
	board.make_move("e7e5")
	var last := {"fen": board.to_fen(), "pv": [{"moves": ["g1f3"], "cp": 300}]}
	var result: Array = classification.evaluate(PackedStringArray(["e2e4", "e7e5"]),
			{"positions": [first, second, last]}, [], [], "w", false)
	assert_eq(result[0].class, "Blunder")
	assert_eq(result[1].class, "Miss", "Black missed a winning position")


func test_recapture_is_best_instead_of_great():
	var classification = load("res://core/classification.gd")
	var board = Board.from_fen(START)
	var moves := PackedStringArray(["e2e4", "d7d5", "e4d5", "d8d5"])
	var positions := []
	for move: String in moves:
		var legal: PackedStringArray = board.legal_moves()
		assert_true(move in legal)
		var alt: String = legal[0] if legal[0] != move else legal[1]
		positions.append({"fen": board.to_fen(), "best_move": move, "pv": [
				{"moves": [move], "cp": 100}, {"moves": [alt], "cp": -100}]})
		board.make_move(move)
	positions.append({"fen": board.to_fen(), "pv": [{"moves": ["b1c3"], "cp": -100}]})
	var result: Array = classification.evaluate(moves, {"positions": positions}, [], [], "w", false)
	assert_eq(result[3].class, "Best", "recapturing the last move cannot be Great")


func test_capture_after_pawn_push_can_be_great():
	var board = Board.from_fen("6k1/3p4/5n2/8/4P3/8/8/6K1 b - - 0 1")
	var moves := PackedStringArray(["d7d5", "e4d5"])
	var positions := []
	for move: String in moves:
		var legal: PackedStringArray = board.legal_moves()
		assert_true(move in legal)
		var alt: String = legal[0] if legal[0] != move else legal[1]
		positions.append({"fen": board.to_fen(), "best_move": move, "pv": [
				{"moves": [move], "cp": 100}, {"moves": [alt], "cp": -100}]})
		board.make_move(move)
	positions.append({"fen": board.to_fen(), "pv": [{"moves": ["g8h8"], "cp": -100}]})
	var result: Array = load("res://core/classification.gd").evaluate(moves, {"positions": positions}, [], [], "w", false)
	assert_eq(result[1].class, "Great", "capturing a defended pawn after its push is not a recapture")


func test_en_passant_free_and_defended_captures():
	var classification = load("res://core/classification.gd")
	for sample in [
			["6k1/8/8/3pP3/8/8/8/6K1 w - d6 0 1", "e5d6", "Best"],
			["6k1/8/5n2/3pP3/8/8/8/6K1 w - d6 0 1", "e5d6", "Great"],
			["6k1/8/8/8/3Pp3/8/8/6K1 b - d3 0 1", "e4d3", "Best"],
			["6k1/8/8/8/3Pp3/5N2/8/6K1 b - d3 0 1", "e4d3", "Great"]]:
		var board = Board.from_fen(sample[0])
		var legal: PackedStringArray = board.legal_moves()
		assert_true(sample[1] in legal, "en passant is legal")
		var alt: String = legal[0] if legal[0] != sample[1] else legal[1]
		var data := _position(sample[0], sample[1], [sample[1]], alt)
		var result: Array = classification.evaluate(PackedStringArray([sample[1]]), data, [], [], "w", false)
		assert_eq(result[0].class, sample[2], sample[0])


func test_checkmate_played_off_pv_is_best_and_leniency_applies_to_forced_mate():
	var classification = load("res://core/classification.gd")
	var fen := "7k/5Q2/6K1/8/8/8/8/8 w - - 0 1"
	var board = Board.from_fen(fen)
	assert_true("f7g7" in board.legal_moves())
	board.make_move("f7g7")
	assert_true(board.in_check() and board.legal_moves().is_empty())
	var data := {"positions": [{"fen": fen, "best_move": "f7e8", "pv": [
			{"moves": ["f7e8"], "mate": 1}, {"moves": ["f7f8"], "mate": 1}]},
			{"fen": board.to_fen(), "pv": [], "terminal_score": -1000}]}
	var result: Array = classification.evaluate(PackedStringArray(["f7g7"]), data, [], [], "w", false)
	assert_eq(result[0].class, "Best", "delivering mate is no slower")
	data = _one("c2c4", {"moves": ["e2e4"], "cp": -600},
			{"moves": ["d2d4"], "cp": -700}, {"moves": ["g1f3"], "mate": 2})
	result = classification.evaluate(PackedStringArray(["c2c4"]), data, [], [], "w", false)
	assert_eq(result[0].class, "Good", "leniency applies when already at -600 cp")


func test_json_fixture_uses_analysis_storage_format():
	var classification = load("res://core/classification.gd")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	assert_true(data is Dictionary)
	if not data is Dictionary:
		return
	var result: Array = classification.evaluate(PackedStringArray(["e2e4", "e7e5"]), data, [], [], "w", false)
	assert_eq(result.map(func(item): return item.class), ["Best", "Best"])


func test_repertoire_uses_the_game_starting_fen():
	var classification = load("res://core/classification.gd")
	var board = Board.from_fen(AFTER_E4)
	var repertoire := [{"moves": PackedStringArray(["e7e5"]),
			"positions": PackedStringArray([board.position_key()])}]
	var data := _position(AFTER_E4, "e7e5", ["e7e5"], "c7c5")
	var result: Array = classification.evaluate(PackedStringArray(["e7e5"]), data, [], repertoire, "b", true)
	assert_eq(result[0].class, "Repertoire", "FEN-rooted repertoire matches the actual starting position")
	assert_true(not result[0].left_repertoire)
