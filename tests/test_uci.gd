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


func test_missing_stockfish_names_the_engine_and_path():
	var uci = UCI.new("engine/stockfish/stockfish.exe", "Stockfish")
	assert_eq(uci.start(PackedStringArray([OS.get_user_data_dir().path_join("test_uci/empty")])), false)
	assert_eq(uci.error, "Stockfish is missing (engine/stockfish/stockfish.exe). Run scripts/fetch-engine.ps1 to download it.")
	uci.free()


func test_search_forwards_all_info_and_bestmove_to_the_request_callback():
	var uci = UCI.new("engine/stockfish/stockfish.exe", "Stockfish")
	uci.available = true
	uci.pid = OS.get_process_id()
	uci._stdio = FileAccess.open("user://rev001-commands.txt", FileAccess.WRITE)
	var received := []
	uci.request_search(["position startpos", "go depth 2"], func(line): received.append(line))
	uci._lines.append_array(["info depth 1 multipv 1 score cp 20", "info depth 2 multipv 2 score cp 10", "bestmove e2e4"])
	uci.poll()
	assert_eq(received, ["info depth 1 multipv 1 score cp 20", "info depth 2 multipv 2 score cp 10", "bestmove e2e4"])
	uci.pid = -1
	uci.free()


func test_stockfish_does_not_send_maia_requests():
	var uci = UCI.new("engine/stockfish/stockfish.exe", "Stockfish")
	uci.available = true
	uci.pid = OS.get_process_id()
	uci._stdio = FileAccess.open("user://rev001-stockfish-commands.txt", FileAccess.WRITE)
	uci.set_level("weights.pb.gz")
	uci.request_policy(START, PackedStringArray())
	assert_eq(uci._stdio.get_position(), 0, "no Maia commands are sent")
	assert_true(uci._steps.is_empty(), "no Maia commands are queued")
	uci.pid = -1
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


func _live_engine(test_name: String) -> String:
	var exe := UCI.engine_path(UCI.search_dirs())
	if exe == "":
		print("SKIP test_uci.gd::%s: no engine/lc0/lc0.exe, run scripts/fetch-engine.ps1" % test_name)
	return exe


func test_stopping_one_bridge_leaves_the_other_running():
	var exe := _live_engine("test_stopping_one_bridge_leaves_the_other_running")
	if exe == "":
		return
	var first = UCI.new()
	var second = UCI.new()
	assert_true(first.start(), first.error)
	assert_true(second.start(), second.error)
	var second_pid: int = second.pid
	assert_true(first.pid != second_pid, "separate engine processes")
	first.stop()
	assert_true(OS.is_process_running(second_pid), "second engine survives first stop")
	second.set_level(exe.get_base_dir().get_base_dir().path_join("weights/maia-1100.pb.gz"))
	assert_true(not _policy(second, ITALIAN).is_empty(), "second engine still answers")
	first.free()
	second.free()


func _wait_for_stop(uci, stops: Array) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while stops.is_empty() and Time.get_ticks_msec() < deadline:
		uci.poll()
		OS.delay_msec(10)
	assert_eq(stops.size(), 1, "one stopped signal within 10 s of polling")
	assert_eq(uci.available, false, "the dead engine is unavailable")
	assert_true("Lc0" in uci.error and "stopped" in uci.error, uci.error)
	uci.poll()
	assert_eq(stops.size(), 1, "later polls do not repeat stopped")


func test_external_exit_reports_stopped_and_discards_queued_requests():
	var exe := _live_engine("test_external_exit_reports_stopped_and_discards_queued_requests")
	if exe == "":
		return
	var uci = UCI.new()
	if not uci.has_signal("stopped"):
		assert_true(false, "the bridge must expose stopped for an unexpected Lc0 exit")
		uci.free()
		return
	var stops := []
	var policies := []
	uci.stopped.connect(func(): stops.append(true))
	uci.policy_ready.connect(func(policy): policies.append(policy))
	assert_true(uci.start(), uci.error)
	var weights := exe.get_base_dir().get_base_dir().path_join("weights/maia-1100.pb.gz")
	uci.set_level(weights)
	uci.request_policy(START, PackedStringArray())
	uci.request_policy(START, ITALIAN.split(" "))
	var pid: int = uci.pid
	assert_eq(OS.kill(pid), OK, "kill Lc0 outside the bridge's stop()")
	_wait_for_stop(uci, stops)
	assert_true(not OS.is_process_running(pid), "the child process is gone")
	assert_true(policies.is_empty(), "abandoned requests emit no policy")
	# Restarting the same bridge must not replay requests or wait for the dead child's reply.
	assert_true(uci.start(), uci.error)
	assert_eq(uci.error, "", "a successful restart clears the old error")
	uci.set_level(weights)
	assert_true(not _policy(uci, ITALIAN).is_empty(), "a fresh request works after restart")
	assert_eq(policies.size(), 1, "only the new request gets a policy")
	uci.stop()
	uci.poll()
	assert_eq(stops.size(), 1, "intentional stop() does not emit stopped")
	uci.free()


func test_missing_net_reports_stopped_instead_of_waiting_for_readyok():
	if _live_engine("test_missing_net_reports_stopped_instead_of_waiting_for_readyok") == "":
		return
	var uci = UCI.new()
	var stops := []
	var policies := []
	uci.stopped.connect(func(): stops.append(true))
	uci.policy_ready.connect(func(policy): policies.append(policy))
	assert_true(uci.start(), uci.error)
	var missing := OS.get_user_data_dir().path_join("BOT-008-no-such-net.pb.gz")
	assert_true(not FileAccess.file_exists(missing), "the live test net must not exist")
	uci.set_level(missing)
	uci.request_policy(START, PackedStringArray())
	_wait_for_stop(uci, stops)
	assert_true(policies.is_empty(), "a failed net emits no policy")
	uci.free()
	assert_eq(stops.size(), 1, "freeing a failed bridge does not emit stopped again")
