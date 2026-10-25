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


class HeldEngine extends "res://engine/uci.gd":
	var requests := []


	func start(_dirs := PackedStringArray()) -> bool:
		return true


	func set_level(_path: String) -> void:
		pass


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
	main.uci.policy_ready.emit({"e7e5": 0.1, "d7d5": 0.9})
	assert_eq(main.board_view.game.moves, PackedStringArray(["e2e4", "e7e5"]))
	var first_target: String = main.maia.target_id
	main.board_view.game.resign("w")
	main._show_result()
	assert_eq(main.history.practice_counts(), {first_target: 1})
	var game_files := DirAccess.get_files_at(folder.path_join("games"))
	var parsed = load("res://core/pgn.gd").parse(FileAccess.get_file_as_string(folder.path_join("games").path_join(game_files[0])))
	assert_eq(parsed.games[0].headers.Opening, "King Pawn")
	main._start(main.rematch(main.settings))
	assert_eq(main.human, "b", "existing rematch swaps human side")
	assert_true(main.maia.target_id != first_target, "least-practiced remaining path")
	assert_eq(main.maia.book.entries[0].colour, "w", "Maia is now White")
	assert_eq(main.maia.book.weights(main.board_view.game.board, 0).e2e4, 20.0)
	assert_eq(main.uci.requests[-1], PackedStringArray(), "Maia requests White's first move")
	assert_eq(setup.repertoire.colour, "w", "imported colour unchanged by rematch")
	main._start({"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Catalog", "selection": "Catalog"})
	assert_true(main.maia.book == setup.book)
	assert_true(main.maia.target_id.begins_with("A00:"))
	assert_eq(main.maia.book.weights(main.board_view.game.board, 0).d2d4, 20.0)
	assert_eq(main.maia.book.weights(main.board_view.game.board, 0).e2e4, 1.0)
	main._start({"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"})
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
	assert_eq(main.clock, null, "no game starts after invalid saved repertoire")
	assert_eq(main.uci.requests.size(), 0)
	assert_true(main.setup.visible)
	assert_true("JSON" in main.setup.get_node("Center/Form/Missing").text)
	assert_eq(main.setup.repertoire.import_pgn(FileAccess.get_file_as_string(STUDY), "w", "Study"), "")
	main.setup.started.emit(settings)
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
