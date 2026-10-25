extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const Game = preload("res://core/game.gd")


func _badges():
	var path := "res://bot/badges.gd"
	assert_true(ResourceLoader.exists(path), "the production review badge function exists")
	return load(path) if ResourceLoader.exists(path) else null


func _game(moves: Array):
	var game = Game.new()
	for move in moves:
		assert_true(game.play(move), "legal fixture move: " + move)
	return game


func test_book_uses_unchecked_catalog_lines_and_never_resumes_after_exit():
	var badges = _badges()
	if badges == null:
		return
	var catalog = Book.new()
	catalog.load_tsv("eco\tname\tpgn\nA04\tReti\t1. Nf3 Nf6 2. d4 d5\nB00\tKing pawn\t1. e4 e5\n")
	assert_eq(catalog.selected_ids(), [], "all catalog entries are unchecked")
	var game = _game(["g1f3", "g8f6", "f3g1", "f6g8", "e2e4"])
	var before: String = game.board.to_fen()
	var entries: Array = catalog.entries.duplicate(true)
	var result: Array = badges.evaluate(game.moves, catalog.entries, [], "w", false)
	assert_eq(result.map(func(mark): return mark.book), [true, true, false, false, false])
	assert_eq(result.map(func(mark): return mark.repertoire), [false, false, false, false, false])
	assert_eq(game.board.to_fen(), before, "review leaves the game unchanged")
	assert_eq(catalog.entries, entries, "review leaves the catalog unchanged")
	assert_eq(badges.evaluate(PackedStringArray(), catalog.entries, [], "w", false), [])
	assert_eq(badges.evaluate(PackedStringArray(["e2e4"]), [], [], "w", false)[0].book, false)
