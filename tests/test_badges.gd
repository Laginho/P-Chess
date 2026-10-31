extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const Game = preload("res://core/game.gd")
const Repertoire = preload("res://bot/repertoire.gd")
const Settings = preload("res://core/settings.gd")
const MainScene = preload("res://ui/main.tscn")
const History = preload("res://core/history.gd")
const STUDY := "1. e4 e5 2. Nf3 (2. Nc3) Nc6 *"
const CATALOG := "eco\tname\tpgn\nC00\tFixture\t1. e4 e5 2. Nf3 Nc6\n"
const CONFIG := {"colour": "w", "level": "maia-1500", "control": "3+2",
		"opening": "Free", "repertoire": "Study", "selection": "Fixture"}


class HeldEngine extends "res://engine/uci.gd":
	var requests := []


	func start(_dirs := PackedStringArray()) -> bool:
		return true


	func set_level(_net_path: String) -> void:
		level_ready.emit()


	func request_policy(_fen: String, moves: PackedStringArray) -> void:
		requests.append(moves.duplicate())


# Hold catalog I/O at the worker boundary so Settings can change during the real await.
class DelayedBook extends "res://bot/book.gd":
	var entered := Semaphore.new()
	var release := Semaphore.new()


	func load_catalog(_folder := "res://data/openings") -> void:
		entered.post()
		release.wait()
		load_tsv(CATALOG)


func _session(folder: String, book = null):
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.history = History.new(folder)
	main.preferences = Settings.new(folder.path_join("settings.cfg"))
	var setup = main.get_node("Setup")
	if book != null:
		setup.book = book
	setup.book.selection_dir = folder.path_join("openings")
	if book == null:
		setup.book.load_tsv(CATALOG)
		setup.book.set_checked("Fixture", true)
		assert_eq(setup.book.save_selection("Fixture"), "")
	setup.repertoire.storage_dir = folder.path_join("repertoires")
	assert_eq(setup.repertoire.import_pgn(STUDY, "w", "Study"), "")
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__badges_silent__")
	return main


func _marks(main, ply: int) -> String:
	var tree: Tree = main.review.get_node("Margin/Content/ReviewBody/Side/Moves")
	assert_eq(tree.columns, 3, "review has move number and both sides")
	if tree.columns < 3:
		return ""
	var rows := tree.get_root().get_children()
	assert_true(rows.size() > ply / 2, "review contains the fixture move")
	return rows[ply / 2].get_tooltip_text(1 + ply % 2) if rows.size() > ply / 2 else ""


func _finish(main) -> void:
	main.board_view.game.resign(main.human)
	main._show_result()
	main.board_view.get_node("GameOver/Panel/Content/Review").pressed.emit()


func _folder() -> String:
	return "user://test_badges_%d" % Time.get_ticks_usec()


func _clean(folder: String) -> void:
	for subdir in [folder.path_join("games"), folder.path_join("openings"),
			folder.path_join("repertoires"), folder]:
		if DirAccess.dir_exists_absolute(subdir):
			for file in DirAccess.get_files_at(subdir):
				DirAccess.remove_absolute(subdir.path_join(file))
			DirAccess.remove_absolute(subdir)


func _badges():
	var path := "res://bot/badges.gd"
	assert_true(ResourceLoader.exists(path), "the production review badge function exists")
	return load(path) if ResourceLoader.exists(path) else null


func _game(moves: Array):
	var game = Game.new()
	for move in moves:
		assert_true(game.play(move), "legal fixture move: " + move)
	return game


