extends "res://tests/run.gd".Test

# The game loop around a game (UI-004, §9.1, §9.2): the rematch settings and the double-Esc resign,
# on a fake time source. Scene tests use the real Main with a fake engine and manually completed
# timer signals, so neither Lc0 nor elapsed wall-clock time decides their outcome.

const Main = preload("res://ui/main.gd")
const BoardView = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")
const MainScene = preload("res://ui/main.tscn")
const HistoryStorage = preload("res://tests/history_storage.gd")


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


# The engine boundary: policies are delivered explicitly, in UCI request order.
class HeldBridge extends "res://engine/uci.gd":
	var requests := []
	var hold_level := false

	func start(_dirs := PackedStringArray()) -> bool:
		return true

	func set_level(_net_path: String) -> void:
		if not hold_level and has_signal("level_ready"):
			emit_signal("level_ready")

	func request_policy(start_fen: String, moves: PackedStringArray) -> void:
		requests.append([start_fen, moves.duplicate()])


class PendingWait extends RefCounted:
	signal timeout


class ManualWaits:
	var pending := []

	func start(_seconds: float) -> Signal:
		var wait := PendingWait.new()
		pending.append(wait)
		return wait.timeout


const SETTINGS := {"colour": "w", "level": "maia-1700", "control": "3+2", "opening": "Free"}


func test_rematch_swaps_colours_and_keeps_the_rest():
	assert_eq(Main.rematch(SETTINGS), {"colour": "b", "level": "maia-1700", "control": "3+2", "opening": "Free"})
	var as_black := SETTINGS.duplicate()
	as_black.colour = "b"
	assert_eq(Main.rematch(as_black).colour, "w")


func test_rematch_of_a_rematch_is_the_first_game_and_leaves_the_input_alone():
	var settings := SETTINGS.duplicate()
	assert_eq(Main.rematch(Main.rematch(settings)), SETTINGS)
	assert_eq(settings, SETTINGS, "rematch returns new settings")


func test_second_esc_within_two_seconds_resigns():
	var time := FakeTime.new()
	var key = Main.ResignKey.new(time.ms)
	assert_true(not key.press(), "the first Esc only shows the hint")
	assert_true(key.armed(), "the hint shows")
	time.now += 1900
	assert_true(key.armed(), "the hint still shows at 1.9 s")
	assert_true(key.press(), "a second Esc at 1.9 s resigns")


func test_after_two_seconds_the_hint_goes_and_the_next_esc_starts_over():
	var time := FakeTime.new()
	var key = Main.ResignKey.new(time.ms)
	key.press()
	time.now += 2100
	assert_true(not key.armed(), "the hint is gone at 2.1 s")
	assert_true(not key.press(), "an Esc at 2.1 s is a first press again")
	assert_true(key.armed(), "and shows the hint again")
	time.now += 1900
	assert_true(key.press(), "a second Esc 1.9 s after that one resigns")


func test_a_resign_disarms_the_key():
	var time := FakeTime.new()
	var key = Main.ResignKey.new(time.ms)
	key.press()
	key.press()
	assert_true(not key.armed(), "no hint after resigning")
	assert_true(not key.press(), "a third Esc starts over")


# An off-tree 800 px board playing `fen`: the picker is wired by hand and slides are off. The
# integration tests below use _session instead, which readies the real Main in the active tree.
func _board(fen: String):
	var board = BoardView.instantiate()
	board._picker = board.get_node("PromotionPicker")
	board.set_piece_theme("cburnett")
	board.slide_seconds = 0
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.size = Vector2(800, 800)
	board.game = Game.new(fen)
	return board


func _mouse(board, pressed: bool, square: String) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = board.square_position(square, 800, board.flipped) + Vector2(50, 50)
	board._gui_input(event)


# A rematch is Main._start handing the board a new game, black at the bottom after playing white.
func _rematch(board) -> void:
	board.game = Game.new()
	board.flipped = true


