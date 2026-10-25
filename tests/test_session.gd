extends "res://tests/run.gd".Test

# The game loop around a game (UI-004, §9.1, §9.2): the rematch settings and the double-Esc resign,
# on a fake time source, so nothing here opens a window or waits.

const Main = preload("res://ui/main.gd")
const BoardView = preload("res://ui/board_view.tscn")
const Game = preload("res://core/game.gd")


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


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
