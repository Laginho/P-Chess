extends "res://tests/run.gd".Test

# UI-006: the promotion decision and the board's mouse input, using the real game and scenes.
const PromotionPicker = preload("res://ui/promotion_picker.gd")
const BoardScene = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")
const Settings = preload("res://core/settings.gd")
const MainScene = preload("res://ui/main.tscn")
const History = preload("res://core/history.gd")
const HistoryStorage = preload("res://tests/history_storage.gd")
const PROMOTION := "4k3/P7/8/8/8/8/8/4K3 w - - 0 1"
var SETTINGS_PATH := "user://test_ui006_settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]


# Replace only the external engine so the actual settings scene and Main lifecycle run.
class NoEngine extends "res://engine/uci.gd":
	func start(_dirs := PackedStringArray()) -> bool:
		return true


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


func test_right_click_cancels_selection_without_drawing():
	for premove in [false, true]:
		var board = _board(Game.START if not premove else "4k3/8/8/8/8/8/4P3/4K3 b - - 0 1")
		board.human_side = "w"
		board.click_click = true
		_click(board, "e2")
		_mouse(board, true, "e4", MOUSE_BUTTON_RIGHT)
		_mouse(board, false, "e5", MOUSE_BUTTON_RIGHT)
		assert_eq(board._selected, "", "right click cancels selection")
		assert_eq(board.drawings, [], "cancellation does not draw")
		_mouse(board, true, "e4", MOUSE_BUTTON_RIGHT)
		_mouse(board, false, "e5", MOUSE_BUTTON_RIGHT)
		assert_eq(board.drawings, [PackedStringArray(["e4", "e5"])], "next right drag draws")
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


