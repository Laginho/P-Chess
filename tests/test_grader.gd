extends "res://tests/run.gd".Test

const FEN := "4k3/8/2r5/8/8/8/8/4K3 b - - 0 1"
const LINE := ["c6c5", "e1f2", "c5c4"]

class FakeProbe extends RefCounted:
	var answers := {}
	var requests := []
	var held := false
	var pending := []
	func probe(fen: String, callback: Callable) -> void:
		requests.append(fen)
		if held:
			pending.append([fen, callback])
		else:
			callback.call(answers.get(fen, {"ok": false, "error": "Missing scripted table"}).duplicate(true))
	func reply() -> void:
		var request: Array = pending.pop_front()
		request[1].call(answers.get(request[0], {"ok": false, "error": "Missing scripted table"}).duplicate(true))

static func position() -> Dictionary:
	return {"id": "one", "pool": "practice", "fen": FEN, "side": "b", "line_length": 2, "goal": "win"}

static func answer(result: String, best: String, moves: Dictionary) -> Dictionary:
	return {"ok": true, "result": result, "best": best, "dtz": moves.get(best, {}).get("dtz", 0), "moves": moves}

static func winning_probe():
	var probe := FakeProbe.new()
	var board = load("res://core/board.gd").from_fen(FEN)
	probe.answers[board.to_fen()] = answer("win", "c6c5", {"c6c5": {"result": "win", "dtz": 5}})
	board.make_move("c6c5")
	probe.answers[board.to_fen()] = answer("loss", "e1f2", {"e1f2": {"result": "loss", "dtz": 4}})
	board.make_move("e1f2")
	probe.answers[board.to_fen()] = answer("win", "c5c4", {"c5c4": {"result": "win", "dtz": 3}})
	return probe

func _grader(probe):
	assert_true(ResourceLoader.exists("res://core/grader.gd"), "grader exists")
	if not ResourceLoader.exists("res://core/grader.gd"):
		return null
	return load("res://core/grader.gd").new(probe)

func test_result_keeping_line_passes_with_marks_on_own_moves():
	var probe = winning_probe()
	var grader = _grader(probe)
	if grader == null:
		return
	var replies := []
	grader.grade(position(), PackedStringArray(LINE), func(result): replies.append(result))
	assert_eq(replies.size(), 1)
	if replies.is_empty():
		return
	var result: Dictionary = replies[0]
	assert_true(result.ok and result.solved)
	assert_eq(result.failed_ply, -1)
	assert_eq(result.plies.map(func(ply): return ply.mark), ["✓", "", "✓"])
	assert_eq(result.plies.map(func(ply): return ply.san), ["Rc5", "Kf2", "Rc4"])
	assert_eq(probe.requests.size(), 3, "uses each root answer in the committed line")

static func failing_probe(result := "draw", dtz := 0):
	var probe = winning_probe()
	var board = load("res://core/board.gd").from_fen(FEN)
	board.make_move("c6c5")
	board.make_move("e1f2")
	probe.answers[board.to_fen()] = answer("win", "c5c3", {
		"c5c3": {"result": "win", "dtz": 3}, "c5c4": {"result": result, "dtz": dtz}})
	board.make_move("c5c3")
	probe.answers[board.to_fen()] = answer("loss", "f2e2", {"f2e2": {"result": "loss", "dtz": 2}})
	board.make_move("f2e2")
	probe.answers[board.to_fen()] = answer("win", "c3c2", {"c3c2": {"result": "win", "dtz": 1}})
	board.make_move("c3c2")
	probe.answers[board.to_fen()] = {"ok": true, "result": "loss", "best": "", "moves": {}, "dtz": 0}
	return probe

func test_first_failure_stops_marks_and_shows_best_line_for_both_sides():
	var probe = failing_probe()
	var grader = _grader(probe)
	if grader == null:
		return
	var selected := position()
	selected.line_length = 3
	var replies := []
	grader.grade(selected, PackedStringArray(["c6c5", "e1f2", "c5c4", "f2e2", "c4c3"]), func(result): replies.append(result))
	var result: Dictionary = replies[0]
	assert_true(result.ok and not result.solved)
	assert_eq(result.get("reason"), "result changed")
	assert_eq(result.failed_ply, 2)
	assert_eq(result.plies.map(func(ply): return ply.mark), ["✓", "", "✗", "", ""])
	assert_eq(result.plies.map(func(ply): return ply.get("grey", false)), [false, false, false, true, true])
	assert_eq(result.get("correct", []).map(func(ply): return ply.uci), ["c5c3", "f2e2", "c3c2"], "stops correction at a terminal probe answer, before five plies")
	assert_eq(result.get("correct", []).map(func(ply): return ply.san), ["Rc3", "Ke2", "Rc2+"])
	assert_eq(probe.requests.size(), 6, "three committed roots and three correction roots, including terminal")

func test_winning_distance_boundary_is_in_root_plies_and_draws_ignore_it():
	var constants: Dictionary = load("res://core/tunables.gd").get_script_constant_map()
	var margin: int = constants.get("COURSE_DTZ_MARGIN", 1)
	assert_true(constants.has("COURSE_DTZ_MARGIN") and margin >= 1, "Syzygy margin is at least one ply")
	for example in [["win", 3 + margin, true, ""], ["win", 4 + margin, false, "too slow"], ["draw", 0, false, "result changed"]]:
		var grader = _grader(failing_probe(example[0], example[1]))
		if grader == null:
			return
		var replies := []
		grader.grade(position(), PackedStringArray(LINE), func(result): replies.append(result))
		assert_eq(replies[0].solved, example[2], str(example))
		assert_eq(replies[0].get("reason", ""), example[3])
	var probe := FakeProbe.new()
	probe.answers[FEN] = answer("draw", "c6c5", {"c6c5": {"result": "draw", "dtz": 0}, "c6c4": {"result": "draw", "dtz": 0}})
	var grader = _grader(probe)
	var selected := position()
	selected.line_length = 1
	var replies := []
	grader.grade(selected, PackedStringArray(["c6c4"]), func(result): replies.append(result))
	assert_true(replies[0].solved, "every drawing move holds")

func test_opponent_better_defence_is_advice_and_never_a_failure():
	var board = load("res://core/board.gd").from_fen(FEN)
	board.make_move("c6c5")
	for example in [["loss", 5, "loss", 4, "Kd2"], ["draw", 0, "loss", 4, "Kd2"], ["win", 1, "draw", 0, "Kd2"], ["loss", 4, "loss", 4, ""], ["draw", 0, "draw", 0, ""]]:
		var probe = winning_probe()
		probe.answers[board.to_fen()] = answer(example[0], "e1d2", {
			"e1d2": {"result": example[0], "dtz": example[1]}, "e1f2": {"result": example[2], "dtz": example[3]}})
		var replies := []
		_grader(probe).grade(position(), PackedStringArray(LINE), func(result): replies.append(result))
		assert_true(replies[0].solved, "opponent cannot fail your line")
		assert_eq(replies[0].plies[1].get("better_defence", ""), example[4], str(example))

func test_probe_errors_even_in_correction_do_not_return_a_grade():
	for correction in [false, true]:
		var probe = failing_probe() if correction else winning_probe()
		var board = load("res://core/board.gd").from_fen(FEN)
		board.make_move("c6c5")
		if correction:
			board.make_move("e1f2")
			board.make_move("c5c3")
		probe.answers[board.to_fen()] = {"ok": false, "error": "Table missing"}
		var replies := []
		_grader(probe).grade(position(), PackedStringArray(LINE), func(result): replies.append(result))
		assert_eq(replies, [{"ok": false, "error": "Table missing"}])