func test_book_uses_unchecked_catalog_lines_and_never_resumes_after_exit():
	var badges = _badges()
	if badges == null:
		return
	var catalog = Book.new()
	catalog.load_tsv("eco\tname\tpgn\nA04\tReti\t1. Nf3 Nf6 2. d4 d5\nB00\tKing pawn\t1. e4 e5\n")
	assert_eq(catalog.selected_ids(), [], "all catalog entries are unchecked")
	var game = _game(["g1f3", "g8f6", "f3g1", "f6g8", "e2e4"])
	var before: String = game.board.to_fen()
	var entries: Array = catalog.entries.duplicate(true)
	var result: Array = badges.evaluate(game.moves, catalog.entries, [], "w", false)
	assert_eq(result.map(func(mark): return mark.book), [true, true, false, false, false])
	assert_eq(result.map(func(mark): return mark.repertoire), [false, false, false, false, false])
	assert_eq(game.board.to_fen(), before, "review leaves the game unchanged")
	assert_eq(catalog.entries, entries, "review leaves the catalog unchanged")
	assert_eq(badges.evaluate(PackedStringArray(), catalog.entries, [], "w", false), [])
	assert_eq(badges.evaluate(PackedStringArray(["e2e4"]), [], [], "w", false)[0].book, false)


func test_repertoire_marks_only_human_moves_until_first_exit_and_lists_distinct_san():
	var badges = _badges()
	if badges == null:
		return
	var repertoire = Repertoire.new()
	assert_eq(repertoire.parse("1. e4 e5 2. Nf3 (2. Nc3) Nc6 *\n\n1. e4 e5 2. Nf3 Nf6 *", "w"), "")
	var game = _game(["e2e4", "e7e5", "d2d4", "b8c6", "g1f3"])
	var lines: Array = repertoire.lines.duplicate(true)
	var result: Array = badges.evaluate(game.moves, [], repertoire.lines, "w", true)
	assert_eq(result.map(func(mark): return mark.repertoire), [true, false, false, false, false])
	assert_eq(result.map(func(mark): return mark.left_repertoire), [false, false, true, false, false])
	assert_eq(result[2].expected, PackedStringArray(["Nc3", "Nf3"]), "all distinct PGN alternatives in SAN")
	assert_eq(result[0].expected, PackedStringArray())
	assert_eq(repertoire.lines, lines, "review leaves the repertoire unchanged")
	var off: Array = badges.evaluate(game.moves, [], repertoire.lines, "w", false)
	assert_eq(off.map(func(mark): return mark.repertoire or mark.left_repertoire), [false, false, false, false, false])


func test_opponent_deviation_and_pgn_leaf_report_no_continuation_only_on_human_turn():
	var badges = _badges()
	if badges == null:
		return
	for pgn in ["1. e4 e5 2. Nf3 *", "1. e4 *"]:
		var repertoire = Repertoire.new()
		assert_eq(repertoire.parse(pgn, "w"), "")
		var game = _game(["e2e4", "c7c5", "g1f3", "d7d6", "d2d4"])
		var result: Array = badges.evaluate(game.moves, [], repertoire.lines, "w", true)
		assert_eq(result.map(func(mark): return mark.repertoire), [true, false, false, false, false])
		assert_eq(result.map(func(mark): return mark.left_repertoire), [false, false, true, false, false])
		assert_eq(result[2].expected, PackedStringArray(), "no invented expected move")
	var game = _game(["e2e4", "e7e5"])
	var absent: Array = badges.evaluate(game.moves, [], [], "w", true)
	assert_eq(absent.map(func(mark): return mark.left_repertoire), [false, false], "no selected repertoire is not an exit")


func test_repertoire_uses_actual_black_side_and_transposed_positions():
	var badges = _badges()
	if badges == null:
		return
	var repertoire = Repertoire.new()
	assert_eq(repertoire.parse("1. Nf3 Nf6 2. g3 g6 3. Bg2 Bg7 *", "w"), "")
	var game = _game(["g2g3", "g7g6", "g1f3", "g8f6", "f1g2", "f8g7"])
	var result: Array = badges.evaluate(game.moves, [], repertoire.lines, "b", true)
	# Cover the alternate move order up to Nf6. The final Bg7 must then match the
	# first chapter by position despite having arrived through the second chapter.
	assert_true(result[1].left_repertoire)
	assert_eq(repertoire.parse("1. Nf3 Nf6 2. g3 g6 3. Bg2 Bg7 *\n\n1. g3 g6 2. Nf3 Nf6 *", "w"), "")
	result = badges.evaluate(game.moves, [], repertoire.lines, "b", true)
	assert_eq(result.map(func(mark): return mark.repertoire), [false, true, false, true, false, true])
	assert_eq(result.map(func(mark): return mark.left_repertoire), [false, false, false, false, false, false])