func test_a_rematch_closes_the_promotion_picker_left_open_by_a_flag():
	var board = _board("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	_mouse(board, true, "a7")
	_mouse(board, false, "a8")
	assert_true(board._picker.visible, "the picker is open")
	board.game.flag("w")
	_rematch(board)
	assert_true(not board._picker.visible, "no picker over the new game")
	assert_eq(board._promoting, "", "no promotion pending")
	board.free()


func test_a_rematch_drops_the_piece_held_when_the_game_ended():
	var board = _board("4k3/8/8/4P3/8/8/8/4K3 w - - 0 1")
	_mouse(board, true, "e5")
	board.game.flag("w")
	_rematch(board)
	assert_eq(board._drag_from, "", "nothing held in the new game")
	assert_eq(board._held_moves, PackedStringArray(), "no targets from the old game")
	assert_true(board.play("e2e4"), "Maia's first move")
	_mouse(board, true, "e7")
	_mouse(board, false, "e6")
	assert_eq(board.game.moves, PackedStringArray(["e2e4", "e7e6"]), "e7e6 plays in the new game")
	board.free()


func _session(waits, start_game := true, queue = null, catalog = null):
	var main = MainScene.instantiate()
	if catalog == null:
		main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	else:
		main.get_node("Setup").book = catalog
	var folder := "user://test_session_history_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.tree_exiting.connect(func(): HistoryStorage.clean(folder))
	main.analysis_queue = queue
	main.uci.free()
	main.uci = HeldBridge.new()
	main.maia = Main.MaiaPlayer.new(main.uci, waits.start)
	# A returning player, isolated from the person's preferences.
	DirAccess.make_dir_recursive_absolute(folder)
	main.preferences = Main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__ui004_silent__")
	if start_game:
		await main._start(SETTINGS.duplicate())
	return main


func _key(main, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	main._unhandled_key_input(event)


func test_game_over_panel_actions():
	for action in ["Review", "Rematch", "NewGame", "Close", "Escape"]:
		var main = await _session(ManualWaits.new())
		_key(main, KEY_ESCAPE)
		_key(main, KEY_ESCAPE)
		assert_true(not main.review.visible, "review waits for a request")
		var panel = main.board_view.get_node_or_null("GameOver")
		assert_true(panel != null and panel.visible, "game-over panel appears")
		if panel:
			assert_eq(panel.get_node("Panel/Content/Headline").text, "Black won")
			assert_eq(panel.get_node("Panel/Content/Reason").text, "by resignation")
			if action == "Escape":
				var event := InputEventKey.new()
				event.keycode = KEY_ESCAPE
				event.pressed = true
				panel._input(event)
			else:
				panel.get_node("Panel/Content/" + action).pressed.emit()
				await _wait_start(main)
			match action:
				"Review":
					assert_true(main.review.visible, "Review opens the review")
				"Rematch":
					assert_eq(main.human, "b", "Rematch swaps colours")
				"NewGame":
					assert_true(main.get_node("Home").visible, "New game opens Home")
				_:
					assert_true(not panel.visible, "the final board remains visible")
					assert_true(main.get_node_or_null("Layout/Side/ReviewButton") == null, "side Review is removed")
		main.free()


func _resign_and_rematch(main) -> void:
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	_key(main, KEY_SPACE)
	await _wait_start(main)


func _finish(waits, index: int) -> void:
	assert_true(index < waits.pending.size(), "think time was scheduled")
	if index < waits.pending.size():
		waits.pending[index].timeout.emit()


func test_a_new_reply_plays_before_an_old_games_wait_finishes():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	assert_true(main.board_view.play("e2e4"))
	main.uci.policy_ready.emit({"e2e4": 1.0})
	main.uci.policy_ready.emit({"e7e5": 1.0})
	await _resign_and_rematch(main)
	assert_eq(main.human, "b", "Space swaps the colour actually played")
	main.uci.policy_ready.emit({"e2e4": 1.0})
	assert_eq(waits.pending.size(), 2, "both policies have entered their waits")
	_finish(waits, 1)
	assert_eq(main.board_view.game.moves, PackedStringArray(["e2e4"]), "the current reply plays first")
	assert_eq(main.board_view.mouse_filter, Control.MOUSE_FILTER_STOP, "the human can answer Maia")
	_finish(waits, 0)
	# e7e5 would be legal here, but belongs to the game that was resigned.
	assert_eq(main.board_view.game.moves, PackedStringArray(["e2e4"]), "the old reply cannot play as the human")
	main.free()


func test_an_old_policy_after_rematch_is_dropped_before_a_wait_is_scheduled():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	assert_true(main.board_view.play("e2e4"))
	await _resign_and_rematch(main)
	assert_eq(main.uci.requests, [[Game.START, PackedStringArray()], [Game.START, PackedStringArray(["e2e4"])],
			[Game.START, PackedStringArray()]], "the old and current policies are queued FIFO")
	main.uci.policy_ready.emit({"e2e4": 1.0})
	main.uci.policy_ready.emit({"e7e5": 1.0})
	assert_eq(waits.pending.size(), 0, "no think time scheduled for an obsolete policy")
	assert_eq(main.maia.latencies_ms, [], "obsolete policies are not processed as current samples")
	main.uci.policy_ready.emit({"d2d4": 1.0})
	assert_eq(waits.pending.size(), 1, "the old entry consumed only its own policy")
	_finish(waits, 0)
	assert_eq(main.board_view.game.moves, PackedStringArray(["d2d4"]), "the current policy still plays")
	main.free()


# The real board's layout is ready one frame after _session adds Main to the tree.
func _laid_out(main):
	await Engine.get_main_loop().process_frame
	assert_true(main.board_view._side() > 0, "the board has a size")


func _mouse_on(main, pressed: bool, square: String) -> void:
	var board = main.board_view
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = board._corner() + board.square_position(square, board._side(), board.flipped) \
			+ Vector2.ONE * board._side() / 16
	board._gui_input(event)


# Main's own flag and Space paths: the clock flags the human, then Space starts the rematch.
func _flag_and_rematch(main) -> void:
	main.clock.flagged.emit(main.human)
	assert_true(main.board_view.game.is_over(), "the flag ended the game")
	_key(main, KEY_SPACE)
	await _wait_start(main)
	assert_eq(main.human, "b", "Space started the rematch")


func test_a_main_rematch_after_a_flag_closes_the_open_promotion_picker():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	await _laid_out(main)
	var replies := ["b7b5", "a7a6", "c8b7", "b8c6"]
	for i in replies.size():
		assert_true(main.board_view.play(["a2a4", "a4b5", "b5a6", "a6b7"][i]))
		main.uci.policy_ready.emit({})
		main.uci.policy_ready.emit({replies[i]: 1.0})
		_finish(waits, i)
	_mouse_on(main, true, "b7")
	_mouse_on(main, false, "a8")
	var picker = main.board_view._picker
	assert_true(picker.visible, "the picker is open")
	assert_eq(picker.get_child_count(), 4, "with its four buttons")
	await _flag_and_rematch(main)
	assert_true(not picker.visible, "no picker over the new game")
	assert_eq(main.board_view._promoting, "", "no promotion pending")
	await Engine.get_main_loop().process_frame
	assert_eq(picker.get_child_count(), 0, "the picker's buttons are gone")
	main.free()


func test_a_main_rematch_after_a_flag_drops_the_held_piece():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	await _laid_out(main)
	_mouse_on(main, true, "e2")
	assert_eq(main.board_view._drag_from, "e2", "e2 is held")
	await _flag_and_rematch(main)
	assert_eq(main.board_view._drag_from, "", "nothing held in the new game")
	assert_eq(main.board_view._held_moves, PackedStringArray(), "no targets from the old game")
	main.uci.policy_ready.emit({"e2e4": 1.0})
	_finish(waits, 0)
	_mouse_on(main, true, "e7")
	_mouse_on(main, false, "e6")
	assert_eq(main.board_view.game.moves, PackedStringArray(["e2e4", "e7e6"]), "e7e6 plays in the new game")
	main.free()


func test_a_main_rematch_kills_the_old_snap_back():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	await _laid_out(main)
	_mouse_on(main, true, "e2")
	_mouse_on(main, false, "e5")
	assert_true(main.board_view._snapping, "e2 is snapping back")
	await _flag_and_rematch(main)
	main.uci.policy_ready.emit({"e2e4": 1.0})
	_finish(waits, 0)
	_mouse_on(main, true, "e7")
	assert_eq(main.board_view._drag_from, "e7", "e7 is held in the new game")
	await Engine.get_main_loop().create_timer(main.board_view.SNAP_BACK_SECONDS * 3).timeout
	assert_eq(main.board_view._drag_from, "e7", "the old snap-back's end does not drop e7")
	main.free()


func test_two_rematches_drop_a_stale_white_move_legal_in_the_current_game():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	assert_true(main.board_view.play("a2a3"))
	main.uci.policy_ready.emit({"a2a3": 1.0})
	main.uci.policy_ready.emit({"a7a6": 1.0})
	await _resign_and_rematch(main)
	main.uci.policy_ready.emit({"d2d4": 1.0})
	await _resign_and_rematch(main)
	assert_eq(main.human, "w", "two rematches restore the original colours")
	assert_eq(main.settings, SETTINGS, "the other settings survive both rematches")
	assert_eq(waits.pending.size(), 2, "no new Maia request on the human's first turn")
	_finish(waits, 1)
	assert_eq(main.board_view.game.moves, PackedStringArray(), "stale d2d4 cannot play as the human")
	assert_true(main.board_view.play("g1f3"))
	main.uci.policy_ready.emit({"g1f3": 1.0})
	main.uci.policy_ready.emit({"e7e5": 1.0})
	_finish(waits, 2)
	_finish(waits, 0)
	assert_eq(main.board_view.game.moves, PackedStringArray(["g1f3", "e7e5"]), "only the current reply plays")
	main.free()


func test_resign_button_shares_the_two_second_window_with_escape():
	for sequence in ["click_click", "click_escape", "escape_click", "expired_click"]:
		var main = await _session(ManualWaits.new())
		var button = main.get_node_or_null("Layout/Side/Actions/ResignButton")
		assert_true(button != null, "resign button exists")
		if button == null:
			main.free()
			continue
		var time := FakeTime.new()
		main.resign_key = Main.ResignKey.new(time.ms)
		assert_true(not button.disabled, "enabled during game")
		if sequence == "escape_click":
			_key(main, KEY_ESCAPE)
		else:
			button.pressed.emit()
		main._process(0)
		assert_true(not main.board_view.game.is_over(), "first action arms")
		assert_eq(button.text, "Click again to resign", "button shows confirmation")
		time.now = 2100 if sequence == "expired_click" else 1900
		if sequence == "expired_click":
			main._process(0)
			assert_eq(button.text, "Resign", "expired confirmation is hidden")
		if sequence == "click_escape":
			_key(main, KEY_ESCAPE)
		else:
			button.pressed.emit()
		assert_eq(main.board_view.game.is_over(), sequence != "expired_click")
		if sequence != "expired_click":
			assert_eq(main.board_view.game.reason, "resignation")
			assert_true(button.disabled, "disabled after game")
		main.free()


func test_resign_button_disabled_in_setup_and_after_engine_stops():
	var main = await _session(ManualWaits.new())
	var button = main.get_node_or_null("Layout/Side/Actions/ResignButton")
	assert_true(button != null, "resign button exists")
	if button:
		main._show_setup()
		assert_true(button.disabled, "disabled in setup")
		await main._start(SETTINGS.duplicate())
		main._on_engine_stopped()
		assert_true(button.disabled, "disabled after engine stops")
	main.free()


func test_settings_blocks_focused_resign_button_from_space():
	var main = await _session(ManualWaits.new())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	for down in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		mouse.position = main.resign_button.get_global_rect().get_center()
		viewport.push_input(mouse, true)
	_push_key(viewport, KEY_COMMA, true)
	assert_true(main.resign_key.armed(), "click arms resignation")
	assert_true(main.settings_screen.get_node("Panel").visible, "Settings opened")
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = down
		viewport.push_input(key, true)
	assert_true(not main.board_view.game.is_over(), "Space in Settings cannot resign")
	main.free()


func test_draw_offer_accepted_on_reply_without_playing_it():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	var button = main.get_node_or_null("Layout/Side/Actions/DrawButton")
	assert_true(button != null, "draw offer button exists")
	if button == null:
		main.free()
		return
	assert_eq(button.text, String.chr(0x00bd), "draw button label")
	assert_true(not button.disabled, "offer available during game")
	assert_true(main.board_view.play("e2e4"))
	button.pressed.emit()
	assert_true(button.disabled, "offer starts cooldown")
	main.uci.evaluation = 9.0
	main.uci.policy_ready.emit({"e2e4": 1.0})
	main.uci.evaluation = -1.5
	main.uci.policy_ready.emit({"e7e5": 1.0})
	main.uci.evaluation = 9.0
	_finish(waits, 0)
	var game = main.board_view.game
	assert_eq(game.moves, PackedStringArray(["e2e4"]), "Maia's move is not played")
	assert_eq(game.result, "1/2-1/2")
	assert_eq(game.reason, "agreement")
	assert_eq(main.history.stats("maia-1700", "3+2").draws, 1)
	var files := DirAccess.get_files_at(main.history._root.path_join("games"))
	assert_eq(files.size(), 1, "one saved PGN")
	if files.size() == 1:
		var pgn := FileAccess.get_file_as_string(main.history._root.path_join("games").path_join(files[0]))
		assert_true('[Result "1/2-1/2"]' in pgn)
		assert_true('[Reason "agreement"]' in pgn)
		assert_true('[Termination "Normal"]' in pgn)
	var panel = main.board_view.get_node_or_null("GameOver")
	assert_true(panel != null, "game-over panel")
	if panel:
		assert_eq(panel.get_node("Panel/Content/Headline").text, "Draw")
		assert_eq(panel.get_node("Panel/Content/Reason").text, "by agreement")
	main.free()


func test_declined_offer_reenables_only_after_ten_human_moves():
	var waits := ManualWaits.new()
	var main = await _session(waits)
	var button = main.get_node("Layout/Side/Actions/DrawButton")
	button.pressed.emit()
	assert_true(button.disabled, "offer immediately disables button")
	var human_moves := ["e2e4", "g1f3", "f1c4", "d2d3", "c2c3", "b1d2", "a2a3", "h2h3", "e1g1", "b2b4"]
	var maia_moves := ["e7e5", "b8c6", "g8f6", "f8c5", "d7d6", "a7a6", "h7h6", "c8e6", "e8g8", "c5b6"]
	for i in human_moves.size():
		assert_true(main.board_view.play(human_moves[i]), "human move %d" % (i + 1))
		assert_eq(button.disabled, i < 9, "cooldown after %d human moves" % (i + 1))
		main.uci.evaluation = null
		main.uci.policy_ready.emit({})
		main.uci.policy_ready.emit({maia_moves[i]: 1.0})
		_finish(waits, i)
		assert_true(not main.board_view.game.is_over(), "decline plays on")
		if i == 0:
			assert_eq(main.board_view.game.moves, PackedStringArray(["e2e4", "e7e5"]))
			assert_eq(main.get_node("Layout/Side/DrawNotice").text, "Maia declined")
			assert_true(main.get_node("Layout/Side/DrawNotice").visible)
			main.get_node("Layout/Side/DrawNoticeTimer").timeout.emit()
			assert_true(not main.get_node("Layout/Side/DrawNotice").visible)
	main._show_setup()
	assert_true(button.disabled, "disabled in setup")
	main.free()


func test_draw_offer_does_not_pass_through_settings_and_resets_on_rematch():
	var main = await _session(ManualWaits.new())
	var button = main.get_node("Layout/Side/Actions/DrawButton")
	main.settings_screen.get_node("Panel").show()
	button.pressed.emit()
	assert_true(not button.disabled, "settings blocks an offer")
	main.settings_screen.get_node("Panel").hide()
	button.pressed.emit()
	assert_true(button.disabled)
	await _resign_and_rematch(main)
	assert_true(not button.disabled, "new game resets cooldown")
	main._set_focus(true)
	assert_true(not button.is_visible_in_tree(), "focus mode hides actions")
	main._set_focus(false)
	assert_true(button.is_visible_in_tree(), "actions return after focus mode")
	main.free()

func test_match_score_follows_players_and_resets():
	var main = await _session(ManualWaits.new())
	var white = main.get_node_or_null("Layout/Side/WhiteClockRow/Score")
	var black = main.get_node_or_null("Layout/Side/BlackClockRow/Score")
	assert_true(white != null and black != null, "score boxes exist")
	if white == null or black == null:
		main.free()
		return
	assert_true(not white.visible and not black.visible, "first game hides boxes")
	main.board_view.game.resign("b")
	main._show_result()
	var score = main.board_view.get_node_or_null("GameOver/Panel/Content/Score")
	assert_true(score != null, "game-over score exists")
	if score:
		assert_eq(score.text, "You 1 – 0 Maia 1700")
	_key(main, KEY_SPACE)
	await _wait_start(main)
	assert_true(white.visible and black.visible, "rematch shows boxes")
	assert_eq(black.text, "1", "human score follows black")
	assert_eq(white.text, "0", "Maia follows white")
	main.board_view.game.agree_draw()
	main._show_result()
	score = main.board_view.get_node("GameOver/Panel/Content/Score")
	assert_eq(score.text, "You 1½ – ½ Maia 1700")
	assert_eq(black.text, "1½", "finished rematch updates human score")
	assert_eq(white.text, "½", "finished rematch updates Maia score")
	main.board_view.get_node("GameOver/Panel/Content/Close").pressed.emit()
	assert_eq(black.text, "1½", "human score remains after closing panel")
	assert_eq(white.text, "½", "Maia score remains after closing panel")
	main.board_view.get_node("GameOver/Panel/Content/Rematch").pressed.emit()
	await _wait_start(main)
	assert_eq(white.text, "1½")
	assert_eq(black.text, "½")
	main._show_setup()
	await main._start(SETTINGS.duplicate())
	assert_true(not white.visible and not black.visible, "New game resets score")
	main.board_view.game.resign("b")
	main._show_result()
	var changed = Main.rematch(main.settings)
	changed.level = "maia-1500"
	await main._start(changed)
	assert_true(not white.visible and not black.visible, "changed level resets score")
	main.free()


func test_match_score_respects_focus_mode():
	var main = await _session(ManualWaits.new())
	var white = main.white_score
	var black = main.black_score
	_key(main, KEY_F11)
	_key(main, KEY_F11)
	assert_true(not white.visible and not black.visible, "first game stays without boxes after focus")
	main.board_view.game.resign("b")
	main._show_result()
	_key(main, KEY_SPACE)
	await _wait_start(main)
	_key(main, KEY_F11)
	assert_true(not white.visible and not black.visible, "focus hides rematch boxes")
	_key(main, KEY_F11)
	assert_true(white.visible and black.visible, "leaving focus restores rematch boxes")
	main.board_view.game.agree_draw()
	main._show_result()
	_key(main, KEY_F11)
	_key(main, KEY_SPACE)
	await _wait_start(main)
	assert_true(not white.visible and not black.visible, "rematch started in focus hides boxes")
	_key(main, KEY_F11)
	assert_true(white.visible and black.visible, "leaving focus restores new rematch boxes")
	main.free()

func _push_key(viewport: Viewport, code: Key, ctrl := false, shift := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		event.ctrl_pressed = ctrl
		event.shift_pressed = shift
		viewport.push_input(event, true)


func test_escape_closes_settings_from_spinbox():
	var main = await _session(ManualWaits.new())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	_push_key(viewport, KEY_COMMA, true)
	for i in 4:
		_push_key(viewport, KEY_TAB)
	_push_key(viewport, KEY_ESCAPE)
	assert_true(not main.settings_screen.get_node("Panel").visible, "Esc closes Settings while editing a SpinBox")
	assert_true(viewport.gui_get_focus_owner() == null, "closing releases focus")
	main.free()


func test_shortcut_closes_settings_with_choice_popup_open():
	var main = await _session(ManualWaits.new())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	var panel = main.settings_screen.get_node("Panel")
	var popup = panel.get_node("Center/Box/Form").get_child(1).get_popup()
	_push_key(viewport, KEY_COMMA, true)
	_push_key(viewport, KEY_SPACE)
	await Engine.get_main_loop().process_frame
	assert_true(popup.visible, "choice popup is open")
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible and not popup.visible, "shortcut closes popup and Settings")
	assert_true(viewport.gui_get_focus_owner() == null, "closing releases focus")
	main.free()


func test_escape_closes_settings_with_choice_popup_open():
	var main = await _session(ManualWaits.new())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	var panel = main.settings_screen.get_node("Panel")
	var popup = panel.get_node("Center/Box/Form").get_child(1).get_popup()
	_push_key(viewport, KEY_COMMA, true)
	_push_key(viewport, KEY_SPACE)
	await Engine.get_main_loop().process_frame
	assert_true(popup.visible, "choice popup is open")
	_push_key(viewport, KEY_ESCAPE)
	assert_true(not panel.visible and not popup.visible, "Esc closes popup and Settings")
	assert_true(viewport.gui_get_focus_owner() == null, "closing releases focus")
	main.free()


func test_keyboard_settings_focus_and_post_game_input():
	var main = await _session(ManualWaits.new())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	var screen = main.settings_screen
	var panel = screen.get_node("Panel")
	var form = screen.get_node("Panel/Center/Box/Form")
	var first = form.get_child(1)
	var close = screen.get_node("Panel/Center/Box/Close")
	_push_key(viewport, KEY_COMMA, true)
	assert_true(panel.visible, "Ctrl+, opens Settings")
	assert_eq(viewport.gui_get_focus_owner(), first, "first row receives focus")
	_push_key(viewport, KEY_TAB, false, true)
	assert_eq(viewport.gui_get_focus_owner(), close, "Shift+Tab wraps to Close")
	_push_key(viewport, KEY_TAB)
	assert_eq(viewport.gui_get_focus_owner(), first, "Tab wraps to first row")
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible, "Ctrl+, closes Settings")
	assert_true(viewport.gui_get_focus_owner() == null, "closing releases focus")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	var game = main.board_view.game
	var game_over = main.board_view.get_node("GameOver")
	_push_key(viewport, KEY_COMMA, true)
	_push_key(viewport, KEY_TAB)
	var checkbox = form.get_child(3)
	var was_checked: bool = checkbox.button_pressed
	_push_key(viewport, KEY_SPACE)
	assert_true(checkbox.button_pressed != was_checked, "Space changes the focused checkbox")
	assert_eq(main.board_view.game, game, "Space does not rematch behind Settings")
	_push_key(viewport, KEY_ESCAPE)
	assert_true(not panel.visible and game_over.visible, "Esc closes Settings, not game over")
	assert_true(viewport.gui_get_focus_owner() == null, "Esc releases focus")
	_push_key(viewport, KEY_SPACE)
	await _wait_start(main)
	assert_true(main.board_view.game != game, "Space rematches after closing")
	main.free()


func test_settings_shortcut_availability_and_mouse_close():
	var main = await _session(ManualWaits.new())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	var screen = main.settings_screen
	var panel = screen.get_node("Panel")
	main._show_setup()
	_push_key(viewport, KEY_COMMA, true)
	assert_true(panel.visible, "shortcut opens in setup")
	_push_key(viewport, KEY_ESCAPE)
	assert_true(not panel.visible and viewport.gui_get_focus_owner() == null, "Esc closes and releases focus")
	# Game hotkeys need a game (§9.2): leave Custom game for a new one.
	await main._start(SETTINGS.duplicate())
	main._set_focus(true)
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible, "shortcut disabled in focus mode")
	main._set_focus(false)
	main.review.show()
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible, "shortcut disabled in review")
	main.review.hide()
	_push_key(viewport, KEY_COMMA, true)
	assert_true(panel.visible and viewport.gui_get_focus_owner() == screen.get_node("Panel/Center/Box/Form").get_child(1), "shortcut focuses first row")
	for down in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		mouse.position = screen.get_node("Panel/Center/Box/Close").get_global_rect().get_center()
		viewport.push_input(mouse, true)
	assert_true(not panel.visible and viewport.gui_get_focus_owner() == null, "mouse Close releases focus")
	_push_key(viewport, KEY_F)
	assert_true(main.board_view.flipped, "F still flips after closing")
	_push_key(viewport, KEY_F11)
	assert_true(main.focus, "F11 still toggles focus after closing")
	main.free()


