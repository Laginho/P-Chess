extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const Game = preload("res://core/game.gd")
const Repertoire = preload("res://bot/repertoire.gd")
const Settings = preload("res://core/settings.gd")


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
