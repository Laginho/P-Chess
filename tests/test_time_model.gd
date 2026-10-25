extends "res://tests/run.gd".Test

# Maia's think time (BOT-005, BOT-006, §4.1-4.2): the pure delay function on seeded RNGs, the
# calibrated table on a fixture, then their wiring in maia_player, through a bridge that takes real
# time to answer and a clock on a fake time source.

const TimeModel = preload("res://bot/time_model.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")
const Clock = preload("res://core/clock.gd")
const Game = preload("res://core/game.gd")

# White to move, and Kxb2 is its only legal move.
const ONE_MOVE := "k7/8/8/8/8/8/1r6/K7 w - - 0 1"
# Clock bins [0, 0.15), [0.15, 0.5), [0.5, ...); top-p bins [0, 0.3), [0.3, 0.6), [0.6, 1].
const SMALL := "res://tests/fixtures/time_model_small.json"
const MALFORMED := "user://time_model_malformed.json"
const OVERFLOW := "1e999"


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


# Answers after compute_ms without blocking the frame, as the real bridge does: a blocked frame
# would count toward Maia's timer and end its wait early.
class LateBridge:
	signal policy_ready(policy: Dictionary)
	var policy := {}
	var compute_ms := 0

	func request_policy(_start_fen: String, _moves: PackedStringArray) -> void:
		await Engine.get_main_loop().create_timer(compute_ms / 1000.0).timeout
		policy_ready.emit(policy)


class Warnings extends Logger:
	var seen: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			seen.append(rationale if rationale else code)