func test_home_settings_button_focuses_first_row():
	var main = await _session(ManualWaits.new(), false)
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	var panel = main.settings_screen.get_node("Panel")
	var form = panel.get_node("Center/Box/Form")
	main.get_node("Home/Center/Form/Settings").grab_focus()
	_push_key(viewport, KEY_ENTER)
	assert_true(panel.visible, "Home's Settings button opens Settings")
	assert_eq(viewport.gui_get_focus_owner(), form.get_child(1), "first row receives focus")
	_push_key(viewport, KEY_TAB)
	assert_eq(viewport.gui_get_focus_owner(), form.get_child(3), "Tab stays inside the panel")
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible and viewport.gui_get_focus_owner() == null, "Ctrl+, closes and releases focus")
	main.free()


func test_settings_shortcut_only_where_open_is_on_top():
	var main = await _session(ManualWaits.new(), false)
	await Engine.get_main_loop().process_frame
	var viewport = main.get_viewport()
	var panel = main.settings_screen.get_node("Panel")
	_push_key(viewport, KEY_COMMA, true)
	assert_true(panel.visible, "shortcut opens on Home")
	_push_key(viewport, KEY_ESCAPE)
	main.get_node("Home")._show_profile()
	_push_key(viewport, KEY_COMMA, true)
	assert_true(panel.visible, "shortcut opens over Profile, which Settings covers")
	_push_key(viewport, KEY_ESCAPE)
	main._show_history()
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible, "shortcut disabled in history")
	main._show_home()
	main.name_dialog.popup_centered()
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible, "shortcut disabled behind the name prompt")
	main.name_dialog.hide()
	main.uci.hold_level = true
	main._start(SETTINGS.duplicate())
	assert_true(main.searching.visible, "searching screen is up")
	_push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible, "shortcut disabled while searching")
	main.uci.emit_signal("level_ready")
	await _wait_start(main)
	_push_key(viewport, KEY_COMMA, true)
	assert_true(panel.visible, "shortcut opens once the game starts")
	main.free()


