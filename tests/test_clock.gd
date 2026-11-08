extends "res://tests/run.gd".Test

# The two clocks (CLOCK-001, §5): a fake time source drives them, so nothing here waits.

const Clock = preload("res://core/clock.gd")
const ClockDisplay = preload("res://ui/clock.gd")
const Game = preload("res://core/game.gd")


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


# A clock on `control` whose two untimed first moves are played, so White's clock runs.
func _running(control: String, time: FakeTime):
	var clock = Clock.new(control, time.ms)
	clock.moved("w")
	clock.moved("b")
	return clock


func test_only_the_three_time_controls():
	assert_eq(Clock.CONTROLS.keys(), ["1+0", "3+2", "5+0"])


func test_sandbox_and_custom_game_offer_only_the_three_controls():
	var home = load("res://ui/home.tscn").instantiate()
	var quick: Node = home.get_node("Center/Form/Quick")
	var quick_controls := []
	for button in quick.get_children():
		if button is Button:
			quick_controls.append(button.text)
	assert_eq(quick_controls, ["1+0", "3+2", "5+0"])
	home.free()
	var setup = load("res://ui/setup.tscn").instantiate()
	Engine.get_main_loop().root.add_child(setup)
	var choice: OptionButton = setup.get_node("Center/Form/Control")
	var custom_controls := []
	for i in choice.item_count:
		custom_controls.append(choice.get_item_text(i))
	assert_eq(custom_controls, ["1+0", "3+2", "5+0"])
	setup.free()


func test_no_clock_runs_while_a_side_makes_its_first_move():
	var time := FakeTime.new()
	var clock = Clock.new("3+2", time.ms)
	time.now += 5000
	assert_eq(clock.left("w"), 180000, "White's first move is untimed")
	clock.moved("w")
	time.now += 7000
	assert_eq(clock.left("b"), 180000, "Black's first move is untimed")
	clock.moved("b")
	assert_eq([clock.left("w"), clock.left("b")], [180000, 180000], "no increment on a first move")
	time.now += 1234
	assert_eq(clock.left("w"), 180000 - 1234, "White's clock runs from Black's first move")
	assert_eq(clock.left("b"), 180000)


func test_increment_is_added_after_each_timed_move():
	var time := FakeTime.new()
	var clock = _running("3+2", time)
	time.now += 1000
	clock.moved("w")
	assert_eq(clock.left("w"), 181000)
	time.now += 500
	assert_eq(clock.left("b"), 179500, "Black's clock runs once White has moved")
	clock.moved("b")
	assert_eq(clock.left("b"), 181500)
	assert_eq(clock.left("w"), 181000, "White's clock stopped while Black thought")


func test_play_out_clock_starts_at_five_minutes_and_adds_five_seconds():
	var time := FakeTime.new()
	var clock = _running("5+5", time)
	assert_eq([clock.left("w"), clock.left("b")], [300000, 300000])
	time.now += 1000
	clock.moved("w")
	assert_eq(clock.left("w"), 304000)
	time.now += 500
	clock.moved("b")
	assert_eq(clock.left("b"), 304500)


func test_no_clock_stays_unchanged_without_warnings_or_flags():
	var time := FakeTime.new()
	var clock = Clock.new("none", time.ms)
	var initial := [clock.left("w"), clock.left("b")]
	var low := []
	var flags := []
	clock.low_time.connect(func(side): low.append(side))
	clock.flagged.connect(func(side): flags.append(side))
	clock.moved("w")
	clock.moved("b")
	time.now += 86400000
	clock.tick()
	clock.moved("w")
	clock.moved("b", true)
	clock.tick()
	clock.stop()
	assert_eq([clock.left("w"), clock.left("b")], initial)
	assert_eq(low, [])
	assert_eq(flags, [])


func test_no_clock_display_does_not_show_zero_time():
	var clock = Clock.new("none", FakeTime.new().ms)
	var display = ClockDisplay.new()
	display.clock = clock
	display._process(0.0)
	assert_true(display.text == "" or display.text == "—" or display.text == "-")
	display.free()


func test_low_time_fires_once_at_the_threshold_of_each_control():
	# 10% of the starting time or 10 s, whichever is lower.
	var thresholds := {"1+0": 6000, "3+2": 10000, "5+0": 10000}
	for control in thresholds:
		var threshold: int = thresholds[control]
		var time := FakeTime.new()
		var clock = _running(control, time)
		var low := []
		clock.low_time.connect(func(side): low.append(side))
		time.now += Clock.CONTROLS[control][0] - threshold - 1
		clock.tick()
		assert_eq(low, [], control + ": above the threshold")
		time.now += 1
		clock.tick()
		assert_eq(low, ["w"], control + ": at the threshold")
		time.now += 100
		clock.tick()
		assert_eq(low, ["w"], control + ": once only")


func test_low_time_fires_once_per_game_even_after_an_increment_lifts_the_clock():
	var time := FakeTime.new()
	var clock = _running("3+2", time)
	var low := []
	clock.low_time.connect(func(side): low.append(side))
	time.now += 171000
	clock.tick()
	clock.moved("w")
	assert_eq(clock.left("w"), 11000)
	clock.moved("b")
	time.now += 2000
	clock.tick()
	assert_eq(low, ["w"])


func test_a_clock_reaching_zero_flags_that_side_once():
	var time := FakeTime.new()
	var clock = _running("1+0", time)
	var flags := []
	clock.flagged.connect(func(side): flags.append(side))
	time.now += 59999
	clock.tick()
	assert_eq(flags, [], "1 ms left")
	time.now += 1
	clock.tick()
	assert_eq(flags, ["w"])
	assert_eq(clock.left("w"), 0)
	time.now += 500
	clock.tick()
	assert_eq(flags, ["w"], "once only")
	assert_eq(clock.left("w"), 0, "never below zero")


func test_maia_can_flag_and_the_game_ends_on_time():
	var time := FakeTime.new()
	var game = Game.new()
	var clock = Clock.new("1+0", time.ms)
	clock.flagged.connect(game.flag)
	for move in ["e2e4", "e7e5", "g1f3"]:
		var side: String = game.board.side_to_move
		game.play(move)
		clock.moved(side)
	time.now += 60000
	clock.tick()
	assert_eq([game.result, game.reason], ["1-0", "time"])


func test_a_move_made_after_the_time_ran_out_flags_instead_of_adding_the_increment():
	var time := FakeTime.new()
	var clock = _running("3+2", time)
	var flags := []
	clock.flagged.connect(func(side): flags.append(side))
	time.now += 180500
	clock.moved("w")
	assert_eq(flags, ["w"])
	assert_eq(clock.left("w"), 0)


func test_display_is_minutes_and_seconds_with_tenths_under_ten_seconds():
	assert_eq(Clock.format(300000), "5:00")
	assert_eq(Clock.format(61000), "1:01")
	assert_eq(Clock.format(59999), "0:59", "never shows more time than is left")
	assert_eq(Clock.format(10000), "0:10")
	assert_eq(Clock.format(9449), "0:09.4")
	assert_eq(Clock.format(0), "0:00.0")
