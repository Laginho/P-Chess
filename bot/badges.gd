extends RefCounted

const Board = preload("res://core/board.gd")
const Game = preload("res://core/game.gd")


# Pure review data, one record per ply. Use every catalog line, regardless of checks.
static func evaluate(moves: PackedStringArray, catalog: Array, repertoire: Array,
		human_colour: String, check_repertoire: bool, starting_fen: String = Game.START) -> Array:
	var book := _continuations(catalog)
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
