extends "res://tests/run.gd".Test

# FEN round-trip, field parsing, invalid input and the position key (CORE-002).

const Board = preload("res://core/board.gd")

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

# Start position, Kiwipete and CPW perft positions 3-6 (CORE-003).
const ROUND_TRIP := [
	START,
	"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
	"8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
	"r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
	"rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
	"r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
]


func test_round_trip_returns_the_same_fen():
	for fen in ROUND_TRIP:
		var board = Board.from_fen(fen)
		assert_true(board != null, "parse failed: " + fen)
		if board:
			assert_eq(board.to_fen(), fen)


func test_keeps_all_six_fields():
	var board = Board.from_fen("4k3/8/8/8/3pP3/8/8/R3K2R b Kq e3 7 42")
	assert_true(board != null, "parse failed")
	if not board:
		return
	assert_eq(board.piece_at("e8"), "k")
	assert_eq(board.piece_at("e4"), "P")
	assert_eq(board.piece_at("d4"), "p")
	assert_eq(board.piece_at("a1"), "R")
	assert_eq(board.piece_at("h1"), "R")
	assert_eq(board.piece_at("e5"), "")
	assert_eq(board.side_to_move, "b")
	assert_eq(board.castling, "Kq")
	assert_eq(board.en_passant, "e3")
	assert_eq(board.halfmove_clock, 7)
	assert_eq(board.fullmove_number, 42)


func test_invalid_fen_returns_null():
	var invalid := [
		"",
		"garbage",
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1",  # 7 ranks
		"rnbqkbnr/pppppppp/8/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",  # 9 ranks
		"rnbqkbnr/pppppppp/9/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",  # rank of 9 squares
		"rnbqkbnr/ppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",  # rank of 7 squares
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNRR w KQkq - 0 1",  # rank of 9 pieces
		"rnbqkbnr/ppppxppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",  # unknown piece letter
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1",  # bad side to move
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR W KQkq - 0 1",  # side is lowercase
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQxq - 0 1",  # bad castling letter
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KKkq - 0 1",  # repeated castling letter
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w -K - 0 1",  # dash mixed with rights
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e9 0 1",  # bad en-passant square
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - x 1",  # bad halfmove clock
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 0",  # fullmove starts at 1
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0",  # missing field
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 x",  # extra field
	]
	for fen in invalid:
		assert_eq(Board.from_fen(fen), null, fen)


func test_position_key_drops_the_move_counters():
	var board = Board.from_fen(START)
	assert_eq(board.position_key(), "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -")
	var later = Board.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 8 5")
	assert_eq(later.position_key(), board.position_key())
	var other_side = Board.from_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")
	assert_true(other_side.position_key() != board.position_key(), "side to move is part of the key")
