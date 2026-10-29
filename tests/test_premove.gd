extends "res://tests/run.gd".Test

const PremoveQueue = preload("res://ui/premove_queue.gd")
const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
const MainScene = preload("res://ui/main.tscn")
const BoardScene = preload("res://ui/board_view.tscn")
const Settings = preload("res://core/settings.gd")
const HistoryStorage = preload("res://tests/history_storage.gd")
const SETTINGS_PATH := "user://test_ui007_settings.cfg"


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


func _session(time: FakeTime, colour := "w", control := "1+0", preferences = null):
	var main = MainScene.instantiate()
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	var folder := "user://test_premove_history_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.tree_exiting.connect(func(): HistoryStorage.clean(folder))
	# Callable keeps a weak reference; keep temporary fake clocks alive with their scene.
	main.set_meta("test_time", time)
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = preferences if preferences != null else main.Settings.new("res://tests/fixtures/no_ui007_settings.cfg")
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
	assert_eq(main.uci.requests.size(), 4, "a prediction and reply after each actual human move")
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


func test_right_click_cancels_the_queue_and_right_drag_still_draws():
	var main = _session(FakeTime.new())
	var board = main.board_view
	board.play("e2e4")
	_drag(board, "g1", "f3")
	_drag(board, "f3", "g5")
	_mouse(board, true, "e4", MOUSE_BUTTON_RIGHT)
	assert_eq(board.premoves.moves, PackedStringArray(), "cancel on press")
	_mouse(board, false, "e5", MOUSE_BUTTON_RIGHT)
	assert_eq(board.drawings, [], "the cancelling click draws nothing")
	_mouse(board, true, "e4", MOUSE_BUTTON_RIGHT)
	_mouse(board, false, "e5", MOUSE_BUTTON_RIGHT)
	assert_eq(board.drawings, [PackedStringArray(["e4", "e5"])], "the next right drag draws")
	_mouse(board, true, "c3", MOUSE_BUTTON_RIGHT)
	_mouse(board, false, "c3", MOUSE_BUTTON_RIGHT)
	assert_eq(board.drawings.size(), 2, "right click can still draw a circle")
	main._on_maia_move("e7e5")
	assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5"]))
	main.free()


func test_black_premoves_include_first_move_cost_and_later_increment():
	var main = _session(FakeTime.new(), "b", "3+2")
	var board = main.board_view
	assert_true(board.flipped)
	board.click_click = true
	for square in ["g8", "f6", "f6", "g4"]:
		_mouse(board, true, square)
		_mouse(board, false, square)
	assert_eq(board.premoves.moves, PackedStringArray(["g8f6", "f6g4"]))
	main._on_maia_move("e2e4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4", "g8f6"]))
	assert_eq(main.clock.left("b"), 179900)
	main._on_maia_move("d2d4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4", "g8f6", "d2d4", "f6g4"]))
	assert_eq(main.clock.left("b"), 181800)
	main.free()


func test_a_premove_that_flags_is_not_played_and_discards_the_whole_queue():
	var time := FakeTime.new()
	var main = _session(time)
	var board = main.board_view
	var sounds := []
	board.sound_requested.connect(func(event): sounds.append(event))
	board.play("e2e4")
	main._on_maia_move("e7e5")
	time.now += 59950
	_drag(board, "g1", "f3")
	_drag(board, "h2", "h4")
	_drag(board, "h4", "h5")
	main._on_maia_move("b8c6")
	assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5", "g1f3", "b8c6"]))
	assert_eq([board.game.result, board.game.reason], ["0-1", "time"])
	assert_eq(main.clock.left("w"), 0)
	assert_eq(board.premoves.moves, PackedStringArray())
	assert_eq(sounds.count("premove"), 0)
	main.free()


func test_maia_checkmate_clears_premoves_and_rematch_keeps_no_ghosts():
	var main = _session(FakeTime.new())
	var board = main.board_view
	_drag(board, "f2", "f3")
	main._on_maia_move("e7e5")
	_drag(board, "g2", "g4")
	_drag(board, "h2", "h4")
	main._on_maia_move("d8h4")
	assert_eq([board.game.result, board.game.reason], ["0-1", "checkmate"])
	assert_eq(board.premoves.moves, PackedStringArray())
	main._start(main.rematch(main.settings))
	_drag(board, "g8", "f6")
	assert_eq(board.premoves.moves, PackedStringArray(["g8f6"]))
	board.game = Game.new()
	assert_eq(board.premoves.moves, PackedStringArray(), "the game setter clears ghosts")
	main.free()


