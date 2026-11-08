extends "res://tests/run.gd".Test

const Board = preload("res://core/board.gd")
const FakeProbe = preload("res://tests/test_grader.gd").FakeProbe
const FEN := "4k3/8/8/8/4p3/R7/7r/4K3 w - - 0 1"

func test_scans_only_own_moves_in_rook_and_pawn_material():
	assert_true(ResourceLoader.exists("res://core/own_game_scan.gd"), "own game scan exists")
	if not ResourceLoader.exists("res://core/own_game_scan.gd"):
		return
	var board = Board.from_fen(FEN)
	var positions := [{"fen": board.to_fen()}]
	for move in ["a3a4", "e8e7", "a4a5"]:
		board.make_move(move)
		positions.append({"fen": board.to_fen()})
	var probe = FakeProbe.new()
	probe.answers[positions[0].fen] = {"ok": true, "result": "draw"}
	probe.answers[positions[1].fen] = {"ok": true, "result": "win"}
	probe.answers[positions[2].fen] = {"ok": true, "result": "loss"}
	probe.answers[positions[3].fen] = {"ok": true, "result": "win"}
	var answers := []
	load("res://core/own_game_scan.gd").new(probe).scan(positions, "w", func(result): answers.append(result))
	assert_eq(answers.size(), 1)
	if answers.size() == 1:
		assert_eq(answers[0].size(), 1)
		if answers[0].size() == 1:
			assert_eq(answers[0][0].ply, 1)
			assert_eq(answers[0][0].before, "draw")
			assert_eq(answers[0][0].after, "loss")
	assert_eq(probe.requests.size(), 4)

func test_ignores_other_material_and_discards_results_on_probe_failure():
	if not ResourceLoader.exists("res://core/own_game_scan.gd"):
		return
	var probe = FakeProbe.new()
	var replies := []
	var scanner = load("res://core/own_game_scan.gd").new(probe)
	scanner.scan([{"fen": load("res://core/game.gd").START}, {"fen": load("res://core/game.gd").START}], "w", func(result): replies.append(result))
	assert_eq(probe.requests.size(), 0)
	assert_eq(replies, [[]])
	var board = Board.from_fen(FEN)
	var positions := [{"fen": board.to_fen()}]
	board.make_move("a3a4")
	positions.append({"fen": board.to_fen()})
	probe.answers[positions[0].fen] = {"ok": true, "result": "draw"}
	scanner.scan(positions, "w", func(result): replies.append(result))
	assert_eq(replies.back(), [])
