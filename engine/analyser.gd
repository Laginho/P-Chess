extends Node

const Tunables = preload("res://core/tunables.gd")


# Samples are completed PV1 depths, in ascending order, from the mover's side.
static func converged(samples: Array) -> bool:
	if samples.size() < Tunables.ANALYSIS_STABLE_DEPTHS:
		return false
	var recent := samples.slice(-Tunables.ANALYSIS_STABLE_DEPTHS)
	if recent.back().depth < Tunables.ANALYSIS_MIN_DEPTH:
		return false
	var first: Dictionary = recent[0]
	var low := 1.0
	var high := 0.0
	for sample: Dictionary in recent:
		if sample.move != first.move:
			return false
		var cp: int = clampi(sample.get("cp", 1000 if sample.get("mate", 0) > 0 else -1000), -1000, 1000)
		var ep := 1.0 / (1.0 + exp(-0.00368208 * cp))
		low = minf(low, ep)
		high = maxf(high, ep)
	return high - low < Tunables.ANALYSIS_EP_CHANGE
