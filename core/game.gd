extends RefCounted

# A game on top of the board: the move history and every way it ends under Lichess behaviour (§7).
# The UI and the bot only ask whether it is over and why.

const Board = preload("res://core/board.gd")

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

var board
# UCI moves played since the starting position.
var moves := PackedStringArray()
# Ends the game the moment a threefold claim becomes available (§7's "auto-claim threefold").
var auto_claim := false
# PGN result: "*" while the game is on, then "1-0", "0-1" or "1/2-1/2".
var result := "*"
# checkmate, stalemate, 50-move, repetition, insufficient material, time or resignation.
var reason := ""
# Position key -> times it has occurred.
var _seen := {}


func _init(fen := START) -> void:
	board = Board.from_fen(fen)
	_after_move()


func is_over() -> bool:
	return result != "*"


# Plays a UCI move; false, changing nothing, when it is illegal or the game is over.
func play(move: String) -> bool:
	if is_over() or not move in board.legal_moves():
		return false
	board.make_move(move)
	moves.append(move)
	_after_move()
	return true


func can_claim_draw() -> bool:
	return not is_over() and _seen[board.position_key()] >= 3


func claim_draw() -> void:
	if can_claim_draw():
		_end("1/2-1/2", "repetition")


func agree_draw() -> void:
	if not is_over():
		_end("1/2-1/2", "agreement")


# side is "w" or "b", as Board.side_to_move.
func resign(side: String) -> void:
	if not is_over():
		_end(_loss(side), "resignation")


# The side whose time ran out loses, unless the opponent cannot mate by any legal sequence.
func flag(side: String) -> void:
	if not is_over():
		_end("1/2-1/2" if board.cannot_mate("b" if side == "w" else "w") else _loss(side), "time")


# In scalachess's order: mate first, so a mating move on the 100th ply wins.
func _after_move() -> void:
	var key: String = board.position_key()
	_seen[key] = _seen.get(key, 0) + 1
	if board.legal_moves().is_empty():
		if board.in_check():
			_end(_loss(board.side_to_move), "checkmate")
		else:
			_end("1/2-1/2", "stalemate")
	elif board.halfmove_clock >= 100:
		_end("1/2-1/2", "50-move")
	elif board.cannot_mate("w") and board.cannot_mate("b"):
		_end("1/2-1/2", "insufficient material")
	elif _seen[key] >= 5 or (auto_claim and _seen[key] >= 3):
		_end("1/2-1/2", "repetition")


static func _loss(side: String) -> String:
	return "0-1" if side == "w" else "1-0"


func _end(new_result: String, new_reason: String) -> void:
	result = new_result
	reason = new_reason
