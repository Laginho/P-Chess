extends RefCounted

const Board = preload("res://core/board.gd")
const Game = preload("res://core/game.gd")


# Pure review data, one record per ply. Use every catalog line, regardless of checks.
static func evaluate(moves: PackedStringArray, catalog: Array, _repertoire: Array,
		_human_colour: String, _check_repertoire: bool) -> Array:
	var book := _continuations(catalog)
	var board = Board.from_fen(Game.START)
	var in_book := true
	var result := []
	for move in moves:
		in_book = in_book and book.get(board.position_key(), {}).has(move)
		result.append({"book": in_book, "repertoire": false,
				"left_repertoire": false, "expected": PackedStringArray()})
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