func test_a_selected_piece_can_still_be_dragged():
	var board = _board()
	board.click_click = true
	_click(board, "e2")
	_mouse(board, true, "e2")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(450, 450)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	board._gui_input(motion)
	_mouse(board, false, "e4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]), "selecting a piece must not disable dragging it")
	board.free()


func test_disabling_click_click_clears_an_existing_selection():
	var board = _board()
	board.click_click = true
	_click(board, "e2")
	board.click_click = false
	_click(board, "e4")
	assert_eq(board.game.moves, PackedStringArray(), "the setting takes effect with a piece selected")
	_mouse(board, true, "e2")
	_mouse(board, false, "e4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]), "dragging stays available")
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


func test_promotion_drop_uses_the_mode_and_alt_opens_the_picker():
	for mode in ["off", "on", "only on premoves"]:
		for alt in [false, true]:
			var board = _board(PROMOTION)
			board.auto_queen = mode
			_mouse(board, true, "a7")
			_mouse(board, false, "a8", MOUSE_BUTTON_LEFT, alt)
			if mode == "on" and not alt:
				assert_eq(board.game.moves, PackedStringArray(["a7a8q"]))
				assert_true(not board.get_node("PromotionPicker").visible)
			else:
				assert_eq(board.game.moves, PackedStringArray())
				var picker = board.get_node("PromotionPicker")
				assert_true(picker.visible, "%s Alt=%s" % [mode, alt])
				# Choose a knight through the actual picker button.
				picker.get_child(3).pressed.emit()
				assert_eq(board.game.moves, PackedStringArray(["a7a8n"]))
			board.free()


func test_click_click_promotions_use_auto_queen_and_alt_too():
	for alt in [false, true]:
		var board = _board(PROMOTION)
		board.click_click = true
		board.auto_queen = "on"
		_click(board, "a7")
		_mouse(board, true, "a8", MOUSE_BUTTON_LEFT, alt)
		_mouse(board, false, "a8", MOUSE_BUTTON_LEFT, alt)
		assert_eq(board.get_node("PromotionPicker").visible, alt)
		assert_eq(board.game.moves, PackedStringArray() if alt else PackedStringArray(["a7a8q"]))
		board.free()


func test_input_settings_default_persist_and_reject_bad_values():
	DirAccess.remove_absolute(SETTINGS_PATH)
	var settings = Settings.new(SETTINGS_PATH)
	assert_eq(settings.get_value("click_click"), false)
	assert_eq(settings.get_value("auto_queen"), "off")
	assert_true(settings.set_value("click_click", true))
	for mode in ["on", "only on premoves", "off"]:
		assert_true(settings.set_value("auto_queen", mode))
		var reloaded = Settings.new(SETTINGS_PATH)
		assert_eq(reloaded.get_value("click_click"), true)
		assert_eq(reloaded.get_value("auto_queen"), mode)
	assert_true(not settings.set_value("click_click", "yes"))
	assert_true(not settings.set_value("auto_queen", "always"))
	var file := ConfigFile.new()
	file.set_value("settings", "click_click", "bad")
	file.set_value("settings", "auto_queen", "bad")
	assert_eq(file.save(SETTINGS_PATH), OK)
	var bad = Settings.new(SETTINGS_PATH)
	assert_eq(bad.get_value("click_click"), false)
	assert_eq(bad.get_value("auto_queen"), "off")
	DirAccess.remove_absolute(SETTINGS_PATH)


func _row_control(form, label: String):
	for i in range(0, form.get_child_count(), 2):
		if form.get_child(i).text == label:
			return form.get_child(i + 1)
	return null


func test_right_drag_draws_an_arrow_and_right_click_draws_a_circle():
	for flipped in [false, true]:
		var board = _board()
		board.flipped = flipped
		_mouse(board, true, "e2", MOUSE_BUTTON_RIGHT)
		_mouse(board, false, "e4", MOUSE_BUTTON_RIGHT)
		_mouse(board, true, "d5", MOUSE_BUTTON_RIGHT)
		_mouse(board, false, "d5", MOUSE_BUTTON_RIGHT)
		assert_eq(board.drawings, [PackedStringArray(["e2", "e4"]), PackedStringArray(["d5", "d5"])])
		assert_eq(board.game.moves, PackedStringArray(), "drawing never plays a move")
		board.free()


func test_off_board_right_gestures_and_unmatched_releases_draw_nothing():
	var board = _board()
	_mouse(board, false, "e4", MOUSE_BUTTON_RIGHT)
	_mouse(board, true, "", MOUSE_BUTTON_RIGHT)
	_mouse(board, false, "e4", MOUSE_BUTTON_RIGHT)
	_mouse(board, true, "e2", MOUSE_BUTTON_RIGHT)
	_mouse(board, false, "", MOUSE_BUTTON_RIGHT)
	assert_eq(board.drawings, [])
	board.free()


func test_drawing_the_same_arrow_or_circle_again_erases_it():
	var board = _board()
	for i in 2:
		_mouse(board, true, "e2", MOUSE_BUTTON_RIGHT)
		_mouse(board, false, "e4", MOUSE_BUTTON_RIGHT)
		_mouse(board, true, "d5", MOUSE_BUTTON_RIGHT)
		_mouse(board, false, "d5", MOUSE_BUTTON_RIGHT)
	assert_eq(board.drawings, [])
	board.free()


func test_right_press_drops_a_held_piece_back():
	var board = _board()
	_mouse(board, true, "e2")
	_mouse(board, true, "e4", MOUSE_BUTTON_RIGHT)
	assert_eq(board._drag_from, "", "the drag ends on the right press")
	_mouse(board, false, "e4")
	_mouse(board, false, "e4", MOUSE_BUTTON_RIGHT)
	assert_eq(board.game.moves, PackedStringArray(), "the left release plays nothing")
	assert_eq(board.drawings, [], "the cancelling click draws nothing")
	board.free()


func test_left_press_clears_all_drawings_and_cancels_an_unfinished_one():
	var board = _board()
	board.click_click = true
	_click(board, "e2")
	_mouse(board, true, "a1", MOUSE_BUTTON_RIGHT)
	_mouse(board, false, "h8", MOUSE_BUTTON_RIGHT)
	_mouse(board, true, "b3", MOUSE_BUTTON_RIGHT)
	_mouse(board, false, "b3", MOUSE_BUTTON_RIGHT)
	_mouse(board, true, "e4")
	assert_eq(board.drawings, [], "drawings clear on press, before release")
	_mouse(board, false, "e4")
	assert_eq(board.game.moves, PackedStringArray(["e2e4"]), "drawing preserves click selection")
	_mouse(board, true, "a1", MOUSE_BUTTON_RIGHT)
	_mouse(board, true, "d4")
	_mouse(board, false, "d4")
	_mouse(board, false, "h8", MOUSE_BUTTON_RIGHT)
	assert_eq(board.drawings, [], "a cancelled gesture cannot restore a drawing")
	board.free()


func test_settings_screen_changes_reach_the_board_and_survive_reload():
	DirAccess.remove_absolute(SETTINGS_PATH)
	var preferences = Settings.new(SETTINGS_PATH)
	preferences.set_value("click_click", true)
	preferences.set_value("auto_queen", "on")
	var history_folder := "user://test_input_modes_history_%d" % Time.get_ticks_usec()
	var isolated_history = History.new(history_folder)
	var main = MainScene.instantiate()
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	main.history = isolated_history
	main.tree_exiting.connect(func(): HistoryStorage.clean(history_folder))
	main.uci.free()
	main.uci = NoEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = preferences
	# Fail before _ready can open the player's history if this harness loses its injection.
	assert_eq(main.history, isolated_history, "history is isolated before Main enters the tree")
	if main.history != isolated_history:
		main.uci.free()
		main.sound_player.free()
		main.settings_screen.free()
		main.free()
		DirAccess.remove_absolute(SETTINGS_PATH)
		return
	Engine.get_main_loop().root.add_child(main)
	assert_eq(main.history, isolated_history, "startup retains the isolated History")
	assert_eq(main.board_view.click_click, true, "stored values apply on startup")
	assert_eq(main.board_view.auto_queen, "on")
	var form = main.settings_screen.get_node("Panel/Center/Box/Form")
	var click = _row_control(form, "Click-click moves")
	var queen = _row_control(form, "Auto-queen")
	assert_true(click != null, "click-click has a settings control")
	assert_true(queen != null, "auto-queen has a settings control")
	if click != null and queen != null:
		assert_eq(click.button_pressed, true)
		assert_eq(queen.get_item_text(queen.selected), "on")
		click.button_pressed = false
		queen.select(2)
		queen.item_selected.emit(2)
		assert_eq(main.board_view.click_click, false, "changes apply without restart")
		assert_eq(main.board_view.auto_queen, "only on premoves")
		var saved = Settings.new(SETTINGS_PATH)
		assert_eq(saved.get_value("click_click"), false)
		assert_eq(saved.get_value("auto_queen"), "only on premoves")
	main.free()
	DirAccess.remove_absolute(SETTINGS_PATH)
