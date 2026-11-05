extends RefCounted

const Board = preload("res://core/board.gd")
const Game = preload("res://core/game.gd")


# Pure review data, one record per ply. Use every catalog line, regardless of checks.
static func evaluate(moves: PackedStringArray, catalog: Array, repertoire: Array,
		human_colour: String, check_repertoire: bool, starting_fen: String = Game.START) -> Array:
	var book: Dictionary = catalog_index(catalog).continuations
	var expected := _continuations(repertoire) if check_repertoire else {}
	var board = Board.from_fen(starting_fen)
	var in_book := true
	var in_repertoire := check_repertoire and not repertoire.is_empty()
	var result := []
	for move in moves:
		in_book = in_book and book.get(board.position_key(), {}).has(move)
		var mark := {"book": in_book, "repertoire": false,
				"left_repertoire": false, "expected": PackedStringArray()}
		if in_repertoire and board.side_to_move == human_colour:
			var continuations: Dictionary = expected.get(board.position_key(), {})
			mark.repertoire = continuations.has(move)
			if not mark.repertoire:
				mark.left_repertoire = true
				in_repertoire = false
				for continuation in continuations:
					mark.expected.append(board.san(continuation))
				mark.expected.sort()
		result.append(mark)
		board.make_move(move)
	return result


static func _continuations(lines: Array) -> Dictionary:
	var positions := {}
	for line in lines:
		for i in line.moves.size():
			var key: String = line.positions[i]
			if not positions.has(key):
				positions[key] = {}
			positions[key][line.moves[i]] = true
	return positions


# Catalog arrays are immutable once published. Keep only the most recently used
# catalog, and notice appended TSV rows as well as replacement arrays.
static var _catalog: Array = []
static var _catalog_size := -1
static var _index := {}


static func catalog_index(lines: Array) -> Dictionary:
	if not is_same(lines, _catalog) or lines.size() != _catalog_size:
		_catalog = lines
		_catalog_size = lines.size()
		var positions := {}
		var endings := {}
		var longest := 0
		for line in lines:
			for key in line.positions:
				positions[key] = true
			longest = maxi(longest, line.positions.size())
			if not line.positions.is_empty():
				endings[line.positions[-1]] = line.get("name", "")
		_index = {"continuations": _continuations(lines), "positions": positions, "endings": endings, "longest": longest}
	return _index