func test_searching_waits_for_the_net_before_starting_the_clock():
	var main = await _session(ManualWaits.new(), false)
	main.uci.hold_level = true
	main._start(SETTINGS.duplicate())
	var screen = main.get_node_or_null("Searching")
	assert_true(screen != null and screen.visible, "searching screen is visible while the net loads")
	assert_eq(main.clock, null, "the game clock waits for the net")
	if screen == null:
		main.free()
		return
	assert_eq(screen.get_node("Center/Content/Match").text, "3+2  ·  Maia 1700")
	assert_eq(screen.get_node("Center/Content/Status").text, "Loading Maia 1700…")
	await Engine.get_main_loop().create_timer(0.6).timeout
	assert_true(screen.visible, "slow work outlasts the minimum display time")
	assert_eq(main.clock, null, "no clock after 0.5 seconds if the net is still loading")
	assert_eq(main.uci.requests.size(), 0, "no game policy before the net is ready")
	main._start(Main.rematch(SETTINGS))
	assert_eq(screen.get_node("Center/Content/Match").text, "3+2  ·  Maia 1700", "duplicate start keeps the pending game")
	main.uci.emit_signal("level_ready")
	while main._starting:
		await Engine.get_main_loop().process_frame
	assert_true(not screen.visible, "readiness closes the screen")
	assert_true(main.clock != null, "only now does the clock exist")
	main.free()


