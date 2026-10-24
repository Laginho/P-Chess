extends "res://tests/run.gd".Test

# Maia's think time (BOT-005, §4.1-4.2): the pure delay function on seeded RNGs, then its wiring in
# maia_player, through a bridge that takes real time to answer and a clock on a fake time source.

const TimeModel = preload("res://bot/time_model.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")
const Clock = preload("res://core/clock.gd")
const Game = preload("res://core/game.gd")

# White to move, and Kxb2 is its only legal move.
const ONE_MOVE := "k7/8/8/8/8/8/1r6/K7 w - - 0 1"


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


# Answers after compute_ms of real time, as Lc0 would.
class SlowBridge:
	signal policy_ready(policy: Dictionary)
	var policy := {}
	var compute_ms := 0

	func request_policy(_start_fen: String, _moves: PackedStringArray) -> void:
		OS.delay_msec(compute_ms)
		policy_ready.emit(policy)


func _rng(seed_value := 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _near(actual: float, expected: float, message := "") -> void:
	assert_true(is_equal_approx(actual, expected), "expected %s, got %s%s" % [expected, actual,
			": " + message if message else ""])


# The moves Maia has sent by the time think() returns: none while it waits out its think time.
func _moves_at_once(game, policy: Dictionary, compute_ms: int, clock) -> Array:
	var bridge := SlowBridge.new()
	bridge.policy = policy
	bridge.compute_ms = compute_ms
	var maia = MaiaPlayer.new(bridge)
	maia.clock = clock
	maia.control = "3+2"
	var got := []
	maia.move_ready.connect(func(move): got.append(move))
	maia.think(game)
	return got


func test_base_formula_without_noise():
	# (clock_left / max(10, 40 - moves_played) + 0.8 x increment) x (1.6 - top_p), in seconds.
	_near(TimeModel.base(180.0, 2.0, 0, 0.6), 6.1, "(4.5 + 1.6) x 1.0")
	_near(TimeModel.base(300.0, 0.0, 20, 0.35), 18.75, "15 x 1.25")
	_near(TimeModel.base(60.0, 0.0, 30, 0.1), 9.0, "6 x 1.5")
	_near(TimeModel.base(60.0, 0.0, 35, 0.1), 9.0, "never fewer than 10 moves to go")


func test_noise_is_log_normal_with_median_1_and_sigma_0_6():
	var rng := _rng(7)
	var draws := []
	for i in 10000:
		draws.append(TimeModel.noise(rng))
	draws.sort()
	assert_true(draws[0] > 0.0, "a delay factor is positive")
	var median: float = (draws[4999] + draws[5000]) / 2.0
	assert_true(absf(median - 1.0) <= 0.05, "median %f" % median)
	var mean := 0.0
	for d in draws:
		mean += log(d)
	mean /= draws.size()
	var variance := 0.0
	for d in draws:
		variance += pow(log(d) - mean, 2)
	var sigma := sqrt(variance / draws.size())
	assert_true(absf(sigma - 0.6) <= 0.03, "log-sigma %f" % sigma)


func test_the_delay_is_the_base_times_the_noise():
	for seed_value in 20:
		var expected: float = TimeModel.base(180.0, 2.0, 12, 0.4) * TimeModel.noise(_rng(seed_value))
		_near(TimeModel.delay(180.0, 2.0, 180.0, 12, 0.4, 20, _rng(seed_value)), expected,
				"seed %d" % seed_value)


func test_one_legal_move_takes_the_floor():
	for seed_value in 20:
		assert_eq(TimeModel.delay(180.0, 2.0, 180.0, 0, 0.3, 1, _rng(seed_value)), 0.05,
				"seed %d" % seed_value)


func test_a_sure_move_in_time_trouble_is_premoved():
	# 15% of 3+2's 180 s is 27 s.
	for seed_value in 20:
		assert_eq(TimeModel.delay(26.0, 2.0, 180.0, 30, 0.91, 20, _rng(seed_value)), 0.05,
				"seed %d" % seed_value)
	var formula: float = TimeModel.base(26.0, 2.0, 30, 0.9) * TimeModel.noise(_rng(3))
	_near(TimeModel.delay(26.0, 2.0, 180.0, 30, 0.9, 20, _rng(3)), formula, "0.9 is not over 0.9")
	formula = TimeModel.base(27.5, 2.0, 30, 0.95) * TimeModel.noise(_rng(3))
	_near(TimeModel.delay(27.5, 2.0, 180.0, 30, 0.95, 20, _rng(3)), formula, "27.5 s is not under 15%")


func test_the_delay_is_clamped_to_the_floor_and_the_clock():
	for seed_value in 20:
		# base 0.0025 s: no noise lifts it off the floor.
		assert_eq(TimeModel.delay(0.1, 0.0, 60.0, 0, 0.6, 20, _rng(seed_value)), 0.05,
				"floor, seed %d" % seed_value)
		# base 240.25 s: no noise brings it under the 10 s left.
		assert_eq(TimeModel.delay(10.0, 300.0, 180.0, 0, 0.6, 20, _rng(seed_value)), 10.0,
				"clock, seed %d" % seed_value)
	# Under the floor's 0.05 s left, the clock wins: Maia never waits past its own flag.
	assert_eq(TimeModel.delay(0.03, 0.0, 60.0, 50, 0.5, 1, _rng()), 0.03)


func test_lc0_compute_time_comes_off_the_delay():
	# Delay 2 s, Lc0 took 0.5 s: 1.5 s left to wait, so the clock is charged 2 s.
	_near(TimeModel.wait(2.0, 0.5), 1.5)
	# Delay 0.05 s, Lc0 took 0.2 s: Maia moves once Lc0 answers, charged 0.2 s.
	assert_eq(TimeModel.wait(0.05, 0.2), 0.0)


func test_with_time_to_think_maia_does_not_answer_at_once():
	var clock = Clock.new("3+2", FakeTime.new().ms)
	assert_eq(_moves_at_once(Game.new(), {"e2e4": 0.5, "d2d4": 0.5}, 0, clock), [])


func test_maia_moves_once_lc0_answers_when_lc0_took_longer_than_the_delay():
	# One legal move: the delay is the 0.05 s floor, and Lc0 takes 0.06 s.
	var clock = Clock.new("3+2", FakeTime.new().ms)
	assert_eq(_moves_at_once(Game.new(ONE_MOVE), {"a1b2": 1.0}, 60, clock), ["a1b2"])


func test_a_premove_reads_maia_s_own_clock_and_the_starting_time():
	var time := FakeTime.new()
	var clock = Clock.new("3+2", time.ms)
	for side in ["w", "b", "w"]:
		clock.moved(side)
	time.now += 170000  # Black's clock runs: 10 s of 180 left, under 15%. White's still reads 182 s.
	var game = Game.new()
	game.play("e2e4")
	# top_p 0.99 is over 0.9, and c7c5 falls under the cut, so the move is e7e5.
	assert_eq(_moves_at_once(game, {"e7e5": 0.99, "c7c5": 0.01}, 60, clock), ["e7e5"])
