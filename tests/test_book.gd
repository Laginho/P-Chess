extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const Game = preload("res://core/game.gd")
const History = preload("res://core/history.gd")
const Pgn = preload("res://core/pgn.gd")
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Catalog"}


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


func test_target_uses_minimum_counts_seeded_ties_and_maias_repertoire_side():
	var book = _sample()
	var rng := RandomNumberGenerator.new()
	var first: String = book.entries[0].id
	var second: String = book.entries[1].id
	assert_eq(book.begin_game({first: 9, second: 2}, rng), second)
	var chosen := {}
	for seed_value in 40:
		rng.seed = seed_value
		var target: String = book.begin_game({}, rng)
		rng.seed = seed_value
		assert_eq(book.begin_game({}, rng), target, "seeded ties repeat")
		chosen[target] = true
	assert_eq(chosen.size(), 2, "ties sample both checked lines")
	book.entries[0]["colour"] = "w"
	book.entries[1]["colour"] = "b"
	assert_eq(book.begin_game({}, rng, "b"), second, "only Maia's repertoire side")
	book.set_checked("Other", false)
	assert_eq(book.begin_game({}, rng, "b"), "", "no eligible target")
	for weight in book.weights(Game.new().board, 0).values():
		assert_eq(weight, 1.0, "empty selection stays free")


func test_position_matching_allows_transpositions_and_reentry_with_the_actual_ply():
	var book = _sample()
	book.begin_game({book.entries[1].id: 2}, RandomNumberGenerator.new())
	var game = _game(["g2g3", "g7g6", "g1f3", "g8f6"])
	assert_eq(book.weights(game.board, game.moves.size()).f1g2, 20.0, "different move order")
	game.play("b1c3")
	for weight in book.weights(game.board, game.moves.size()).values():
		assert_eq(weight, 1.0, "no checked continuation")
	for move in ["b8c6", "c3b1", "c6b8"]:
		assert_true(game.play(move))
	assert_eq(book.weights(game.board, game.moves.size()).f1g2, 16.2, "ply 8, not line ply 4")


func _folder() -> String:
	return "user://test_book_%d" % Time.get_ticks_usec()


func _clean(folder: String) -> void:
	for subdir in [folder.path_join("games"), folder.path_join("openings"), folder]:
		if DirAccess.dir_exists_absolute(subdir):
			for file in DirAccess.get_files_at(subdir):
				DirAccess.remove_absolute(subdir.path_join(file))
			DirAccess.remove_absolute(subdir)


func test_finished_games_persist_target_practice_counts_without_changing_result_stats():
	var folder := _folder()
	var history = History.new(folder)
	assert_true(history.has_method("practice_counts"), "practice is persisted with history stats")
	if not history.has_method("practice_counts"):
		return
	var target: String = _sample().entries[0].id
	assert_eq(history.practice_counts(), {})
	var game = Game.new()
	assert_eq(history.save(game, [], SETTINGS, "", target), "", "unfinished games don't count")
	assert_eq(history.practice_counts(), {})
	game.resign("w")
	assert_true(not history.save(game, [], SETTINGS, "", target).is_empty(), history.error)
	assert_eq(History.new(folder).practice_counts(), {target: 1})
	assert_eq(History.new(folder).stats("maia-1500", "3+2").losses, 1)
	assert_true(not history.save(game, [], SETTINGS).is_empty(), "Free has no target")
	assert_eq(History.new(folder).practice_counts(), {target: 1})
	_clean(folder)


func test_opening_header_names_only_the_deepest_catalog_endpoint_reached_in_any_mode():
	var book = _sample()
	assert_true(book.has_method("opening_name"), "catalog recognition is independent of checked lines")
	if not book.has_method("opening_name"):
		return
	book.load_tsv("eco\tname\tpgn\nA04\tReti\t1. Nf3\n")
	var game = _game(["g2g3", "g7g6", "g1f3", "g8f6", "f1g2", "f8g7"])
	# The final position transposes into Target; it must beat the shorter Reti name.
	assert_eq(book.opening_name(game.moves), "Target")
	var partial = _game(["g1f3", "g8f6", "g2g3", "g7g6"])
	assert_eq(book.opening_name(partial.moves), "Reti", "future Target endpoint was never reached")
	assert_eq(book.opening_name(PackedStringArray(["e2e4"])), "")
	assert_eq(book.opening_name(PackedStringArray()), "")
	assert_true(game.play("b1c3"))
	game.resign("w")
	var folder := _folder()
	var history = History.new(folder)
	history.book = book
	for mode in ["Catalog", "Free", "My repertoire"]:
		var settings := SETTINGS.duplicate()
		settings.opening = mode
		var path: String = history.save(game, [1, 2, 3, 4, 5, 6, 7], settings)
		assert_true(not path.is_empty(), history.error)
		var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
		assert_eq(parsed.games[0].headers.get("Opening"), "Target", mode)
	_clean(folder)
