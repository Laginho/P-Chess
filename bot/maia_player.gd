extends RefCounted

# Maia's side of the game (§3): asks the bridge for its policy on the game so far and answers with
# one move sampled by move_picker, after its think time (§4) when it has a clock. The bridge is
# anything with request_policy() and policy_ready.

signal move_ready(move: String)

const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
const MovePicker = preload("res://bot/move_picker.gd")
const TimeModel = preload("res://bot/time_model.gd")
const UCI = preload("res://engine/uci.gd")

var rng := RandomNumberGenerator.new()
# The game's core/clock.gd and its control ("3+2"); without a clock Maia answers at once.
var clock
var control := ""
# The Maia level ("maia-1500"): with control, it picks the think-time bucket of time_table.
var level := ""
var time_table := TimeModel.load_table(TimeModel.TABLE)
# From think() to Lc0's answer, one entry per move; the think time comes after.
var latencies_ms := []
# The picker's cut and temperature (§3.3) and the panic intensity (§3.4), from the settings.
var tau := MovePicker.DEFAULT_TAU
var temperature := MovePicker.DEFAULT_TEMPERATURE
var panic := "medium"

var _bridge
var _game
var _asked_usec := 0
# T and tau for the move being thought, panic applied.
var _picker := {}


func _init(bridge) -> void:
	rng.randomize()
	_bridge = bridge
	_bridge.policy_ready.connect(_on_policy)


# engine/weights/<level>.pb.gz next to the engine found by the bridge.
static func net_path(level: String) -> String:
	return UCI.engine_path(UCI.search_dirs()).get_base_dir().get_base_dir() \
			.path_join("weights/%s.pb.gz" % level)


# move_ready follows once the bridge answers. Maia's clock, in ms, drives the panic; a start_time of
# 0 means no clock and no panic.
func think(game, time_left := 0, start_time := 0) -> void:
	_game = game
	_asked_usec = Time.get_ticks_usec()
	_picker = {"temperature": temperature, "tau": tau}
	if start_time > 0:
		_picker = MovePicker.panic(temperature, tau, panic, time_left, start_time)
	# shortcut: every game starts from the initial position; keep the start FEN in Game when one does not.
	_bridge.request_policy(Game.START, game.moves)


func median_ms() -> float:
	if latencies_ms.is_empty():
		return 0.0
	var sorted := latencies_ms.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 else (sorted[middle - 1] + sorted[middle]) / 2.0


func _on_policy(policy: Dictionary) -> void:
	var legal: PackedStringArray = _game.board.legal_moves()
	var usable := {}
	var top_p := 0.0
	for move in policy:
		if move in legal:
			usable[move] = policy[move]
			top_p = maxf(top_p, policy[move])
	if usable.is_empty():
		# Nothing legal to sample from: any legal move beats Maia never answering.
		for move in legal:
			usable[move] = 1.0
	var move := MovePicker.pick(usable, rng, {}, _picker.tau, _picker.temperature)
	var compute_ms := (Time.get_ticks_usec() - _asked_usec) / 1000.0
	latencies_ms.append(compute_ms)
	if clock:
		# Maia's clock runs through Lc0's time and the wait alike: it can flag.
		var left: float = clock.left(_game.board.side_to_move) / 1000.0
		var start: float = Clock.CONTROLS[control][0] / 1000.0
		var delay := TimeModel.delay(left, clock.increment / 1000.0, start, _game.moves.size() / 2,
				top_p, legal.size(), rng, TimeModel.bucket(time_table, control, level, left / start, top_p))
		var wait := TimeModel.wait(delay, compute_ms / 1000.0)
		if wait > 0.0:
			await Engine.get_main_loop().create_timer(wait).timeout
	move_ready.emit(move)