func test_check_setting_is_off_by_default_persists_and_is_editable_on_settings_screen():
	assert_true(Settings.DEFAULTS.has("check_repertoire"), "check-my-moves is a stored setting")
	if not Settings.DEFAULTS.has("check_repertoire"):
		return
	var folder := _folder()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("settings.cfg")
	var store = Settings.new(path)
	assert_eq(store.get_value("check_repertoire"), false)
	var screen = load("res://ui/settings.tscn").instantiate()
	screen.store = store
	Engine.get_main_loop().root.add_child(screen)
	var form = screen.get_node("Panel/Center/Box/Form")
	var toggle: CheckBox
	for i in form.get_child_count():
		var child = form.get_child(i)
		if child is Label and child.text == "Check my moves against my repertoire":
			toggle = form.get_child(i + 1)
	assert_true(toggle != null, "the setting is visible and editable")
	if toggle != null:
		assert_true(not toggle.button_pressed)
		toggle.button_pressed = true
		assert_eq(Settings.new(path).get_value("check_repertoire"), true)
		assert_true(not store.set_value("check_repertoire", "yes"), "only booleans are accepted")
	screen.free()
	_clean(folder)


func test_setup_selects_check_repertoire_in_every_mode_without_changing_free_or_catalog_colour():
	var folder := _folder()
	var setup = load("res://ui/setup.tscn").instantiate()
	setup.book.selection_dir = folder.path_join("openings")
	setup.repertoire.storage_dir = folder.path_join("repertoires")
	assert_eq(setup.book.save_selection("Catalog"), "")
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 2. Nf3 *", "w", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var opening: OptionButton = setup.get_node("Center/Form/Opening")
	var colour: OptionButton = setup.get_node("Center/Form/Colour")
	var saved: OptionButton = setup.get_node("Center/Form/RepertoireControls/Saved")
	var started := []
	setup.started.connect(func(settings): started.append(settings))
	for index in [0, 1, 2]:
		colour.select(1)
		opening.select(index)
		opening.item_selected.emit(index)
		assert_true(saved.is_visible_in_tree(), "a repertoire can be picked in " + setup.OPENINGS[index])
		assert_eq(colour.disabled, index == 2, "only My repertoire fixes the initial colour")
		setup.get_node("Center/Form/Start").pressed.emit()
		assert_eq(started.size(), index + 1)
		if started.size() == index + 1:
			assert_eq(started[index].get("repertoire", ""), "Study")
			assert_eq(started[index].colour, "w" if index == 2 else "b")
			assert_eq(started[index].opening, setup.OPENINGS[index])
	setup.free()
	_clean(folder)


func test_real_games_show_badges_only_in_review_in_every_mode_and_keep_book_when_checking_is_off():
	for mode in ["Free", "Catalog", "My repertoire"]:
		for checking in [false, true]:
			var folder := _folder()
			var main = _session(folder)
			assert_true(main.preferences.set_value("check_repertoire", checking))
			var config := CONFIG.duplicate()
			config.opening = mode
			main.setup.started.emit(config)
			await _wait_start(main)
			assert_eq(main.settings.opening, mode)
			assert_true(main.history.book == main.setup.book, "history keeps the catalog")
			if mode == "Free":
				assert_eq(main.maia.target_id, "", "checking does not enable Maia's book")
			for move in ["e2e4", "e7e5", "d2d4", "b8c6", "g1f3"]:
				assert_true(main.board_view.play(move))
			assert_true(not main.review.visible, "review stays hidden during play")
			assert_true(not main.setup.visible, "the repertoire picker stays hidden during play")
			assert_eq(main.move_list.get_parsed_text(), "1. e4   e5\n2. d4   Nc6\n3. Nf3", "no live book or repertoire hints")
			_finish(main)
			assert_true(main.review.visible)
			assert_eq(_marks(main, 0), "Book · Repertoire" if checking else "Book")
			assert_eq(_marks(main, 1), "Book", "opponent has no repertoire badge")
			assert_eq(_marks(main, 2), "Left repertoire — expected: Nc3, Nf3" if checking else "")
			assert_eq(_marks(main, 4), "", "neither badge resumes after the exit")
			main.free()
			_clean(folder)


