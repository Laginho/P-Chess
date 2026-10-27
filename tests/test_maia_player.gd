extends "res://tests/run.gd".Test

# Maia's side of the game (BOT-004): a fake bridge hands it a fixed policy, a seeded RNG makes the
# sample repeatable. The latency check at the end runs only where engine/ holds Lc0 and the nets.

const Game = preload("res://core/game.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")
const UCI = preload("res://engine/uci.gd")
const Clock = preload("res://core/clock.gd")


# Answers every request at once with the same policy, as uci.gd would after bestmove.
class FakeBridge:
	signal policy_ready(policy: Dictionary)
	var policy := {}
	var requests := []
	var policies := []
	var immediate := true

	func request_policy(start_fen: String, moves: PackedStringArray) -> void:
		requests.append([start_fen, moves])
		if immediate:
			policy_ready.emit(policies.pop_front() if policies else policy)


class FakeTime:
	var now := 0

	func ms() -> int:
		return now


class HeldWaits:
	signal timeout
	var seconds := []

	func start(wait: float) -> Signal:
		seconds.append(wait)
		return timeout


# The move Maia answers with on `game`, given `policy` and the RNG seed.
func _move(policy: Dictionary, seed_value: int, game = Game.new()) -> String:
	var bridge := FakeBridge.new()
	bridge.policy = policy
	var maia = MaiaPlayer.new(bridge)
	maia.rng.seed = seed_value
	var got := []
	maia.move_ready.connect(func(move): got.append(move))
	maia.think(game)
	assert_eq(got.size(), 1, "one move per think")
	return got[0] if got else ""


func test_maia_asks_for_the_game_so_far_and_answers_from_the_policy():
	var game = Game.new()
	game.play("e2e4")
	var bridge := FakeBridge.new()
	bridge.policy = {"e7e5": 0.6, "c7c5": 0.4}
	var maia = MaiaPlayer.new(bridge)
	var got := []
	maia.move_ready.connect(func(move): got.append(move))
	maia.think(game)
	assert_eq(bridge.requests, [[Game.START, PackedStringArray()], [Game.START, PackedStringArray(["e2e4"])]],
			"predict the human before asking for Maia's move")
	assert_eq(got.size(), 1, "one move")
	assert_true(got and got[0] in ["e7e5", "c7c5"], str(got))
	assert_eq(maia.latencies_ms.size(), 1, "the prediction is not a move latency sample")


func test_only_the_top_predicted_human_move_allows_a_premove():
	for human_move in ["e2e4", "d2d4"]:
		for prediction in [{"d2d4": 0.1, "e2e4": 0.9}, {}]:
			var time := FakeTime.new()
			var clock = Clock.new("1+0", time.ms)
			for side in ["w", "b", "w"]:
				clock.moved(side)
			time.now = 55000
			var game = Game.new()
			assert_true(game.play(human_move))
			var bridge := FakeBridge.new()
			bridge.policies = [prediction, {"e7e5": 0.99, "c7c5": 0.01}]
			var waits := HeldWaits.new()
			var maia = MaiaPlayer.new(bridge, waits.start)
			maia.clock = clock
			maia.control = "1+0"
			maia.level = "maia-1500"
			maia.time_table = {"clock_bins": [0.0, 1.0], "top_p_bins": [0.0, 1.0],
					"buckets": {"1+0/maia-1500/0/0": {"median": 0.001, "log_sigma": 0.0}}}
			var got := []
			maia.move_ready.connect(func(move): got.append(move))
			maia.think(game)
			assert_eq(got, [], "both overrides still wait for the hand")
			assert_eq(waits.seconds.size(), 1, "one wait per think")
			if waits.seconds.size() == 1:
				if human_move == "e2e4" and not prediction.is_empty():
					assert_true(waits.seconds[0] > 0.0 and waits.seconds[0] <= 0.05, "expected premove")
				else:
					assert_true(waits.seconds[0] >= 0.38, "unexpected/unknown move requires reaction")
				waits.timeout.emit()
			assert_eq(got, ["e7e5"], "only the reply policy selects Maia's move")
			assert_eq(maia.latencies_ms.size(), 1)


