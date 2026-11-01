extends "res://tests/run.gd".Test

const Board = preload("res://core/board.gd")
const Book = preload("res://bot/book.gd")
const STUDY := "res://tests/fixtures/pgn/repertoire_study.pgn"


func test_import_fields_keep_visible_labels_after_typing():
	var importer = load("res://ui/repertoire_import.tscn").instantiate()
	Engine.get_main_loop().root.add_child(importer)
	importer.present()
	importer.get_node("Margin/Form/FileRow/Path").text = "study.pgn"
	importer.get_node("Margin/Form/Name").text = "Study"
	for item in [["PathLabel", "PGN file"], ["NameLabel", "Repertoire name"]]:
		var label = importer.get_node_or_null("Margin/Form/" + item[0])
		assert_true(label != null and label.visible and label.text == item[1], item[1] + " label is visible")
	importer.free()


func test_viewer_shows_black_line_and_steps_without_allowing_moves():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 2. Nf3 *", "b", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var list: ItemList = screen.get_node("Margin/Form/List")
	list.item_selected.emit(0)
	var lines = screen.find_child("LineRows", true, false)
	var board = screen.find_child("Board", true, false)
	assert_true(lines != null and board != null, "viewer provides lines and a board")
	if lines != null and board != null:
		assert_true(board.flipped, "Black is at the bottom")
		assert_eq(lines.get_child_count(), 1)
		var row: Button = lines.get_child(0)
		assert_eq(row.find_child("Name", true, false).text, "Line 1", "an unnamed line has a readable fallback")
		assert_true(row.button_pressed, "the displayed line is selected")
		row.pressed.emit()
		assert_eq(board.game.board.position_key(), "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -")
		assert_eq(board.game.moves[-1], "g1f3", "last move is highlighted")
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_LEFT
		screen._unhandled_key_input(key)
		assert_eq(board.game.moves.size(), 2)
		key.keycode = KEY_RIGHT
		screen._unhandled_key_input(key)
		assert_eq(board.game.moves.size(), 3)
		assert_eq(board.mouse_filter, Control.MOUSE_FILTER_IGNORE, "board ignores user moves")
	setup.free()
	_clean(folder)


