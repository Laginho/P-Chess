extends RefCounted

# Human-only moves on a copy of the position. Opponent replies are unknown until execution.
var human: String
var moves := PackedStringArray()
var style := "Chess.com":
	set(value):
		style = value
		if value == "off":
			clear()
		elif value == "Lichess" and moves.size() > 1:
			moves.resize(1)


func _init(side: String) -> void:
	human = side


func enqueue(board, move: String) -> bool:
	if style == "off" or board.side_to_move == human:
		return false
	var ghost = input_position(board)
	if ghost == null or not move in targets(ghost, move.substr(0, 2)):
		return false
	# Repeated human turns can put the opposing king in reach of Board's move generator.
	if ghost.piece_at(move.substr(2, 2)).to_lower() == "k":
		return false
	if style == "Lichess":
		clear()
	moves.append(move)
	return true


func clear() -> void:
	moves.clear()


# Take only the due move. The caller plays it before asking for another opponent reply.
func take(board) -> String:
	if moves.is_empty() or board.side_to_move != human:
		return ""
	var move := moves[0]
	if not move in board.legal_moves():
		clear()
		return ""
	moves.remove_at(0)
	return move


# Lichess replaces its one move, so input starts from the real position, not its old ghost.
func input_position(board):
	if style != "Lichess":
		return position(board)
	var ghost = board.copy()
	_human_turn(ghost)
	return ghost


# Null means a queued move no longer fits the known position. Execution will drop that queue.
func position(board):
	var ghost = board.copy()
	for move in moves:
		_human_turn(ghost)
		if not move in targets(ghost, move.substr(0, 2)) or ghost.piece_at(move.substr(2, 2)).to_lower() == "k":
			return null
		var from := move.substr(0, 2)
		var to := move.substr(2, 2)
		var from_index: int = (from.unicode_at(1) - 49) * 8 + from.unicode_at(0) - 97
		var to_index: int = (to.unicode_at(1) - 49) * 8 + to.unicode_at(0) - 97
		var piece: String = ghost.squares[from_index]
		if piece.to_lower() == "p" and from[0] != to[0] and to == ghost.en_passant:
			ghost.squares[to_index - 8 if human == "w" else to_index + 8] = ""
		ghost.squares[to_index] = piece if move.length() == 4 else (move[4].to_upper() if human == "w" else move[4])
		ghost.squares[from_index] = ""
		if piece.to_lower() == "k" and absi(to_index - from_index) == 2:
			var rook: int = from_index + 3 if to_index > from_index else from_index - 4
			var rook_to: int = (from_index + to_index) / 2
			if ghost.squares[rook] == ("R" if human == "w" else "r") and ghost.squares[rook_to].to_lower() != "k":
				ghost.squares[rook_to] = ghost.squares[rook]
				ghost.squares[rook] = ""
		ghost.en_passant = "-"
	_human_turn(ghost)
	return ghost


func _human_turn(board) -> void:
	if board.side_to_move != human:
		board.en_passant = "-"
	board.side_to_move = human


# Geometric targets ignore enemy pieces and check; real legality is checked when due.
# Own pieces only move when queued, so the input position decides what they block (§8.2).
func targets(board, from: String) -> PackedStringArray:
	var result := PackedStringArray()
	if from.length() != 2 or from[0] not in "abcdefgh" or from[1] not in "12345678":
		return result
	var piece: String = board.piece_at(from)
	if piece == "" or (piece == piece.to_upper()) != (human == "w"):
		return result
	var x := from.unicode_at(0) - 97
	var y := from.unicode_at(1) - 49
	for tx in 8:
		for ty in 8:
			var dx: int = absi(tx - x)
			var dy: int = absi(ty - y)
			var forward: int = (ty - y) * (1 if human == "w" else -1)
			var fits := false
			match piece.to_lower():
				"n": fits = (dx == 1 and dy == 2) or (dx == 2 and dy == 1)
				"b": fits = dx == dy and dx > 0 and _clear(board, x, y, tx, ty)
				"r": fits = (dx == 0) != (dy == 0) and _clear(board, x, y, tx, ty)
				"q": fits = ((dx == dy and dx > 0) or ((dx == 0) != (dy == 0))) and _clear(board, x, y, tx, ty)
				"k": fits = (maxi(dx, dy) == 1) or (from == ("e1" if human == "w" else "e8") and dy == 0 and dx == 2 and _clear(board, x, y, 7 if tx > x else 0, y))
				# A push checks one square past its target, so its landing square is covered too.
				"p": fits = (dx == 1 and forward == 1) or (dx == 0 and (forward == 1 or (forward == 2 and y == (1 if human == "w" else 6))) and _clear(board, x, y, tx, ty + (1 if human == "w" else -1)))
			var to := "abcdefgh"[tx] + str(ty + 1)
			if fits and board.piece_at(to).to_lower() != "k":
				if piece.to_lower() == "p" and ty == (7 if human == "w" else 0):
					for promotion in ["q", "r", "b", "n"]:
						result.append(from + to + promotion)
				else:
					result.append(from + to)
	return result


# True when no own piece stands strictly between the two squares of one line.
func _clear(board, x: int, y: int, tx: int, ty: int) -> bool:
	var step := Vector2i(signi(tx - x), signi(ty - y))
	var at := Vector2i(x, y) + step
	while at != Vector2i(tx, ty):
		var piece: String = board.squares[at.y * 8 + at.x]
		if piece != "" and (piece == piece.to_upper()) == (human == "w"):
			return false
		at += step
	return true
