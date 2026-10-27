extends "res://tests/run.gd".Test

# The board's pixel <-> square mapping, both orientations, at two board sizes (UI-001).
# Points are measured from the board's top-left corner; `flipped` puts black at the bottom.

const BoardView = preload("res://ui/board_view.gd")


func test_point_to_square_with_white_at_the_bottom():
	assert_eq(BoardView.square_at(Vector2(0, 0), 800, false), "a8")
	assert_eq(BoardView.square_at(Vector2(799, 799), 800, false), "h1")
	assert_eq(BoardView.square_at(Vector2(350, 450), 800, false), "d4")
	assert_eq(BoardView.square_at(Vector2(130, 70), 480, false), "c7")
	assert_eq(BoardView.square_at(Vector2(479.5, 0), 480, false), "h8")


func test_point_to_square_with_black_at_the_bottom():
	assert_eq(BoardView.square_at(Vector2(0, 0), 800, true), "h1")
	assert_eq(BoardView.square_at(Vector2(799, 799), 800, true), "a8")
	assert_eq(BoardView.square_at(Vector2(350, 450), 800, true), "e5")
	assert_eq(BoardView.square_at(Vector2(130, 70), 480, true), "f2")


func test_points_off_the_board_name_no_square():
	for flipped in [false, true]:
		assert_eq(BoardView.square_at(Vector2(800, 10), 800, flipped), "", "right edge")
		assert_eq(BoardView.square_at(Vector2(10, 800), 800, flipped), "", "bottom edge")
		assert_eq(BoardView.square_at(Vector2(-1, 10), 800, flipped), "", "left of the board")
		assert_eq(BoardView.square_at(Vector2(10, -0.5), 800, flipped), "", "above the board")


func test_square_to_top_left_corner():
	assert_eq(BoardView.square_position("a1", 800, false), Vector2(0, 700))
	assert_eq(BoardView.square_position("h8", 800, false), Vector2(700, 0))
	assert_eq(BoardView.square_position("e2", 480, false), Vector2(240, 360))
	assert_eq(BoardView.square_position("a1", 800, true), Vector2(700, 0))
	assert_eq(BoardView.square_position("h8", 800, true), Vector2(0, 700))
	assert_eq(BoardView.square_position("e2", 480, true), Vector2(180, 60))


