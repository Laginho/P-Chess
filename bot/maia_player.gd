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
const Tunables = preload("res://core/tunables.gd")

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
var book
var book_intensity := "medium"
var target_id := ""

var _bridge
var _game
var _generation := 0
# Policies arrive FIFO, but each policy's wait may finish in a different order.
var _pending := []
var _wait_for_timeout: Callable


func _init(bridge, wait_for_timeout := Callable()) -> void:
	rng.randomize()
	_bridge = bridge
	_bridge.policy_ready.connect(_on_policy)
	_wait_for_timeout = wait_for_timeout if wait_for_timeout.is_valid() else _timer_timeout


# The evaluation is in pawns from Maia's side; no evaluation always declines.
static func accepts_draw(evaluation, board, maia_left: float, start: float) -> bool:
	if evaluation == null:
		return false
	var values := {"q": 9, "r": 5, "b": 3, "n": 3}
	var nonpawn := 0
	for piece in board.squares:
		nonpawn += values.get(piece.to_lower(), 0)
	var fp := 1.0 - nonpawn / Tunables.DRAW_START_NONPAWN
	var ft := 1.0 - maia_left / start
	var phase := (fp + ft) / 2.0
	return evaluation <= Tunables.DRAW_EVAL_LOSING or (evaluation <= Tunables.DRAW_EVAL_MAX and phase >= Tunables.DRAW_PHASE_MIN)


# engine/weights/<level>.pb.gz next to the engine found by the bridge.
static func net_path(level: String) -> String:
	return UCI.engine_path(UCI.search_dirs()).get_base_dir().get_base_dir() \
			.path_join("weights/%s.pb.gz" % level)


# Invalidate policies and waits even when the new game starts with the human's turn. Keep pending
# snapshots: each obsolete entry must still consume its own eventual FIFO policy reply.
func begin_game(game, mode := "Free", counts := {}, side := "") -> void:
	_generation += 1
	_game = game
	target_id = book.begin_game(counts, rng, side) if book != null and mode != "Free" else ""


# move_ready follows once the bridge answers. Maia's clock, in ms, drives the panic; a start_time of
# 0 means no clock and no panic. Snapshot before requesting: a bridge can answer synchronously.
func think(game, time_left := 0, start_time := 0) -> void:
	if game != _game:
		begin_game(game)
	var picker := {"temperature": temperature, "tau": tau}
	if start_time > 0:
		picker = MovePicker.panic(temperature, tau, panic, time_left, start_time)
	var weights: Dictionary = book.weights(game.board, game.moves.size(), book_intensity) \
			if book != null and not target_id.is_empty() else {}
	var request := {"generation": _generation, "game": game, "ply": game.moves.size(),
			"asked_usec": Time.get_ticks_usec(), "picker": picker, "weights": weights, "clock": clock,
			"control": control, "level": level, "time_table": time_table, "expected": false}
	if not game.moves.is_empty():
		var prediction := request.duplicate()
		prediction["reply"] = request
		prediction["last_move"] = game.moves[-1]
		_pending.append(prediction)
	_pending.append(request)
	# shortcut: every game starts from the initial position; keep the start FEN in Game when one does not.
	if not game.moves.is_empty():
		_bridge.request_policy(Game.START, game.moves.slice(0, -1))
	_bridge.request_policy(Game.START, game.moves)


func median_ms() -> float:
	if latencies_ms.is_empty():
		return 0.0
	var sorted := latencies_ms.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 else (sorted[middle - 1] + sorted[middle]) / 2.0


func _on_policy(policy: Dictionary) -> void:
	if _pending.is_empty():
		return
	var request: Dictionary = _pending.pop_front()
	if not _is_current(request):
		return
	if request.has("reply"):
		var top := ""
		for move in policy:
			if top.is_empty() or policy[move] > policy[top]:
				top = move
		request.reply.expected = top == request.last_move
		return
	var game = request.game
	var legal: PackedStringArray = game.board.legal_moves()
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
	var move := MovePicker.pick(usable, rng, request.weights, request.picker.tau, request.picker.temperature)
	var compute_ms: float = (Time.get_ticks_usec() - request.asked_usec) / 1000.0
	latencies_ms.append(compute_ms)
	var request_clock = request.clock
	if request_clock:
		# Maia's clock runs through Lc0's time and the wait alike: it can flag.
		var left: float = request_clock.left(game.board.side_to_move) / 1000.0
		var start: float = Clock.CONTROLS[request.control][0] / 1000.0
		var bucket := TimeModel.bucket(request.time_table, request.control, request.level, left / start, top_p)
		var delay := TimeModel.delay(left, request_clock.increment / 1000.0, start, game.moves.size() / 2,
				top_p, legal.size(), rng, bucket, request.expected)
		var wait := TimeModel.wait(delay, compute_ms / 1000.0)
		if wait > 0.0:
			await _wait_for_timeout.call(wait)
	if _is_current(request):
		move_ready.emit(move)


func _is_current(request: Dictionary) -> bool:
	return request.generation == _generation and request.game == _game \
			and not request.game.is_over() and request.game.moves.size() == request.ply


# Injectable timer completion: tests emit a signal explicitly instead of sleeping.
func _timer_timeout(seconds: float) -> Signal:
	return Engine.get_main_loop().create_timer(seconds).timeout
