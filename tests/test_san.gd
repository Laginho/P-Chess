extends "res://tests/run.gd".Test

# Standard Algebraic Notation in and out (CORE-005).

const Board = preload("res://core/board.gd")

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
# After 1.e4 e5 2.Bc4 Nc6.
const ITALIAN := "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR w KQkq - 2 3"
# After 1.f3 e5 2.g4.
const FOOLS := "rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq - 0 2"
const CASTLES := "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
const EN_PASSANT := "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"
const PROMOTION := "8/4P3/8/8/8/8/8/k3K3 w - - 0 1"
const CAPTURE_PROMOTION := "3r3k/4P3/8/8/8/8/8/K7 w - - 0 1"
# Queens on a1, a4 and d1 all reach d4.
const THREE_QUEENS := "8/7k/8/8/Q7/8/8/Q2Q3K w - - 0 1"
# Knights on b1 and f1 both reach d2.
const TWO_KNIGHTS := "4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1"
# Rooks on a1 and a5 both reach a3.
const TWO_ROOKS := "4k3/8/8/R7/8/8/8/R3K3 w - - 0 1"
# The e2 knight is pinned, so only the c2 knight reaches d4.
const PINNED_KNIGHT := "4k3/4r3/8/8/8/8/2N1N3/4K3 w - - 0 1"

const PERFT_POSITIONS := [
	START,
	"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
	"8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
	"r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
	"rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
	"r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
]


func _check_san(cases: Array) -> void:
	for c in cases:
		assert_eq(Board.from_fen(c[0]).san(c[1]), c[2], c[1])


func _check_parse(cases: Array) -> void:
	for c in cases:
		assert_eq(Board.from_fen(c[0]).parse_san(c[1]), c[2], c[1])


func test_moves_print_as_san():
	_check_san([
		[START, "e2e4", "e4"],
		[START, "g1f3", "Nf3"],
		["rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2", "e4d5", "exd5"],
		[EN_PASSANT, "e5d6", "exd6"],
		[ITALIAN, "c4f7", "Bxf7+"],
		[FOOLS, "d8h4", "Qh4#"],
		[CASTLES, "e1g1", "O-O"],
		[CASTLES, "e1c1", "O-O-O"],
		[PROMOTION, "e7e8q", "e8=Q"],
		[PROMOTION, "e7e8r", "e8=R"],
		[PROMOTION, "e7e8b", "e8=B"],
		[PROMOTION, "e7e8n", "e8=N"],
		[CAPTURE_PROMOTION, "e7d8q", "exd8=Q+"],
		[CAPTURE_PROMOTION, "e7d8n", "exd8=N"],
	])


func test_disambiguation_uses_file_then_rank_then_both():
	_check_san([
		[TWO_KNIGHTS, "b1d2", "Nbd2"],
		[TWO_KNIGHTS, "f1d2", "Nfd2"],
		[TWO_ROOKS, "a1a3", "R1a3"],
		[TWO_ROOKS, "a5a3", "R5a3"],
		[THREE_QUEENS, "a1d4", "Qa1d4"],
		[THREE_QUEENS, "a4d4", "Q4d4"],
		[THREE_QUEENS, "d1d4", "Qdd4"],
		[PINNED_KNIGHT, "c2d4", "Nd4"],
	])


func test_san_parses_back_to_the_move():
	_check_parse([
		[START, "e4", "e2e4"],
		[START, "Nf3", "g1f3"],
		[EN_PASSANT, "exd6", "e5d6"],
		[CASTLES, "O-O", "e1g1"],
		[CASTLES, "O-O-O", "e1c1"],
		[PROMOTION, "e8=N", "e7e8n"],
		[CAPTURE_PROMOTION, "exd8=Q+", "e7d8q"],
		[THREE_QUEENS, "Qa1d4", "a1d4"],
		[THREE_QUEENS, "Q4d4", "a4d4"],
		[THREE_QUEENS, "Qdd4", "d1d4"],
		[TWO_ROOKS, "R5a3", "a5a3"],
		[PINNED_KNIGHT, "Nd4", "c2d4"],
	])


func test_trailing_check_mate_and_annotation_marks_are_accepted():
	_check_parse([
		[ITALIAN, "Bxf7+", "c4f7"],
		[FOOLS, "Qh4#", "d8h4"],
		[START, "e4!", "e2e4"],
		[START, "Nf3?", "g1f3"],
		[ITALIAN, "Bxf7+!?", "c4f7"],
		[FOOLS, "Qh4#!!", "d8h4"],
	])


func test_illegal_or_ambiguous_san_is_an_error():
	_check_parse([
		[START, "e5", ""],
		[START, "Nf6", ""],
		[START, "Ke2", ""],
		[START, "O-O", ""],
		[START, "", ""],
		[START, "hello", ""],
		[PROMOTION, "e8", ""],
		[THREE_QUEENS, "Qd4", ""],
		[THREE_QUEENS, "Qad4", ""],
		[THREE_QUEENS, "Q1d4", ""],
		[TWO_KNIGHTS, "Nd2", ""],
	])


func test_every_printed_move_of_the_perft_positions_parses_back():
	for fen in PERFT_POSITIONS:
		var board = Board.from_fen(fen)
		for move in board.legal_moves():
			var text: String = board.san(move)
			assert_eq(board.parse_san(text), move, "%s %s (%s)" % [fen, move, text])
