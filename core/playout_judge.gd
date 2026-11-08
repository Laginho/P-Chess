extends RefCounted

const Board = preload("res://core/board.gd")
const Tunables = preload("res://core/tunables.gd")
var probe

func _init(tablebase) -> void:
	probe = tablebase

# Ask about the position before the move: root move results are for the mover.
func check(fen: String, move: String, goal: String, own_moves: int, callback: Callable) -> void:
	var board = Board.from_fen(fen)
	if board == null or move not in board.legal_moves():
		callback.call({"ok": false, "error": "Invalid play-out move."})
		return
	probe.probe(board.to_fen(), func(answer: Dictionary):
		if not answer.get("ok", false):
			callback.call(answer)
			return
		var played: Dictionary = answer.get("moves", {}).get(move, {})
		if played.is_empty() or not answer.has("result"):
			callback.call({"ok": false, "error": "The tablebase did not return this move."})
			return
		if played.get("result") != answer.result:
			callback.call({"ok": true, "state": "failed", "best": answer.get("best", "")})
			return
		board.make_move(move)
		var mate: bool = board.legal_moves().is_empty() and board.in_check()
		var promoted := move.length() == 5
		var pieces := "".join(board.squares)
		var pawn_gone: bool = not "P" in pieces and not "p" in pieces
		var reason := ""
		if goal == "convert":
			if promoted:
				reason = "You promoted a pawn."
			elif mate:
				reason = "You checkmated."
		elif goal == "hold":
			if pawn_gone:
				reason = "You captured the pawn and kept the draw."
			elif own_moves >= Tunables.COURSE_HOLD_MOVES:
				reason = "You held the draw for %d moves." % Tunables.COURSE_HOLD_MOVES
		callback.call({"ok": true, "state": "passed" if not reason.is_empty() else "continue", "best": answer.get("best", ""), "reason": reason})
	)