func _mouse(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


# CLOCK-001: a flag is the first way a game ends while a piece is held.
func test_a_piece_held_when_the_game_ends_snaps_back_without_a_move():
	var board = BoardView.new()
	board.size = Vector2(800, 800)
	board.game = preload("res://core/game.gd").new()
	var emitted := []
	board.move_played.connect(func(san): emitted.append(san))
	board.sound_requested.connect(func(event): emitted.append(event))
	board._gui_input(_mouse(true, Vector2(450, 650)))
	board.game.flag("w")
	board._gui_input(_mouse(false, Vector2(450, 450)))
	assert_eq(emitted, [], "no move, no sound")
	assert_eq(board.game.moves, PackedStringArray())
	assert_eq(board._drag_from, "", "the piece is no longer held")
	board.free()


func test_every_square_centre_maps_back_to_its_square():
	for side in [800.0, 480.0]:
		for flipped in [false, true]:
			for i in 64:
				var square: String = "abcdefgh"[i % 8] + str(i / 8 + 1)
				var centre: Vector2 = BoardView.square_position(square, side, flipped) + Vector2.ONE * side / 16
				assert_eq(BoardView.square_at(centre, side, flipped), square, "%s %d %s" % [square, side, flipped])


# CLEAN-002: an open promotion picker follows the board through a flip and a resize.
func _open_promotion_picker(premove: bool):
	var board = preload("res://ui/board_view.tscn").instantiate()
	board.game = preload("res://core/game.gd").new("4k3/P7/8/8/8/8/7P/4K3 %s - - 0 1" % ("b" if premove else "w"))
	if premove:
		board.human_side = "w"
	board.slide_seconds = 0
	Engine.get_main_loop().root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(800, 800)
	board._gui_input(_mouse(true, Vector2(50, 150)))
	board._gui_input(_mouse(false, Vector2(50, 50)))
	return board


# Expected button rectangles: queen on `at` (the promotion square), the rest one cell apart.
func _assert_picker_buttons(board, at: Vector2, cell: float, down: bool, when: String) -> void:
	var picker = board.get_node("PromotionPicker")
	assert_true(picker.visible, when)
	for i in 4:
		var expected := Rect2(at + Vector2(0, i * cell * (1 if down else -1)), Vector2.ONE * cell)
		assert_eq(picker.get_child(i).get_rect(), expected, "%s, button %d" % [when, i])


func test_an_open_promotion_picker_follows_flip_and_resize():
	for premove in [false, true]:
		for choose in [true, false]:
			var board = _open_promotion_picker(premove)
			var played := []
			board.move_played.connect(func(san): played.append(san))
			_assert_picker_buttons(board, Vector2(0, 0), 100, true, "opened")
			board.flipped = true
			_assert_picker_buttons(board, Vector2(700, 700), 100, false, "flipped")
			# 480 wide, 600 high: a 480 board centred vertically, 60 px squares.
			board.size = Vector2(480, 600)
			_assert_picker_buttons(board, Vector2(420, 480), 60, false, "resized")
			var picker = board.get_node("PromotionPicker")
			if choose:
				picker.get_child(3).pressed.emit()
			else:
				picker._gui_input(_mouse(true, Vector2(10, 10)))
			var moved := PackedStringArray(["a7a8n"]) if choose else PackedStringArray()
			var label := "premove=%s choose=%s" % [premove, choose]
			assert_true(not picker.visible, label)
			assert_eq(board.premoves.moves if premove else board.game.moves, moved, label)
			assert_eq(board.game.moves if premove else board.premoves.moves, PackedStringArray(), label)
			assert_eq(played.size(), 1 if choose and not premove else 0, label)
			board.free()


func _held_board(fen: String, human: String, square: String, selected: bool):
	var board = preload("res://ui/board_view.tscn").instantiate()
	board.game = preload("res://core/game.gd").new(fen)
	board.human_side = human
	board.flipped = human == "b"
	board.click_click = selected
	board.slide_seconds = 0
	Engine.get_main_loop().root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(800, 800)
	var at: Vector2 = board.square_position(square, 800, board.flipped) + Vector2(50, 50)
	board._gui_input(_mouse(true, at))
	if selected:
		board._gui_input(_mouse(false, at))
	return board


func test_held_targets_update_to_legal_moves_including_new_en_passant():
	for selected in [false, true]:
		for case in [
			["4k3/3p4/8/4P3/8/8/8/4K3 b - - 0 1", "w", "e5", "d7d5", "d6", "e6"],
			["4k3/8/8/8/4p3/8/3P4/4K3 w - - 0 1", "b", "e4", "d2d4", "d3", "e3"],
		]:
			var board = _held_board(case[0], case[1], case[2], selected)
			assert_true(board._held_moves.size() > 2, "premove dots include geometric captures")
			assert_true(board.play(case[3]))
			assert_eq(board._held_moves.size(), 2, "only the advance and en passant are now legal")
			assert_true(case[2] + case[4] in board._held_moves, "the newly available en passant target")
			assert_true(case[2] + case[5] in board._held_moves, "the ordinary pawn advance")
			var to: Vector2 = board.square_position(case[4], 800, board.flipped) + Vector2(50, 50)
			if selected:
				board._gui_input(_mouse(true, to))
			board._gui_input(_mouse(false, to))
			assert_eq(board.game.moves, PackedStringArray([case[3], case[2] + case[4]]))
			assert_eq(board._drag_from, "", "playing the held piece ends its hold")
			assert_eq(board._selected, "")
			board.free()


func test_capturing_a_held_piece_clears_drag_selection_and_targets():
	for selected in [false, true]:
		for case in [
			["4k3/8/3p4/4P3/8/8/P7/4K3 b - - 0 1", "w", "e5", "d6e5", "e6"],
			["4k3/p7/8/8/4p3/3P4/8/4K3 w - - 0 1", "b", "e4", "d3e4", "e3"],
		]:
			var board = _held_board(case[0], case[1], case[2], selected)
			assert_true(board.play(case[3]))
			assert_eq(board._drag_from, "")
			assert_eq(board._selected, "")
			assert_eq(board._held_moves, PackedStringArray())
			var to: Vector2 = board.square_position(case[4], 800, board.flipped) + Vector2(50, 50)
			if selected:
				board._gui_input(_mouse(true, to))
			board._gui_input(_mouse(false, to))
			assert_eq(board.game.moves, PackedStringArray([case[3]]), "stale input cannot play the captured piece")
			board.free()
