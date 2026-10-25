extends RefCounted

const Board = preload("res://core/board.gd")
const Pgn = preload("res://core/pgn.gd")

# One virtual root holds starting positions, so FEN chapters cannot merge unrelated moves.
# Each real node has position, children keyed by UCI, and merged annotations.
var tree := {}
var lines: Array = []
var colour := "w"


# Validate every chapter before publishing any tree. Errors keep the previous repertoire.
func parse(text: String, human_colour: String) -> String:
	if human_colour not in ["w", "b"]:
		return "Choose White or Black for the repertoire."
	var parsed := Pgn.parse(text)
	if not parsed.error.is_empty():
		return parsed.error
	var merged := {}
	for game in parsed.games:
		if game.moves.is_empty():
			continue
		var board = Board.from_fen(game.headers.get("FEN", Pgn.START))
		var key: String = board.position_key()
		if not merged.has(key):
			merged[key] = _node(key)
		_merge(game.moves, merged[key], board)
	if merged.is_empty():
		return "The PGN contains no moves."
	var paths := []
	for root in merged.values():
		_collect(root, PackedStringArray(), PackedStringArray([root.position]), paths, human_colour)
	tree = merged
	lines = paths
	colour = human_colour
	return ""


static func _node(position: String) -> Dictionary:
	return {"position": position, "children": {}, "comments": [], "comments_before": [], "nags": []}


static func _merge(moves: Array, parent: Dictionary, board) -> void:
	for move in moves:
		for variation in move.variations:
			_merge(variation, parent, board.copy())
		board.make_move(move.uci)
		if not parent.children.has(move.uci):
			parent.children[move.uci] = _node(board.position_key())
		var child: Dictionary = parent.children[move.uci]
		for fields in [["comment", "comments"], ["comment_before", "comments_before"]]:
			var annotation: String = move[fields[0]]
			if not annotation.is_empty() and annotation not in child[fields[1]]:
				child[fields[1]].append(annotation)
		for nag in move.nags:
			if nag not in child.nags:
				child.nags.append(nag)
		parent = child


static func _collect(node: Dictionary, moves: PackedStringArray, positions: PackedStringArray,
		paths: Array, human_colour: String) -> void:
	if node.children.is_empty():
		var id := "repertoire:%s:%s" % [human_colour, (positions[0] + " " + " ".join(moves)).sha256_text()]
		paths.append({"id": id, "moves": moves, "positions": positions})
		return
	for move in node.children:
		var next_moves := moves.duplicate()
		var next_positions := positions.duplicate()
		next_moves.append(move)
		next_positions.append(node.children[move].position)
		_collect(node.children[move], next_moves, next_positions, paths, human_colour)
