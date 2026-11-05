extends Node

const Tunables = preload("res://core/tunables.gd")
const Board = preload("res://core/board.gd")

const Analyser = preload("res://engine/analyser.gd")

signal updated(fen: String, position: Dictionary)
signal failed(message: String)
signal settled(fen: String, position: Dictionary)

var _bridge
var _started := false
var _fen := ""
var _search_fen := ""
var _draining := false
var _lines := {}
var _generation := 0
var _results := {}
var _live_results := {}
var _depths := {}
var _only_legal_move := false
var _required := []


func _init(bridge) -> void:
	_bridge = bridge


# Required FENs are ordered class prerequisites. Only the shown FEN emits live PVs.
func search(fen: String, required: Array = []) -> bool:
	_fen = fen
	_required = required.duplicate()
	if not _started:
		if not _bridge.start():
			failed.emit(_bridge.error)
			return false
		_started = true
		_bridge.stopped.connect(_engine_stopped)
		_bridge.new_game()
	if _live_results.has(fen):
		updated.emit(fen, _live_results[fen].duplicate(true))
	elif _results.has(fen):
		updated.emit(fen, result(fen))
	_schedule()
	return true


func retain(fens: Array) -> void:
	for fen in _results.keys():
		if not fen in fens:
			_results.erase(fen)
	for fen in _live_results.keys():
		if not fen in fens:
			_live_results.erase(fen)


# Terminal results are supplied by Review's game state, including repetition draws.
func remember(position: Dictionary) -> void:
	if not _results.has(position.fen):
		_results[position.fen] = position.duplicate(true)


func _process(_delta: float) -> void:
	if _started:
		_schedule()


func _next_fen() -> String:
	for fen: String in _required:
		if not _results.has(fen):
			return fen
	# Frozen class inputs do not replace the unlimited shown-position search.
	return _fen


func _schedule() -> void:
	if _draining:
		return
	var next := _next_fen()
	if not _search_fen.is_empty():
		# Keep the unlimited shown search running after its class settles.
		if next == _search_fen:
			return
		_draining = true
		_bridge.stop_search()
	elif not next.is_empty():
		_begin_search(next)


func _begin_search(fen: String) -> void:
	if _bridge.engine_id.is_empty():
		return
	_search_fen = fen
	_lines.clear()
	_depths.clear()
	_only_legal_move = Board.from_fen(fen).legal_moves().size() == 1
	_generation += 1
	_bridge.request_search(PackedStringArray([
			"setoption name Threads value %d" % maxi(1, OS.get_processor_count() - 1),
			"setoption name MultiPV value 2", "position fen " + fen, "go infinite"]),
			_receive.bind(_generation))


func _receive(line: String, generation: int) -> void:
	if not _started or generation != _generation:
		return
	if line.begins_with("bestmove"):
		_search_fen = ""
		_draining = false
		_schedule()
		return
	if _draining:
		return
	var parsed := Analyser._parse_info(line)
	if parsed.is_empty():
		return
	var number: int = parsed.multipv
	parsed.erase("multipv")
	if _lines.has(number) and parsed.depth < _lines[number].depth:
		return
	_lines[number] = parsed
	_record_depth(number, parsed)
	if not _lines.has(1):
		return
	var pv := []
	for n in [1, 2]:
		if _lines.has(n):
			pv.append(_lines[n].duplicate(true))
	if _search_fen == _fen:
		# Keep newer PVs visible while a restarted search catches up.
		var previous: Dictionary = _live_results.get(_fen, {})
		if previous.is_empty() or _lines[1].depth >= previous.pv[0].depth:
			var position := {"fen": _fen, "pv": pv, "best_move": _lines[1].moves[0]}
			_live_results[_fen] = position.duplicate(true)
			updated.emit(_fen, position)
	_schedule()


# Classification reads immutable completed depths, never the evolving live PVs.
func result(fen: String) -> Dictionary:
	return _results.get(fen, {}).duplicate(true)


func _record_depth(number: int, parsed: Dictionary) -> void:
	if _results.has(_search_fen):
		return
	var depth: int = parsed.depth
	if not _depths.has(depth):
		_depths[depth] = {}
	_depths[depth][number] = parsed.duplicate(true)
	var samples := []
	var completed := _depths.keys()
	completed.sort()
	for d in completed:
		var lines: Dictionary = _depths[d]
		if not lines.has(1) or (not _only_legal_move and not lines.has(2)):
			continue
		var sample: Dictionary = lines[1].duplicate(true)
		sample.move = sample.moves[0]
		samples.append(sample)
	var current: Dictionary = _depths[depth]
	if not current.has(1) or (not _only_legal_move and not current.has(2)):
		return
	var nodes: int = maxi(current[1].get("nodes", 0), current.get(2, {}).get("nodes", 0))
	if nodes < Tunables.ANALYSIS_NODES and not Analyser.converged(samples):
		return
	var pv := [current[1].duplicate(true)]
	if not _only_legal_move:
		pv.append(current[2].duplicate(true))
	var position := {"fen": _search_fen, "pv": pv, "best_move": pv[0].moves[0]}
	_results[_search_fen] = position
	settled.emit(_search_fen, position.duplicate(true))


func _engine_stopped() -> void:
	var message: String = _bridge.error
	stop(false)
	failed.emit(message)


func stop(clear_results := true) -> void:
	_generation += 1
	_fen = ""
	_search_fen = ""
	_draining = false
	_lines.clear()
	if clear_results:
		_results.clear()
		_live_results.clear()
	_required.clear()
	_depths.clear()
	if _started:
		_started = false
		_bridge.stopped.disconnect(_engine_stopped)
		_bridge.stop()
