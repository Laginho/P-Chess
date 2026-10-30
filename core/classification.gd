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
		var played_score := -_score(after.pv[0]) if not after.pv.is_empty() else -int(after.terminal_score)
		for line: Dictionary in lines:
			if line.moves[0] == moves[i]:
				played_score = _score(line)
				break
		var before_ep := _ep(_score(best))
		var after_ep := _ep(played_score)
		var loss := maxf(0.0, before_ep - after_ep)
		var label := _band(loss)
		if Board.from_fen(before.fen).legal_moves().size() == 1:
			label = "Forced"
		elif marks[i].repertoire:
			label = "Repertoire"
		elif marks[i].book:
			label = "Book"
		elif moves[i] == before.best_move:
			label = "Best"
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
