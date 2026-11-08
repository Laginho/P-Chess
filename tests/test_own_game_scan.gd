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

func test_black_player_and_white_pawn_use_player_perspective():
	var fen := "4k3/7R/8/4P3/8/r7/8/4K3 b - - 0 1"
	var board = Board.from_fen(fen)
	var positions := [{"fen": board.to_fen()}]
	board.make_move("a3a4")
	positions.append({"fen": board.to_fen()})
	var probe = FakeProbe.new()
	probe.answers[positions[0].fen] = {"ok": true, "result": "win"}
	probe.answers[positions[1].fen] = {"ok": true, "result": "draw"}
	var replies := []
	load("res://core/own_game_scan.gd").new(probe).scan(positions, "b", func(result): replies.append(result))
	assert_eq(replies[0].size(), 1)
	if replies[0].size() == 1:
		assert_eq(replies[0][0].before, "win")
		assert_eq(replies[0][0].after, "draw")

func test_probe_failure_after_a_marker_discards_the_whole_scan():
	var board = Board.from_fen(FEN)
	var positions := [{"fen": board.to_fen()}]
	for move in ["a3a4", "e8e7", "a4a5"]:
		board.make_move(move)
		positions.append({"fen": board.to_fen()})
	var probe = FakeProbe.new()
	probe.answers[positions[0].fen] = {"ok": true, "result": "draw"}
	probe.answers[positions[1].fen] = {"ok": true, "result": "win"}
	var replies := []
	load("res://core/own_game_scan.gd").new(probe).scan(positions, "w", func(result): replies.append(result))
	assert_eq(replies, [[]])

func test_pgn_reaches_the_endgame_before_probing():
	var pgn := "[FEN \"4k3/8/8/8/p3p3/R7/7r/4K3 w - - 0 1\"]\n\n1. Rxa4 Ke7 2. Ra5 *"
	var parsed: Dictionary = load("res://core/pgn.gd").parse(pgn)
	assert_eq(parsed.error, "")
	if parsed.games.is_empty():
		return
	var game: Dictionary = parsed.games[0]
	var board = Board.from_fen(game.headers.FEN)
	var positions := [{"fen": board.to_fen()}]
	for move in game.moves:
		board.make_move(move.uci)
		positions.append({"fen": board.to_fen()})
	var probe = FakeProbe.new()
	probe.answers[positions[2].fen] = {"ok": true, "result": "win"}
	probe.answers[positions[3].fen] = {"ok": true, "result": "draw"}
	var replies := []
	load("res://core/own_game_scan.gd").new(probe).scan(positions, "w", func(result): replies.append(result))
	assert_eq(probe.requests, [positions[2].fen, positions[3].fen])
	assert_eq(replies[0].size(), 1)
	if replies[0].size() == 1:
		assert_eq(replies[0][0].ply, 3)

func test_nearby_material_is_never_probed():
	var probe = FakeProbe.new()
	var scanner = load("res://core/own_game_scan.gd").new(probe)
	for fen in ["4k3/8/8/8/4p3/R7/7r/3QK3 w - - 0 1", "4k3/8/8/8/4p3/R7/8/4K3 w - - 0 1", "4k3/8/8/8/4p3/R7/6pr/4K3 w - - 0 1"]:
		scanner.scan([{"fen": fen}, {"fen": fen}], "w", func(_result): pass)
	assert_true(probe.requests.is_empty())
