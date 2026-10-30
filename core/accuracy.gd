extends RefCounted

const Tunables = preload("res://core/tunables.gd")


static func move_accuracy(before: float, after: float) -> float:
	if after >= before:
		return 100.0
	return clampf(103.1668 * exp(-0.04354 * (before - after)) - 3.1669 + 1.0, 0.0, 100.0)


# Positions are stored in game order; each score belongs to the side to move.
static func evaluate(analysis: Dictionary) -> Dictionary:
	var positions: Array = analysis.positions
	var result := {"white": null, "black": null}
	if positions.size() < 2:
		return result
	var starts_white: bool = positions[0].fen.split(" ")[1] == "w"
	var win_percents: Array[float] = []
	for i in positions.size():
		var position: Dictionary = positions[i]
		var line: Dictionary = position.pv[0] if not position.pv.is_empty() else {"cp": position.terminal_score}
		var score: int = int(line.cp) if line.has("cp") else (Tunables.CLASSIFICATION_CP_LIMIT if line.mate > 0 else -Tunables.CLASSIFICATION_CP_LIMIT)
		if (i % 2 == 0) != starts_white:
			score = -score
		win_percents.append(100.0 / (1.0 + exp(-Tunables.CLASSIFICATION_EP_FACTOR * clampi(score, -Tunables.CLASSIFICATION_CP_LIMIT, Tunables.CLASSIFICATION_CP_LIMIT))))
	var window_size := clampi((positions.size() - 1) / 10, 2, 8)
	var weighted := [0.0, 0.0]
	var weights := [0.0, 0.0]
	var reciprocal := [0.0, 0.0]
	var counts := [0, 0]
	var zero := [false, false]
	for i in positions.size() - 1:
		var start := maxi(0, i - window_size + 2)
		var window := win_percents.slice(start, start + window_size)
		var mean := 0.0
		for value: float in window:
			mean += value
		mean /= window.size()
		var variance := 0.0
		for value: float in window:
			variance += (value - mean) * (value - mean)
		var weight := clampf(sqrt(variance / window.size()), 0.5, 12.0)
		var white: bool = (i % 2 == 0) == starts_white
		var before := win_percents[i] if white else 100.0 - win_percents[i]
		var after := win_percents[i + 1] if white else 100.0 - win_percents[i + 1]
		var accuracy := move_accuracy(before, after)
		var side := 0 if white else 1
		weighted[side] += accuracy * weight
		weights[side] += weight
		counts[side] += 1
		if accuracy == 0.0:
			zero[side] = true
		else:
			reciprocal[side] += 1.0 / accuracy
	for side in 2:
		if counts[side] > 0:
			var harmonic: float = 0.0 if zero[side] else counts[side] / reciprocal[side]
			result["white" if side == 0 else "black"] = (weighted[side] / weights[side] + harmonic) / 2.0
	return result