func test_rematch_checks_actual_black_moves_and_no_continuation_is_explicit():
	var folder := _folder()
	var main = _session(folder)
	main.preferences.set_value("check_repertoire", true)
	main.setup.started.emit(CONFIG.duplicate())
	await _wait_start(main)
	_finish(main)
	main.review.rematch_requested.emit()
	assert_eq(main.human, "b")
	for move in ["e2e4", "e7e5", "g1f3", "h7h6"]:
		assert_true(main.board_view.play(move))
	_finish(main)
	assert_eq(_marks(main, 0), "Book", "White is now the opponent")
	assert_eq(_marks(main, 1), "Book · Repertoire", "check the actual Black player")
	assert_eq(_marks(main, 3), "Left repertoire — expected: Nc6")
	await main._start(CONFIG.duplicate())
	for move in ["e2e4", "c7c5", "g1f3"]:
		assert_true(main.board_view.play(move))
	_finish(main)
	assert_eq(_marks(main, 2), "Left repertoire — No continuation in repertoire")
	main.free()
	_clean(folder)


func test_game_snapshots_repertoire_and_uses_live_check_preference_at_review():
	var folder := _folder()
	var main = _session(folder)
	# Start with checking off; enabling it during play uses this game's PGN,
	# even if a saved study was replaced after the game started.
	main.setup.started.emit(CONFIG.duplicate())
	await _wait_start(main)
	assert_eq(main.setup.repertoire.import_pgn("1. d4 d5 *", "w", "Study"), "")
	main.preferences.set_value("check_repertoire", true)
	assert_true(main.board_view.play("e2e4"))
	_finish(main)
	assert_eq(_marks(main, 0), "Book · Repertoire", "use the game's immutable repertoire snapshot")
	main.free()
	_clean(folder)


func test_expected_moves_are_visible_in_review_without_hovering_over_a_clipped_badge():
	var folder := _folder()
	var main = _session(folder)
	main.preferences.set_value("check_repertoire", true)
	main.setup.started.emit(CONFIG.duplicate())
	await _wait_start(main)
	for move in ["e2e4", "e7e5", "d2d4"]:
		assert_true(main.board_view.play(move))
	_finish(main)
	var details = main.review.get_node_or_null("Margin/Content/ReviewBody/Side/RepertoireExit")
	assert_true(details != null, "expected moves have a readable area outside the narrow badge column")
	if details != null:
		assert_true(details.is_visible_in_tree())
		assert_eq(details.text, "2. White: Left repertoire — expected: Nc3, Nf3")
	main.review.rematch_requested.emit()
	_finish(main)
	if details != null:
		assert_true(not details.visible, "a fresh no-move review clears the previous exit details")
	main.free()
	_clean(folder)