func test_viewer_numbers_and_highlights_a_line_starting_with_black():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	var pgn := "[SetUp \"1\"]\n[FEN \"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1\"]\n1... e5 2. e4 *"
	assert_eq(setup.repertoire.import_pgn(pgn, "b", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	var row = screen.find_child("LineRows", true, false).get_child(0)
	assert_eq(row.find_child("Moves", true, false).text, "1...e5 2.e4")
	assert_eq(row.accessibility_description, "1...e5 2.e4")
	var navigation = screen.find_child("Navigation", true, false)
	var moves = navigation.get_node("Moves")
	assert_eq(moves.text, "1...e5 [bgcolor=#4a4741][color=#ece9e4][b]2.e4[/b][/color][/bgcolor]")
	navigation.get_node("Previous").pressed.emit()
	assert_eq(moves.text, "[bgcolor=#4a4741][color=#ece9e4][b]1...e5[/b][/color][/bgcolor] 2.e4")
	setup.free()
	_clean(folder)


func test_repertoire_selection_shows_its_name_colour_and_line_count():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "b", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	var heading = screen.find_child("LineHeading", true, false)
	var detail = screen.find_child("LineDetail", true, false)
	assert_true(heading != null and detail != null, "selected repertoire has a lines header")
	if heading != null and detail != null:
		assert_eq(heading.text, "Study")
		assert_eq(detail.text, "As Black · 1 line")
	setup.free()
	_clean(folder)


func test_editor_places_its_controls_in_a_card():
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	var card = editor.find_child("Card", true, false)
	assert_true(card is PanelContainer, "editor controls have a card background")
	if card != null:
		assert_true(card.is_ancestor_of(editor.find_child("Tree", true, false)))
	editor.free()


func test_repertoire_navigation_is_below_its_board():
	var screen = load("res://ui/repertoire_screen.tscn").instantiate()
	var board = screen.find_child("Board", true, false)
	var navigation = screen.find_child("Navigation", true, false)
	assert_true(board != null and navigation != null and board.get_parent() == navigation.get_parent(), "navigation shares the board column")
	screen.free()


func _find_move(item: Node, moves: PackedStringArray) -> Button:
	if item is Button and item.has_meta("move_path") and item.get_meta("move_path") == moves:
		return item
	for child in item.get_children():
		var found := _find_move(child, moves)
		if found != null:
			return found
	return null


func test_editor_keeps_a_linear_line_at_one_indentation():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	var tree = editor.find_child("Tree", true, false)
	var first := _find_move(tree, PackedStringArray(["e2e4"]))
	var last := _find_move(tree, PackedStringArray(["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6"]))
	assert_true(first != null and last != null, "every move remains selectable")
	if first != null and last != null:
		assert_eq(first.get_parent().get_parent(), last.get_parent().get_parent(), "a linear sequence shares one row")
		assert_eq(first.text, "1.e4")
		var third := _find_move(tree, PackedStringArray(["e2e4", "e7e5", "g1f3"]))
		assert_eq(third.text, "2.Nf3")
	editor.free()
	_clean(folder)


func test_editor_numbers_a_line_that_starts_with_black():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	var pgn := "[SetUp \"1\"]\n[FEN \"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1\"]\n1... e5 2. e4 *"
	assert_eq(repertoire.import_pgn(pgn, "b", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	var first := _find_move(editor.find_child("Tree", true, false), PackedStringArray(["e7e5"]))
	assert_true(first != null)
	if first != null:
		assert_eq(first.text, "1...e5")
	editor.free()
	_clean(folder)


func test_editor_numbers_a_black_variation_at_the_start_of_its_row():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 (1... c5) 2. Nf3 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	var variation := _find_move(editor.find_child("Tree", true, false), PackedStringArray(["e2e4", "c7c5"]))
	assert_true(variation != null)
	if variation != null:
		assert_eq(variation.text, "1...c5")
	editor.free()
	_clean(folder)


func test_editor_delete_button_remains_available_to_keyboard_focus():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	var move := _find_move(editor.find_child("Tree", true, false), PackedStringArray(["e2e4"]))
	var trash: Button = move.get_parent().get_child(1)
	move.grab_focus()
	await Engine.get_main_loop().process_frame
	assert_true(trash.visible, "delete appears when a move has keyboard focus")
	trash.grab_focus()
	await Engine.get_main_loop().process_frame
	assert_true(trash.visible and trash.has_focus(), "delete stays available while focused")
	trash.pressed.emit()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	assert_true(_find_move(editor.find_child("Tree", true, false), PackedStringArray(["e2e4"])) == null, "focused delete removes the branch")
	editor.free()
	await Engine.get_main_loop().process_frame
	_clean(folder)


func test_selected_editor_move_keeps_enough_width_for_its_text():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	var move := _find_move(editor.find_child("Tree", true, false), PackedStringArray(["e2e4"]))
	move.pressed.emit()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var text_width := move.get_theme_font("font").get_string_size(move.text, HORIZONTAL_ALIGNMENT_LEFT, -1, move.get_theme_font_size("font_size")).x
	var needed := text_width + move.get_theme_stylebox("pressed").get_minimum_size().x
	assert_true(move.size.x >= needed, "selected move text fits")
	editor.free()
	_clean(folder)


func test_viewer_displays_opening_name_and_moves_on_separate_lines():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	var screen = setup.get_node("RepertoireScreen")
	screen.get_node("OpeningPicker").book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn Game\t1. e4 e5\n")
	Engine.get_main_loop().root.add_child(setup)
	screen.present()
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	var row = screen.find_child("LineRows", true, false).get_child(0)
	assert_eq(row.find_child("Name", true, false).text, "King's Pawn Game")
	assert_eq(row.find_child("Moves", true, false).text, "1.e4 e5")
	setup.free()
	_clean(folder)


func _repertoire():
	var path := "res://bot/repertoire.gd"
	assert_true(ResourceLoader.exists(path), "the production repertoire importer exists")
	return load(path).new() if ResourceLoader.exists(path) else null


func test_chapters_and_nested_variations_merge_into_root_to_leaf_lines():
	var repertoire = _repertoire()
	if repertoire == null:
		return
	assert_eq(repertoire.parse(FileAccess.get_file_as_string(STUDY), "w"), "")
	assert_eq(repertoire.colour, "w")
	assert_eq(repertoire.lines.size(), 4, "duplicate and shorter chapters add no leaf")
	var actual := []
	for line in repertoire.lines:
		actual.append(" ".join(line.moves))
		assert_eq(line.positions.size(), line.moves.size() + 1)
	actual.sort()
	assert_eq(actual, ["e2e4 c7c5 b1c3", "e2e4 c7c5 g1f3 d7d6",
			"e2e4 e7e5 g1f3 b8c6", "e2e4 e7e5 g1f3 g8f6"])
	var root: Dictionary = repertoire.tree.values()[0]
	assert_eq(root.children.keys(), ["e2e4"], "one shared first move")
	assert_eq(root.children.e2e4.children.size(), 2, "merged replies")
	assert_eq(root.children.e2e4.children.e7e5.nags, [1])


func _folder() -> String:
	return "user://test_repertoire_%d" % Time.get_ticks_usec()


func test_chapter_leading_comments_merge_without_duplicates_and_survive_reload():
	var repertoire = _repertoire()
	if repertoire == null:
		return
	var folder := _folder()
	repertoire.storage_dir = folder
	var study := """[Event "Chapter one"]
{Chapter one guidance} 1. e4 {Central space} e5 $1 ({Sicilian guidance} 1... c5) *
[Event "Chapter two"]
{Chapter two guidance} 1. e4 e5 2. Nf3 *
[Event "Duplicate guidance"]
{Chapter one guidance} 1. e4 *
[Event "No guidance"]
1. e4 *
[Event "Different root"]
[SetUp "1"]
[FEN "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"]
{Black to move guidance} 1... e5 *
"""
	assert_eq(repertoire.import_pgn(study, "w", "Annotated study"), "")
	var loaded = _repertoire()
	loaded.storage_dir = folder
	assert_eq(loaded.load_saved("Annotated study"), "")
	for imported in [repertoire, loaded]:
		var root: Dictionary = imported.tree[Board.from_fen(Book.START).position_key()]
		assert_eq(root.comments, ["Chapter one guidance", "Chapter two guidance"],
				"distinct chapter guidance survives import and reload, once per comment")
		assert_eq(root.children.e2e4.comments, ["Central space"])
		assert_eq(root.children.e2e4.children.e7e5.nags, [1])
		assert_eq(root.children.e2e4.children.c7c5.comments_before, ["Sicilian guidance"])
		var other_position = Board.from_fen(Book.START)
		other_position.make_move("e2e4")
		assert_eq(imported.tree[other_position.position_key()].comments, ["Black to move guidance"],
				"chapter comments stay with their own starting position")
		assert_eq(imported.lines.size(), 3, "annotations and duplicate chapters do not add paths")
	assert_eq(loaded.lines, repertoire.lines, "reload preserves paths and stable IDs")
	_clean(folder)


func _clean(folder: String) -> void:
	for child in DirAccess.get_directories_at(folder):
		_clean(folder.path_join(child))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


func test_import_persists_colour_and_invalid_pgn_never_creates_or_replaces_a_save():
	var repertoire = _repertoire()
	if repertoire == null:
		return
	assert_true(repertoire.has_method("import_pgn"), "validated import and atomic save")
	if not repertoire.has_method("import_pgn"):
		return
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn(FileAccess.get_file_as_string(STUDY), "b", "Study"), "")
	var saved := FileAccess.get_file_as_string(folder.path_join("Study.json"))
	var loaded = _repertoire()
	loaded.storage_dir = folder
	assert_eq(loaded.names(), ["Study"])
	assert_eq(loaded.load_saved("Study"), "")
	assert_eq(loaded.colour, "b")
	assert_eq(loaded.lines, repertoire.lines, "stable line IDs across loads")
	var invalid := "1. e4 e5 *\n[Event \"Broken chapter\"]\n1. d4 d5 2. Bh5 *"
	for name in ["Study", "Broken"]:
		var error: String = repertoire.import_pgn(invalid, "w", name)
		assert_true("Game 2, move 2." in error and "Bh5" in error, error)
	assert_eq(FileAccess.get_file_as_string(folder.path_join("Study.json")), saved)
	assert_eq(repertoire.names(), ["Study"], "no failed-import file or temporary file")
	assert_eq(repertoire.colour, "b", "failed import preserves live repertoire")
	assert_eq(repertoire.lines, loaded.lines)
	for text in ["", "{only a comment}", "[Event \"Empty\"]"]:
		assert_true(not repertoire.import_pgn(text, "w", "Empty").is_empty())
	for name in ["../escape", "CON", "trail.", ""]:
		assert_true(not repertoire.import_pgn("1. e4 *", "w", name).is_empty())
	assert_true(not repertoire.import_pgn("1. e4 *", "random", "BadColour").is_empty())
	assert_true(not repertoire.load_saved("Missing").is_empty())
	assert_eq(repertoire.lines, loaded.lines, "failed load preserves valid in-memory data")
	_clean(folder)


func test_repertoire_book_uses_existing_targets_weights_and_actual_maia_side():
	var repertoire = _repertoire()
	if repertoire == null:
		return
	assert_eq(repertoire.parse(FileAccess.get_file_as_string(STUDY), "w"), "")
	var book = Book.new()
	assert_true(book.has_method("load_repertoire"), "book accepts imported root-to-leaf paths")
	if not book.has_method("load_repertoire"):
		return
	book.load_tsv("eco\tname\tpgn\nA00\tCatalog only\t1. d4 d5\n")
	book.set_checked("Catalog only", true)
	book.load_repertoire(repertoire.lines, "b")
	assert_eq(book.entries.size(), 4, "replaces catalog")
	assert_eq(book.selected_ids().size(), 4)
	var counts := {}
	for line in repertoire.lines:
		counts[line.id] = 10 if line.moves[1] == "c7c5" else 0
	var rng := RandomNumberGenerator.new()
	var target: String = book.begin_game(counts, rng, "b")
	assert_true(not target.is_empty())
	var board = Board.from_fen(Book.START)
	board.make_move("e2e4")
	for intensity in {"weak": [5.0, 2.0], "medium": [20.0, 5.0], "strong": [100.0, 15.0]}:
		var weights: Dictionary = book.weights(board, 1, intensity)
		var expected: Array = {"weak": [5.0, 2.0], "medium": [20.0, 5.0], "strong": [100.0, 15.0]}[intensity]
		assert_eq(weights.e7e5, expected[0])
		assert_eq(weights.c7c5, expected[1])
		assert_eq(weights.d7d5, 1.0, "catalog doesn't leak into repertoire")
	assert_eq(book.weights(board, 11).e7e5, 10.5)
	for weight in book.weights(board, 16).values():
		assert_eq(weight, 1.0)
	assert_eq(book.begin_game({}, rng, "w"), "", "eligibility is actual Maia side")
	book.load_repertoire(repertoire.lines, "w")
	assert_true(not book.begin_game({}, rng, "w").is_empty(), "swapped rematch")
	assert_eq(book.weights(Board.from_fen(Book.START), 0).e2e4, 20.0)
	assert_eq(repertoire.colour, "w", "book preparation doesn't rewrite saved human colour")
	book.load_repertoire([], "w")
	assert_eq(book.begin_game({}, rng, "w"), "", "empty book clears previous continuations")
	assert_eq(book.opening_name(PackedStringArray(["d2d4", "d7d5"])), "")


func test_real_import_and_setup_controls_adopt_saved_colour_and_reject_invalid_files():
	var setup = load("res://ui/setup.tscn").instantiate()
	var repertoire = setup.get("repertoire")
	assert_true(repertoire != null, "setup exposes saved repertoires")
	if repertoire == null:
		setup.free()
		return
	var folder := _folder()
	repertoire.storage_dir = folder
	setup.book.selection_dir = folder.path_join("openings")
	Engine.get_main_loop().root.add_child(setup)
	var opening: OptionButton = setup.get_node("Center/Form/Opening")
	assert_true(not opening.is_item_disabled(2), "My repertoire is available")
	opening.select(2)
	opening.item_selected.emit(2)
	var start: Button = setup.get_node("Center/Form/Start")
	assert_true(start.disabled, "no repertoire yet")
	setup.get_node("Center/Form/RepertoireControls/Import").pressed.emit()
	var screen = setup.get_node("RepertoireScreen")
	assert_true(screen.visible, "repertoire screen opens")
	screen.get_node("Margin/Form/Buttons/Import").pressed.emit()
	var importer = screen.get_node("RepertoireImport")
	assert_true(importer.visible)
	importer.get_node("Margin/Form/Name").text = "My study"
	importer.get_node("Margin/Form/Colour").select(1)
	importer.get_node("Margin/Form/FileRow/Path").text = ProjectSettings.globalize_path(STUDY)
	importer.get_node("Margin/Form/Import").pressed.emit()
	assert_eq(repertoire.names(), ["My study"])
	assert_true(not importer.visible, "successful import closes and selects its save")
	assert_true(not start.disabled)
	var colour_picker: OptionButton = setup.get_node("Center/Form/Colour")
	assert_eq(colour_picker.selected, 1, "saved human Black")
	assert_true(colour_picker.disabled, "the repertoire determines initial colour")
	var started := []
	setup.started.connect(func(settings): started.append(settings))
	start.pressed.emit()
	assert_eq(started.size(), 1)
	assert_eq(started[0].colour, "b")
	assert_eq(started[0].repertoire, "My study")
	assert_eq(started[0].opening, "My repertoire")
	screen.get_node("Margin/Form/Buttons/Import").pressed.emit()
	assert_true(not importer.import_file("res://missing-study.pgn", "Missing", "w").is_empty())
	DirAccess.make_dir_recursive_absolute(folder)
	var bad_file := FileAccess.open(folder.path_join("bad.pgn"), FileAccess.WRITE)
	bad_file.store_string("1. e4 e5 2. Bh6 *")
	bad_file.close()
	importer.get_node("Margin/Form/Name").text = "Bad study"
	importer.get_node("Margin/Form/FileRow/Path").text = folder.path_join("bad.pgn")
	importer.get_node("Margin/Form/Import").pressed.emit()
	assert_true(importer.visible, "invalid import remains editable")
	assert_true("move 2." in importer.get_node("Margin/Form/Status").text)
	assert_eq(repertoire.names(), ["My study"])
	importer.hide()
	opening.select(0)
	opening.item_selected.emit(0)
	assert_true(not colour_picker.disabled, "Free restores choice")
	assert_true(not start.disabled)
	setup.free()
	_clean(folder)


class HeldEngine extends "res://engine/uci.gd":
	var requests := []


	func start(_dirs := PackedStringArray()) -> bool:
		return true


	func set_level(_path: String) -> void:
		level_ready.emit()


	func request_policy(_fen: String, moves: PackedStringArray) -> void:
		requests.append(moves.duplicate())


func _session(folder: String):
	var main = load("res://ui/main.tscn").instantiate()
	main.preferences = load("res://core/settings.gd").new(folder.path_join("settings.cfg"))
	main.history = load("res://core/history.gd").new(folder)
	var setup = main.get_node("Setup")
	setup.book.selection_dir = folder.path_join("openings")
	setup.book.load_tsv("eco\tname\tpgn\nC40\tKing Pawn\t1. e4 e5\nA00\tCatalog only\t1. d4 d5\n")
	setup.book.set_checked("Catalog only", true)
	assert_eq(setup.book.save_selection("Catalog"), "")
	setup.repertoire.storage_dir = folder.path_join("repertoires")
	assert_eq(setup.repertoire.import_pgn(FileAccess.get_file_as_string(STUDY), "w", "Study"), "")
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = load("res://bot/maia_player.gd").new(main.uci)
	Engine.get_main_loop().root.add_child(main)
	main.board_view.slide_seconds = 0
	main.sound_player.select_theme("__repertoire_silent__")
	return main


func test_main_uses_repertoire_for_maia_catalog_for_history_and_preserves_rematches_and_modes():
	var setup_probe = load("res://ui/setup.tscn").instantiate()
	var supported := setup_probe.get("repertoire") != null
	setup_probe.free()
	if not supported:
		assert_true(false, "repertoire lifecycle exists")
		return
	var folder := _folder()
	var main = _session(folder)
	var setup = main.setup
	var opening: OptionButton = setup.get_node("Center/Form/Opening")
	opening.select(2)
	opening.item_selected.emit(2)
	setup.get_node("Center/Form/Start").pressed.emit()
	await _wait_start(main)
	assert_eq(main.settings.opening, "My repertoire")
	assert_true(main.maia.book != setup.book, "practice book replaces the catalog")
	assert_eq(main.maia.book.entries.size(), 4)
	assert_true(main.maia.target_id.begins_with("repertoire:"))
	assert_true(main.history.book == setup.book, "history retains catalog recognition")
	main.maia.clock = null
	main.maia.book_intensity = "strong"
	main.maia.tau = 0.5
	assert_true(main.board_view.play("e2e4"))
	assert_eq(main.uci.requests[-1], PackedStringArray(["e2e4"]))
	# With strong book weights e5 survives the 50% cut; without them only d5 survives.
	main.uci.policy_ready.emit({"e2e4": 1.0})
	main.uci.policy_ready.emit({"e7e5": 0.1, "d7d5": 0.9})
	assert_eq(main.board_view.game.moves, PackedStringArray(["e2e4", "e7e5"]))
	var first_target: String = main.maia.target_id
	main.board_view.game.resign("w")
	main._show_result()
	assert_eq(main.history.practice_counts(), {first_target: 1})
	var game_files := DirAccess.get_files_at(folder.path_join("games"))
	var parsed = load("res://core/pgn.gd").parse(FileAccess.get_file_as_string(folder.path_join("games").path_join(game_files[0])))
	assert_eq(parsed.games[0].headers.Opening, "King Pawn")
	await main._start(main.rematch(main.settings))
	assert_eq(main.human, "b", "existing rematch swaps human side")
	assert_true(main.maia.target_id != first_target, "least-practiced remaining path")
	assert_eq(main.maia.book.entries[0].colour, "w", "Maia is now White")
	assert_eq(main.maia.book.weights(main.board_view.game.board, 0).e2e4, 20.0)
	assert_eq(main.uci.requests[-1], PackedStringArray(), "Maia requests White's first move")
	assert_eq(setup.repertoire.colour, "w", "imported colour unchanged by rematch")
	await main._start({"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Catalog", "selection": "Catalog"})
	assert_true(main.maia.book == setup.book)
	assert_true(main.maia.target_id.begins_with("A00:"))
	assert_eq(main.maia.book.weights(main.board_view.game.board, 0).d2d4, 20.0)
	assert_eq(main.maia.book.weights(main.board_view.game.board, 0).e2e4, 1.0)
	await main._start({"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"})
	assert_eq(main.maia.target_id, "")
	main.free()
	_clean(folder)


func test_failed_repertoire_load_does_not_start_clock_or_policy_and_can_retry():
	var setup = load("res://ui/setup.tscn").instantiate()
	var supported := setup.get("repertoire") != null
	setup.free()
	if not supported:
		assert_true(false, "repertoire lifecycle exists")
		return
	var folder := _folder()
	var main = _session(folder)
	var settings := {"colour": "w", "level": "maia-1500", "control": "3+2",
			"opening": "My repertoire", "repertoire": "Study"}
	var path: String = main.setup.repertoire.storage_dir.path_join("Study.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{invalid")
	file.close()
	main.setup.started.emit(settings)
	await _wait_start(main)
	assert_eq(main.clock, null, "no game starts after invalid saved repertoire")
	assert_eq(main.uci.requests.size(), 0)
	assert_true(main.setup.visible)
	assert_true("JSON" in main.setup.get_node("Center/Form/Missing").text)
	assert_eq(main.setup.repertoire.import_pgn(FileAccess.get_file_as_string(STUDY), "w", "Study"), "")
	main.setup.started.emit(settings)
	await _wait_start(main)
	assert_true(main.clock != null, "successful retry starts a fresh game")
	assert_true(main.maia.target_id.begins_with("repertoire:"))
	main.free()
	_clean(folder)


func test_setup_keeps_engine_guidance_and_clears_repertoire_errors_when_changing_mode():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	setup.book.selection_dir = folder.path_join("openings")
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var opening: OptionButton = setup.get_node("Center/Form/Opening")
	var status: Label = setup.get_node("Center/Form/Missing")
	var file := FileAccess.open(folder.path_join("Study.json"), FileAccess.WRITE)
	file.store_string("bad JSON")
	file.close()
	opening.select(2)
	opening.item_selected.emit(2)
	assert_true(status.visible and "JSON" in status.text)
	opening.select(0)
	opening.item_selected.emit(0)
	assert_true(not status.visible, "Free clears the irrelevant repertoire load error")
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	setup.show_missing("Engine unavailable")
	opening.select(2)
	opening.item_selected.emit(2)
	assert_true(status.visible and "Engine unavailable" in status.text, "repertoire colour loading must preserve missing-engine guidance")
	setup.free()
	_clean(folder)

func test_catalog_selection_saves_repertoire_and_book_uses_it():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	var catalog = load("res://bot/book.gd").new()
	catalog.load_tsv("eco\tname\tpgn\nB12\tCaro-Kann Defense: Advance Variation\t1. e4 c6 2. d4 d5 3. e5\nB10\tCaro-Kann Defense: Two Knights\t1. e4 c6 2. Nc3 d5\n")
	catalog.set_checked("Caro-Kann Defense", true)
	assert_true(repertoire.has_method("save_openings"), "save checked catalog entries")
	if not repertoire.has_method("save_openings"):
		return
	assert_true(not repertoire.save_openings(catalog, "b", "").is_empty())
	var empty = load("res://bot/book.gd").new()
	assert_true(not repertoire.save_openings(empty, "b", "Empty").is_empty())
	assert_eq(repertoire.save_openings(catalog, "b", "Caro"), "")
	var loaded = _repertoire()
	loaded.storage_dir = folder
	assert_eq(loaded.load_saved("Caro"), "")
	assert_eq(loaded.colour, "b")
	assert_eq(loaded.lines.size(), 2)
	for entry in catalog.entries:
		var found := false
		for line in loaded.lines:
			if line.moves == entry.moves:
				found = true
		assert_true(found, "catalog moves survive saving")
	var book = load("res://bot/book.gd").new()
	book.load_repertoire(loaded.lines, "w")
	book.begin_game({}, RandomNumberGenerator.new(), "w")
	var board = load("res://core/board.gd").from_fen(load("res://bot/book.gd").START)
	assert_true(book.weights(board, 0).e2e4 > 1.0, "My repertoire follows the selected lines")
	_clean(folder)

func test_repertoire_source_survives_reload_and_edits_and_legacy_has_no_source():
	var folder := _folder()
	var repertoire = _repertoire()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 *", "w", "PGN"), "")
	var book = load("res://bot/book.gd").new()
	book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn Game\t1. e4 e5\n")
	book.set_checked("King's Pawn Game", true)
	assert_eq(repertoire.save_openings(book, "b", "Opening"), "")
	for pair in [["PGN", "pgn"], ["Opening", "openings"]]:
		var loaded = _repertoire()
		loaded.storage_dir = folder
		assert_eq(loaded.load_saved(pair[0]), "")
		assert_eq(loaded.get("source"), pair[1], "source survives reload")
		assert_eq(loaded.save_edited(loaded.tree, pair[0]), "")
		assert_eq(loaded.load_saved(pair[0]), "")
		assert_eq(loaded.get("source"), pair[1], "source survives editing")
	var file := FileAccess.open(folder.path_join("Legacy.json"), FileAccess.WRITE)
	file.store_string('{"version":1,"colour":"w","pgn":"1. e4 *"}')
	file.close()
	assert_eq(repertoire.load_saved("Legacy"), "")
	assert_eq(repertoire.get("source"), "", "legacy origin is unknown")
	_clean(folder)


func test_editor_shows_unsaved_changes_only_after_a_change():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	var marker = editor.find_child("Unsaved", true, false)
	assert_true(marker != null, "editor has an unsaved changes marker")
	if marker != null:
		assert_true(not marker.visible, "opening a repertoire is clean")
	assert_true(editor.board.play("g1f3"))
	if marker != null:
		assert_true(marker.visible, "a new move marks the repertoire dirty")
	editor.save()
	if marker != null:
		assert_true(not marker.visible, "saving clears the marker")
	editor.free()
	_clean(folder)


func test_editor_extends_a_selected_line_and_saves_it():
	var path := "res://ui/repertoire_editor.tscn"
	assert_true(ResourceLoader.exists(path), "editor scene exists")
	if not ResourceLoader.exists(path):
		return
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	var editor = load(path).instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	assert_true(editor.get_node("Margin/Form/Content/Board").play("g1f3"))
	editor.save()
	var loaded = _repertoire()
	loaded.storage_dir = folder
	assert_eq(loaded.load_saved("Study"), "")
	assert_eq(" ".join(loaded.lines[0].moves), "e2e4 e7e5 g1f3")
	editor.free()
	_clean(folder)

func test_editor_keeps_existing_annotations_when_saving_a_branch():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("{Root} 1. e4 {Space} e5 $1 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	assert_true(editor.get_node("Margin/Form/Content/Board").play("g1f3"))
	editor.save()
	var loaded = _repertoire()
	loaded.storage_dir = folder
	assert_eq(loaded.load_saved("Study"), "")
	var root: Dictionary = loaded.tree.values()[0]
	assert_eq(root.comments, ["Root"])
	assert_eq(root.children.e2e4.comments, ["Space"])
	assert_eq(root.children.e2e4.children.e7e5.nags, [1])
	editor.free()
	_clean(folder)

func test_editor_opens_from_screen_branches_and_cancel_discards():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 2. Nf3 *", "w", "Study"), "")
	var original := FileAccess.get_file_as_string(folder.path_join("Study.json"))
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	var button = screen.get_node_or_null("Margin/Form/Buttons/Edit")
	assert_true(button != null, "screen offers editing")
	if button != null:
		button.pressed.emit()
		var editor = screen.get_node("RepertoireEditor")
		var tree = editor.find_child("Tree", true, false)
		var first = _find_move(tree, PackedStringArray(["e2e4"]))
		first.pressed.emit()
		assert_true(editor.get_node("Margin/Form/Content/Board").play("c7c5"))
		editor.find_child("Cancel", true, false).pressed.emit()
		assert_eq(FileAccess.get_file_as_string(folder.path_join("Study.json")), original)
	setup.free()
	_clean(folder)

func test_editor_saves_a_branch_and_deletes_a_subtree():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 2. Nf3 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study")
	var tree = editor.find_child("Tree", true, false)
	var e4 = _find_move(tree, PackedStringArray(["e2e4"]))
	e4.pressed.emit()
	assert_true(editor.get_node("Margin/Form/Content/Board").play("c7c5"))
	await Engine.get_main_loop().process_frame
	var e5 = _find_move(tree, PackedStringArray(["e2e4", "e7e5"]))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	e5.gui_input.emit(click)
	editor.save()
	var loaded = _repertoire()
	loaded.storage_dir = folder
	assert_eq(loaded.load_saved("Study"), "")
	assert_eq(loaded.lines.size(), 1)
	assert_eq(" ".join(loaded.lines[0].moves), "e2e4 c7c5")
	editor.free()
	_clean(folder)

func test_each_repertoire_card_opens_its_own_editor():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Alpha"), "")
	assert_eq(setup.repertoire.import_pgn("1. d4 d5 *", "b", "Beta"), "")
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var cards = screen.find_child("Cards", true, false)
	assert_true(cards != null, "repertoire cards exist")
	if cards != null:
		assert_eq(cards.get_child_count(), 2)
		for i in range(cards.get_child_count()):
			var edit = cards.get_child(i).find_child("Edit", true, false)
			assert_true(edit != null, "each card has an edit button")
			if edit != null:
				edit.pressed.emit()
				var editor = screen.get_node("RepertoireEditor")
				assert_true(editor.visible)
				assert_eq(editor.saved_name, ["Alpha", "Beta"][i])
				editor.hide()
	setup.free()
	_clean(folder)


func test_selected_repertoire_card_has_an_accent_outline():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var select: Button = screen.find_child("Cards", true, false).get_child(0).get_child(0)
	select.pressed.emit()
	var style: StyleBoxFlat = select.get_theme_stylebox("pressed")
	assert_eq(style.border_color, Color("7fa650"), "selection has the green outline")
	setup.free()
	_clean(folder)


func test_repertoire_card_shows_readable_name_and_origin():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var card = screen.find_child("Cards", true, false).get_child(0)
	var title = card.find_child("CardTitle", true, false)
	var detail = card.find_child("CardDetail", true, false)
	assert_true(title != null and detail != null, "name and origin are separate labels")
	if title != null and detail != null:
		assert_eq(title.text, "Study")
		assert_eq(detail.text, "1 line · imported PGN")
	setup.free()
	_clean(folder)


func test_editor_button_tracks_repertoire_selection():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var button: Button = screen.get_node("Margin/Form/Buttons/Edit")
	assert_true(button.disabled)
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	assert_true(not button.disabled, "a loaded repertoire can be edited")
	screen.present()
	assert_true(button.disabled, "refresh clears selection")
	var file := FileAccess.open(folder.path_join("Study.json"), FileAccess.WRITE)
	file.store_string("bad JSON")
	file.close()
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	assert_true(button.disabled, "failed loading cannot open editor")
	setup.free()
	_clean(folder)

func test_editor_allows_legal_moves_after_automatic_draw():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("[SetUp \"1\"]\n[FEN \"7k/8/8/8/8/8/8/KB6 w - - 0 1\"]\n1. Ba2 *", "w", "Study"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	assert_true(editor.board.play("h8g7"), "legal continuation after insufficient material")
	editor.save()
	assert_eq(repertoire.load_saved("Study"), "")
	assert_eq(repertoire.lines[0].moves, PackedStringArray(["b1a2", "h8g7"]))
	editor.free()
	_clean(folder)

func test_editor_preserves_variation_opening_comment_on_save():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 ({Sicilian} 1... c5) *", "w", "Study"), "")
	assert_eq(repertoire.save_edited(repertoire.tree.duplicate(true), "Study"), "")
	assert_eq(repertoire.load_saved("Study"), "")
	var e4: Dictionary = repertoire.tree.values()[0].children.e2e4
	assert_eq(e4.comments, [])
	assert_eq(e4.children.c7c5.comments_before, ["Sicilian"])
	_clean(folder)

func test_editor_save_keeps_comments_holding_a_closing_brace():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 ; Compare } and { here
e5 ; Mark }
2. Nf3 *", "w", "Study"), "")
	assert_eq(repertoire.save_edited(repertoire.tree.duplicate(true), "Study"), "")
	assert_eq(repertoire.load_saved("Study"), "")
	var e4: Dictionary = repertoire.tree.values()[0].children.e2e4
	assert_eq(e4.comments, ["Compare } and { here"])
	assert_eq(e4.children.e7e5.comments, ["Mark }"])
	assert_eq(" ".join(repertoire.lines[0].moves), "e2e4 e7e5 g1f3")
	_clean(folder)

func test_cancelling_the_importer_returns_to_the_repertoire_screen():
	var setup = load("res://ui/setup.tscn").instantiate()
	setup.repertoire.storage_dir = _folder()
	Engine.get_main_loop().root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	var importer = screen.get_node("RepertoireImport")
	screen.present()
	await Engine.get_main_loop().process_frame
	screen.get_node("Margin/Form/Buttons/Import").pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_true(importer.visible, "importer opens")
	importer.get_node("Margin/Form/Done").pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_true(not importer.visible and screen.visible, "closing the importer keeps Repertoires open")
	setup.free()

func test_repertoire_screen_fits_the_smallest_window():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	Engine.get_main_loop().root.add_child(setup)
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var editor = screen.get_node("RepertoireEditor")
	editor.present(setup.repertoire, "Study", 0)
	var picker = screen.get_node("OpeningPicker")
	picker.present_repertoire(setup.repertoire)
	await Engine.get_main_loop().process_frame
	# 800x600 is the main window's minimum size (ui/main.gd).
	for window in [screen, editor, picker]:
		var needed: Vector2 = window.get_contents_minimum_size()
		assert_true(needed.x <= 800 and needed.y <= 600, "%s needs %s" % [window.name, needed])
	setup.free()
	_clean(folder)


func test_long_repertoire_name_keeps_viewer_and_editor_inside_minimum_window():
	var root: Window = Engine.get_main_loop().root
	var old_embed := root.gui_embed_subwindows
	var old_size := root.size
	root.gui_embed_subwindows = true
	root.size = Vector2i(800, 600)
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	var name := "My favourite repertoire for studying the Caro-Kann Defense and its classical and advance variations"
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", name), "")
	root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var heading = screen.find_child("LineHeading", true, false)
	assert_eq(screen.size, Vector2i(800, 600), "viewer fills the minimum viewport")
	assert_eq(heading.text, name)
	assert_eq(heading.tooltip_text, name, "full name remains available")
	var editor = screen.get_node("RepertoireEditor")
	editor.present(setup.repertoire, name, 0)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var editor_heading = editor.find_child("Heading", true, false)
	assert_eq(editor.size, Vector2i(800, 600), "editor fills the minimum viewport")
	assert_true(editor_heading.text.ends_with(name))
	assert_eq(editor_heading.tooltip_text, name, "full name remains available")
	setup.free()
	root.gui_embed_subwindows = old_embed
	root.size = old_size
	_clean(folder)


func test_embedded_repertoire_windows_fill_the_available_viewport():
	var root: Window = Engine.get_main_loop().root
	var old_embed := root.gui_embed_subwindows
	var old_size := root.size
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 800)
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	assert_eq(screen.size, Vector2i(1280, 800), "Repertoires is a full screen, as in the design")
	var editor = screen.get_node("RepertoireEditor")
	editor.present(setup.repertoire, "Study", 0)
	assert_eq(editor.size, Vector2i(1280, 800), "editor is a full screen, as in the design")
	setup.free()
	root.gui_embed_subwindows = old_embed
	root.size = old_size
	_clean(folder)


func test_repertoire_screen_dims_behind_its_dialogs():
	var root: Window = Engine.get_main_loop().root
	var old_embed := root.gui_embed_subwindows
	root.gui_embed_subwindows = true
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	DirAccess.make_dir_recursive_absolute(folder)
	setup.repertoire.storage_dir = folder
	root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var dim = screen.get_node_or_null("Dim")
	assert_true(dim != null and not dim.visible, "no backdrop on the screen itself")
	if dim != null:
		for dialog in [screen.get_node("OpeningPicker"), screen.get_node("RepertoireImport")]:
			if dialog.name == "OpeningPicker":
				dialog.present_repertoire(setup.repertoire)
			else:
				dialog.present()
			assert_true(dim.visible, "%s dims the screen behind it" % dialog.name)
			dialog.hide()
			assert_true(not dim.visible, "closing %s removes the backdrop" % dialog.name)
	setup.free()
	root.gui_embed_subwindows = old_embed
	_clean(folder)


func test_full_screen_repertoire_windows_follow_the_main_window_size():
	var root: Window = Engine.get_main_loop().root
	var old_embed := root.gui_embed_subwindows
	var old_size := root.size
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 800)
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 e5 *", "w", "Study"), "")
	root.add_child(setup)
	var screen = setup.get_node("RepertoireScreen")
	screen.present()
	var editor = screen.get_node("RepertoireEditor")
	editor.present(setup.repertoire, "Study", 0)
	root.size = Vector2i(800, 600)
	await Engine.get_main_loop().process_frame
	assert_eq(screen.size, Vector2i(800, 600), "Repertoires shrinks with the window")
	assert_eq(editor.size, Vector2i(800, 600), "the editor shrinks with the window")
	assert_eq(editor.position, Vector2i.ZERO)
	setup.free()
	root.gui_embed_subwindows = old_embed
	root.size = old_size
	_clean(folder)


func test_repertoire_lists_scroll_to_the_focused_control():
	var screen = load("res://ui/repertoire_screen.tscn").instantiate()
	for name in ["CardScroll", "LineScroll"]:
		assert_true(screen.find_child(name, true, false).follow_focus, "%s follows Tab" % name)
	assert_true(screen.get_node("RepertoireEditor").find_child("Tree", true, false).follow_focus, "editor tree follows Tab")
	screen.free()


func test_editor_marks_an_edit_at_the_end_of_a_long_line():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	var moves := PackedStringArray()
	for i in 20:
		moves.append("%d. %s %s" % [i + 1, "Nf3" if i % 2 == 0 else "Ng1", "Nf6" if i % 2 == 0 else "Ng8"])
	assert_eq(repertoire.import_pgn(" ".join(moves) + " *", "w", "Long"), "")
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	Engine.get_main_loop().root.add_child(editor)
	editor.present(repertoire, "Long", 0)
	var unsaved = editor.find_child("Unsaved", true, false)
	assert_true(not unsaved.visible, "an untouched long line has no unsaved changes")
	assert_true(editor.get_node("Margin/Form/Content/Board").play("e2e4"))
	assert_true(unsaved.visible, "a move added after 40 plies is an unsaved change")
	editor.free()
	_clean(folder)


func test_viewer_line_names_drop_the_shared_opening_family():
	var setup = load("res://ui/setup.tscn").instantiate()
	var folder := _folder()
	setup.repertoire.storage_dir = folder
	assert_eq(setup.repertoire.import_pgn("1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 (4. h4) *", "b", "Caro"), "")
	var screen = setup.get_node("RepertoireScreen")
	screen.get_node("OpeningPicker").book.load_tsv("eco	name	pgn
B12	Caro-Kann Defense: Advance Variation, Short Variation	1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3
B12	Caro-Kann Defense: Advance Variation, Tal Variation	1. e4 c6 2. d4 d5 3. e5 Bf5 4. h4
")
	Engine.get_main_loop().root.add_child(setup)
	screen.present()
	screen.get_node("Margin/Form/List").item_selected.emit(0)
	var names := []
	for row in screen.find_child("LineRows", true, false).get_children():
		names.append(row.find_child("Name", true, false).text)
		assert_true(row.tooltip_text.begins_with("Caro-Kann Defense: "), "the full name stays in the tooltip")
		assert_true(row.accessibility_name.begins_with("Caro-Kann Defense: "), "and in the accessible name")
	names.sort()
	assert_eq(names, ["Advance Variation, Short Variation", "Advance Variation, Tal Variation"])
	setup.free()
	_clean(folder)


func _editor_mouse(window: Window, point: Vector2, button: int, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point + Vector2(window.position)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = motion.position
	event.global_position = motion.position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func test_editor_right_click_refreshes_tree_and_board():
	var repertoire = _repertoire()
	var folder := _folder()
	repertoire.storage_dir = folder
	assert_eq(repertoire.import_pgn("1. e4 e5 2. Nf3 *", "w", "Study"), "")
	var root: Window = Engine.get_main_loop().root
	var old_embed := root.gui_embed_subwindows
	var old_size := root.size
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 800)
	var editor = load("res://ui/repertoire_editor.tscn").instantiate()
	root.add_child(editor)
	editor.present(repertoire, "Study", 0)
	editor.size = Vector2i(760, 520)
	await Engine.get_main_loop().process_frame
	var tree = editor.find_child("Tree", true, false)
	var e5 = _find_move(tree, PackedStringArray(["e2e4", "e7e5"]))
	var point: Vector2 = e5.global_position + e5.size / 2
	_editor_mouse(editor, point, MOUSE_BUTTON_RIGHT, true)
	_editor_mouse(editor, point, MOUSE_BUTTON_RIGHT, false)
	await Engine.get_main_loop().process_frame
	# The deletion refreshes the tree deferred, which can land after the frame the click arrived in.
	await Engine.get_main_loop().process_frame
	assert_true(_find_move(tree, PackedStringArray(["e2e4", "e7e5"])) == null, "deleted subtree disappears")
	assert_eq(editor.board.game.board.position_key(), editor._node().position, "board returns to parent")
	assert_eq(editor.path, PackedStringArray(["e2e4"]))
	editor.free()
	root.gui_embed_subwindows = old_embed
	root.size = old_size
	_clean(folder)


# Starts now cross a real asynchronous searching screen.
func _wait_start(main) -> void:
	while main._starting:
		await Engine.get_main_loop().process_frame
