extends "res://tests/run.gd".Test

const Book = preload("res://bot/book.gd")
const START_KEY := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"
const E4_KEY := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -"
const E5_KEY := "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -"


func test_every_committed_lichess_row_loads_with_san_moves_and_position_keys():
	var book = Book.new()
	book.load_catalog()
	assert_eq(book.errors, [])
	# Counts from the pinned upstream files, excluding each header.
	assert_eq(book.volume_counts, {"a": 823, "b": 781, "c": 1250, "d": 644, "e": 367})
	assert_eq(book.entries.size(), 3865)
	var ids := {}
	for entry in book.entries:
		assert_true(not ids.has(entry.id), "a saved line has an unambiguous id")
		ids[entry.id] = true
		assert_true(not entry.moves.is_empty(), entry.name)
		assert_eq(entry.positions.size(), entry.moves.size() + 1, entry.name)
		assert_eq(entry.positions[0], START_KEY)


func test_invalid_san_is_reported_and_skipped_without_losing_later_rows():
	var book = Book.new()
	book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn Game\t1. e4 e5\n"
			+ "A00\tBad line\t1. e4 e5 2. Qh9\nA00\tAnother line\t1. d4\n"
			+ "A00\tNo moves\t1.\n", "sample")
	assert_eq(book.entries.size(), 2)
	assert_eq(book.entries[0].moves, PackedStringArray(["e2e4", "e7e5"]))
	assert_eq(book.entries[0].positions, PackedStringArray([START_KEY, E4_KEY, E5_KEY]))
	assert_eq(book.entries[1].name, "Another line")
	assert_eq(book.errors.size(), 2)
	assert_true("sample:3" in book.errors[0] and "Qh9" in book.errors[0], "report source, row and move")
	if book.errors.size() > 1:
		assert_true("sample:5" in book.errors[1], "a row with no moves is also reported")


func _sample():
	var book = Book.new()
	book.load_tsv("eco\tname\tpgn\n"
			+ "B20\tSicilian Defense\t1. e4 c5\n"
			+ "B90\tSicilian Defense: Najdorf Variation, English Attack\t1. e4 c5 2. Nf3\n"
			+ "B90\tSicilian Defense: Najdorf Variation, English Attack\t1. Nf3 c5 2. e4\n"
			+ "B90\tSicilian Defense: Najdorf Variation, Adams Attack\t1. e4 c5 2. Nc3\n"
			+ "C20\tKing's Pawn Game\t1. e4 e5\n")
	return book


func test_names_form_a_tree_and_search_keeps_matching_branches_and_their_ancestors():
	var book = _sample()
	assert_eq(book.roots, ["Sicilian Defense", "King's Pawn Game"])
	assert_eq(book.nodes["Sicilian Defense"].children, ["Sicilian Defense: Najdorf Variation"])
	var najdorf: Dictionary = book.nodes["Sicilian Defense: Najdorf Variation"]
	assert_eq(najdorf.label, "Najdorf Variation")
	assert_eq(najdorf.children, ["Sicilian Defense: Najdorf Variation, English Attack",
			"Sicilian Defense: Najdorf Variation, Adams Attack"])
	assert_eq(book.nodes[najdorf.children[0]].lines.size(), 2, "transposed rows share a name node")
	assert_eq(book.search("eNgLiSh"), ["Sicilian Defense", "Sicilian Defense: Najdorf Variation",
			"Sicilian Defense: Najdorf Variation, English Attack"])
	assert_eq(book.search("sicilian").size(), 4, "a family match includes all variations")
	assert_eq(book.search("unmatched"), [])
	assert_eq(book.search("").size(), 5)


func test_search_matches_original_punctuation_and_keeps_normalized_paths_and_ancestors():
	var book = Book.new()
	book.load_tsv("eco\tname\tpgn\n"
			+ "C25\tVienna Gambit, with Max Lange Defense: Cunningham Defense\t1. e4 e5 2. Nc3 Nc6 3. f4\n"
			+ "A00\tPolish Opening, with d5\t1. b4 d5\n"
			+ "B20\tSicilian Defense\t1. e4 c5\n")
	assert_eq(book.errors, [])
	var vienna := ["Vienna Gambit", "Vienna Gambit: with Max Lange Defense",
			"Vienna Gambit: with Max Lange Defense, Cunningham Defense"]
	for query in ["Vienna Gambit, with Max Lange Defense: Cunningham Defense",
			"mAx LaNgE dEfEnSe: cUnNiNgHaM", "Gambit, with", "Cunningham",
			"Vienna Gambit: with Max Lange Defense, Cunningham Defense"]:
		assert_eq(book.search(query), vienna, query)
	for query in ["Polish Opening, with d5", "oPeNiNg, WiTh", "Polish Opening: with d5"]:
		assert_eq(book.search(query), ["Polish Opening", "Polish Opening: with d5"], query)
	assert_eq(book.search("unmatched"), [])
	assert_eq(book.search("").size(), 6)