# Starts now cross a real asynchronous searching screen.
func _wait_start(main) -> void:
	while main._starting:
		await Engine.get_main_loop().process_frame

func test_searching_fast_quick_custom_and_rematch_last_half_a_second():
	var main = await _session(ManualWaits.new(), false)
	for route in ["quick", "custom", "rematch"]:
		if route == "custom":
			main._show_setup()
		elif route == "rematch":
			main.board_view.game.resign(main.human)
			main._show_result()
		var old_game = main.board_view.game
		var old_clock = main.clock
		var started_at := Time.get_ticks_msec()
		match route:
			"quick": main.get_node("Home/Center/Form/Quick/ThreeTwo").pressed.emit()
			"custom": main.setup.started.emit(SETTINGS.duplicate())
			"rematch": main.review.rematch_requested.emit()
		assert_true(main.searching.visible, route + " shows searching")
		_key(main, KEY_F11)
		assert_true(not main.focus, "game hotkeys wait for searching to close")
		assert_eq(main.searching.get_node("Center/Content/Status").text, "Preparing game\u2026")
		assert_eq(main.searching.get_node("Center/Content/Match").text,
				"3+2  \u00b7  Maia " + ("1500" if route == "quick" else "1700"))
		await Engine.get_main_loop().create_timer(0.1).timeout
		assert_true(main.searching.visible, "fast work still waits for the minimum")
		assert_true(main.board_view.game == old_game, "no new game while searching")
		assert_true(main.clock == old_clock, "no new clock while searching")
		await _wait_start(main)
		assert_true(Time.get_ticks_msec() - started_at >= 500, "minimum is 0.5 seconds")
		assert_true(not main.searching.visible)
		assert_true(main.board_view.game != old_game and main.clock != null)
	main.free()