func test_stale_prediction_and_move_replies_keep_their_fifo_slots():
	for prediction_already_arrived in [false, true]:
		var bridge := FakeBridge.new()
		bridge.immediate = false
		var maia = MaiaPlayer.new(bridge)
		var old_game = Game.new()
		assert_true(old_game.play("e2e4"))
		var got := []
		maia.move_ready.connect(func(move): got.append(move))
		maia.think(old_game)
		if prediction_already_arrived:
			bridge.policy_ready.emit({"e2e4": 1.0})
		var game = Game.new()
		assert_true(game.play("d2d4"))
		maia.begin_game(game)
		maia.think(game)
		assert_eq(bridge.requests, [[Game.START, PackedStringArray()],
				[Game.START, PackedStringArray(["e2e4"])], [Game.START, PackedStringArray()],
				[Game.START, PackedStringArray(["d2d4"])]])
		if not prediction_already_arrived:
			bridge.policy_ready.emit({"e2e4": 1.0})
		bridge.policy_ready.emit({"e7e5": 1.0})
		assert_eq(got, [], "both obsolete replies are consumed and dropped")
		assert_eq(maia.latencies_ms, [], "obsolete replies do not affect the current game")
		bridge.policy_ready.emit({"d2d4": 1.0})
		assert_eq(got, [], "the current prediction cannot play a move")
		bridge.policy_ready.emit({"c7c5": 1.0})
		assert_eq(got, ["c7c5"], "the current move receives its own policy")
		assert_eq(maia.latencies_ms.size(), 1)


func test_the_same_seed_gives_the_same_move_and_the_default_cut_holds():
	# 1% is under the default tau of 2%: move_picker cuts it, so it is never played.
	var policy := {"e2e4": 0.5, "d2d4": 0.49, "g1f3": 0.01}
	var seen := {}
	for seed_value in 200:
		var move := _move(policy, seed_value)
		assert_eq(_move(policy, seed_value), move, "seed %d" % seed_value)
		seen[move] = true
	var played := seen.keys()
	played.sort()
	assert_eq(played, ["d2d4", "e2e4"], "sampled, not always the top move")


func test_an_illegal_policy_entry_is_never_played():
	# Unfiltered, e2e5 would be the top move and g1f3 would fall under the cut.
	for seed_value in 50:
		assert_eq(_move({"e2e5": 0.99, "g1f3": 0.01}, seed_value), "g1f3", "seed %d" % seed_value)


func test_a_policy_without_a_legal_move_still_gets_a_legal_move():
	var legal: PackedStringArray = Game.new().board.legal_moves()
	for policy in [{"e2e5": 1.0}, {}]:
		var move := _move(policy, 7)
		assert_true(move in legal, "%s from %s" % [move, policy])


func test_median_latency():
	var maia = MaiaPlayer.new(FakeBridge.new())
	assert_eq(maia.median_ms(), 0.0, "no moves yet")
	maia.latencies_ms = [5.0, 1.0, 3.0]
	assert_eq(maia.median_ms(), 3.0, "odd count")
	maia.latencies_ms = [10.0, 1.0, 3.0, 2.0]
	assert_eq(maia.median_ms(), 2.5, "even count")


# Maia plays both sides for 30 plies through the real bridge, polled every millisecond. The median
# is printed, not asserted: Lc0 shares the CPU, so it measured 16-73 ms on one machine as its load
# changed. Criterion 4 is read from the app's own log after a manual game.
func test_live_game_through_lc0_plays_legal_moves():
	if UCI.engine_path(UCI.search_dirs()) == "":
		print("SKIP test_maia_player.gd::test_live_game_through_lc0_plays_legal_moves: "
				+ "no engine/lc0/lc0.exe, run scripts/fetch-engine.ps1")
		return
	var uci = UCI.new()
	assert_true(uci.start(), uci.error)
	uci.set_level(MaiaPlayer.net_path("maia-1500"))
	var game = Game.new()
	var maia = MaiaPlayer.new(uci)
	maia.move_ready.connect(func(move): assert_true(game.play(move), "illegal " + move))
	for ply in 30:
		if game.is_over():
			break
		var before: int = game.moves.size()
		maia.think(game)
		var deadline := Time.get_ticks_msec() + 30000
		while game.moves.size() == before and Time.get_ticks_msec() < deadline:
			uci.poll()
			OS.delay_msec(1)
		assert_true(game.moves.size() > before, "no move within 30 s at ply %d" % ply)
	uci.free()
	assert_eq(maia.latencies_ms.size(), game.moves.size(), "one latency per move")
	print("maia-1500 median %.1f ms over %d moves" % [maia.median_ms(), maia.latencies_ms.size()])
