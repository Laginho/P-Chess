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