func test_a_hold_survives_maias_reply_and_drops_as_a_normally_timed_move():
	for selected in [false, true]:
		var time := FakeTime.new()
		var main = _session(time)
		var board = main.board_view
		board.click_click = selected
		board.play("e2e4")
		_mouse(board, true, "g1")
		if selected:
			_mouse(board, false, "g1")
		main._on_maia_move("e7e5")
		time.now += 350
		if selected:
			_mouse(board, true, "f3")
		_mouse(board, false, "f3")
		assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5", "g1f3"]))
		assert_eq(board.premoves.moves, PackedStringArray())
		assert_eq(main.clock.left("w"), 59650, "the drop uses elapsed time, not the 100 ms premove cost")
		main.free()


func test_a_reply_and_due_premove_preserve_an_unfinished_drag():
	for selected in [false, true]:
		var main = _session(FakeTime.new())
		var board = main.board_view
		board.click_click = selected
		board.play("e2e4")
		_drag(board, "g1", "f3")
		_mouse(board, true, "f3")
		if selected:
			_mouse(board, false, "f3")
		board.slide_seconds = 0.12
		main._on_maia_move("e7e5")
		if not selected:
			assert_eq(board._slide_to, "", "the held knight is not also drawn as a sliding piece")
		if selected:
			_mouse(board, true, "g5")
		_mouse(board, false, "g5")
		assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5", "g1f3"]))
		assert_eq(board.premoves.moves, PackedStringArray(["f3g5"]), "the held ghost becomes the live knight, and its release queues the next move")
		main.free()


func test_a_due_premove_moving_the_held_live_piece_ends_the_hold():
	for selected in [false, true]:
		var main = _session(FakeTime.new())
		var board = main.board_view
		board.premove_style = "Lichess"
		board.click_click = selected
		board.play("e2e4")
		_drag(board, "g1", "f3")
		_mouse(board, true, "g1")
		if selected:
			_mouse(board, false, "g1")
		main._on_maia_move("e7e5")
		assert_eq(board._drag_from, "")
		assert_eq(board._selected, "")
		assert_eq(board._held_moves, PackedStringArray())
		if selected:
			_mouse(board, true, "h3")
		_mouse(board, false, "h3")
		assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e5", "g1f3"]))
		assert_eq(board.premoves.moves, PackedStringArray(), "the moved source cannot queue a stale replacement")
		main.free()


func test_an_invalid_remaining_ghost_cancels_the_hold_without_a_stale_drop():
	var main = _session(FakeTime.new())
	var board = main.board_view
	board.game = Game.new("8/8/8/8/2k5/8/R7/K7 b - - 0 1")
	_drag(board, "a2", "a3")
	_drag(board, "a3", "b3")
	_mouse(board, true, "b3")
	main._on_maia_move("c4b3")
	assert_eq(board.game.moves, PackedStringArray(["c4b3", "a2a3"]))
	assert_eq(board._drag_from, "", "the remaining ghost would capture Maia's king")
	assert_eq(board._held_moves, PackedStringArray())
	_mouse(board, false, "b4")
	assert_eq(board.premoves.moves, PackedStringArray(["a3b3"]), "the release adds nothing to the invalid tail")
	main.free()


func _promotion_board():
	var board = BoardScene.instantiate()
	board.game = Game.new("4k3/P7/8/8/8/8/7P/4K3 b - - 0 1")
	board.human_side = "w"
	board.slide_seconds = 0
	Engine.get_main_loop().root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(800, 800)
	return board


func test_premove_promotions_follow_auto_queen_and_alt_allows_underpromotion():
	for mode in ["off", "on", "only on premoves"]:
		for alt in [false, true]:
			var board = _promotion_board()
			board.auto_queen = mode
			_drag(board, "a7", "a8", alt)
			var automatic: bool = mode != "off" and not alt
			assert_eq(board.get_node("PromotionPicker").visible, not automatic, "%s Alt=%s" % [mode, alt])
			if not automatic:
				board.get_node("PromotionPicker").get_child(3).pressed.emit()
			assert_eq(board.premoves.moves, PackedStringArray(["a7a8q" if automatic else "a7a8n"]))
			assert_eq(board.game.moves, PackedStringArray(), "a promotion choice queues, never plays early")
			assert_eq(board.premoves.position(board.game.board).piece_at("a8"), "Q" if automatic else "N")
			board.free()


