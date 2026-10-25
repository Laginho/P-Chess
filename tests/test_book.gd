extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const Game = preload("res://core/game.gd")
const History = preload("res://core/history.gd")
const Pgn = preload("res://core/pgn.gd")
const MaiaPlayer = preload("res://bot/maia_player.gd")
const Settings = preload("res://core/settings.gd")
const MainScene = preload("res://ui/main.tscn")
const CATALOG := "eco\tname\tpgn\n" \
		+ "A04\tTarget\t1. Nf3 Nf6 2. g3 g6 3. Bg2 Bg7\n" \
		+ "A04\tOther\t1. Nf3 Nf6 2. g3 g6 3. d3 d6\n" \
		+ "A04\tUnchecked\t1. Nf3 Nf6 2. g3 g6 3. c4 c5\n"
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Catalog"}


func _sample():
	var book = Book.new()
	book.load_tsv(CATALOG)
	book.set_checked("Target", true)
	book.set_checked("Other", true)
	assert_eq(book.errors, [])
	return book


func _game(moves: Array):
	var game = Game.new()
	for move in moves:
		assert_true(game.play(move), move)
	return game


func test_checked_moves_receive_target_and_other_weights_with_game_ply_fade():
	var book = _sample()
	assert_true(book.has_method("begin_game"), "the book chooses a target at game start")
	if not book.has_method("begin_game"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	book.begin_game({book.entries[1].id: 4}, rng)
	var game = _game(["g1f3", "g8f6", "g2g3", "g7g6"])
	for intensity in {"weak": [5.0, 2.0, 3.0, 1.5],
			"medium": [20.0, 5.0, 10.5, 3.0], "strong": [100.0, 15.0, 50.5, 8.0]}:
		var expected: Array = {"weak": [5.0, 2.0, 3.0, 1.5],
				"medium": [20.0, 5.0, 10.5, 3.0], "strong": [100.0, 15.0, 50.5, 8.0]}[intensity]
		for ply in [4, 6, 11, 16, 18]:
			var weights: Dictionary = book.weights(game.board, ply, intensity)
			assert_eq(weights.size(), game.board.legal_moves().size(), "one weight per legal move")
			assert_eq(weights.f1g2, expected[0] if ply <= 6 else (expected[2] if ply == 11 else 1.0))
			assert_eq(weights.d2d3, expected[1] if ply <= 6 else (expected[3] if ply == 11 else 1.0))
			assert_eq(weights.c2c4, 1.0, "unchecked line")
			assert_eq(weights.b1c3, 1.0, "off-book legal move")


func test_target_uses_minimum_counts_seeded_ties_and_maias_repertoire_side():
	var book = _sample()
	var rng := RandomNumberGenerator.new()
	var first: String = book.entries[0].id
	var second: String = book.entries[1].id
	assert_eq(book.begin_game({first: 9, second: 2}, rng), second)
	var chosen := {}
	for seed_value in 40:
		rng.seed = seed_value
		var target: String = book.begin_game({}, rng)
		rng.seed = seed_value
		assert_eq(book.begin_game({}, rng), target, "seeded ties repeat")
		chosen[target] = true
	assert_eq(chosen.size(), 2, "ties sample both checked lines")
	book.entries[0]["colour"] = "w"
	book.entries[1]["colour"] = "b"
	assert_eq(book.begin_game({}, rng, "b"), second, "only Maia's repertoire side")
	book.set_checked("Other", false)
	assert_eq(book.begin_game({}, rng, "b"), "", "no eligible target")
	for weight in book.weights(Game.new().board, 0).values():
		assert_eq(weight, 1.0, "empty selection stays free")


func test_position_matching_allows_transpositions_and_reentry_with_the_actual_ply():
	var book = _sample()
	book.begin_game({book.entries[1].id: 2}, RandomNumberGenerator.new())
	var game = _game(["g2g3", "g7g6", "g1f3", "g8f6"])
	assert_eq(book.weights(game.board, game.moves.size()).f1g2, 20.0, "different move order")
	game.play("b1c3")
	for weight in book.weights(game.board, game.moves.size()).values():
		assert_eq(weight, 1.0, "no checked continuation")
	for move in ["b8c6", "c3b1", "c6b8"]:
		assert_true(game.play(move))
	assert_true(is_equal_approx(book.weights(game.board, game.moves.size()).f1g2, 16.2), "ply 8, not line ply 4")


func _folder() -> String:
	return "user://test_book_%d" % Time.get_ticks_usec()


func _clean(folder: String) -> void:
	for subdir in [folder.path_join("games"), folder.path_join("openings"), folder]:
		if DirAccess.dir_exists_absolute(subdir):
			for file in DirAccess.get_files_at(subdir):
				DirAccess.remove_absolute(subdir.path_join(file))
			DirAccess.remove_absolute(subdir)


func test_finished_games_persist_target_practice_counts_without_changing_result_stats():
	var folder := _folder()
	var history = History.new(folder)
	assert_true(history.has_method("practice_counts"), "practice is persisted with history stats")
	if not history.has_method("practice_counts"):
		return
	var target: String = _sample().entries[0].id
	assert_eq(history.practice_counts(), {})
	var game = Game.new()
	assert_eq(history.call("save", game, [], SETTINGS, "", target), "", "unfinished games don't count")
	assert_eq(history.practice_counts(), {})
	game.resign("w")
	assert_true(not history.call("save", game, [], SETTINGS, "", target).is_empty(), history.error)
	assert_eq(History.new(folder).practice_counts(), {target: 1})
	assert_eq(History.new(folder).stats("maia-1500", "3+2").losses, 1)
	assert_true(not history.save(game, [], SETTINGS).is_empty(), "Free has no target")
	assert_eq(History.new(folder).practice_counts(), {target: 1})
	_clean(folder)


func test_corrupt_practice_counts_report_zero_and_allow_target_selection():
	var book = _sample()
	var target: String = book.entries[0].id
	var other: String = book.entries[1].id
	var unchecked: String = book.entries[2].id
	for invalid in ["invalid", "4", -1, 1.0, 1.5, true, false, [], {}]:
		var folder := _folder()
		assert_eq(DirAccess.make_dir_recursive_absolute(folder), OK)
		var stored := ConfigFile.new()
		stored.set_value("practice", target, invalid)
		stored.set_value("practice", other, 4)
		stored.set_value("practice", unchecked, 0)
		assert_eq(stored.save(folder.path_join("stats.cfg")), OK)
		var history = History.new(folder)
		var counts: Dictionary = history.practice_counts()
		assert_eq(counts, {target: 0, other: 4, unchecked: 0}, var_to_str(invalid))
		assert_true(history.error.contains("Corrupt") and history.error.contains("practice/" + target),
				"report the corrupt practice id through the shared history warning")
		assert_eq(book.begin_game(counts, RandomNumberGenerator.new()), target,
				"the corrupt count is zero when choosing the least-practiced line")
		var warning: String = history.error
		assert_eq(history.practice_counts(), counts)
		assert_eq(history.error, warning, "reading again does not duplicate the warning")
		_clean(folder)


class FakeBridge:
	signal policy_ready(policy: Dictionary)
	var immediate := true
	var requests := []
	var policy := {"e2e4": 0.995, "g1f3": 0.005}


	func request_policy(fen: String, moves: PackedStringArray) -> void:
		requests.append([fen, moves])
		if immediate:
			policy_ready.emit(policy)


func test_maia_weights_before_the_cut_and_free_never_samples_the_half_percent_move():
	var bridge := FakeBridge.new()
	var maia = MaiaPlayer.new(bridge)
	assert_true("book_intensity" in maia, "Maia accepts book settings")
	if not "book_intensity" in maia:
		return
	maia.book = _sample()
	maia.book_intensity = "strong"
	var played := []
	maia.move_ready.connect(func(move): played.append(move))
	for mode in ["Catalog", "Free"]:
		played.clear()
		for seed_value in 1000:
			maia.rng.seed = seed_value
			var game = Game.new()
			maia.call("begin_game", game, mode, {}, "w")
			maia.think(game)
		assert_eq(played.size(), 1000, "one first move per seeded game")
		assert_true(played.count("g1f3") > 0 if mode == "Catalog" else played.count("g1f3") == 0, mode)
	# A delayed reply uses its request's intensity; obsolete games still consume FIFO replies.
	bridge.immediate = false
	var game = Game.new()
	maia.call("begin_game", game, "Catalog", {}, "w")
	maia.book_intensity = "strong"
	maia.think(game)
	maia.call("begin_game", Game.new())
	var before := played.size()
	bridge.policy_ready.emit(bridge.policy)
	assert_eq(played.size(), before, "stale policy is dropped")
	var seen := {}
	for seed_value in 80:
		maia.rng.seed = seed_value
		game = Game.new()
		maia.call("begin_game", game, "Catalog", {}, "w")
		maia.book_intensity = "strong"
		maia.think(game)
		maia.book_intensity = "weak"
		bridge.policy_ready.emit(bridge.policy)
		seen[played[-1]] = true
	assert_true(seen.has("g1f3"), "request snapshots strong weights before a later setting change")


func test_book_intensity_defaults_persists_validates_and_has_a_working_settings_row():
	assert_true(Settings.DEFAULTS.has("book_intensity"), "book intensity is a stored setting")
	if not Settings.DEFAULTS.has("book_intensity"):
		return
	var folder := _folder()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("settings.cfg")
	var store = Settings.new(path)
	assert_eq(store.get_value("book_intensity"), "medium")
	assert_true(not store.set_value("book_intensity", "extreme"))
	var screen = load("res://ui/settings.tscn").instantiate()
	screen.store = store
	Engine.get_main_loop().root.add_child(screen)
	var rows: Array = screen.get_node("Panel/Center/Box/Form").get_children()
	var choice: OptionButton
	for index in rows.size():
		if rows[index] is Label and rows[index].text == "Book intensity":
			choice = rows[index + 1]
	assert_true(choice != null, "visible book intensity row")
	if choice != null:
		assert_eq(choice.get_item_text(choice.selected), "medium")
		choice.select(2)
		choice.item_selected.emit(2)
		assert_eq(Settings.new(path).get_value("book_intensity"), "strong")
	screen.free()
	_clean(folder)


func test_opening_header_names_only_the_deepest_catalog_endpoint_reached_in_any_mode():
	var book = _sample()
	assert_true(book.has_method("opening_name"), "catalog recognition is independent of checked lines")
	if not book.has_method("opening_name"):
		return
	book.load_tsv("eco\tname\tpgn\nA04\tReti\t1. Nf3\n")
	var game = _game(["g2g3", "g7g6", "g1f3", "g8f6", "f1g2", "f8g7"])
	# The final position transposes into Target; it must beat the shorter Reti name.
	assert_eq(book.opening_name(game.moves), "Target")
	var partial = _game(["g1f3", "g8f6", "g2g3", "g7g6"])
	assert_eq(book.opening_name(partial.moves), "Reti", "future Target endpoint was never reached")
	assert_eq(book.opening_name(PackedStringArray(["e2e4"])), "")
	assert_eq(book.opening_name(PackedStringArray()), "")
	assert_true(game.play("b1c3"))
	game.resign("w")
	var folder := _folder()
	var history = History.new(folder)
	history.book = book
	for mode in ["Catalog", "Free", "My repertoire"]:
		var settings := SETTINGS.duplicate()
		settings.opening = mode
		var path: String = history.save(game, [1, 2, 3, 4, 5, 6, 7], settings)
		assert_true(not path.is_empty(), history.error)
		var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
		assert_eq(parsed.games[0].headers.get("Opening"), "Target", mode)
	_clean(folder)


class HeldEngine extends "res://engine/uci.gd":
	var requests := []


	func start(_dirs := PackedStringArray()) -> bool:
		return true


	func set_level(_net_path: String) -> void:
		pass


	func request_policy(_fen: String, moves: PackedStringArray) -> void:
		requests.append(moves.duplicate())


func _session(folder: String, book):
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.history = History.new(folder)
	main.preferences = Settings.new(folder.path_join("settings.cfg"))
	book.selection_dir = folder.path_join("openings")
	main.get_node("Setup").book = book
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = MaiaPlayer.new(main.uci)
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__book_silent__")
	return main


func _saved_games(folder: String) -> Array:
	var games := []
	for file in DirAccess.get_files_at(folder.path_join("games")):
		var parsed := Pgn.parse(FileAccess.get_file_as_string(folder.path_join("games").path_join(file)))
		assert_eq(parsed.error, "")
		games.append_array(parsed.games)
	return games


func test_main_uses_named_selection_counts_once_rematches_and_recognizes_free_openings():
	var folder := _folder()
	var book = _sample()
	var main = _session(folder, book)
	book.set_checked("Other", false)
	assert_eq(book.save_selection("Practice"), "")
	book.set_checked("Target", false)
	book.set_checked("Other", true)
	var settings := SETTINGS.duplicate()
	settings.selection = "Practice"
	main.setup.started.emit(settings)
	assert_eq(main.maia.target_id, book.entries[0].id, "load the saved name, not residual picker checks")
	assert_true(main.maia.book == book, "one shared catalog")
	assert_true(main.preferences.set_value("book_intensity", "strong"))
	assert_eq(main.maia.book_intensity, "strong", "live preference routing")
	for move in ["g1f3", "g8f6", "g2g3", "g7g6", "f1g2", "f8g7"]:
		assert_true(main.board_view.play(move))
	main.board_view.game.resign("w")
	main._show_result()
	main._show_result()
	assert_eq(History.new(folder).practice_counts(), {book.entries[0].id: 1})
	var games := _saved_games(folder)
	assert_eq(games.size(), 1, "terminal callbacks save exactly once")
	assert_eq(games[0].headers.get("Opening"), "Target")
	book.set_checked("Other", true)
	assert_eq(book.save_selection("Practice"), "")
	main._start(main.rematch(main.settings))
	assert_eq(main.human, "b")
	assert_eq(main.maia.target_id, book.entries[1].id, "rematch uses persisted least-practiced target")
	assert_eq(main.uci.requests[-1], PackedStringArray(), "Maia now plays White first")
	main.board_view.game.resign("b")
	main._show_result()
	var counts: Dictionary = History.new(folder).practice_counts()
	assert_eq(counts, {book.entries[0].id: 1, book.entries[1].id: 1})
	settings.opening = "Free"
	main._start(settings)
	assert_eq(main.maia.target_id, "", "Free clears the previous target")
	for move in ["g1f3", "g8f6", "g2g3", "g7g6", "f1g2", "f8g7"]:
		assert_true(main.board_view.play(move))
	main.board_view.game.resign("w")
	main._show_result()
	assert_eq(History.new(folder).practice_counts(), counts, "Free doesn't increment a target")
	games = _saved_games(folder)
	assert_eq(games.size(), 3)
	assert_eq(games.filter(func(game): return game.headers.get("Opening") == "Target").size(), 2,
			"both Catalog and Free recognize the opening")
	main.free()
	_clean(folder)


# The external catalog I/O boundary is held by semaphores, without timing assumptions.
class DelayedBook extends "res://bot/book.gd":
	var entered := Semaphore.new()
	var release := Semaphore.new()
	var loads := 0


	func load_catalog(_folder := "res://data/openings") -> void:
		loads += 1
		entered.post()
		release.wait()
		load_tsv(CATALOG)


func _watch_catalog(picker, ready: Array) -> void:
	ready.append(await picker.ensure_catalog())


func test_cold_main_and_picker_share_one_loader_and_wait_responsively_before_start():
	var folder := _folder()
	var book := DelayedBook.new()
	var main = _session(folder, book)
	var picker = main.setup.get_node("OpeningPicker")
	assert_true(picker.has_method("ensure_catalog"), "public shared catalog readiness")
	if not picker.has_method("ensure_catalog"):
		main.free()
		_clean(folder)
		return
	var selection = _sample()
	selection.selection_dir = book.selection_dir
	selection.set_checked("Other", false)
	assert_eq(selection.save_selection("Practice"), "")
	var settings := SETTINGS.duplicate()
	settings.colour = "b"
	settings.selection = "Practice"
	main.setup.started.emit(settings)
	book.entered.wait()
	assert_eq(main.clock, null, "no clock during loading")
	assert_eq(main.uci.requests.size(), 0, "no engine request during loading")
	assert_eq(main.board_view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the waiting board cannot play before a clock exists")
	assert_true(main.result_label.text.contains("Loading"), "visible loading status")
	assert_true(not picker.visible, "starting a game doesn't open the picker")
	var ready := []
	_watch_catalog(picker, ready)
	_watch_catalog(picker, ready)
	main._process(0)
	picker._process(0)
	assert_eq(ready.size(), 0, "responsiveness doesn't publish a partly loaded catalog")
	book.release.post()
	var deadline := Time.get_ticks_msec() + 5000
	while ready.size() < 2 and Time.get_ticks_msec() < deadline:
		picker._process(0)
		OS.delay_msec(1)
	assert_eq(ready, ["", ""], "all waiters resume after joining one worker")
	assert_eq(book.loads, 1)
	assert_true(main.clock != null)
	assert_eq(main.uci.requests.size(), 1)
	assert_eq(main.maia.target_id, book.entries[0].id, "cold start loads current saved selection")
	_watch_catalog(picker, ready)
	assert_eq(ready.size(), 3, "already loaded readiness completes immediately")
	assert_eq(book.loads, 1)
	main.free()
	_clean(folder)


func test_main_joins_a_picker_load_without_applying_its_old_selection_and_rejects_a_bad_save_name():
	var folder := _folder()
	var book := DelayedBook.new()
	var main = _session(folder, book)
	var picker = main.setup.get_node("OpeningPicker")
	var selection = _sample()
	selection.selection_dir = book.selection_dir
	selection.set_checked("Other", false)
	assert_eq(selection.save_selection("Current"), "")
	selection.set_checked("Target", false)
	selection.set_checked("Other", true)
	assert_eq(selection.save_selection("Old"), "")
	picker.present("Old")
	picker.hide()
	book.entered.wait()
	var settings := SETTINGS.duplicate()
	settings.selection = "Current"
	main.setup.started.emit(settings)
	assert_eq(main.clock, null)
	book.release.post()
	var ready := []
	_watch_catalog(picker, ready)
	var deadline := Time.get_ticks_msec() + 5000
	while ready.is_empty() and Time.get_ticks_msec() < deadline:
		picker._process(0)
		OS.delay_msec(1)
	assert_eq(ready, [""])
	assert_eq(book.loads, 1)
	assert_eq(main.maia.target_id, book.entries[0].id, "Main loads its own saved selection after joining")
	assert_eq(book.selected_ids(), [book.entries[0].id], "hidden picker's old name is not loaded")
	assert_eq(main.board_view.mouse_filter, Control.MOUSE_FILTER_STOP, "input resumes when ready")
	main.board_view.game.resign("w")
	main._show_result()
	settings.selection = "missing"
	var requests: int = main.uci.requests.size()
	main.setup.started.emit(settings)
	assert_true(main.setup.visible, "invalid saved selection returns to setup")
	assert_eq(main.uci.requests.size(), requests)
	assert_true(main.board_view.game.is_over(), "failed Catalog start doesn't create a free game")
	main.free()
	_clean(folder)


func test_loader_startup_failure_reports_an_error_without_a_game_and_allows_retry():
	var folder := _folder()
	var book = Book.new()
	var main = _session(folder, book)
	var picker = main.setup.get_node("OpeningPicker")
	assert_true("start_catalog_worker" in picker, "thread-start system boundary can report failure")
	if not "start_catalog_worker" in picker:
		main.free()
		_clean(folder)
		return
	picker.start_catalog_worker = func(_worker, _load): return ERR_CANT_CREATE
	var settings := SETTINGS.duplicate()
	settings.opening = "Free"
	settings.colour = "b"
	main.setup.started.emit(settings)
	assert_eq(main.clock, null)
	assert_eq(main.uci.requests.size(), 0)
	assert_true(main.setup.visible, "setup remains available to retry")
	var status: Label = main.setup.get_node("Center/Form/Missing")
	assert_true(status.visible and status.text.contains("Cannot start catalog loading"))
	book.load_tsv(CATALOG)
	main.setup.started.emit(settings)
	assert_true(main.clock != null, "a corrected retry starts")
	assert_eq(main.uci.requests.size(), 1)
	assert_eq(main.maia.target_id, "", "Free mode stays free after a load error")
	main.free()
	_clean(folder)
