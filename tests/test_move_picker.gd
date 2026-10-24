extends "res://tests/run.gd".Test

# BOT-003: spec §3.3. Policy keys are opaque move ids (UCI in the game).

const MovePicker = preload("res://bot/move_picker.gd")


func test_weights_are_renormalised_before_the_cut():
	# Weighted: a 10, b .47, c .03 (total 10.5), so c falls to .29% and is cut.
	var dist: Dictionary = MovePicker.distribution({"a": 0.5, "b": 0.47, "c": 0.03}, {"a": 20.0})
	_assert_dist(dist, {"a": 1000.0 / 1047.0, "b": 47.0 / 1047.0})


func test_top_move_is_taken_after_weighting():
	# Weighted: a .5, b .49, c 1.0, so c is the top move and the only one over 30%.
	var dist: Dictionary = MovePicker.distribution({"a": 0.5, "b": 0.49, "c": 0.01}, {"c": 100.0}, 0.3)
	_assert_dist(dist, {"c": 1.0})


func test_cut_comes_before_temperature():
	# At T = 4 a 1.5% move would rise over 2% if the temperature came first.
	var dist: Dictionary = MovePicker.distribution({"a": 0.6, "b": 0.385, "c": 0.015}, {}, 0.02, 4.0)
	assert_true(not dist.has("c"), str(dist))
	assert_eq(dist.size(), 2, str(dist))


func test_temperature_is_p_to_the_one_over_t_then_renormalised():
	var policy := {"a": 0.6, "b": 0.4}
	_assert_dist(MovePicker.distribution(policy, {}, 0.02, 2.0), {"a": 3.0 - sqrt(6.0), "b": sqrt(6.0) - 2.0})
	_assert_dist(MovePicker.distribution(policy, {}, 0.02, 0.5), {"a": 0.36 / 0.52, "b": 0.16 / 0.52})