func test_maia_reply_closes_an_open_premove_promotion_picker():
	var board = _promotion_board()
	_drag(board, "a7", "a8")
	assert_true(board.get_node("PromotionPicker").visible)
	assert_true(board.play("e8f8"))
	assert_true(not board.get_node("PromotionPicker").visible, "no stale picker after Maia's reply")
	assert_eq(board.premoves.moves, PackedStringArray())
	assert_eq(board.game.moves, PackedStringArray(["e8f8"]))
	_drag(board, "h2", "h4")
	assert_eq(board.game.moves[-1], "h2h4", "ordinary input is unblocked")
	board.free()


func test_right_click_on_the_promotion_overlay_also_cancels_the_queue():
	var board = _promotion_board()
	_drag(board, "h2", "h4")
	_drag(board, "a7", "a8")
	assert_true(board.get_node("PromotionPicker").visible)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = board.global_position + Vector2(450, 450)
	board.get_viewport().push_input(event, true)
	assert_eq(board.premoves.moves, PackedStringArray())
	assert_true(not board.get_node("PromotionPicker").visible)
	board.free()


func _row_control(form, label: String):
	for i in range(0, form.get_child_count(), 2):
		if form.get_child(i).text == label:
			return form.get_child(i + 1)
	return null


func test_premove_setting_persists_and_screen_changes_apply_immediately():
	DirAccess.remove_absolute(SETTINGS_PATH)
	var settings = Settings.new(SETTINGS_PATH)
	assert_eq(settings.get_value("premove_style"), "Chess.com")
	for style in ["off", "Chess.com", "Lichess"]:
		assert_true(settings.set_value("premove_style", style))
		assert_eq(Settings.new(SETTINGS_PATH).get_value("premove_style"), style)
	assert_true(not settings.set_value("premove_style", "checkers"))
	var main = _session(FakeTime.new(), "w", "1+0", settings)
	var board = main.board_view
	assert_eq(board.premoves.style, "Lichess", "stored choice applies on startup")
	board.play("e2e4")
	_drag(board, "g1", "f3")
	_drag(board, "b1", "c3")
	assert_eq(board.premoves.moves, PackedStringArray(["b1c3"]))
	var control = _row_control(main.settings_screen.get_node("Panel/Center/Box/Form"), "Premove style")
	assert_true(control != null, "the style has a settings control")
	if control != null:
		control.select(2)
		control.item_selected.emit(2)
		assert_eq(board.premoves.style, "Chess.com")
		_drag(board, "g1", "f3")
		assert_eq(board.premoves.moves.size(), 2)
		_mouse(board, true, "h2")
		control.select(0)
		control.item_selected.emit(0)
		_mouse(board, false, "h4")
		_drag(board, "d2", "d4")
		assert_eq(board.premoves.style, "off")
		assert_eq(board.premoves.moves, PackedStringArray())
		assert_eq(board.game.moves, PackedStringArray(["e2e4"]), "off allows no opponent-turn moves")
		assert_eq(Settings.new(SETTINGS_PATH).get_value("premove_style"), "off")
	main.free()
	var config := ConfigFile.new()
	config.set_value("settings", "premove_style", "invalid")
	assert_eq(config.save(SETTINGS_PATH), OK)
	assert_eq(Settings.new(SETTINGS_PATH).get_value("premove_style"), "Chess.com")
	DirAccess.remove_absolute(SETTINGS_PATH)


func test_queued_moves_use_the_ghost_position_without_changing_the_game():
	var game = Game.new()
	game.play("e2e4")
	var before: String = game.board.to_fen()
	var queue = PremoveQueue.new("w")
	assert_true(queue.enqueue(game.board, "g1f3"))
	assert_true(queue.enqueue(game.board, "f3g5"), "the second move starts on the first ghost")
	assert_true(not queue.enqueue(game.board, "g1h3"), "the knight has left g1")
	assert_true(not queue.enqueue(game.board, "a7a6"), "only human pieces")
	assert_true(not queue.enqueue(game.board, "a1b3"), "geometry misses are refused")
	var ghost = queue.position(game.board)
	assert_eq(ghost.piece_at("g5"), "N")
	assert_eq(ghost.piece_at("f3"), "")
	assert_eq(ghost.piece_at("g1"), "")
	assert_eq(game.board.to_fen(), before, "preview never plays on the live board")
	assert_eq(game.moves, PackedStringArray(["e2e4"]))