class SearchAnalysis extends RefCounted:
	signal finished(success: bool, error: String)
	signal progress(done: int, total: int)
	var cancelling := false

	func start(_path: String, _maximum: bool) -> bool:
		return true

	func cancel() -> void:
		cancelling = true


func _queued_search_session():
	var runner := SearchAnalysis.new()
	var queue_file := "user://test_searching_queue_%d.cfg" % Time.get_ticks_usec()
	var queue = Main.AnalysisQueue.new(runner, queue_file)
	var main = await _session(ManualWaits.new(), false, queue)
	main.tree_exiting.connect(func(): DirAccess.remove_absolute(queue_file))
	DirAccess.make_dir_recursive_absolute(main.history._root)
	var path: String = main.history._root.path_join("queued.pgn")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("1. e4 *")
	file.close()
	queue.enqueue(path)
	return {"main": main, "runner": runner, "path": path}

func test_searching_pauses_analysis_before_loading_the_net():
	var fixture = await _queued_search_session()
	var main = fixture.main
	main.uci.hold_level = true
	main._start(SETTINGS.duplicate())
	assert_eq(main.searching.get_node("Center/Content/Status").text, "Pausing analysis\u2026")
	while not fixture.runner.cancelling:
		await Engine.get_main_loop().process_frame
	assert_eq(main.clock, null)
	assert_eq(main.searching.get_node("Center/Content/Status").text, "Pausing analysis\u2026")
	fixture.runner.finished.emit(false, "cancelled")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	assert_eq(main.searching.get_node("Center/Content/Status").text, "Loading Maia 1700\u2026")
	main.uci.level_ready.emit()
	await _wait_start(main)
	assert_eq(main.analysis_queue.current(), "", "queue stays paused during play")
	main._show_home()
	assert_eq(main.analysis_queue.current(), fixture.path, "queue resumes on Home")
	main.free()