func test_required_repertoire_load_failure_prevents_new_game_and_retry_uses_repaired_study():
	for mode in ["Free", "Catalog", "My repertoire"]:
		var folder := _folder()
		var main = _session(folder)
		main.preferences.set_value("check_repertoire", true)
		var path: String = main.setup.repertoire.storage_dir.path_join("Study.json")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("corrupt")
		file.close()
		var config := CONFIG.duplicate()
		config.opening = mode
		main.setup.started.emit(config)
		await _wait_start(main)
		assert_eq(main.clock, null, "failed checking load does not start " + mode)
		assert_true(main.setup.visible, "failed load returns to setup")
		assert_true(main.setup.get_node("Center/Form/Missing").visible, "show the load error")
		assert_eq(main.setup.repertoire.import_pgn(STUDY, "w", "Study"), "")
		main.setup.started.emit(config)
		await _wait_start(main)
		assert_true(main.clock != null, "repaired repertoire permits retry")
		assert_true(main.board_view.play("e2e4"))
		_finish(main)
		assert_eq(_marks(main, 0), "Book · Repertoire")
		main.free()
		_clean(folder)


func test_enabling_checking_during_catalog_load_rejects_bad_repertoire_and_allows_repaired_retry():
	var folder := _folder()
	var book := DelayedBook.new()
	var main = _session(folder, book)
	var original_game = main.board_view.game
	var file := FileAccess.open(main.setup.repertoire.storage_dir.path_join("Study.json"), FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	main.setup.get_node("Center/Form/Colour").select(1)
	assert_eq(main.preferences.get_value("check_repertoire"), false)
	main.setup.get_node("Center/Form/Start").pressed.emit()
	await _wait_start(main)
	book.entered.wait()
	assert_eq(main.clock, null, "no clock while catalog I/O is pending")
	assert_eq(main.uci.requests.size(), 0)
	main.settings_screen.get_node("Open").pressed.emit()
	var form = main.settings_screen.get_node("Panel/Center/Box/Form")
	var toggle: CheckBox
	for i in form.get_child_count():
		if form.get_child(i) is Label and form.get_child(i).text == "Check my moves against my repertoire":
			toggle = form.get_child(i + 1)
	assert_true(toggle != null, "real Settings control enables checking during catalog loading")
	if toggle != null:
		toggle.button_pressed = true
	assert_eq(main.preferences.get_value("check_repertoire"), true)
	main.settings_screen.get_node("Panel/Center/Box/Close").pressed.emit()
	var picker = main.setup.get_node("OpeningPicker")
	var ready := []
	picker.catalog_ready.connect(func(error): ready.append(error))
	book.release.post()
	var deadline := Time.get_ticks_msec() + 5000
	while ready.is_empty() and Time.get_ticks_msec() < deadline:
		picker._process(0)
		OS.delay_msec(1)
	assert_eq(ready, [""], "the real catalog await completed successfully")
	assert_eq(main.clock, null, "newly required corrupt repertoire prevents clock creation")
	assert_eq(main.uci.requests.size(), 0, "no Maia request after the failed required load")
	assert_true(main.board_view.game == original_game, "failed start does not replace the game")
	assert_true(main.setup.visible, "return to setup for repair and retry")
	var status: Label = main.setup.get_node("Center/Form/Missing")
	assert_true(status.is_visible_in_tree() and status.text == "The repertoire is not valid JSON.")
	assert_eq(main.setup.repertoire.import_pgn("1. d4 d5 *", "w", "Study"), "")
	main.setup.get_node("Center/Form/Start").pressed.emit()
	await _wait_start(main)
	assert_true(main.clock != null, "repair permits retry without a stuck start guard")
	assert_eq(main.human, "b", "Free mode preserves the chosen colour")
	assert_eq(main.settings.opening, "Free")
	assert_eq(main.maia.target_id, "", "checking does not enable Maia's repertoire mode")
	assert_eq(main.uci.requests.size(), 1, "only the successful retry requests Maia's first move")
	assert_true(main.board_view.play("d2d4"))
	assert_true(main.board_view.play("d7d5"))
	_finish(main)
	assert_eq(_marks(main, 1), "Repertoire", "retry snapshots the repaired study, not the old e4 paths")
	main.free()
	_clean(folder)


# Starts now cross a real asynchronous searching screen.
func _wait_start(main) -> void:
	while main._starting:
		await Engine.get_main_loop().process_frame
