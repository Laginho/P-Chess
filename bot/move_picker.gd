extends RefCounted

# Turns Maia's policy into one sampled move (spec §3.3). Pure: the caller owns the RNG.
# A policy (and weights) maps a move id to a number; the move ids are opaque here.

const DEFAULT_TAU := 0.02
const DEFAULT_TEMPERATURE := 1.0
# Panic intensity -> [T_max, tau_min] (spec §3.4); "off" leaves T and tau alone.
const PANIC := {"low": [1.3, 0.01], "medium": [1.7, 0.005], "high": [2.2, 0.002]}


# Book weight, renormalise; cut below tau keeping the top move, renormalise; p^(1/T), renormalise.
static func distribution(policy: Dictionary, weights := {}, tau := DEFAULT_TAU,
		temperature := DEFAULT_TEMPERATURE) -> Dictionary:
	var p := {}
	for move in policy:
		p[move] = policy[move] * weights.get(move, 1.0)
	p = _normalised(p)
	if p.is_empty():
		return p
	var top = p.keys()[0]
	for move in p:
		if p[move] > p[top]:
			top = move
	if p[top] <= 0.0:
		return {top: 1.0}  # no usable mass (all-zero policy or weights): the first move
	var kept := {}
	for move in p:
		if move == top or p[move] >= tau:
			kept[move] = p[move]
	kept = _normalised(kept)
	# Relative to the top move, so a small T cannot underflow every p to 0; T = 0 keeps the top.
	var top_p: float = kept[top]
	for move in kept:
		kept[move] = pow(kept[move] / top_p, 1.0 / temperature)
	return _normalised(kept)


# The sampled move, or "" for an empty policy.
static func pick(policy: Dictionary, rng: RandomNumberGenerator, weights := {}, tau := DEFAULT_TAU,
		temperature := DEFAULT_TEMPERATURE) -> String:
	var dist := distribution(policy, weights, tau, temperature)
	var r := rng.randf()
	var move := ""
	for m in dist:
		move = m
		r -= dist[m]
		if r < 0.0:
			break
	return move


# T and tau under time pressure: unchanged down to 10% of the starting time, then linear
# to T_max and tau_min at 0. Both times in the same unit.
static func panic(temperature: float, tau: float, intensity: String, time_left: float,
		start_time: float) -> Dictionary:
	if intensity == "off":
		return {"temperature": temperature, "tau": tau}
	var target: Array = PANIC[intensity]
	var s := clampf(1.0 - time_left / (0.1 * start_time), 0.0, 1.0)
	return {"temperature": lerpf(temperature, target[0], s), "tau": lerpf(tau, target[1], s)}


# All zero (or empty) has no distribution to keep, so it is returned as is.
static func _normalised(p: Dictionary) -> Dictionary:
	var total := 0.0
	for move in p:
		total += p[move]
	if total <= 0.0:
		return p
	var out := {}
	for move in p:
		out[move] = p[move] / total
	return out