func test_checks_propagate_to_descendants_and_parents_show_partial_state():
	var book = _sample()
	var family := "Sicilian Defense"
	var najdorf := family + ": Najdorf Variation"
	var english := najdorf + ", English Attack"
	assert_eq(book.check_state(family), 0)
	book.set_checked(english, true)
	assert_eq(book.selected_ids().size(), 2, "both transpositions are selected")
	assert_eq(book.check_state(english), 1)
	assert_eq(book.check_state(najdorf), 2)
	assert_eq(book.check_state(family), 2)
	assert_eq(book.check_state("King's Pawn Game"), 0)
	book.set_checked(najdorf, true)
	assert_eq(book.check_state(najdorf), 1)
	assert_eq(book.check_state(family), 2, "family's own line is still unchecked")
	book.set_checked(family, true)
	assert_eq(book.selected_ids().size(), 4)
	assert_eq(book.check_state(family), 1)
	book.set_checked(najdorf, false)
	assert_eq(book.selected_ids(), [book.entries[0].id], "keep the family's own catalog line")
	book.set_checked(family, false)
	assert_eq(book.selected_ids(), [])
	assert_eq(book.check_state(family), 0)


func _folder() -> String:
	return "user://test_openings_%d" % Time.get_ticks_usec()


func _remove_folder(folder: String) -> void:
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)


func test_named_selections_round_trip_and_can_be_replaced_or_empty():
	var folder := _folder()
	var book = _sample()
	book.selection_dir = folder
	assert_eq(book.selection_names(), [])
	book.set_checked("Sicilian Defense: Najdorf Variation", true)
	var selected: Array = book.selected_ids()
	assert_eq(book.save_selection("Najdorf practice"), "")
	assert_true(FileAccess.file_exists(folder.path_join("Najdorf practice.json")))
	var restored = _sample()
	restored.selection_dir = folder
	assert_eq(restored.selection_names(), ["Najdorf practice"])
	assert_eq(restored.load_selection("Najdorf practice"), "")
	assert_eq(restored.selected_ids(), selected)
	assert_eq(restored.check_state("Sicilian Defense"), 2)
	restored.set_checked("Sicilian Defense", false)
	assert_eq(restored.save_selection("Najdorf practice"), "")
	assert_eq(book.load_selection("Najdorf practice"), "")
	assert_eq(book.selected_ids(), [], "loading replaces the old selection, including with an empty one")
	_remove_folder(folder)


func test_selection_errors_preserve_checks_and_cannot_escape_the_selection_folder():
	var folder := _folder()
	var book = _sample()
	book.selection_dir = folder
	book.set_checked("King's Pawn Game", true)
	var selected: Array = book.selected_ids()
	for name in ["", "../escape", "a/b", "a\\b", ".", "..", "a:b", "trailing.", "CON", "NUL.json"]:
		assert_true(not book.save_selection(name).is_empty(), "reject unsafe filename " + name)
		assert_true(not book.load_selection(name).is_empty(), "refuse unsafe load " + name)
	assert_true(not book.load_selection("missing").is_empty())
	assert_eq(book.selected_ids(), selected)
	assert_eq(book.save_selection("valid"), "")
	for contents in ["not JSON", "[]", '{"version":1,"lines":["unknown"]}',
			'{"version":1,"lines":[42]}', '{"version":2,"lines":[]}']:
		var file := FileAccess.open(folder.path_join("broken.json"), FileAccess.WRITE)
		file.store_string(contents)
		file.close()
		assert_true(not book.load_selection("broken").is_empty(), contents)
		assert_eq(book.selected_ids(), selected, "failed load leaves current checks untouched")
	_remove_folder(folder)


func _find_item(item: TreeItem, path: String) -> TreeItem:
	if item.get_metadata(0) == path:
		return item
	for child in item.get_children():
		var found := _find_item(child, path)
		if found != null:
			return found
	return null


