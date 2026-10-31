extends "res://tests/run.gd".Test

# The real history store and PGN reader, with files isolated from the player's data.
const History = preload("res://core/history.gd")
const Game = preload("res://core/game.gd")
const Pgn = preload("res://core/pgn.gd")
const MainScene = preload("res://ui/main.tscn")
const Clock = preload("res://core/clock.gd")
const HistoryStorage = preload("res://tests/history_storage.gd")
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"}


func test_same_named_players_use_human_colour_for_stats_and_delete():
	var folder := _folder()
	var history = History.new(folder)
	for colour in ["w", "b"]:
		var settings := SETTINGS.duplicate()
		settings.colour = colour
		settings.player_name = "Maia 1500"
		for outcome in ["win", "loss", "draw"]:
			var game = Game.new()
			if outcome == "draw":
				game.agree_draw()
			else:
				game.flag(("b" if colour == "w" else "w") if outcome == "win" else colour)
			var path: String = history.save(game, [], settings)
			var counts := {"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0}
			counts[{"win": "wins", "loss": "losses", "draw": "draws"}[outcome]] = 1
			if outcome != "draw":
				counts["flag_wins" if outcome == "win" else "flag_losses"] = 1
			assert_eq(History.new(folder).stats("maia-1500", "3+2"), counts)
			assert_true(history.delete(path))
			assert_eq(History.new(folder).stats("maia-1500", "3+2"),
					{"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0}, colour + " " + outcome)
	HistoryStorage.clean(folder)


func test_legacy_delete_falls_back_to_you_in_either_colour():
	var folder := _folder()
	var history = History.new(folder)
	for colour in ["w", "b"]:
		var settings := SETTINGS.duplicate()
		settings.colour = colour
		var game = Game.new()
		game.flag("b" if colour == "w" else "w")
		var path: String = history.save(game, [], settings)
		var saved: Dictionary = Pgn.parse(FileAccess.get_file_as_string(path)).games[0]
		saved.headers.erase("HumanColor")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(Pgn.write(saved))
		file.close()
		assert_true(history.delete(path))
		assert_eq(History.new(folder).stats("maia-1500", "3+2"),
				{"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	HistoryStorage.clean(folder)


func test_history_shows_saved_names_and_renames_legacy_you_without_changing_pgn():
	for colour in ["w", "b"]:
		for legacy in [false, true]:
			var folder := _folder()
			DirAccess.make_dir_recursive_absolute(folder)
			var main = MainScene.instantiate()
			main.history = History.new(folder)
			main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
			main.preferences.set_value("player_name", "Current name")
			main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
			main.uci.free()
			main.uci = HeldEngine.new()
			main.maia = main.MaiaPlayer.new(main.uci)
			var settings := SETTINGS.duplicate()
			settings.colour = colour
			settings.player_name = "You" if legacy else "Maia 1500"
			var game = Game.new()
			game.flag("b" if colour == "w" else "w")
			var path: String = main.history.save(game, [], settings)
			if legacy:
				var saved: Dictionary = Pgn.parse(FileAccess.get_file_as_string(path)).games[0]
				saved.headers.erase("HumanColor")
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_string(Pgn.write(saved))
				file.close()
			var original := FileAccess.get_file_as_string(path)
			Engine.get_main_loop().root.add_child(main)
			main.get_node("Home/Center/Form/History").pressed.emit()
			var card = main.history_screen.get_node("Margin/Content/Cards/List").get_child(0)
			assert_eq(card.get_child(0).flipped, colour == "b", "thumbnail follows HumanColor")
			var displayed := "Current name" if legacy else "Maia 1500"
			var text: String = card.get_node("Details/Text").text
			assert_true(text.contains(displayed + (" (White)" if colour == "w" else " (Black)")))
			assert_true(text.contains("Won on time"), "result follows HumanColor")
			card.get_node("Details/HBoxContainer/Review").pressed.emit()
			assert_eq(main.review.get_node("Margin/Content/ReviewBody/BoardView").flipped, colour == "b")
			main.review.receive_position(0, {"pv": [{"cp": 0, "moves": ["e2e4"]}]})
			var summary: String = main.review.get_node("Margin/Content/ReviewBody/Side/Summary").text
			assert_true(summary.contains(("White: " if colour == "w" else "Black: ") + displayed))
			var copied := []
			main.review.copy_text = func(value): copied.append(value)
			main.review.get_node("Margin/Content/Actions/CopyPgn").pressed.emit()
			assert_eq(copied, [original], "export keeps the saved names too")
			assert_eq(FileAccess.get_file_as_string(path), original)
			main.free()
			HistoryStorage.clean(folder)


# Hold the external UCI reply while the real analyser, queue and screen run.
class HeldAnalysisBridge extends RefCounted:
	var engine_id := "Stockfish 19"
	var callback := Callable()
	var stops := 0
	func new_game() -> void:
		pass
	func request_search(_commands: PackedStringArray, next: Callable) -> void:
		callback = next
	func stop_search() -> void:
		stops += 1
	func answer() -> void:
		callback.call("info depth 12 multipv 1 score cp 32 pv e2e4")
		callback.call("bestmove e2e4")


class HeldAnalysis extends RefCounted:
	signal progress(done: int, total: int)
	signal finished(success: bool, error: String)
	var bridge := HeldAnalysisBridge.new()
	var analyser = preload("res://engine/analyser.gd").new(bridge)
	func _init() -> void:
		analyser.progress.connect(func(done, total): progress.emit(done, total))
		analyser.finished.connect(func(success, error): finished.emit(success, error))
	func start(path: String, maximum: bool) -> bool:
		if not FileAccess.file_exists(path):
			return false
		var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
		if not parsed.error.is_empty() or parsed.games.size() != 1:
			return false
		return analyser.analyse(analyser.positions_from_game(parsed.games[0]),
				"user://analysis".path_join(path.get_file() + ".json"), maximum)
	func cancel() -> void:
		analyser.cancel()


func test_confirm_delete_cancels_active_analysis_before_its_final_reply():
	var fixture := _queued_history()
	var path: String = fixture.paths[0]
	fixture.cards[path].get_child(1).button_pressed = true
	fixture.cards[path].get_node("Details/HBoxContainer/Delete").pressed.emit()
	fixture.screen.get_node("DeleteConfirmation").get_ok_button().pressed.emit()
	assert_true(not FileAccess.file_exists(path))
	assert_eq(fixture.screen.get_node("Margin/Content/Cards/List").get_child_count(), 0)
	_assert_pending_history(fixture, [])
	assert_eq(fixture.runner.bridge.stops, 1, "stop the search before its held reply arrives")
	fixture.runner.bridge.answer()
	assert_eq(fixture.queue.current(), "")
	var output := "user://analysis".path_join(path.get_file() + ".json")
	assert_true(not FileAccess.file_exists(output), "the final reply cannot recreate deleted analysis")
	fixture.queue._process(1.1)
	assert_true(not FileAccess.file_exists(output), "no orphan survives the missing-file scan")
	fixture.screen.get_node("Margin/Content/BatchActions").get_child(0).pressed.emit()
	_assert_pending_history(fixture, [])
	_clean_queued_history(fixture)


func test_confirm_delete_removes_waiting_game_without_cancelling_active_analysis():
	var fixture := _queued_history(2)
	var active: String = fixture.paths[0]
	var waiting: String = fixture.paths[1]
	fixture.cards[waiting].get_node("Details/HBoxContainer/Delete").pressed.emit()
	fixture.screen.get_node("DeleteConfirmation").get_ok_button().pressed.emit()
	assert_true(not FileAccess.file_exists(waiting) and FileAccess.file_exists(active))
	_assert_pending_history(fixture, [active])
	assert_eq(fixture.queue.current(), active)
	assert_eq(fixture.runner.bridge.stops, 0)
	fixture.runner.bridge.answer()
	assert_eq(fixture.queue.current(), "", "the deleted waiting game never starts")
	_assert_pending_history(fixture, [])
	assert_eq(fixture.runner.analyser.read_analysis(
			"user://analysis".path_join(active.get_file() + ".json"), "Stockfish 19", 3000000).state, "analysed")
	fixture.queue._process(1.1)
	assert_true(not FileAccess.file_exists("user://analysis".path_join(waiting.get_file() + ".json")))
	_clean_queued_history(fixture)


func test_cancel_and_failed_delete_preserve_active_analysis_and_stats():
	var fixture := _queued_history()
	var path: String = fixture.paths[0]
	var counts: Dictionary = fixture.history.stats("maia-1500", "3+2")
	var button = fixture.cards[path].get_node("Details/HBoxContainer/Delete")
	var dialog = fixture.screen.get_node("DeleteConfirmation")
	button.pressed.emit()
	dialog.get_cancel_button().pressed.emit()
	assert_true(FileAccess.file_exists(path))
	_assert_pending_history(fixture, [path])
	assert_eq(fixture.queue.current(), path)
	assert_eq(fixture.runner.bridge.stops, 0)
	assert_eq(History.new(fixture.folder).stats("maia-1500", "3+2"), counts)
	var temporary: String = fixture.folder.path_join("stats.cfg.deleting")
	assert_eq(DirAccess.make_dir_absolute(temporary), OK)
	button.pressed.emit()
	dialog.get_ok_button().pressed.emit()
	assert_true(FileAccess.file_exists(path))
	assert_true(not fixture.history.error.is_empty())
	assert_true(fixture.screen.get_node("DeleteError").visible)
	assert_eq(fixture.screen.get_node("DeleteError").dialog_text, fixture.history.error)
	assert_eq(fixture.screen.get_node("Margin/Content/Cards/List").get_child_count(), 1)
	_assert_pending_history(fixture, [path])
	assert_eq(fixture.queue.current(), path)
	assert_eq(fixture.runner.bridge.stops, 0, "a failed deletion must leave analysis running")
	for store in [fixture.history, History.new(fixture.folder)]:
		assert_eq(store.stats("maia-1500", "3+2"), counts)
	fixture.runner.bridge.answer()
	_assert_pending_history(fixture, [])
	assert_eq(fixture.runner.analyser.read_analysis(
			"user://analysis".path_join(path.get_file() + ".json"), "Stockfish 19", 3000000).state, "analysed")
	_clean_queued_history(fixture)


func _queued_history(count := 1) -> Dictionary:
	var folder := _folder()
	var history = History.new(folder)
	var runner := HeldAnalysis.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	var paths := []
	for i in count:
		var game = Game.new()
		game.resign("w")
		var path: String = history.save(game, [], SETTINGS)
		assert_true(not path.is_empty())
		paths.append(path)
		queue.enqueue(path)
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, load("res://core/settings.gd").new(folder.path_join("settings.cfg")))
	var cards := {}
	var records: Array = history.games()
	for i in records.size():
		cards[records[i].path] = screen.get_node("Margin/Content/Cards/List").get_child(i)
	assert_eq(queue.current(), paths[0])
	assert_eq(queue.pending(), paths)
	return {"folder": folder, "history": history, "runner": runner, "queue": queue,
			"paths": paths, "screen": screen, "cards": cards}


func _assert_pending_history(fixture: Dictionary, expected: Array) -> void:
	assert_eq(fixture.queue.pending(), expected)
	var reloaded = load("res://core/analysis_queue.gd").new(null, fixture.folder.path_join("queue.cfg"))
	assert_eq(reloaded.pending(), expected, "persist the queue immediately")
	reloaded.free()


func _clean_queued_history(fixture: Dictionary) -> void:
	fixture.screen.free()
	fixture.queue.free()
	fixture.runner.analyser.free()
	for path: String in fixture.paths:
		var output := "user://analysis".path_join(path.get_file() + ".json")
		if FileAccess.file_exists(output):
			DirAccess.remove_absolute(output)
	HistoryStorage.clean(fixture.folder)


func test_history_delete_requires_confirmation():
	var folder := _folder()
	var history = History.new(folder)
	var game = Game.new()
	game.resign("w")
	var path: String = history.save(game, [], SETTINGS)
	var screen = load("res://ui/history_screen.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, load("res://core/settings.gd").new(folder.path_join("settings.cfg")))
	var list = screen.get_node("Margin/Content/Cards/List")
	var button = list.get_child(0).get_node_or_null("Details/HBoxContainer/Delete")
	assert_true(button != null)
	if button != null:
		button.pressed.emit()
		var dialog = screen.get_node("DeleteConfirmation")
		assert_true(dialog.visible and FileAccess.file_exists(path))
		dialog.canceled.emit()
		assert_true(FileAccess.file_exists(path) and list.get_child_count() == 1)
		button.pressed.emit()
		dialog.confirmed.emit()
		assert_true(not FileAccess.file_exists(path) and list.get_child_count() == 0)
	screen.free()
	HistoryStorage.clean(folder)


func test_delete_removes_files_and_reverses_targeted_flag_win():
	var folder := _folder()
	var history = History.new(folder)
	var game = Game.new()
	game.flag("b")
	var path: String = history.save(game, [], SETTINGS, "", "line-1")
	var snapshot := path.trim_suffix(".pgn") + ".repertoire.json"
	var file := FileAccess.open(snapshot, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	DirAccess.make_dir_recursive_absolute("user://analysis")
	var analysis := "user://analysis".path_join(path.get_file() + ".json")
	file = FileAccess.open(analysis, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	assert_true(history.delete(path))
	assert_true(not FileAccess.file_exists(path) and not FileAccess.file_exists(snapshot) and not FileAccess.file_exists(analysis))
	assert_eq(History.new(folder).stats("maia-1500", "3+2"), {"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	assert_eq(History.new(folder).practice_counts().get("line-1"), 0)
	HistoryStorage.clean(folder)


func test_delete_legacy_and_failure_preserve_practice_and_never_go_negative():
	var folder := _folder()
	var history = History.new(folder)
	var game = Game.new()
	game.resign("w")
	var path: String = history.save(game, [], SETTINGS, "", "line-1")
	var legacy: String = history.save(game, [], SETTINGS)
	assert_true(not history.delete(folder.path_join("missing.pgn")))
	assert_true(not history.error.is_empty())
	assert_eq(history.stats("maia-1500", "3+2").losses, 2)
	assert_true(history.delete(legacy))
	assert_eq(history.practice_counts().get("line-1"), 1)
	assert_true(history.delete(path))
	assert_true(not history.delete(path))
	assert_eq(history.stats("maia-1500", "3+2").losses, 0)
	assert_eq(history.practice_counts().get("line-1"), 0)
	HistoryStorage.clean(folder)


func test_delete_restores_files_when_final_removal_fails():
	_check_delete_rollback("removal")


func test_delete_restores_files_and_counts_when_stats_save_fails():
	_check_delete_rollback("stats")


func _check_delete_rollback(failure: String) -> void:
	var folder := _folder()
	var history = History.new(folder)
	var game = Game.new()
	game.flag("b")
	var path: String = history.save(game, [], SETTINGS, "", "line-1")
	var snapshot := path.trim_suffix(".pgn") + ".repertoire.json"
	DirAccess.make_dir_recursive_absolute("user://analysis")
	var analysis := "user://analysis".path_join(path.get_file() + ".json")
	for item in [snapshot, analysis]:
		var file := FileAccess.open(item, FileAccess.WRITE)
		file.store_string("original " + item.get_file())
		file.close()
	var paths := [path, snapshot, analysis]
	var contents := {}
	for item in paths:
		contents[item] = FileAccess.get_file_as_bytes(item)
	var temp := folder.path_join("stats.cfg.deleting")
	if failure == "removal":
		assert_eq(FileAccess.set_read_only_attribute(analysis, true), OK)
	else:
		assert_eq(DirAccess.make_dir_absolute(temp), OK)
	assert_true(not history.delete(path), "delete must report the injected failure")
	assert_true(not history.error.is_empty())
	var expected := {"wins": 1, "draws": 0, "losses": 0, "flag_wins": 1, "flag_losses": 0}
	for store in [history, History.new(folder)]:
		assert_eq(store.stats("maia-1500", "3+2"), expected)
		assert_eq(store.practice_counts().get("line-1"), 1)
	for item in paths:
		assert_true(FileAccess.file_exists(item), "original file restored: " + item)
		assert_eq(FileAccess.get_file_as_bytes(item), contents[item])
		assert_true(not FileAccess.file_exists(item + ".deleting"))
	for item in [analysis, analysis + ".deleting"]:
		if FileAccess.file_exists(item):
			FileAccess.set_read_only_attribute(item, false)
			DirAccess.remove_absolute(item)
	if DirAccess.dir_exists_absolute(temp):
		DirAccess.remove_absolute(temp)
	assert_true(not FileAccess.file_exists(temp))
	HistoryStorage.clean(folder)


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
		level_ready.emit()


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
	await main._start(settings.duplicate())
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
		var main = await _session(folder, time)
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
				"Result": "0-1", "Termination": "Normal", "Reason": "checkmate", "HumanColor": "w"})
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
	var main = await _session(folder, time)
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
	await _wait_start(main)
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
				"Result": "0-1", "Termination": "Normal", "Reason": "resignation", "HumanColor": "b", "Opening": "Bird Opening"})
	HistoryStorage.clean(folder)


func test_main_saves_a_clock_flag_once_and_keeps_move_time_snapshots():
	var folder := _folder()
	var time := FakeTime.new()
	var main = await _session(folder, time)
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
	var main = await _session(folder, time)
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
	var main = await _session(folder, time, settings)
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
		var main = await _session(folder, time)
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
		var main = await _session(folder, time)
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


# Starts now cross a real asynchronous searching screen.
func _wait_start(main) -> void:
	while main._starting:
		await Engine.get_main_loop().process_frame
