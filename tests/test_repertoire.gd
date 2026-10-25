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
	var invalid := "1. e4 e5 *\n[Event \"Broken chapter\"]\n1. d4 d5 2. Bh6 *"
	for name in ["Study", "Broken"]:
		var error: String = repertoire.import_pgn(invalid, "w", name)
		assert_true("Game 2, move 2." in error and "Bh6" in error, error)
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
