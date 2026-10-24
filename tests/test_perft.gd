extends "res://tests/run.gd".Test

# Legal moves proven by perft against the Chess Programming Wiki numbers, plus copy-make,
# promotions and check (CORE-003).

const Board = preload("res://core/board.gd")

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const KIWIPETE := "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"


# Leaf count; the last level counts legal moves without playing them.
static func perft(board, depth: int) -> int:
	var moves: PackedStringArray = board.legal_moves()
	if depth == 1:
		return moves.size()
	var nodes := 0
	for move in moves:
		var next = board.copy()
		next.make_move(move)
		nodes += perft(next, depth - 1)
	return nodes


func test_start_position_perft_to_depth_4():
	var board = Board.from_fen(START)
	var expected := [20, 400, 8902, 197281]
	for depth in range(1, 5):
		assert_eq(perft(board, depth), expected[depth - 1], "depth %d" % depth)


func test_kiwipete_perft_to_depth_3():
	var board = Board.from_fen(KIWIPETE)
	var expected := [48, 2039, 97862]
	for depth in range(1, 4):
		assert_eq(perft(board, depth), expected[depth - 1], "depth %d" % depth)


func test_positions_3_to_6_perft_at_depth_3():
	var expected := {
		"8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1": 2812,
		"r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1": 9467,
		"rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8": 62379,
		"r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10": 89890,
	}
	for fen in expected:
		assert_eq(perft(Board.from_fen(fen), 3), expected[fen], fen)


func test_moving_a_copy_leaves_the_original_fen_unchanged():
	var board = Board.from_fen(KIWIPETE)
	for first in board.legal_moves():
		var after_first = board.copy()
		after_first.make_move(first)
		var fen: String = after_first.to_fen()
		assert_true(fen != KIWIPETE, first + " changed nothing")
		for second in after_first.legal_moves():
			var after_second = after_first.copy()
			after_second.make_move(second)
			assert_eq(after_first.to_fen(), fen, first + " " + second)
	assert_eq(board.to_fen(), KIWIPETE)


func test_each_promotion_is_its_own_move():
	var board = Board.from_fen("8/4P3/8/8/8/8/8/k3K3 w - - 0 1")
	var moves: PackedStringArray = board.legal_moves()
	for piece in ["Q", "R", "B", "N"]:
		var move: String = "e7e8" + piece.to_lower()
		assert_true(move in moves, move + " missing")
		var after = board.copy()
		after.make_move(move)
		assert_eq(after.piece_at("e8"), piece, move)
		assert_eq(after.piece_at("e7"), "", move)


func test_reports_whether_the_side_to_move_is_in_check():
	assert_eq(Board.from_fen(START).in_check(), false, "start")
	assert_eq(Board.from_fen("4k3/8/8/8/8/8/8/4K2r w - - 0 1").in_check(), true, "rook on the rank")
	assert_eq(Board.from_fen("4k3/8/8/8/8/8/8/4R1K1 b - - 0 1").in_check(), true, "rook on the file")
	assert_eq(Board.from_fen("4k3/8/8/8/8/8/8/4R1K1 w - - 0 1").in_check(), false, "only the side to move counts")
	assert_eq(Board.from_fen("4k3/3P4/8/8/8/8/8/4K3 b - - 0 1").in_check(), true, "white pawn")
	assert_eq(Board.from_fen("4k3/8/8/8/8/8/3p4/4K3 w - - 0 1").in_check(), true, "black pawn")
	assert_eq(Board.from_fen("4k3/8/8/8/8/8/4p3/4K3 w - - 0 1").in_check(), false, "a pawn does not attack ahead")


# As Lichess and python-chess write FEN, so the position key after a double push matches the same
# position reached otherwise (repetition, §7).
func test_en_passant_square_is_recorded_only_when_the_capture_is_legal():
	var after_double_push := {
		[START, "e2e4"]: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
		["4k3/8/8/8/3p4/8/4P3/4K3 w - - 0 1", "e2e4"]: "4k3/8/8/8/3pP3/8/8/4K3 b - e3 0 1",
		# dxe3 would open the rank to the king
		["8/8/8/8/k2p3R/8/4P3/4K3 w - - 0 1", "e2e4"]: "8/8/8/8/k2pP2R/8/8/4K3 b - - 0 1",
		# the a6 pawn is not beside h5
		["4k3/7p/P7/8/8/8/8/4K3 b - - 0 1", "h7h5"]: "4k3/8/P7/7p/8/8/8/4K3 w - - 0 2",
	}
	for start_and_move in after_double_push:
		var board = Board.from_fen(start_and_move[0])
		board.make_move(start_and_move[1])
		assert_eq(board.to_fen(), after_double_push[start_and_move], start_and_move[0])


# from_fen accepts positions chess never reaches; move generation must still hold on them.
func test_a_side_without_a_king_is_never_in_check():
	var board = Board.from_fen("7k/8/8/8/3R4/8/8/7r w - - 0 1")
	assert_eq(board.legal_moves().size(), 14)
	assert_eq(board.in_check(), false)


func test_a_pawn_on_its_last_rank_has_no_moves():
	assert_eq(Board.from_fen("P6k/8/8/8/8/8/8/K7 w - - 0 1").legal_moves().size(), 3, "white pawn on a8")
	assert_eq(Board.from_fen("k7/8/8/8/8/8/8/K6p b - - 0 1").legal_moves().size(), 3, "black pawn on h1")
