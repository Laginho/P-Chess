extends "res://tests/run.gd".Test

# The game loop around a game (UI-004, §9.1, §9.2): the rematch settings and the double-Esc resign,
# on a fake time source. Scene tests use the real Main with a fake engine and manually completed
# timer signals, so neither Lc0 nor elapsed wall-clock time decides their outcome.

const Main = preload("res://ui/main.gd")
const BoardView = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")
const MainScene = preload("res://ui/main.tscn")


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


# The board scene on an 800 px board, playing `fen`. The runner calls tests before the root enters
# the tree, so the scene never gets _ready (nor does Main): the picker is wired by hand and nothing
# slides, since a tween needs the tree.
func _board(fen: String):
	var board = BoardView.instantiate()
	board._picker = board.get_node("PromotionPicker")
	board.set_piece_theme("cburnett")
	board.slide_seconds = 0
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
	assert_eq(main.uci.requests, [[Game.START, PackedStringArray(["e2e4"])],
			[Game.START, PackedStringArray()]], "the old and current policies are queued FIFO")
	main.uci.policy_ready.emit({"e7e5": 1.0})
	assert_eq(waits.pending.size(), 0, "no think time scheduled for an obsolete policy")
	assert_eq(main.maia.latencies_ms, [], "obsolete policies are not processed as current samples")
	main.uci.policy_ready.emit({"d2d4": 1.0})
	assert_eq(waits.pending.size(), 1, "the old entry consumed only its own policy")
	_finish(waits, 0)
	assert_eq(main.board_view.game.moves, PackedStringArray(["d2d4"]), "the current policy still plays")
	main.free()


func test_two_rematches_drop_a_stale_white_move_legal_in_the_current_game():
	var waits := ManualWaits.new()
	var main = _session(waits)
	assert_true(main.board_view.play("a2a3"))
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
	main.uci.policy_ready.emit({"e7e5": 1.0})
	_finish(waits, 2)
	_finish(waits, 0)
	assert_eq(main.board_view.game.moves, PackedStringArray(["g1f3", "e7e5"]), "only the current reply plays")
	main.free()
