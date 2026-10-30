extends RefCounted

const Badges = preload("res://bot/badges.gd")


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
		var label := "Best" if moves[i] == before.best_move else "Excellent"
		result.append({"class": label, "loss": loss, "before_ep": before_ep,
				"after_ep": after_ep, "left_repertoire": marks[i].left_repertoire,
				"expected": marks[i].expected})
	return result


static func _score(line: Dictionary) -> int:
	return int(line.cp) if line.has("cp") else (1000 if line.mate > 0 else -1000)


static func _ep(cp: int) -> float:
	return 1.0 / (1.0 + exp(-0.00368208 * clampi(cp, -1000, 1000)))
