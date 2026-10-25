extends RefCounted

# Human-only moves on a copy of the position. Opponent replies are unknown until execution.
var human: String
var moves := PackedStringArray()


func _init(side: String) -> void:
	human = side


func enqueue(board, move: String) -> bool:
	if board.side_to_move == human:
		return false
	var ghost = position(board)
	if ghost == null or not move in ghost.legal_moves():
		return false
	moves.append(move)
	return true


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
