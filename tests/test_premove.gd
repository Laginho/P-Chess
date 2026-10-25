extends "res://tests/run.gd".Test

const PremoveQueue = preload("res://ui/premove_queue.gd")
const Game = preload("res://core/game.gd")


func test_queued_moves_use_the_ghost_position_without_changing_the_game():
	var game = Game.new()
	game.play("e2e4")
	var before: String = game.board.to_fen()
	var queue = PremoveQueue.new("w")
	assert_true(queue.enqueue(game.board, "g1f3"))
	assert_true(queue.enqueue(game.board, "f3g5"), "the second move starts on the first ghost")
	assert_true(not queue.enqueue(game.board, "g1h3"), "the knight has left g1")
	assert_true(not queue.enqueue(game.board, "a7a6"), "only human pieces")
	assert_true(not queue.enqueue(game.board, "a1a4"), "blocked moves are refused")
	var ghost = queue.position(game.board)
	assert_eq(ghost.piece_at("g5"), "N")
	assert_eq(ghost.piece_at("f3"), "")
	assert_eq(ghost.piece_at("g1"), "")
	assert_eq(game.board.to_fen(), before, "preview never plays on the live board")
	assert_eq(game.moves, PackedStringArray(["e2e4"]))


func test_styles_default_to_chess_com_and_lichess_replaces_from_the_live_position():
	var game = Game.new()
	game.play("e2e4")
	var queue = PremoveQueue.new("w")
	assert_eq(queue.style, "Chess.com")
	queue.style = "Lichess"
	assert_true(queue.enqueue(game.board, "g1f3"))
	assert_true(not queue.enqueue(game.board, "f3g5"), "replacement ignores the previous ghost")
	assert_true(queue.enqueue(game.board, "b1c3"))
	assert_eq(queue.moves, PackedStringArray(["b1c3"]))
	assert_eq(queue.position(game.board).piece_at("g1"), "N")
	queue.style = "off"
	assert_eq(queue.moves, PackedStringArray(), "disabling clears queued moves")
	assert_true(not queue.enqueue(game.board, "g1f3"))
	queue.style = "Chess.com"
	assert_true(queue.enqueue(game.board, "g1f3"))
	assert_true(queue.enqueue(game.board, "f3g5"))
	queue.style = "Lichess"
	assert_eq(queue.moves, PackedStringArray(["g1f3"]), "changing style keeps at most one")
	queue.clear()
	assert_eq(queue.moves, PackedStringArray())


func test_one_premove_per_reply_and_an_illegal_premove_drops_the_tail():
	var game = Game.new()
	var queue = PremoveQueue.new("w")
	assert_eq(queue.take(game.board), "", "empty queue")
	assert_true(not queue.enqueue(game.board, "e2e4"), "cannot queue on the human turn")
	game.play("e2e4")
	for move in ["d2d4", "d4d5", "g1f3"]:
		assert_true(queue.enqueue(game.board, move), move)
	assert_eq(queue.take(game.board), "", "wait for Maia")
	assert_true(game.play("e7e5"))
	assert_eq(queue.take(game.board), "d2d4")
	assert_true(game.play("d2d4"))
	assert_eq(queue.moves, PackedStringArray(["d4d5", "g1f3"]))
	assert_eq(queue.take(game.board), "", "the next move still waits")
	assert_true(game.play("e5d4"), "Maia captures the queued pawn")
	assert_eq(queue.take(game.board), "")
	assert_eq(queue.moves, PackedStringArray(), "the illegal move and its tail disappear")
	assert_eq(game.moves, PackedStringArray(["e2e4", "e7e5", "d2d4", "e5d4"]))


func test_black_ghosts_and_execution_follow_the_same_rules():
	var game = Game.new()
	var queue = PremoveQueue.new("b")
	assert_true(queue.enqueue(game.board, "g8f6"))
	assert_true(queue.enqueue(game.board, "f6g4"))
	assert_true(not queue.enqueue(game.board, "g1f3"))
	assert_eq(queue.position(game.board).piece_at("g4"), "n")
	game.play("e2e4")
	assert_eq(queue.take(game.board), "g8f6")
	game.play("g8f6")
	game.play("a2a3")
	assert_eq(queue.take(game.board), "f6g4")
	assert_eq(queue.moves, PackedStringArray())
