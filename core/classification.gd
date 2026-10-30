extends RefCounted

const Badges = preload("res://bot/badges.gd")
const Board = preload("res://core/board.gd")
const Tunables = preload("res://core/tunables.gd")


# Analysis scores are from the side to move in each stored position.
static func evaluate(moves: PackedStringArray, analysis: Dictionary, catalog: Array,
		repertoire: Array, human_colour: String, check_repertoire: bool) -> Array:
	var positions: Array = analysis.positions
	var marks: Array = Badges.evaluate(moves, catalog, repertoire, human_colour, check_repertoire)
	var result := []
	for i in moves.size():
		var before: Dictionary = positions[i]
		var lines: Array = before.pv
		var best: Dictionary = lines[0]
		var after: Dictionary = positions[i + 1]
		var played: Dictionary = after.pv[0].duplicate() if not after.pv.is_empty() else {"cp": after.terminal_score}
		var key := "cp" if played.has("cp") else "mate"
		played[key] = -int(played[key])
		for line: Dictionary in lines:
			if line.moves[0] == moves[i]:
				played = line
				break
		if after.pv.is_empty():
			played = {"cp": -int(after.terminal_score)}
			var end_board = Board.from_fen(after.fen)
			if int(after.terminal_score) == -Tunables.CLASSIFICATION_CP_LIMIT and end_board.in_check() and end_board.legal_moves().is_empty():
				played = {"mate": 1}
		var played_score := _score(played)
		var before_ep := _ep(_score(best))
		var after_ep := _ep(played_score)
		var loss := maxf(0.0, before_ep - after_ep)
		var label := _mate_or_band(best, played, loss)
		if label in ["Mistake", "Blunder"] and i > 0 and result[i - 1].class in ["Mistake", "Blunder"] \
				and before_ep >= Tunables.CLASSIFICATION_MISS_BEFORE_EP \
				and after_ep <= Tunables.CLASSIFICATION_MISS_AFTER_EP \
				and loss >= Tunables.CLASSIFICATION_MISS_LOSS:
			label = "Miss"
		elif label == "Blunder" and (played_score >= Tunables.CLASSIFICATION_LENIENT_CP \
				or _score(best) <= -Tunables.CLASSIFICATION_LENIENT_CP):
			label = "Good"
		var board = Board.from_fen(before.fen)
		if board.legal_moves().size() == 1:
			label = "Forced"
		elif marks[i].repertoire:
			label = "Repertoire"
		elif marks[i].book:
			label = "Book"
		elif moves[i] == before.best_move:
			label = "Best"
			if _great(board, moves, i, lines, after_ep):
				label = "Brilliant" if _sacrifice(board, lines[0].moves) else "Great"
		result.append({"class": label, "loss": loss, "before_ep": before_ep,
				"after_ep": after_ep, "left_repertoire": marks[i].left_repertoire,
				"expected": marks[i].expected})
	return result


static func _score(line: Dictionary) -> int:
	return int(line.cp) if line.has("cp") else (Tunables.CLASSIFICATION_CP_LIMIT if line.mate > 0 else -Tunables.CLASSIFICATION_CP_LIMIT)


static func _ep(cp: int) -> float:
	return 1.0 / (1.0 + exp(-Tunables.CLASSIFICATION_EP_FACTOR * clampi(cp, -Tunables.CLASSIFICATION_CP_LIMIT, Tunables.CLASSIFICATION_CP_LIMIT)))


static func _band(loss: float) -> String:
	if loss <= Tunables.CLASSIFICATION_EXCELLENT_LOSS:
		return "Excellent"
	if loss <= Tunables.CLASSIFICATION_GOOD_LOSS:
		return "Good"
	if loss <= Tunables.CLASSIFICATION_INACCURACY_LOSS:
		return "Inaccuracy"
	if loss <= Tunables.CLASSIFICATION_MISTAKE_LOSS:
		return "Mistake"
	return "Blunder"


static func _mate_or_band(best: Dictionary, played: Dictionary, loss: float) -> String:
	var before_mate: int = best.get("mate", 0)
	var after_mate: int = played.get("mate", 0)
	if after_mate < 0:
		if -after_mate <= Tunables.CLASSIFICATION_MATE_BLUNDER_MOVES:
			return "Blunder"
		if -after_mate <= Tunables.CLASSIFICATION_MATE_MISTAKE_MOVES:
			return "Mistake"
		return "Inaccuracy"
	if before_mate > 0:
		if after_mate > 0:
			if after_mate <= before_mate:
				return "Best"
			return "Excellent" if after_mate <= before_mate + Tunables.CLASSIFICATION_MATE_SLOWER else "Good"
		var cp := _score(played)
		if cp >= Tunables.CLASSIFICATION_MATE_EXCELLENT_CP:
			return "Excellent"
		if cp >= Tunables.CLASSIFICATION_MATE_GOOD_CP:
			return "Good"
		if cp >= Tunables.CLASSIFICATION_MATE_INACCURACY_CP:
			return "Inaccuracy"
		return "Mistake" if cp >= 0 else "Blunder"
	return _band(loss)


static func _great(board, moves: PackedStringArray, i: int, lines: Array, after_ep: float) -> bool:
	if lines.size() < 2 or _score(lines[1]) >= Tunables.CLASSIFICATION_GREAT_PV2_CP:
		return false
	if _ep(_score(lines[0])) - _ep(_score(lines[1])) < Tunables.CLASSIFICATION_GREAT_LOSS or after_ep < Tunables.CLASSIFICATION_MIN_EP:
		return false
	var move := moves[i]
	if board.in_check() or move.length() > 4 or (i > 0 and moves[i - 1].substr(2, 2) == move.substr(2, 2)):
		return false
	var victim: String = board.piece_at(move.substr(2, 2))
	if not victim.is_empty():
		var square := (move.unicode_at(3) - 49) * 8 + move.unicode_at(2) - 97
		if not board._attacked(square, board.side_to_move == "b"):
			return false
	return true


static func _sacrifice(board, pv: Array) -> bool:
	var side: String = board.side_to_move
	var before := _material(board, side)
	var position = board.copy()
	for i in mini(pv.size(), Tunables.CLASSIFICATION_SACRIFICE_PLIES + 1):
		var move: String = pv[i]
		if not move in position.legal_moves():
			break
		position.make_move(move)
	return _material(position, side) < before


static func _material(board, side: String) -> int:
	var balance := 0
	for piece: String in board.squares:
		if piece.is_empty():
			continue
		var value: int = Tunables.CLASSIFICATION_MATERIAL.get(piece.to_lower(), 0)
		balance += value if (piece == piece.to_upper()) == (side == "w") else -value
	return balance
