extends "res://tests/run.gd".Test

const PremoveQueue = preload("res://ui/premove_queue.gd")
const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
const MainScene = preload("res://ui/main.tscn")


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


# Only the external engine is replaced. Moves arrive explicitly through Main's Maia callback.
class HeldEngine extends "res://engine/uci.gd":
	var requests := []

	func start(_dirs := PackedStringArray()) -> bool:
		return true

	func set_level(_net_path: String) -> void:
		pass

	func request_policy(_start: String, moves: PackedStringArray) -> void:
		requests.append(moves.duplicate())


func _session(time: FakeTime, colour := "w", control := "1+0"):
	var main = MainScene.instantiate()
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_ui007_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__ui007_silent__")
	main._start({"colour": colour, "level": "maia-1700", "control": control, "opening": "Free"})
	main.clock = Clock.new(control, time.ms)
	main.clock.flagged.connect(main._on_flagged)
	main.maia.clock = main.clock
	main.white_clock.clock = main.clock
	main.black_clock.clock = main.clock
	return main


func _mouse(board, pressed: bool, square: String, button := MOUSE_BUTTON_LEFT, alt := false) -> void:
	var side: float = minf(board.size.x, board.size.y)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.alt_pressed = alt
	event.position = (board.size - Vector2.ONE * side) / 2 + board.square_position(square, side, board.flipped) + Vector2.ONE * side / 16
	board._gui_input(event)


func _drag(board, from: String, to: String, alt := false) -> void:
	_mouse(board, true, from)
	_mouse(board, false, to, MOUSE_BUTTON_LEFT, alt)


func test_main_queues_human_moves_and_executes_one_per_maia_reply():
	var time := FakeTime.new()
	var main = _session(time)
	var board = main.board_view
	var sounds := []
	board.sound_requested.connect(func(event): sounds.append(event))
	board.play("e2e4")
	assert_eq(board.mouse_filter, Control.MOUSE_FILTER_STOP, "input stays available during Maia's turn")
	_drag(board, "e7", "e5")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]), "the human cannot move Maia's pieces")
	_drag(board, "d2", "d4")
	_drag(board, "d4", "d5")
	_drag(board, "g1", "f3")
	assert_eq(board.premoves.moves, PackedStringArray(["d2d4", "d4d5", "g1f3"]))
	assert_eq(board.premoves.position(board.game.board).piece_at("d5"), "P")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]))
	main._on_maia_move("e7e5")
	assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5", "d2d4"]))
	assert_eq(board.premoves.moves, PackedStringArray(["d4d5", "g1f3"]))
	assert_eq(main.clock.left("w"), 59900)
	assert_eq(sounds.count("premove"), 1)
	assert_eq(main.uci.requests.size(), 2, "one request after each actual human move")
	time.now += 2000
	main._on_maia_move("e5d4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5", "d2d4", "e5d4"]))
	assert_eq(board.premoves.moves, PackedStringArray())
	assert_eq(main.clock.left("w"), 59900, "an illegal premove costs nothing")
	assert_eq(main.clock.left("b"), 58000)
	_drag(board, "g1", "f3")
	assert_eq(board.game.moves[-1], "g1f3", "ordinary moves still work after a dropped queue")
	assert_eq(sounds.count("premove"), 1)
	main.free()


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
