extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const Game = preload("res://core/game.gd")


func _sample():
	var book = Book.new()
	book.load_tsv("eco\tname\tpgn\n"
			+ "A04\tTarget\t1. Nf3 Nf6 2. g3 g6 3. Bg2 Bg7\n"
			+ "A04\tOther\t1. Nf3 Nf6 2. g3 g6 3. d3 d6\n"
			+ "A04\tUnchecked\t1. Nf3 Nf6 2. g3 g6 3. c4 c5\n")
	book.set_checked("Target", true)
	book.set_checked("Other", true)
	assert_eq(book.errors, [])
	return book


func _game(moves: Array):
	var game = Game.new()
	for move in moves:
		assert_true(game.play(move), move)
	return game


func test_checked_moves_receive_target_and_other_weights_with_game_ply_fade():
	var book = _sample()
	assert_true(book.has_method("begin_game"), "the book chooses a target at game start")
	if not book.has_method("begin_game"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	book.begin_game({book.entries[1].id: 4}, rng)
	var game = _game(["g1f3", "g8f6", "g2g3", "g7g6"])
	for intensity in {"weak": [5.0, 2.0, 3.0, 1.5],
			"medium": [20.0, 5.0, 10.5, 3.0], "strong": [100.0, 15.0, 50.5, 8.0]}:
		var expected: Array = {"weak": [5.0, 2.0, 3.0, 1.5],
				"medium": [20.0, 5.0, 10.5, 3.0], "strong": [100.0, 15.0, 50.5, 8.0]}[intensity]
		for ply in [4, 6, 11, 16, 18]:
			var weights: Dictionary = book.weights(game.board, ply, intensity)
			assert_eq(weights.size(), game.board.legal_moves().size(), "one weight per legal move")
			assert_eq(weights.f1g2, expected[0] if ply <= 6 else (expected[2] if ply == 11 else 1.0))
			assert_eq(weights.d2d3, expected[1] if ply <= 6 else (expected[3] if ply == 11 else 1.0))
			assert_eq(weights.c2c4, 1.0, "unchecked line")
			assert_eq(weights.b1c3, 1.0, "off-book legal move")
