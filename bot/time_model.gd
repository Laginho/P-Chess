extends RefCounted

# How long Maia thinks (§4), in seconds: the calibrated table of §4.1 where it has a bucket, the
# hand-tuned fallback of §4.2 elsewhere, with the overrides of §4.1. Pure: the caller owns the RNG.

const FLOOR := 0.05
const REACTION := 0.4
const SIGMA := 0.6
# Written by scripts/calibrate_time.py (§4.3):
# {"clock_bins": [edges], "top_p_bins": [edges], "buckets": [{"control": "3+2", "level": "maia-1500",
#  "clock_bin": 0, "top_p_bin": 2, "median": seconds, "log_sigma": σ}, ...]}
# n ascending edges make n - 1 bins; bin i holds [edge i, edge i+1), and values past either end fall
# in the end bins. Clock bins are on the fraction of the starting time left.
const TABLE := "res://data/time_model.json"


# {"clock_bins", "top_p_bins", "buckets": {key: bucket}}; {} when the file is missing, or with a
# warning when it is malformed, so the formula is used.
static func load_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return _malformed(path, json.get_error_message())
	var data = json.data
	if not (data is Dictionary and _edges(data.get("clock_bins")) and _edges(data.get("top_p_bins"))
			and data.get("buckets") is Array):
		return _malformed(path, "needs clock_bins, top_p_bins and buckets")
	var buckets := {}
	for b in data.buckets:
		if not (b is Dictionary and b.get("control") is String and b.get("level") is String
				and _bin_index(b.get("clock_bin"), data.clock_bins)
				and _bin_index(b.get("top_p_bin"), data.top_p_bins)
				and _number(b.get("median")) and b.median > 0 and _number(b.get("log_sigma"))
				and b.log_sigma >= 0):
			return _malformed(path, "bad bucket %s" % JSON.stringify(b))
		buckets[_key(b.control, b.level, int(b.clock_bin), int(b.top_p_bin))] = {
			"median": float(b.median), "log_sigma": float(b.log_sigma)}
	return {"clock_bins": data.clock_bins, "top_p_bins": data.top_p_bins, "buckets": buckets}


# {"median", "log_sigma"} for the game's position, or {} when the table has no such bucket.
static func bucket(table: Dictionary, control: String, level: String, clock_fraction: float,
		top_p: float) -> Dictionary:
	if table.is_empty():
		return {}
	return table.buckets.get(_key(control, level, _bin(table.clock_bins, clock_fraction),
			_bin(table.top_p_bins, top_p)), {})


# §4.2 without the noise.
static func base(clock_left: float, increment: float, moves_played: int, top_p: float) -> float:
	return (clock_left / maxi(10, 40 - moves_played) + 0.8 * increment) * (1.6 - top_p)


# Log-normal with median 1.
static func noise(rng: RandomNumberGenerator) -> float:
	return exp(rng.randfn(0.0, SIGMA))


# The floor with one legal move, or an expected human move with top_p over 0.9 and under 10% of
# the starting time left. Otherwise sample the bucket or formula, with time for reaction and hand
# movement. The clock-left clamp wins over either floor.
static func delay(clock_left: float, increment: float, start: float, moves_played: int, top_p: float,
		legal_moves: int, rng: RandomNumberGenerator, from_bucket := {}, expected := false) -> float:
	var seconds := FLOOR
	if legal_moves > 1 and not (expected and top_p > 0.9 and clock_left < 0.1 * start):
		if from_bucket:
			seconds = from_bucket.median * exp(rng.randfn(0.0, from_bucket.log_sigma))
		else:
			seconds = base(clock_left, increment, moves_played, top_p) * noise(rng)
		seconds = maxf(seconds, REACTION)
	return minf(seconds, clock_left)


# What is left to wait once Lc0 took `compute`, so Maia's clock is charged max(delay, compute).
static func wait(delay_seconds: float, compute: float) -> float:
	return maxf(0.0, delay_seconds - compute)


static func _key(control: String, level: String, clock_bin: int, top_p_bin: int) -> String:
	return "%s/%s/%d/%d" % [control, level, clock_bin, top_p_bin]


static func _bin(edges: Array, value: float) -> int:
	return edges.slice(1, -1).bsearch(value, false)


# Finite too: the JSON parser reads 1e999 as inf.
static func _number(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(value)


static func _edges(edges) -> bool:
	if not (edges is Array and edges.size() >= 2):
		return false
	for i in edges.size():
		if not _number(edges[i]) or (i > 0 and edges[i] <= edges[i - 1]):
			return false
	return true


static func _bin_index(index, edges: Array) -> bool:
	return _number(index) and index == int(index) and index >= 0 and index < edges.size() - 1


static func _malformed(path: String, why: String) -> Dictionary:
	push_warning("%s is malformed (%s); Maia's think time uses the formula" % [path, why])
	return {}