func test_small_temperature_does_not_underflow():
	# At T = 0.001 every p^1000 underflows to 0, yet a outweighs b by (0.4 / 0.35)^1000.
	var policy := {"a": 0.4, "b": 0.35, "c": 0.25}
	_assert_dist(MovePicker.distribution(policy, {}, 0.02, 0.001), {"a": 1.0, "b": 0.0, "c": 0.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var moves := []
	for i in 100:
		moves.append(MovePicker.pick(policy, rng, {}, 0.02, 0.001))
	assert_eq(moves.count("a"), 100, "drew %s" % [moves.slice(0, 5)])


func test_zero_temperature_keeps_only_the_top_move():
	# The limit of p^(1/T) as T falls to 0.
	_assert_dist(MovePicker.distribution({"a": 0.4, "b": 0.35, "c": 0.25}, {}, 0.02, 0.0), {"a": 1.0, "b": 0.0, "c": 0.0})


func test_weighted_book_move_survives_the_cut():
	var policy := {"a": 0.6, "b": 0.395, "c": 0.005}
	var dist: Dictionary = MovePicker.distribution(policy, {"c": 20.0}, 0.02)
	_assert_dist(dist, {"a": 120.0 / 219.0, "b": 79.0 / 219.0, "c": 20.0 / 219.0})
	assert_true(not MovePicker.distribution(policy, {}, 0.02).has("c"), "unweighted 0.5% move is cut")


func test_only_the_top_move_is_left_when_every_move_is_below_tau():
	_assert_dist(MovePicker.distribution({"a": 0.4, "b": 0.35, "c": 0.25}, {}, 0.5), {"a": 1.0})
	# 60 moves, all under 2%: the 1.95% one is the top.
	var policy := {"top": 0.0195}
	for i in 59:
		policy["m%d" % i] = (1.0 - 0.0195) / 59.0
	_assert_dist(MovePicker.distribution(policy), {"top": 1.0})


func test_temperature_one_leaves_the_cut_distribution_unchanged():
	var policy := {"a": 0.5, "b": 0.3, "c": 0.15, "d": 0.04, "e": 0.01}
	var dist: Dictionary = MovePicker.distribution(policy, {}, 0.02, 1.0)
	_assert_dist(dist, {"a": 50.0 / 99.0, "b": 30.0 / 99.0, "c": 15.0 / 99.0, "d": 4.0 / 99.0})


func test_seeded_draws_match_the_final_distribution():
	var policy := {"a": 0.5, "b": 0.3, "c": 0.15, "d": 0.04, "e": 0.01}
	for t in [1.0, 2.0]:
		var dist: Dictionary = MovePicker.distribution(policy, {}, 0.02, t)
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		var counts := {}
		for i in 10000:
			var move: String = MovePicker.pick(policy, rng, {}, 0.02, t)
			counts[move] = counts.get(move, 0) + 1
		for move in counts:
			assert_true(dist.has(move), "T=%s drew cut move %s" % [t, move])
		for move in dist:
			var freq: float = counts.get(move, 0) / 10000.0
			assert_true(absf(freq - dist[move]) <= 0.02, "T=%s %s: drawn %.4f, expected %.4f" % [t, move, freq, dist[move]])


func test_defaults_are_two_percent_and_t_one():
	assert_eq(MovePicker.DEFAULT_TAU, 0.02)
	assert_eq(MovePicker.DEFAULT_TEMPERATURE, 1.0)
	# 1.9% is cut and the rest keep their ratio (T = 1); 2.1% survives.
	_assert_dist(MovePicker.distribution({"a": 0.6, "b": 0.381, "c": 0.019}), {"a": 600.0 / 981.0, "b": 381.0 / 981.0})
	_assert_dist(MovePicker.distribution({"a": 0.6, "b": 0.379, "c": 0.021}), {"a": 0.6, "b": 0.379, "c": 0.021})


func test_missing_weights_count_as_one():
	var dist: Dictionary = MovePicker.distribution({"a": 0.5, "b": 0.25, "c": 0.25}, {"b": 3.0})
	_assert_dist(dist, {"a": 1.0 / 3.0, "b": 0.5, "c": 1.0 / 6.0})


func test_same_seed_gives_the_same_moves_whatever_the_global_rng():
	var policy := {"a": 0.3, "b": 0.25, "c": 0.2, "d": 0.15, "e": 0.1}
	seed(1)
	var first := _draws(policy, 7)
	seed(2)
	var second := _draws(policy, 7)
	assert_eq(second, first)
	assert_true(_draws(policy, 8) != first, "another seed gives other moves")


func test_degenerate_policies():
	var rng := RandomNumberGenerator.new()
	assert_eq(MovePicker.pick({}, rng), "")
	assert_eq(MovePicker.distribution({}), {})
	# All zero (no usable policy): still one of its moves, not NaN.
	assert_true(MovePicker.pick({"a": 0.0, "b": 0.0}, rng) in ["a", "b"])
	# No usable mass (all-zero policy or all-zero weights): the first move gets all of it.
	_assert_dist(MovePicker.distribution({"a": 0.0, "b": 0.0}), {"a": 1.0})
	_assert_dist(MovePicker.distribution({"a": 0.6, "b": 0.4}, {"a": 0.0, "b": 0.0}), {"a": 1.0})


# Spec §3.4, on a 1+0 clock (60,000 ms, so 10% is 6,000 ms).

func test_panic_leaves_t_and_tau_unchanged_down_to_ten_percent():
	_assert_panic(MovePicker.panic(1.0, 0.02, "high", 30000, 60000), 1.0, 0.02)
	_assert_panic(MovePicker.panic(1.0, 0.02, "high", 6000, 60000), 1.0, 0.02)
	_assert_panic(MovePicker.panic(1.4, 0.03, "low", 6000, 60000), 1.4, 0.03)


func test_panic_reaches_the_intensity_targets_at_zero():
	_assert_panic(MovePicker.panic(1.0, 0.02, "low", 0, 60000), 1.3, 0.01)
	_assert_panic(MovePicker.panic(1.0, 0.02, "medium", 0, 60000), 1.7, 0.005)
	_assert_panic(MovePicker.panic(1.0, 0.02, "high", 0, 60000), 2.2, 0.002)
	# A clock overrun below 0 stays at the targets.
	_assert_panic(MovePicker.panic(1.0, 0.02, "high", -500, 60000), 2.2, 0.002)


func test_panic_moves_linearly_in_between():
	_assert_panic(MovePicker.panic(1.0, 0.02, "medium", 3000, 60000), 1.35, 0.0125)
	_assert_panic(MovePicker.panic(1.0, 0.02, "high", 1500, 60000), 1.9, 0.0065)


func test_panic_off_leaves_t_and_tau_unchanged():
	_assert_panic(MovePicker.panic(1.0, 0.02, "off", 0, 60000), 1.0, 0.02)
	_assert_panic(MovePicker.panic(1.4, 0.03, "off", 0, 60000), 1.4, 0.03)


func _assert_panic(actual: Dictionary, temperature: float, tau: float) -> void:
	assert_true(is_equal_approx(actual.get("temperature", NAN), temperature) and is_equal_approx(actual.get("tau", NAN), tau),
			"got %s, expected T %s and tau %s" % [actual, temperature, tau])


func _draws(policy: Dictionary, rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var moves := []
	for i in 50:
		moves.append(MovePicker.pick(policy, rng))
	return moves


func _assert_dist(actual: Dictionary, expected: Dictionary) -> void:
	assert_eq(actual.keys().size(), expected.size(), "moves %s, expected %s" % [actual, expected])
	for move in expected:
		assert_true(actual.has(move) and absf(actual[move] - expected[move]) < 1e-6,
				"%s: got %s, expected %s" % [move, actual.get(move), expected[move]])
