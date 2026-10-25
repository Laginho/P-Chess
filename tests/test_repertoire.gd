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
