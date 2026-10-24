extends "res://tests/run.gd".Test

# The game loop around a game (UI-004, §9.1, §9.2): the rematch settings and the double-Esc resign,
# on a fake time source, so nothing here opens a window or waits.

const Main = preload("res://ui/main.gd")


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
