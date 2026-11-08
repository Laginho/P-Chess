extends "res://tests/run.gd".Test

const Sample = preload("res://tests/test_grader.gd")

func _judge(probe):
	assert_true(ResourceLoader.exists("res://core/playout_judge.gd"), "play-out judge exists")
	if not ResourceLoader.exists("res://core/playout_judge.gd"):
		return null
	return load("res://core/playout_judge.gd").new(probe)

func test_result_change_fails_and_result_kept_continues():
	var probe = Sample.FakeProbe.new()
	probe.answers[Sample.FEN] = Sample.answer("win", "c6c5", {"c6c5": {"result": "win", "dtz": 5}, "c6c4": {"result": "draw", "dtz": 0}})
	var judge = _judge(probe)
	if judge == null:
		return
	var replies := []
	judge.check(Sample.FEN, "c6c4", "convert", 1, func(result): replies.append(result))
	assert_eq(replies[0].state, "failed")
	assert_eq(replies[0].best, "c6c5")
	judge.check(Sample.FEN, "c6c5", "convert", 1, func(result): replies.append(result))
	assert_eq(replies[1].state, "continue")

func test_promotion_and_mate_convert_and_capturing_pawn_holds():
	for example in [
		["7k/P7/5K2/8/8/8/8/8 w - - 0 1", "a7a8q", "win", "convert", "You promoted a pawn."],
		["7k/8/5KQ1/8/8/8/8/8 w - - 0 1", "g6g7", "win", "convert", "You checkmated."],
		["4k3/8/8/8/8/8/4p2R/K7 w - - 0 1", "h2e2", "draw", "hold", "You captured the pawn and kept the draw."]]:
		var probe = Sample.FakeProbe.new()
		probe.answers[example[0]] = Sample.answer(example[2], example[1], {example[1]: {"result": example[2], "dtz": 1}})
		var judge = _judge(probe)
		if judge == null:
			return
		var replies := []
		judge.check(example[0], example[1], example[3], 1, func(result): replies.append(result))
		assert_eq(replies[0].state, "passed", str(example))
		assert_eq(replies[0].get("reason", ""), example[4])

func test_thirtieth_held_move_passes_only_if_result_kept_and_probe_errors_surface():
	var fen := "4k3/8/2r5/8/P7/8/8/4K3 b - - 0 1"
	var probe = Sample.FakeProbe.new()
	probe.answers[fen] = Sample.answer("draw", "c6c5", {"c6c5": {"result": "draw", "dtz": 0}, "c6c4": {"result": "loss", "dtz": 0}})
	var judge = _judge(probe)
	if judge == null:
		return
	var replies := []
	judge.check(fen, "c6c5", "hold", 29, func(result): replies.append(result))
	judge.check(fen, "c6c5", "hold", 30, func(result): replies.append(result))
	judge.check(fen, "c6c4", "hold", 30, func(result): replies.append(result))
	assert_eq(replies.map(func(result): return result.state), ["continue", "passed", "failed"])
	assert_eq(replies[1].get("reason", ""), "You held the draw for 30 moves.")
	probe.answers[fen] = {"ok": false, "error": "missing table"}
	judge.check(fen, "c6c5", "hold", 30, func(result): replies.append(result))
	assert_eq(replies[3].error, "missing table")
