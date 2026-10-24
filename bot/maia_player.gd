extends RefCounted

# Maia's side of the game (§3): asks the bridge for its policy on the game so far and answers with
# one move sampled by move_picker. The bridge is anything with request_policy() and policy_ready.

signal move_ready(move: String)

const Game = preload("res://core/game.gd")
const MovePicker = preload("res://bot/move_picker.gd")
const UCI = preload("res://engine/uci.gd")

var rng := RandomNumberGenerator.new()
# From think() to move_ready, one entry per move.
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
	for move in policy:
		if move in legal:
			usable[move] = policy[move]
	if usable.is_empty():
		# Nothing legal to sample from: any legal move beats Maia never answering.
		for move in legal:
			usable[move] = 1.0
	var move := MovePicker.pick(usable, rng, {}, _picker.tau, _picker.temperature)
	latencies_ms.append((Time.get_ticks_usec() - _asked_usec) / 1000.0)
	move_ready.emit(move)
