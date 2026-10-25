extends RefCounted

# Both sides' clocks (§5), in milliseconds. A side's clock runs while it is to move, from its second
# move on: its first move is untimed and adds no increment, as on Lichess. The time source is
# injected, a Callable returning milliseconds, so the tests never wait; the game passes
# Time.get_ticks_msec.

signal low_time(side: String)
signal flagged(side: String)

# Control -> [starting ms, increment ms]. Only these three: the time model has no data for others.
const CONTROLS := {"1+0": [60000, 0], "3+2": [180000, 2000], "5+0": [300000, 0]}

var increment := 0
# 10% of the starting time or 10 s, whichever is lower.
var low_time_ms := 0

var _now: Callable
var _left := {}
# Sides that have made their first move.
var _moved := {}
# Sides already warned of low time: once per game.
var _warned := {}
# The side whose clock runs, "" when none, and the time it started running.
var _running := ""
var _since := 0


func _init(control: String, time_source: Callable) -> void:
	_now = time_source
	var start: int = CONTROLS[control][0]
	increment = CONTROLS[control][1]
	low_time_ms = mini(start / 10, 10000)
	_left = {"w": start, "b": start}


# side is "w" or "b", as Board.side_to_move.
func left(side: String) -> int:
	if side != _running:
		return _left[side]
	return maxi(0, _left[side] - (_now.call() - _since))


# After `side` moved: its clock stops and gains the increment, or flags when the time ran out
# before the move; the other side's clock starts once that side has made its first move.
# A premove costs exactly 100 ms, even on the untimed first move; increment still starts later.
func moved(side: String, premove := false) -> void:
	var timed := side == _running
	if timed:
		if premove:
			# Use the fixed cost instead of frame/animation time since the opponent's move.
			_running = ""
		else:
			stop()
	if premove:
		_left[side] = maxi(0, _left[side] - 100)
		if _left[side] <= low_time_ms and not _warned.has(side):
			_warned[side] = true
			low_time.emit(side)
	if timed or premove:
		if _left[side] == 0:
			flagged.emit(side)
			return
		if timed:
			_left[side] += increment
	_moved[side] = true
	var other := "b" if side == "w" else "w"
	if _moved.has(other):
		_running = other
		_since = _now.call()


# Called every frame: the low-time warning and the flag of the side whose clock runs.
func tick() -> void:
	if not _running:
		return
	var side := _running
	var ms := left(side)
	if ms <= low_time_ms and not _warned.has(side):
		_warned[side] = true
		low_time.emit(side)
	if ms == 0:
		stop()
		flagged.emit(side)


# Freezes both clocks, as when the game ends.
func stop() -> void:
	if _running:
		_left[_running] = left(_running)
		_running = ""


# m:ss, and tenths under 10 s (0:09.4). Truncated, so it never shows more time than is left.
static func format(ms: int) -> String:
	if ms < 10000:
		return "0:%02d.%d" % [ms / 1000, ms % 1000 / 100]
	var seconds := ms / 1000
	return "%d:%02d" % [seconds / 60, seconds % 60]