func test_picker_search_checks_partial_parents_and_save_load_buttons_use_the_catalog():
	var scene = load("res://ui/opening_picker.tscn")
	assert_true(scene != null, "the real opening picker scene exists")
	if scene == null:
		return
	var picker = scene.instantiate()
	var folder := _folder()
	picker.book = _sample()
	picker.book.selection_dir = folder
	Engine.get_main_loop().root.add_child(picker)
	picker.present()
	var tree: Tree = picker.get_node("Margin/Form/Tree")
	var search: LineEdit = picker.get_node("Margin/Form/Search")
	search.text = "eNgLiSh"
	search.text_changed.emit(search.text)
	var family := "Sicilian Defense"
	var najdorf := family + ": Najdorf Variation"
	var english := najdorf + ", English Attack"
	assert_true(_find_item(tree.get_root(), "King's Pawn Game") == null)
	var item := _find_item(tree.get_root(), english)
	assert_true(item != null, "search retains the matching variation")
	if item == null:
		picker.free()
		return
	item.select(0)
	assert_true(tree.edit_selected(), "edit a real checkbox through Godot")
	assert_eq(picker.book.check_state(english), 1)
	assert_true(_find_item(tree.get_root(), family).is_indeterminate(0))
	assert_true(_find_item(tree.get_root(), najdorf).is_indeterminate(0))
	var names: Array = []
	picker.saved.connect(func(name): names.append(name))
	picker.get_node("Margin/Form/SaveRow/Name").text = "Najdorf"
	picker.get_node("Margin/Form/SaveRow/Save").pressed.emit()
	assert_eq(names, ["Najdorf"])
	assert_eq(picker.book.selection_names(), ["Najdorf"])
	# Checking a filtered family still selects its hidden descendants.
	_find_item(tree.get_root(), family).select(0)
	assert_true(tree.edit_selected())
	assert_eq(picker.book.selected_ids().size(), 4)
	picker.get_node("Margin/Form/LoadRow/Load").pressed.emit()
	assert_eq(picker.book.selected_ids().size(), 2, "load restores the saved checks")
	search.clear()
	search.text_changed.emit("")
	assert_true(_find_item(tree.get_root(), "King's Pawn Game") != null)
	assert_true(_find_item(tree.get_root(), english).is_checked(0))
	picker.get_node("Margin/Form/Done").pressed.emit()
	assert_true(not picker.visible)
	picker.free()
	_remove_folder(folder)


func test_setup_lists_saved_selections_and_emits_catalog_choice_while_free_stays_compatible():
	var folder := _folder()
	var book = _sample()
	book.selection_dir = folder
	book.set_checked("Sicilian Defense: Najdorf Variation", true)
	assert_eq(book.save_selection("Najdorf"), "")
	var setup = load("res://ui/setup.tscn").instantiate()
	setup.book = book
	Engine.get_main_loop().root.add_child(setup)
	var modes: OptionButton = setup.get_node("Center/Form/Opening")
	assert_true(not modes.is_item_disabled(1), "Catalog is enabled")
	assert_true(modes.is_item_disabled(2), "repertoire still belongs to OPEN-003")
	var settings: Array = []
	setup.started.connect(func(choice): settings.append(choice))
	setup.get_node("Center/Form/Start").pressed.emit()
	assert_eq(settings[0], {"colour": "w", "level": "maia-1500", "control": "1+0", "opening": "Free"})
	modes.select(1)
	modes.item_selected.emit(1)
	var selections: OptionButton = setup.get_node("Center/Form/CatalogControls/Selections")
	assert_eq(selections.get_item_text(0), "Najdorf")
	assert_true(selections.is_visible_in_tree())
	setup.get_node("Center/Form/Start").pressed.emit()
	assert_eq(settings[1].opening, "Catalog")
	assert_eq(settings[1].selection, "Najdorf")
	# The picker saves another name and setup immediately offers it without reopening setup.
	setup.get_node("Center/Form/CatalogControls/Edit").pressed.emit()
	var picker = setup.get_node("OpeningPicker")
	assert_true(picker.visible)
	picker.get_node("Margin/Form/SaveRow/Name").text = "New practice"
	picker.get_node("Margin/Form/SaveRow/Save").pressed.emit()
	assert_eq(selections.item_count, 2)
	assert_eq(selections.get_item_text(selections.selected), "New practice")
	setup.free()
	_remove_folder(folder)


func test_setup_without_saved_selections_blocks_catalog_start_but_allows_editing_and_free():
	var setup = load("res://ui/setup.tscn").instantiate()
	setup.book = _sample()
	setup.book.selection_dir = _folder()
	Engine.get_main_loop().root.add_child(setup)
	var modes: OptionButton = setup.get_node("Center/Form/Opening")
	var start: Button = setup.get_node("Center/Form/Start")
	modes.select(1)
	modes.item_selected.emit(1)
	assert_true(start.disabled)
	assert_true(not setup.get_node("Center/Form/CatalogControls/Edit").disabled)
	var choices: Array = []
	setup.started.connect(func(settings): choices.append(settings))
	start.pressed.emit()
	assert_eq(choices, [], "even a stale start signal cannot start Catalog without a selection")
	modes.select(0)
	modes.item_selected.emit(0)
	assert_true(not start.disabled)
	assert_true(not setup.get_node("Center/Form/CatalogControls").visible)
	setup.free()
