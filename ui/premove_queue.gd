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
	if ghost == null or not move in ghost.legal_moves():
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
		if not move in ghost.legal_moves():
			return null
		ghost.make_move(move)
	_human_turn(ghost)
	return ghost


func _human_turn(board) -> void:
	if board.side_to_move != human:
		board.en_passant = "-"
	board.side_to_move = human
