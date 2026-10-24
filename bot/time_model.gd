extends RefCounted

# How long Maia thinks (§4), in seconds: the hand-tuned fallback of §4.2 with the overrides of §4.1.
# Pure: the caller owns the RNG. BOT-006 replaces the formula with the calibrated table.

const FLOOR := 0.05
const SIGMA := 0.6


# §4.2 without the noise.
static func base(clock_left: float, increment: float, moves_played: int, top_p: float) -> float:
	return (clock_left / maxi(10, 40 - moves_played) + 0.8 * increment) * (1.6 - top_p)


# Log-normal with median 1.
static func noise(rng: RandomNumberGenerator) -> float:
	return exp(rng.randfn(0.0, SIGMA))


# The floor with one legal move, or for a "premove": top_p over 0.9 with under 15% of the starting
# time left. Clamped to [FLOOR, clock_left]; under FLOOR left, the clock wins.
static func delay(clock_left: float, increment: float, start: float, moves_played: int, top_p: float,
		legal_moves: int, rng: RandomNumberGenerator) -> float:
	var seconds := FLOOR
	if legal_moves > 1 and not (top_p > 0.9 and clock_left < 0.15 * start):
		seconds = base(clock_left, increment, moves_played, top_p) * noise(rng)
	return minf(maxf(seconds, FLOOR), clock_left)


# What is left to wait once Lc0 took `compute`, so Maia's clock is charged max(delay, compute).
static func wait(delay_seconds: float, compute: float) -> float:
	return maxf(0.0, delay_seconds - compute)
