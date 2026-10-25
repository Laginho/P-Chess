extends "res://tests/run.gd".Test

const PremoveQueue = preload("res://ui/premove_queue.gd")
const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


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


func test_premove_costs_exactly_100_ms_and_adds_the_usual_increment():
	var time := FakeTime.new()
	var clock = Clock.new("3+2", time.ms)
	clock.moved("w")
	clock.moved("b")
	time.now += 7
	clock.moved("w", true)
	assert_eq(clock.left("w"), 181900, "fixed cost, independent of frame/animation time")
	time.now += 500
	assert_eq(clock.left("w"), 181900, "human clock stops")
	assert_eq(clock.left("b"), 179500, "opponent clock starts")
	clock.moved("b")
	assert_eq(clock.left("b"), 181500, "ordinary moves still use elapsed time")


func test_first_move_premove_still_costs_100_ms_without_first_move_increment():
	var time := FakeTime.new()
	var clock = Clock.new("3+2", time.ms)
	clock.moved("w")
	clock.moved("b", true)
	assert_eq(clock.left("b"), 179900)
	assert_eq(clock.left("w"), 180000)
	time.now += 200
	assert_eq(clock.left("w"), 179800)


func test_premove_cannot_be_saved_from_flag_by_the_increment():
	for remaining in [0, 50, 100, 101]:
		var time := FakeTime.new()
		var clock = Clock.new("3+2", time.ms)
		clock.moved("w")
		clock.moved("b")
		time.now += 180000 - remaining
		clock.moved("w")
		clock.moved("b")
		# White has its increment but then spends it on an ordinary move.
		time.now += 2000
		clock.stop()
		clock.moved("b")
		var flags := []
		clock.flagged.connect(func(side): flags.append(side))
		clock.moved("w", true)
		assert_eq(flags, ["w"] if remaining <= 100 else [], "remaining=%d" % remaining)
		assert_eq(clock.left("w"), 0 if remaining <= 100 else 2001)


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