func _rng(seed_value := 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _near(actual: float, expected: float, message := "") -> void:
	assert_true(is_equal_approx(actual, expected), "expected %s, got %s%s" % [expected, actual,
			": " + message if message else ""])


# The moves Maia has sent by the time think() returns: none while it waits out its think time.
func _moves_at_once(game, policy: Dictionary, compute_ms: int, clock, table := {}, level := "") -> Array:
	var bridge := SlowBridge.new()
	bridge.policy = policy
	bridge.compute_ms = compute_ms
	var maia = MaiaPlayer.new(bridge)
	maia.clock = clock
	maia.control = "3+2"
	maia.level = level
	maia.time_table = table
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


# A sure 0.3 s delay against Lc0's 0.1 s, on a real-time clock: Maia's move after the full wait.
const DELAY_MS := 300
const COMPUTE_MS := 100
# Timers follow Godot's 60 Hz frame timing, so one can end up to a tick (17 ms) early or late.
const FRAME_MS := 20


# Follows Maia's move through its wait and a guard past it, and charges White's clock on arrival, as
# the game does. Returns the moves, their times since think(), and what White's clock was charged.
func _delayed_move() -> Dictionary:
	var table := {"clock_bins": [0.0, 2.0], "top_p_bins": [0.0, 1.0],
			"buckets": {"3+2/maia-1500/0/0": {"median": DELAY_MS / 1000.0, "log_sigma": 0.0}}}
	# SceneTree timers count frame time, and earlier tests ran inside one long frame: Godot catches up
	# on it in frames that take no real time. Let it, so Lc0's and Maia's timers run in real time.
	while true:
		var settle := Time.get_ticks_msec()
		await Engine.get_main_loop().create_timer(0.05).timeout
		if Time.get_ticks_msec() - settle >= 50 - FRAME_MS:
			break
	var bridge := LateBridge.new()
	bridge.policy = {"e2e4": 0.5, "d2d4": 0.5}
	bridge.compute_ms = COMPUTE_MS
	# Held here until the guard ends: Maia must outlive its own wait.
	var maia = MaiaPlayer.new(bridge)
	var clock = Clock.new("3+2", Time.get_ticks_msec)
	maia.clock = clock
	maia.control = "3+2"
	maia.level = "maia-1500"
	maia.time_table = table
	clock.moved("w")
	clock.moved("b")  # Both first moves are untimed: White's clock runs from here, at 180 s.
	var asked := Time.get_ticks_msec()
	var moves := []
	var arrivals := []
	maia.move_ready.connect(func(move):
		moves.append(move)
		arrivals.append(Time.get_ticks_msec() - asked)
		clock.moved("w"))
	maia.think(Game.new())
	await Engine.get_main_loop().create_timer(DELAY_MS * 3 / 1000.0).timeout
	return {"moves": moves, "arrivals": arrivals,
			"charged": 180000 + clock.increment - clock.left("w")}


func test_a_delay_longer_than_lc0_s_compute_brings_one_move_after_the_wait():
	var run := await _delayed_move()
	assert_eq(run.moves.size(), 1, "exactly one move: %s" % [run.moves])
	assert_true(run.arrivals.size() == 1 and run.arrivals[0] >= DELAY_MS - FRAME_MS,
			"arrived after %s ms, the delay is %d" % [run.arrivals, DELAY_MS])


func test_maia_s_clock_is_charged_the_delay_when_it_outlasts_lc0():
	var run := await _delayed_move()
	# max(0.3 s, 0.1 s), give or take the frames the two timers resolve on.
	assert_true(absi(run.charged - DELAY_MS) <= 2 * FRAME_MS,
			"charged %d ms, max(delay, compute) is %d" % [run.charged, DELAY_MS])


func _median(table: Dictionary, control: String, level: String, clock_fraction: float, top_p: float):
	return TimeModel.bucket(table, control, level, clock_fraction, top_p).get("median")


func test_the_table_buckets_by_control_level_clock_and_top_p():
	var table := TimeModel.load_table(SMALL)
	assert_eq(_median(table, "3+2", "maia-1500", 0.0, 0.0), 1.0, "the first edge opens bin 0")
	assert_eq(_median(table, "3+2", "maia-1500", 0.1499, 0.2999), 1.0, "under both edges")
	assert_eq(_median(table, "3+2", "maia-1500", 0.15, 0.0), 2.0, "an edge opens the bin above it")
	assert_eq(_median(table, "3+2", "maia-1500", 0.4999, 0.3), 3.0)
	assert_eq(_median(table, "3+2", "maia-1500", 0.5, 0.5999), 0.001)
	assert_eq(_median(table, "3+2", "maia-1500", 0.5, 0.6), 4.0)
	assert_eq(_median(table, "3+2", "maia-1500", 1.0, 1.0), 4.0, "the last edge is in the last bin")
	assert_eq(_median(table, "3+2", "maia-1500", 1.3, 0.9), 4.0, "increments lift the clock past its start")
	assert_eq(_median(table, "1+0", "maia-1100", 0.05, 0.95), 0.5, "control and level are part of the key")
	assert_eq(TimeModel.bucket(table, "3+2", "maia-1500", 1.0, 0.95).get("log_sigma"), 0.5)


func test_a_missing_bucket_is_empty():
	var table := TimeModel.load_table(SMALL)
	assert_eq(TimeModel.bucket(table, "3+2", "maia-1500", 0.1, 0.4), {}, "bin (0, 1) is not in the file")
	assert_eq(TimeModel.bucket(table, "5+0", "maia-1500", 0.9, 0.9), {}, "no 5+0 bucket")
	assert_eq(TimeModel.bucket(table, "1+0", "maia-1500", 0.05, 0.95), {}, "1+0 only for maia-1100")
	assert_eq(TimeModel.bucket(table, "3+2", "", 0.9, 0.9), {}, "no level, no bucket")
	assert_eq(TimeModel.bucket({}, "3+2", "maia-1500", 0.9, 0.9), {}, "no table, no bucket")


func test_without_a_bucket_the_delay_is_the_formula():
	var table := TimeModel.load_table("res://tests/fixtures/no_such_table.json")
	assert_eq(table, {}, "a missing file is an empty table")
	for seed_value in 20:
		var formula: float = TimeModel.base(180.0, 2.0, 12, 0.4) * TimeModel.noise(_rng(seed_value))
		_near(TimeModel.delay(180.0, 2.0, 180.0, 12, 0.4, 20, _rng(seed_value),
				TimeModel.bucket(table, "3+2", "maia-1500", 1.0, 0.4)), formula, "seed %d" % seed_value)


func test_a_bucket_s_delay_is_log_normal_around_its_median():
	var bucket := TimeModel.bucket(TimeModel.load_table(SMALL), "3+2", "maia-1500", 1.0, 0.8)
	var rng := _rng(11)
	var draws := []
	for i in 10000:
		draws.append(TimeModel.delay(180.0, 2.0, 180.0, 12, 0.8, 20, rng, bucket))
	draws.sort()
	var median: float = (draws[4999] + draws[5000]) / 2.0
	assert_true(absf(median - 4.0) <= 0.2, "median %f, the bucket's is 4 s" % median)
	var mean := 0.0
	for d in draws:
		mean += log(d)
	mean /= draws.size()
	var variance := 0.0
	for d in draws:
		variance += pow(log(d) - mean, 2)
	var sigma := sqrt(variance / draws.size())
	assert_true(absf(sigma - 0.5) <= 0.03, "log-sigma %f, the bucket's is 0.5" % sigma)


func test_a_bucket_s_delay_keeps_the_overrides_and_the_clamps():
	var sure := {"median": 4.0, "log_sigma": 0.0}
	assert_eq(TimeModel.delay(180.0, 2.0, 180.0, 12, 0.5, 20, _rng(), sure), 4.0)
	assert_eq(TimeModel.delay(180.0, 2.0, 180.0, 12, 0.5, 1, _rng(), sure), 0.05, "one legal move")
	assert_eq(TimeModel.delay(26.0, 2.0, 180.0, 30, 0.91, 20, _rng(), sure), 0.05, "premove")
	assert_eq(TimeModel.delay(3.0, 2.0, 180.0, 30, 0.5, 20, _rng(), sure), 3.0, "the clock left")
	assert_eq(TimeModel.delay(180.0, 2.0, 180.0, 12, 0.5, 20, _rng(), {"median": 0.001, "log_sigma": 0.0}),
			0.05, "the floor")


func test_a_malformed_table_warns_and_is_empty():
	var good := {"clock_bins": [0.0, 0.5, 1.0], "top_p_bins": [0.0, 1.0], "buckets": [
		{"control": "3+2", "level": "maia-1500", "clock_bin": 1, "top_p_bin": 0, "median": 2.0, "log_sigma": 0.4}]}
	_write(JSON.stringify(good))
	assert_eq(_median(TimeModel.load_table(MALFORMED), "3+2", "maia-1500", 0.7, 0.5), 2.0,
			"the well-formed base loads")
	var cases := {
		"not JSON": "{\"clock_bins\": [0.0,",
		"not an object": "[]",
		"no buckets": _without(good, "buckets"),
		"no clock bins": _without(good, "clock_bins"),
		"one edge": _with(good, "clock_bins", [0.0]),
		"edges not ascending": _with(good, "top_p_bins", [0.0, 0.6, 0.3]),
		"an edge not a number": _with(good, "clock_bins", [0.0, "half", 1.0]),
		"buckets not a list": _with(good, "buckets", {}),
		"a bucket not an object": _with(good, "buckets", [3]),
		"no level": _bucket_with(good, "level", null),
		"median not a number": _bucket_with(good, "median", "2 s"),
		"median zero": _bucket_with(good, "median", 0.0),
		"negative log-sigma": _bucket_with(good, "log_sigma", -0.1),
		"clock bin past the last": _bucket_with(good, "clock_bin", 2),
		"negative top-p bin": _bucket_with(good, "top_p_bin", -1),
		"fractional bin": _bucket_with(good, "clock_bin", 0.5),
		"an overflowing median": _overflowing(_bucket_with(good, "median", OVERFLOW)),
		"an overflowing log-sigma": _overflowing(_bucket_with(good, "log_sigma", OVERFLOW)),
		"an overflowing last edge": _overflowing(_with(good, "clock_bins", [0.0, 0.5, OVERFLOW])),
		"an overflowing first edge": _overflowing(_with(good, "top_p_bins", ["-" + OVERFLOW, 1.0])),
	}
	for name in cases:
		_write(cases[name])
		var warnings := Warnings.new()
		OS.add_logger(warnings)
		var table := TimeModel.load_table(MALFORMED)
		OS.remove_logger(warnings)
		assert_eq(table, {}, name)
		# The parser warns of its own on 1e999 ("Exponent too high"); count the loader's.
		var loader_warnings := warnings.seen.filter(func(w): return MALFORMED in w)
		assert_true(loader_warnings.size() == 1, "%s: one warning, got %s" % [name, warnings.seen])
	DirAccess.remove_absolute(MALFORMED)


func _write(text: String) -> void:
	var f := FileAccess.open(MALFORMED, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _without(table: Dictionary, key: String) -> String:
	var copy := table.duplicate(true)
	copy.erase(key)
	return JSON.stringify(copy)


func _with(table: Dictionary, key: String, value) -> String:
	var copy := table.duplicate(true)
	copy[key] = value
	return JSON.stringify(copy)


# JSON.stringify cannot write a number past a float, so the cases quote it and this unquotes it:
# Godot's parser reads 1e999 as inf.
func _overflowing(text: String) -> String:
	return text.replace("\"-%s\"" % OVERFLOW, "-" + OVERFLOW).replace("\"%s\"" % OVERFLOW, OVERFLOW)


# null erases the key.
func _bucket_with(table: Dictionary, key: String, value) -> String:
	var copy := table.duplicate(true)
	if value == null:
		copy.buckets[0].erase(key)
	else:
		copy.buckets[0][key] = value
	return JSON.stringify(copy)


func test_in_a_game_maia_s_delay_comes_from_its_bucket():
	# 3+2 at the start: clock fraction 1, top_p 0.5, so maia-1500's bucket is the 0.001 s one and the
	# delay is the 0.05 s floor: Maia moves once Lc0 answers. The formula would wait about 6 s.
	var table := TimeModel.load_table(SMALL)
	var policy := {"e2e4": 0.5, "d2d4": 0.5}
	var clock = Clock.new("3+2", FakeTime.new().ms)
	assert_eq(_moves_at_once(Game.new(), policy, 60, clock, table, "maia-1500").size(), 1, "from the bucket")
	clock = Clock.new("3+2", FakeTime.new().ms)
	assert_eq(_moves_at_once(Game.new(), policy, 60, clock, table, "maia-1100"), [],
			"maia-1100 has no 3+2 bucket: the formula")
