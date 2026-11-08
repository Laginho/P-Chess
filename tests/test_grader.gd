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
