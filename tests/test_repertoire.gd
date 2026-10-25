extends "res://tests/run.gd".Test

const Board = preload("res://core/board.gd")
const Book = preload("res://bot/book.gd")
const STUDY := "res://tests/fixtures/pgn/repertoire_study.pgn"


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
		assert_eq(weights.e7e5, Book.INTENSITIES[intensity][0])
		assert_eq(weights.c7c5, Book.INTENSITIES[intensity][1])
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
	var importer = setup.get_node("RepertoireImport")
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
	setup.get_node("Center/Form/RepertoireControls/Import").pressed.emit()
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
