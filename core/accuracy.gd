extends RefCounted


static func move_accuracy(before: float, after: float) -> float:
	if after >= before:
		return 100.0
	return clampf(103.1668 * exp(-0.04354 * (before - after)) - 3.1669 + 1.0, 0.0, 100.0)
