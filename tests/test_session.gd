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

	func start(_dirs := PackedStringArray()) -> bool:
		return true

	func set_level(_net_path: String) -> void:
		pass

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


func _session(waits):
	var main = MainScene.instantiate()
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	var folder := "user://test_session_history_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.tree_exiting.connect(func(): HistoryStorage.clean(folder))
	main.uci.free()
	main.uci = HeldBridge.new()
	main.maia = Main.MaiaPlayer.new(main.uci, waits.start)
	# Ignore the person's preferences without saving or changing them.
	main.preferences = Main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__ui004_silent__")
	main._start(SETTINGS.duplicate())
	return main


func _key(main, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	main._unhandled_key_input(event)


func test_game_over_panel_actions():
	for action in ["Review", "Rematch", "NewGame", "Close", "Escape"]:
		var main = _session(ManualWaits.new())
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
			match action:
				"Review":
					assert_true(main.review.visible, "Review opens the review")
				"Rematch":
					assert_eq(main.human, "b", "Rematch swaps colours")
				"NewGame":
					assert_true(main.setup.visible, "New game opens setup")
				_:
					assert_true(not panel.visible, "the final board remains visible")
					var review_button = main.get_node_or_null("Layout/Side/ReviewButton")
					assert_true(review_button != null and review_button.visible, "side Review is available")
					if review_button:
						review_button.pressed.emit()
						assert_true(main.review.visible, "side Review opens review")
		main.free()


func _resign_and_rematch(main) -> void:
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	_key(main, KEY_SPACE)


func _finish(waits, index: int) -> void:
	assert_true(index < waits.pending.size(), "think time was scheduled")
	if index < waits.pending.size():
		waits.pending[index].timeout.emit()


func test_a_new_reply_plays_before_an_old_games_wait_finishes():
	var waits := ManualWaits.new()
	var main = _session(waits)
	assert_true(main.board_view.play("e2e4"))
	main.uci.policy_ready.emit({"e2e4": 1.0})
	main.uci.policy_ready.emit({"e7e5": 1.0})
	_resign_and_rematch(main)
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
	var main = _session(waits)
	assert_true(main.board_view.play("e2e4"))
	_resign_and_rematch(main)
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
	assert_eq(main.human, "b", "Space started the rematch")


func test_a_main_rematch_after_a_flag_closes_the_open_promotion_picker():
	var waits := ManualWaits.new()
	var main = _session(waits)
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
	_flag_and_rematch(main)
	assert_true(not picker.visible, "no picker over the new game")
	assert_eq(main.board_view._promoting, "", "no promotion pending")
	await Engine.get_main_loop().process_frame
	assert_eq(picker.get_child_count(), 0, "the picker's buttons are gone")
	main.free()


func test_a_main_rematch_after_a_flag_drops_the_held_piece():
	var waits := ManualWaits.new()
	var main = _session(waits)
	await _laid_out(main)
	_mouse_on(main, true, "e2")
	assert_eq(main.board_view._drag_from, "e2", "e2 is held")
	_flag_and_rematch(main)
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
	var main = _session(waits)
	await _laid_out(main)
	_mouse_on(main, true, "e2")
	_mouse_on(main, false, "e5")
	assert_true(main.board_view._snapping, "e2 is snapping back")
	_flag_and_rematch(main)
	main.uci.policy_ready.emit({"e2e4": 1.0})
	_finish(waits, 0)
	_mouse_on(main, true, "e7")
	assert_eq(main.board_view._drag_from, "e7", "e7 is held in the new game")
	await Engine.get_main_loop().create_timer(main.board_view.SNAP_BACK_SECONDS * 3).timeout
	assert_eq(main.board_view._drag_from, "e7", "the old snap-back's end does not drop e7")
	main.free()


func test_two_rematches_drop_a_stale_white_move_legal_in_the_current_game():
	var waits := ManualWaits.new()
	var main = _session(waits)
	assert_true(main.board_view.play("a2a3"))
	main.uci.policy_ready.emit({"a2a3": 1.0})
	main.uci.policy_ready.emit({"a7a6": 1.0})
	_resign_and_rematch(main)
	main.uci.policy_ready.emit({"d2d4": 1.0})
	_resign_and_rematch(main)
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
