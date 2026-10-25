extends "res://tests/run.gd".Test

# UI-006: the promotion decision and the board's mouse input, using the real game and scenes.
const PromotionPicker = preload("res://ui/promotion_picker.gd")
const BoardScene = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")


func test_auto_queen_mode_premove_and_alt_decision():
	# Columns: ordinary, ordinary + Alt, premove, premove + Alt.
	var expected := {
		"off": [false, false, false, false],
		"on": [true, false, true, false],
		"only on premoves": [false, false, true, false],
	}
	var picker = PromotionPicker
	for mode in expected:
		var column := 0
		for premove in [false, true]:
			for alt in [false, true]:
				assert_eq(picker.should_auto_queen(mode, premove, alt), expected[mode][column],
						"%s premove=%s Alt=%s" % [mode, premove, alt])
				column += 1


func _board(fen := Game.START):
	var board = BoardScene.instantiate()
	board.game = Game.new(fen)
	board.slide_seconds = 0
	Engine.get_main_loop().root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(800, 800)
	return board


func _mouse(board, pressed: bool, square: String, button := MOUSE_BUTTON_LEFT, alt := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.alt_pressed = alt
	event.position = board.square_position(square, 800, board.flipped) + Vector2(50, 50) if square else Vector2(-10, -10)
	board._gui_input(event)


func _click(board, square: String) -> void:
	_mouse(board, true, square)
	_mouse(board, false, square)


func test_click_click_selects_without_moving_then_plays_a_legal_target():
	var board = _board()
	board.click_click = true
	var moves := []
	board.move_played.connect(func(san): moves.append(san))
	_click(board, "e2")
	assert_eq(board.game.moves, PackedStringArray(), "the first click only selects")
	_click(board, "e4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]))
	assert_eq(moves, ["e4"], "a click move is emitted once")
	board.free()


func test_clicking_elsewhere_deselects_including_off_board_and_same_square():
	for elsewhere in ["e5", "d2", "e7", "e2", ""]:
		var board = _board()
		board.click_click = true
		_click(board, "e2")
		_click(board, elsewhere)
		_click(board, "e4")
		assert_eq(board.game.moves, PackedStringArray(), "selection cleared by " + elsewhere)
		_click(board, "e2")
		_click(board, "e4")
		assert_eq(board.game.moves, PackedStringArray(["e2e4"]), "a fresh selection still works")
		board.free()


func test_dragging_still_works_in_both_input_modes_and_orientations():
	for enabled in [false, true]:
		for flipped in [false, true]:
			var board = _board()
			board.click_click = enabled
			board.flipped = flipped
			_mouse(board, true, "e2")
			_mouse(board, false, "e4")
			assert_eq(board.game.moves, PackedStringArray(["e2e4"]))
			board.free()


func test_click_click_is_off_by_default():
	var board = _board()
	assert_eq(board.click_click, false)
	_click(board, "e4")
	assert_eq(board.game.moves, PackedStringArray(), "an empty square cannot select")
	_click(board, "e7")
	assert_eq(board.game.moves, PackedStringArray(), "the opponent cannot be selected")
	board.free()


func test_a_flag_or_replacement_game_cannot_play_a_stale_selection():
	var board = _board()
	board.click_click = true
	_click(board, "e2")
	board.game.flag("w")
	_click(board, "e4")
	assert_eq(board.game.moves, PackedStringArray(), "a flag prevents a selected move")
	board.game = Game.new()
	_click(board, "d2")
	board.game = Game.new()
	_click(board, "d4")
	assert_eq(board.game.moves, PackedStringArray(), "a rematch forgets the selected square")
	_click(board, "e2")
	_click(board, "e4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]))
	board.free()
