extends "res://tests/run.gd".Test

# The Lc0 bridge, §3.1–3.2 (BOT-002): the info-string parser on a fixture, the engine lookup, and a
# live level switch that runs only where engine/ holds Lc0 and the Maia nets.

const Board = preload("res://core/board.gd")
const UCI = preload("res://engine/uci.gd")

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
# The fixture's position: an Italian where white can castle either way.
const ITALIAN := "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 d2d3 g8f6 b1c3 d7d6 c1e3 c8e6 d1d2 d8d7"


func _board(fen: String, moves := ""):
	var board = Board.from_fen(fen)
	for move in moves.split(" ", false):
		board.make_move(move)
	return board


# One VerboseMoveStats line, laid out as in the fixture.
static func _line(move: String, percent: float) -> String:
	return "info string %-5s (100 ) N:       0 (+ 0) (P: %5.2f%%) (WL:  -.-----) (D: -.---) (Q: -0.04512)" % [move, percent]


static func _sorted(items: Array) -> Array:
	var copy := items.duplicate()
	copy.sort()
	return copy


static func _sum(policy: Dictionary) -> float:
	var total := 0.0
	for move in policy:
		total += policy[move]
	return total


func test_parser_reads_every_legal_move_from_lc0_output():
	var lines := FileAccess.get_file_as_string("res://tests/fixtures/lc0_verbose.txt").split("\n")
	var board = _board(START, ITALIAN)
	var policy := UCI.parse_policy(lines, board)
	assert_eq(_sorted(policy.keys()), _sorted(Array(board.legal_moves())), "keys are the legal moves")
	assert_true(absf(_sum(policy) - 1.0) < 0.001, "probabilities sum to %f" % _sum(policy))
	assert_true(is_equal_approx(policy.get("c4e6", 0.0), 0.1186), "Bxe6 at 11.86%")
	# Lc0 writes castling as king takes rook (e1h1); Board writes the king's move (e1g1).
	assert_true(is_equal_approx(policy.get("e1g1", 0.0), 0.0662), "O-O at 6.62%")
	assert_true(is_equal_approx(policy.get("e1c1", 0.0), 0.2639), "O-O-O at 26.39%")


func test_parser_takes_castling_in_either_spelling_and_leaves_rook_moves_alone():
	var white = _board(START, ITALIAN)
	var kings_move := UCI.parse_policy(PackedStringArray([_line("e1g1", 30.0), _line("e1c1", 6.5)]), white)
	assert_eq(_sorted(kings_move.keys()), ["e1c1", "e1g1"], "already the king's move")
	assert_true(is_equal_approx(kings_move.get("e1g1", 0.0), 0.3), "O-O at 30%")
	var black = _board("rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R b KQkq - 0 4")
	assert_eq(UCI.parse_policy(PackedStringArray([_line("e8h8", 12.0)]), black).keys(), ["e8g8"], "black O-O")
	var rook = _board("4k3/8/8/8/8/8/8/K3R3 w - - 0 1")
	assert_eq(UCI.parse_policy(PackedStringArray([_line("e1h1", 5.0)]), rook).keys(), ["e1h1"], "rook e1-h1")


func test_engine_lookup_takes_the_first_folder_holding_lc0():
	var root := OS.get_user_data_dir().path_join("test_uci")
	var empty := root.path_join("empty")
	var full := root.path_join("full")
	DirAccess.make_dir_recursive_absolute(full.path_join("engine/lc0"))
	var exe := full.path_join("engine/lc0/lc0.exe")
	FileAccess.open(exe, FileAccess.WRITE).close()
	assert_eq(UCI.engine_path(PackedStringArray([empty, full])), exe, "found in the second folder")
	assert_eq(UCI.engine_path(PackedStringArray([empty])), "", "missing")
	DirAccess.remove_absolute(exe)


func test_missing_engine_reports_unavailable_naming_the_fetch_script():
	var uci = UCI.new()
	assert_eq(uci.start(PackedStringArray([OS.get_user_data_dir().path_join("test_uci/empty")])), false)
	assert_eq(uci.available, false)
	assert_true("scripts/fetch-engine.ps1" in uci.error, uci.error)
	uci.free()


# Polls on this thread, as the game's _process does, until bestmove or a 30 s timeout.
func _policy(uci, moves: String) -> Dictionary:
	var got := []
	uci.policy_ready.connect(func(policy): got.append(policy), CONNECT_ONE_SHOT)
	uci.request_policy(START, moves.split(" "))
	var deadline := Time.get_ticks_msec() + 30000
	while got.is_empty() and Time.get_ticks_msec() < deadline:
		uci.poll()
		OS.delay_msec(10)
	assert_true(not got.is_empty(), "no bestmove within 30 s")
	return got[0] if got else {}


func test_switching_from_maia_1100_to_1900_changes_the_policy():
	var exe := UCI.engine_path(UCI.search_dirs())
	if exe == "":
		print("SKIP test_uci.gd::test_switching_from_maia_1100_to_1900_changes_the_policy: "
				+ "no engine/lc0/lc0.exe, run scripts/fetch-engine.ps1")
		return
	var weights := exe.get_base_dir().get_base_dir().path_join("weights")
	var uci = UCI.new()
	assert_true(uci.start(), uci.error)
	uci.set_level(weights.path_join("maia-1100.pb.gz"))
	var low := _policy(uci, ITALIAN)
	uci.set_level(weights.path_join("maia-1900.pb.gz"))
	var high := _policy(uci, ITALIAN)
	var pid: int = uci.pid
	uci.free()
	assert_true(not OS.is_process_running(pid), "Lc0 stopped when the bridge is freed")
	var legal := _sorted(Array(_board(START, ITALIAN).legal_moves()))
	for policy in [low, high]:
		assert_eq(_sorted(policy.keys()), legal, "live keys are the legal moves, castling included")
		assert_true(absf(_sum(policy) - 1.0) < 0.01, "live probabilities sum to %f" % _sum(policy))
	var changed := false
	for move in low:
		changed = changed or absf(low[move] - high.get(move, 0.0)) > 0.0001
	assert_true(changed, "maia-1900 answered with maia-1100's policy")