func test_searching_engine_stop_during_net_or_minimum_returns_home():
	for hold in [true, false]:
		var main = await _session(ManualWaits.new(), false)
		main.uci.hold_level = hold
		main._start(SETTINGS.duplicate())
		main.uci.error = "Maia stopped during start"
		main.uci.stopped.emit()
		await _wait_start(main)
		assert_true(not main.searching.visible, "failure closes searching")
		assert_eq(main.clock, null)
		assert_eq(main.uci.requests.size(), 0)
		assert_true(main.get_node("Home").visible)
		assert_true(main.get_node("Home/Center/Form/Missing").text.contains("Maia stopped during start"))
		main.uci.level_ready.emit()
		assert_eq(main.clock, null, "late readyok cannot start a failed game")
		main.free()

func test_searching_invalid_selection_and_repertoire_close_with_error():
	for mode in ["Catalog", "My repertoire"]:
		var main = await _session(ManualWaits.new(), false)
		main.setup.book.selection_dir = main.history._root.path_join("openings")
		main.setup.repertoire.storage_dir = main.history._root.path_join("repertoires")
		var choice := SETTINGS.duplicate()
		choice.opening = mode
		choice.selection = "missing"
		choice.repertoire = "missing" if mode == "My repertoire" else ""
		await main._start(choice)
		assert_true(not main.searching.visible)
		assert_true(main.setup.visible)
		assert_true(main.setup.get_node("Center/Form/Missing").visible)
		assert_true(not main.setup.get_node("Center/Form/Missing").text.is_empty())
		assert_eq(main.clock, null)
		assert_eq(main.uci.requests.size(), 0)
		await main._start(SETTINGS.duplicate())
		assert_true(main.clock != null, "valid retry succeeds")
		main.free()

