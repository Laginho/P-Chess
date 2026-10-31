extends "res://tests/run.gd".Test

# The real history store and PGN reader, with files isolated from the player's data.
const History = preload("res://core/history.gd")
const Game = preload("res://core/game.gd")
const Pgn = preload("res://core/pgn.gd")
const MainScene = preload("res://ui/main.tscn")
const Clock = preload("res://core/clock.gd")
const HistoryStorage = preload("res://tests/history_storage.gd")
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"}


func test_games_is_empty_before_the_first_save():
	var folder := _folder()
	assert_eq(History.new(folder).games(), [])
	assert_eq(DirAccess.make_dir_recursive_absolute(folder), OK)
	assert_eq(History.new(folder).games(), [])
	HistoryStorage.clean(folder)


func test_thumbnail_uses_deepest_named_position_or_fallback():
	var history = History.new(_folder())
	var book = load("res://bot/book.gd").new()
	book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn\t1. e4 e5\nC40\tKing's Knight\t1. e4 e5 2. Nf3 Nc6\n")
	history.book = book
	var known := PackedStringArray(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4"])
	assert_eq(history.thumbnail(known), {"ply": 4, "opening": "King's Knight"})
	var prefix := PackedStringArray(["e2e4", "e7e5", "g1f3", "g8f6"])
	assert_eq(history.thumbnail(prefix), {"ply": 3, "opening": "King's Pawn"}, "the thumbnail includes a catalog prefix after the last named position")
	var unknown := PackedStringArray(["a2a3", "a7a6", "b2b3", "b7b6", "c2c3", "c7c6", "d2d3", "d7d6", "e2e3", "e7e6", "f2f3"])
	assert_eq(history.thumbnail(unknown), {"ply": 10, "opening": ""})
	assert_eq(history.thumbnail(unknown.slice(0, 6)), {"ply": 6, "opening": ""})
	assert_eq(history.thumbnail(PackedStringArray()), {"ply": 0, "opening": ""})


func test_reason_prefers_header_and_infers_legacy_ending():
	var history = History.new(_folder())
	assert_eq(history.reason({"headers": {"Reason": "agreement"}, "moves": [], "result": "1/2-1/2"}), "agreement")
	var mate = Pgn.parse("1. f3 e5 2. g4 Qh4# 0-1").games[0]
	assert_eq(history.reason(mate), "checkmate")
	assert_eq(history.reason({"headers": {"Termination": "Normal"}, "moves": [], "result": "1-0"}), "resignation")
	assert_eq(history.reason({"headers": {}, "moves": [], "result": "1/2-1/2"}), "")
	for case in [["7k/5Q2/6K1/8/8/8/8/8 b - - 0 1", "stalemate"], ["7k/8/8/8/8/8/8/K7 w - - 0 1", "insufficient material"], ["7k/8/8/8/8/8/R7/K7 w - - 100 1", "50-move"]]:
		assert_eq(history.reason({"headers": {"FEN": case[0]}, "moves": [], "result": "1/2-1/2"}), case[1])


class FakeTime:
	var now := 0


	func ms() -> int:
		return now


class HeldEngine extends "res://engine/uci.gd":
	func start(_dirs := PackedStringArray()) -> bool:
		return true


	func set_level(_net_path: String) -> void:
		pass


	func request_policy(_fen: String, _moves: PackedStringArray) -> void:
		pass


func test_repertoire_snapshot_round_trip_and_missing_file():
	var folder := _folder()
	var history = History.new(folder)
	var repertoire = load("res://bot/repertoire.gd").new()
	assert_eq(repertoire.parse("1. e4 e5 2. Nf3 *", "b"), "")
	var game = Game.new()
	game.resign("w")
	var path: String = history.save(game, [], SETTINGS, "", "", repertoire.lines, repertoire.colour)
	assert_true(FileAccess.file_exists(path.trim_suffix(".pgn") + ".repertoire.json"))
	var snapshot: Dictionary = history.read_repertoire(path)
	assert_eq(snapshot.colour, "b")
	assert_eq(snapshot.lines, repertoire.lines)
	var plain: String = history.save(game, [], SETTINGS)
	assert_true(not FileAccess.file_exists(plain.trim_suffix(".pgn") + ".repertoire.json"))
	assert_eq(history.read_repertoire(plain).lines, [])
	HistoryStorage.clean(folder)

func _session(folder: String, time: FakeTime, settings := SETTINGS):
	var main = MainScene.instantiate()
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	main.history = History.new(folder)
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_history_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__history_silent__")
	main._start(settings.duplicate())
	main.clock = Clock.new(settings.control, time.ms)
	main.clock.flagged.connect(main._on_flagged)
	main.maia.clock = main.clock
	main.white_clock.clock = main.clock
	main.black_clock.clock = main.clock
	return main


func _key(main, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	main._unhandled_key_input(event)


func _games(folder: String) -> Array:
	var games := []
	if not DirAccess.dir_exists_absolute(folder.path_join("games")):
		return games
	for file in DirAccess.get_files_at(folder.path_join("games")):
		var parsed := Pgn.parse(FileAccess.get_file_as_string(folder.path_join("games").path_join(file)))
		assert_eq(parsed.error, "")
		games.append_array(parsed.games)
	return games


func _folder() -> String:
	return "user://test_history_%d" % Time.get_ticks_usec()


func _seed_result_records(folder: String, corrupt) -> bool:
	assert_eq(DirAccess.make_dir_recursive_absolute(folder), OK)
	var stored := ConfigFile.new()
	stored.set_value("maia-1500", "3+2", corrupt)
	stored.set_value("maia-1500", "1+0",
			{"wins": 3, "draws": 2, "losses": 1, "flag_wins": 1, "flag_losses": 0})
	stored.set_value("maia-1700", "3+2",
			{"wins": 9, "draws": 8, "losses": 7, "flag_wins": 2, "flag_losses": 1})
	stored.set_value("practice", "fixture-line", 4)
	var status := stored.save(folder.path_join("stats.cfg"))
	assert_eq(status, OK, "seed only owned test history")
	return status == OK


func _assert_recovered_result_records(folder: String) -> void:
	var stored := ConfigFile.new()
	assert_eq(stored.load(folder.path_join("stats.cfg")), OK)
	assert_eq(stored.get_value("maia-1500", "3+2"),
			{"wins": 0, "draws": 0, "losses": 1, "flag_wins": 0, "flag_losses": 0})
	assert_eq(stored.get_value("maia-1500", "1+0"),
			{"wins": 3, "draws": 2, "losses": 1, "flag_wins": 1, "flag_losses": 0})
	assert_eq(stored.get_value("maia-1700", "3+2"),
			{"wins": 9, "draws": 8, "losses": 7, "flag_wins": 2, "flag_losses": 1})
	assert_eq(stored.get_value("practice", "fixture-line"), 4, "practice data survives")


func test_save_recovers_corrupt_result_records_and_preserves_valid_stats():
	var corrupt_records: Array = [{"wins": 12}, 12, {}, "invalid", []]
	for invalid_counter in [-1, 1.5, 1.0, true, "2", null]:
		for counter in ["wins", "draws", "losses", "flag_wins", "flag_losses"]:
			var record := {"wins": 3, "draws": 2, "losses": 1, "flag_wins": 1, "flag_losses": 0}
			record[counter] = invalid_counter
			corrupt_records.append(record)
	for record in corrupt_records:
		var folder := _folder()
		if not _seed_result_records(folder, record):
			HistoryStorage.clean(folder)
			continue
		var history = History.new(folder)
		var game = Game.new()
		game.resign("w")
		var path = history.save(game, [], SETTINGS)
		assert_true(path is String and not path.is_empty(), "corrupt stats do not prevent saving the PGN")
		assert_true(history.error.contains("Corrupt") and history.error.contains("maia-1500")
				and history.error.contains("3+2"), "report the affected result record: " + var_to_str(record))
		_assert_recovered_result_records(folder)
		assert_eq(History.new(folder).stats("maia-1500", "3+2"),
				{"wins": 0, "draws": 0, "losses": 1, "flag_wins": 0, "flag_losses": 0})
		assert_eq(_games(folder).size(), 1)
		HistoryStorage.clean(folder)


func test_main_recovers_corrupt_stats_once_and_reports_them_in_the_review():
	for record in [{"wins": 12}, 12]:
		var folder := _folder()
		if not _seed_result_records(folder, record):
			HistoryStorage.clean(folder)
			continue
		var time := FakeTime.new()
		var main = _session(folder, time)
		_key(main, KEY_ESCAPE)
		_key(main, KEY_ESCAPE)
		main._show_result()
		assert_true(main.board_view.game.is_over())
		assert_true(main.history.error.contains("Corrupt"), "corrupt stats are reported after saving")
		assert_true(main.result_label.text.contains("History: " + main.history.error))
		assert_true(main.result_label.text.contains("Space for a rematch"))
		main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()
		var review = main.get_node("Review")
		assert_true(review.visible, "review still opens after corrupt history is recovered")
		assert_true(review.get_node("Margin/Content/Result").text.contains("History: " + main.history.error),
				"the visible review reports the corruption")
		_assert_recovered_result_records(folder)
		var games := _games(folder)
		assert_eq(games.size(), 1, "repeated results do not duplicate saves during recovery")
		if games.size() == 1:
			assert_eq(games[0].result, "0-1")
		main.free()
		HistoryStorage.clean(folder)


func test_finished_game_saves_one_pgn_with_headers_moves_and_exact_clocks():
	var folder := _folder()
	var history = History.new(folder)
	var game = Game.new()
	for move in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		assert_true(game.play(move))
	var path: String = history.save(game, [180000, 180000, 179534, 181001], SETTINGS)
	assert_eq(history.error, "")
	assert_eq(DirAccess.get_files_at(folder.path_join("games")).size(), 1)
	var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
	assert_eq(parsed.error, "")
	assert_eq(parsed.games.size(), 1)
	if parsed.games.size() == 1:
		var saved: Dictionary = parsed.games[0]
		assert_eq(saved.headers, {"White": "You", "Black": "Maia 1500", "TimeControl": "180+2",
				"Result": "0-1", "Termination": "Normal", "Reason": "checkmate"})
		assert_eq(saved.result, "0-1")
		assert_eq(saved.moves.map(func(move): return move.uci), ["f2f3", "e7e5", "g2g4", "d8h4"])
		assert_eq(saved.moves.map(func(move): return move.clock_ms), [180000, 180000, 179534, 181001])
	HistoryStorage.clean(folder)


func test_stats_survive_reload_and_separate_level_control_and_human_colour():
	var folder := _folder()
	var history = History.new(folder)
	var flag_win = Game.new()
	flag_win.flag("b")
	history.save(flag_win, [], SETTINGS)
	var draw = Game.new()
	for move in ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"]:
		assert_true(draw.play(move))
	draw.claim_draw()
	history.save(draw, [180000, 180000, 180000, 180000, 180000, 180000, 180000, 180000], SETTINGS)
	var as_black := SETTINGS.duplicate()
	as_black.colour = "b"
	var loss = Game.new()
	loss.flag("b")
	history.save(loss, [], as_black)
	var normal_win = Game.new()
	normal_win.resign("b")
	history.save(normal_win, [], SETTINGS)
	var other := SETTINGS.duplicate()
	other.level = "maia-1700"
	other.control = "1+0"
	history.save(normal_win, [], other)
	var reloaded = History.new(folder)
	assert_eq(reloaded.stats("maia-1500", "3+2"), {"wins": 2, "draws": 1, "losses": 1, "flag_wins": 1, "flag_losses": 1})
	assert_eq(reloaded.stats("maia-1700", "1+0"), {"wins": 1, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	assert_eq(reloaded.stats("maia-1500", "1+0"), {"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	assert_eq(DirAccess.get_files_at(folder.path_join("games")).size(), 5, "rapid saves never overwrite a PGN")
	HistoryStorage.clean(folder)


func test_main_saves_mate_once_with_final_increment_and_resets_history_on_rematch():
	var folder := _folder()
	var time := FakeTime.new()
	var main = _session(folder, time)
	assert_true(main.board_view.play("f2f3"))
	main._on_maia_move("e7e5")
	time.now = 250
	assert_true(main.board_view.play("g2g4"))
	time.now = 1250
	main._on_maia_move("d8h4")
	main._show_result()
	var games := _games(folder)
	assert_eq(games.size(), 1, "repeated result handling saves only once")
	if games.size() == 1:
		assert_eq(games[0].result, "0-1")
		assert_eq(games[0].moves.map(func(move): return move.clock_ms), [180000, 180000, 181750, 181000])
	assert_eq(History.new(folder).stats("maia-1500", "3+2").losses, 1)
	_key(main, KEY_SPACE)
	main._on_maia_move("e2e4")
	_key(main, KEY_ESCAPE)
	_key(main, KEY_ESCAPE)
	games = _games(folder)
	assert_eq(games.size(), 2)
	var rematches := games.filter(func(game): return game.moves.size() == 1)
	assert_eq(rematches.size(), 1)
	if rematches.size() == 1:
		assert_eq(rematches[0].moves[0].uci, "e2e4")
		assert_eq(rematches[0].moves[0].clock_ms, 180000, "no previous-game clock snapshots")
		assert_eq(rematches[0].headers.White, "Maia 1500")
	assert_eq(History.new(folder).stats("maia-1500", "3+2").losses, 2)
	main.free()
	HistoryStorage.clean(folder)


func test_headers_use_actual_level_colour_control_and_only_a_known_opening():
	var folder := _folder()
	var history = History.new(folder)
	var settings := {"colour": "b", "level": "maia-1900", "control": "1+0"}
	for control in {"1+0": "60+0", "3+2": "180+2", "5+0": "300+0"}:
		settings.control = control
		var game = Game.new()
		game.resign("w")
		var path: String = history.save(game, [], settings, "Bird Opening")
		var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
		assert_eq(parsed.error, "")
		assert_eq(parsed.games[0].headers, {"White": "Maia 1900", "Black": "You",
				"TimeControl": {"1+0": "60+0", "3+2": "180+2", "5+0": "300+0"}[control],
				"Result": "0-1", "Termination": "Normal", "Reason": "resignation", "Opening": "Bird Opening"})
	HistoryStorage.clean(folder)


func test_main_saves_a_clock_flag_once_and_keeps_move_time_snapshots():
	var folder := _folder()
	var time := FakeTime.new()
	var main = _session(folder, time)
	assert_true(main.board_view.play("e2e4"))
	main._on_maia_move("e7e5")
	time.now = 180000
	main._process(0)
	main._show_result()
	var games := _games(folder)
	assert_eq(games.size(), 1)
	if games.size() == 1:
		assert_eq(games[0].headers.Termination, "Time forfeit")
		assert_eq(games[0].result, "0-1")
		assert_eq(games[0].moves.map(func(move): return move.clock_ms), [180000, 180000], "not the clocks at game end")
	assert_eq(History.new(folder).stats("maia-1500", "3+2"),
			{"wins": 0, "draws": 0, "losses": 1, "flag_wins": 0, "flag_losses": 1})
	main.free()
	HistoryStorage.clean(folder)


func test_main_saves_a_claimed_draw_once():
	var folder := _folder()
	var time := FakeTime.new()
	var main = _session(folder, time)
	main.board_view.game.auto_claim = false
	for move in ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"]:
		assert_true(main.board_view.play(move))
	main.claim_draw.pressed.emit()
	main._show_result()
	var games := _games(folder)
	assert_eq(games.size(), 1)
	if games.size() == 1:
		assert_eq(games[0].result, "1/2-1/2")
		assert_eq(games[0].headers.Termination, "Normal")
		assert_eq(games[0].moves.size(), 8)
	assert_eq(History.new(folder).stats("maia-1500", "3+2").draws, 1)
	main.free()
	HistoryStorage.clean(folder)


func test_main_records_first_and_later_premoves_after_exactly_one_charge():
	var folder := _folder()
	var time := FakeTime.new()
	var settings := SETTINGS.duplicate()
	settings.colour = "b"
	var main = _session(folder, time, settings)
	var board = main.board_view
	assert_true(board.premoves.enqueue(board.game.board, "g8f6"))
	assert_true(board.premoves.enqueue(board.game.board, "f6g4"))
	main._on_maia_move("e2e4")
	main._on_maia_move("d2d4")
	main._on_flagged("w")
	var games := _games(folder)
	assert_eq(games.size(), 1)
	if games.size() == 1:
		assert_eq(games[0].moves.map(func(move): return move.uci), ["e2e4", "g8f6", "d2d4", "f6g4"])
		assert_eq(games[0].moves.map(func(move): return move.clock_ms), [180000, 179900, 182000, 181800])
	assert_eq(History.new(folder).stats("maia-1500", "3+2").flag_wins, 1)
	main.free()
	HistoryStorage.clean(folder)


func test_main_waits_for_the_last_snapshot_when_move_accounting_emits_a_flag():
	for final_move in ["g1f3", "d8h4"]:
		var folder := _folder()
		var time := FakeTime.new()
		var main = _session(folder, time)
		if final_move == "g1f3":
			main.board_view.play("e2e4")
			main._on_maia_move("e7e5")
		else:
			main.board_view.play("f2f3")
			main._on_maia_move("e7e5")
			main.board_view.play("g2g4")
		time.now = 200000
		main.board_view.play(final_move)
		var games := _games(folder)
		assert_eq(games.size(), 1)
		if games.size() == 1:
			assert_eq(games[0].moves[-1].uci, final_move)
			assert_eq(games[0].moves[-1].clock_ms, 0)
			assert_eq(games[0].headers.Termination, "Time forfeit" if final_move == "g1f3" else "Normal",
					"terminal-move precedence is preserved")
		assert_eq(main.history.error, "")
		main.free()
		HistoryStorage.clean(folder)


func test_main_reports_failed_game_and_stats_writes_in_the_result_ui():
	for blocked in ["games", "stats.cfg"]:
		var folder := _folder()
		var time := FakeTime.new()
		var main = _session(folder, time)
		DirAccess.make_dir_recursive_absolute(folder)
		if blocked == "games":
			var file := FileAccess.open(folder.path_join(blocked), FileAccess.WRITE)
			file.close()
		else:
			DirAccess.make_dir_absolute(folder.path_join(blocked))
		_key(main, KEY_ESCAPE)
		_key(main, KEY_ESCAPE)
		assert_true(main.board_view.game.is_over())
		assert_true(not main.history.error.is_empty(), "write failure is returned")
		assert_true(main.result_label.text.contains("History: " + main.history.error), "the player sees the failure")
		assert_true(main.result_label.text.contains("Space for a rematch"), "the game remains usable")
		main.free()
		DirAccess.remove_absolute(folder.path_join(blocked))
		HistoryStorage.clean(folder)
