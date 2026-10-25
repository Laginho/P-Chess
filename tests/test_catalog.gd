extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const START_KEY := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"
const E4_KEY := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -"
const E5_KEY := "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -"


func test_every_committed_lichess_row_loads_with_san_moves_and_position_keys():
	var book = Book.new()
	book.load_catalog()
	assert_eq(book.errors, [])
	# Counts from the pinned upstream files, excluding each header.
	assert_eq(book.volume_counts, {"a": 823, "b": 781, "c": 1250, "d": 644, "e": 367})
	assert_eq(book.entries.size(), 3865)
	var ids := {}
	for entry in book.entries:
		assert_true(not ids.has(entry.id), "a saved line has an unambiguous id")
		ids[entry.id] = true
		assert_true(not entry.moves.is_empty(), entry.name)
		assert_eq(entry.positions.size(), entry.moves.size() + 1, entry.name)
		assert_eq(entry.positions[0], START_KEY)


func test_invalid_san_is_reported_and_skipped_without_losing_later_rows():
	var book = Book.new()
	book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn Game\t1. e4 e5\n"
			+ "A00\tBad line\t1. e4 e5 2. Qh9\nA00\tAnother line\t1. d4\n", "sample")
	assert_eq(book.entries.size(), 2)
	assert_eq(book.entries[0].moves, PackedStringArray(["e2e4", "e7e5"]))
	assert_eq(book.entries[0].positions, PackedStringArray([START_KEY, E4_KEY, E5_KEY]))
	assert_eq(book.entries[1].name, "Another line")
	assert_eq(book.errors.size(), 1)
	assert_true("sample:3" in book.errors[0] and "Qh9" in book.errors[0], "report source, row and move")