func test_searching_engine_stop_before_analysis_pause_keeps_queue_resumed():
	var fixture = await _queued_search_session()
	var main = fixture.main
	main._start(SETTINGS.duplicate())
	main.uci.error = "Maia stopped while pausing"
	main.uci.stopped.emit()
	await Engine.get_main_loop().process_frame
	# Finish any cancellation that raced with the engine failure.
	fixture.runner.finished.emit(false, "cancelled")
	await _wait_start(main)
	assert_true(not main.searching.visible)
	assert_true(main.get_node("Home").visible)
	assert_eq(main.analysis_queue.current(), fixture.path, "Home keeps analysis running after failure")
	main.free()


func test_searching_engine_stop_during_catalog_closes_without_a_game():
	var book = load("res://tests/test_book.gd").DelayedBook.new()
	var main = await _session(ManualWaits.new(), false, null, book)
	main._start(SETTINGS.duplicate())
	book.entered.wait()
	assert_true(main.searching.visible)
	assert_eq(main.searching.get_node("Center/Content/Status").text, "Preparing game\u2026")
	assert_eq(main.clock, null)
	main.uci.error = "Maia stopped during catalog loading"
	main.uci.stopped.emit()
	assert_true(not main.searching.visible, "engine failure closes searching immediately")
	assert_true(main.get_node("Home").visible)
	assert_true(main.get_node("Home/Center/Form/Missing").visible)
	book.release.post()
	await _wait_start(main)
	assert_eq(main.clock, null, "finishing the catalog cannot start a failed game")
	assert_eq(main.uci.requests.size(), 0)
	main.free()


func test_game_has_no_settings_button():
	var main = await _session(ManualWaits.new())
	assert_true(not main.settings_screen.get_node("Open").visible, "game has no Settings button")
	main.free()


func test_game_panel_identifies_players_and_actions():
	var main = await _session(ManualWaits.new())
	var side = main.get_node("Layout/Side")
	assert_eq(side.get_child(0), main.black_clock.get_parent(), "Maia is at the top")
	assert_eq(main.black_clock.get_parent().get_node("Name").text, "Maia")
	assert_eq(main.white_clock.get_parent().get_node("Name").text, "You")
	assert_eq(main.draw_button.text, "?  Offer draw")
	assert_eq(main.resign_button.text, "Resign")
	main.free()