func test_ghost_moves_reject_king_captures_without_changing_the_accepted_prefix():
	for human in ["w", "b"]:
		var game = Game.new()
		assert_true(game.play("e2e4"))
		if human == "b":
			assert_true(game.play("e7e5"))
		var live_fen: String = game.board.to_fen()
		var live_moves: PackedStringArray = game.moves.duplicate()
		var queue = PremoveQueue.new(human)
		var prefix := PackedStringArray(["f1c4", "d1h5", "h5f7"] if human == "w" else ["f8c5", "d8h4", "h4f2"])
		for move in prefix:
			assert_true(queue.enqueue(game.board, move), move)
		var ghost_fen: String = queue.position(game.board).to_fen()
		var capture := "f7e8" if human == "w" else "f2e1"
		assert_true(not queue.enqueue(game.board, capture), "a premove cannot capture the opposing king: " + capture)
		assert_eq(queue.moves, prefix, "rejecting a move preserves the accepted prefix")
		var ghost = queue.position(game.board)
		assert_eq(ghost.to_fen(), ghost_fen, "the rejected move leaves the ghost unchanged")
		assert_eq(ghost.squares.count("K"), 1)
		assert_eq(ghost.squares.count("k"), 1)
		assert_eq(game.board.to_fen(), live_fen)
		assert_eq(game.moves, live_moves)


func test_ghost_projection_rejects_a_king_moving_onto_a_queued_destination():
	var game = Game.new("8/8/8/8/2k5/8/R7/K7 b - - 0 1")
	var queue = PremoveQueue.new("w")
	assert_true(queue.enqueue(game.board, "a2a3"))
	assert_true(queue.enqueue(game.board, "a3b3"))
	assert_true(queue.position(game.board) != null, "the original projection is valid")
	assert_true(game.play("c4b3"), "Maia's king enters a later queued destination")
	var live_fen: String = game.board.to_fen()
	assert_eq(queue.position(game.board), null, "an updated preview must not capture Maia's king")
	assert_eq(queue.moves, PackedStringArray(["a2a3", "a3b3"]), "projection leaves execution to the due-move check")
	assert_eq(game.board.to_fen(), live_fen)
	assert_eq(game.board.squares.count("K"), 1)
	assert_eq(game.board.squares.count("k"), 1)
	assert_eq(queue.take(game.board), "a2a3", "a valid due move still executes")


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


func test_geometric_premoves_and_recapture():
	var game = Game.new("4k3/8/3p4/4P3/8/5N2/P7/R3K3 b - - 0 1")
	var queue = PremoveQueue.new("w")
	assert_true(not queue.enqueue(game.board, "f3e4"), "knight geometry")
	assert_true(not queue.enqueue(game.board, "e5e4"), "pawn cannot go backwards")
	assert_true(queue.enqueue(game.board, "f3e5"), "own piece on target")
	assert_eq(queue.position(game.board).piece_at("e5"), "N")
	assert_true(queue.enqueue(game.board, "e5f7"), "next move uses the replacement")
	assert_true(game.play("d6e5"), "Maia captures the pawn")
	assert_eq(queue.take(game.board), "f3e5")
	assert_true(game.play("f3e5"), "the recapture plays")
	queue.clear()
	assert_true(queue.enqueue(game.board, "a1a4"), "rook passes through a blocker")
	queue.clear()
	assert_true(queue.enqueue(game.board, "a2b3"), "pawn captures diagonally onto empty square")


func test_premove_targets_include_geometry_on_the_board():
	var board = BoardScene.instantiate()
	board.game = Game.new("4k3/8/8/4P3/8/5N2/P7/R3K3 b - - 0 1")
	board.human_side = "w"
	Engine.get_main_loop().root.add_child(board)
	board.size = Vector2(800, 800)
	_mouse(board, true, "f3")
	assert_true("f3e5" in board._held_moves, "own piece is a displayed target")
	_mouse(board, false, "e5")
	assert_eq(board.premoves.moves, PackedStringArray(["f3e5"]))
	board.free()
