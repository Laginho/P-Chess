extends Node

const Analyser = preload("res://engine/analyser.gd")

signal updated(fen: String, position: Dictionary)
signal failed(message: String)

var _bridge
var _started := false
var _fen := ""
var _search_fen := ""
var _draining := false
var _lines := {}
var _generation := 0


func _init(bridge) -> void:
	_bridge = bridge


func search(fen: String) -> bool:
	if fen == _fen and _started:
		return true
	_fen = fen
	_lines.clear()
	if not _started:
		if not _bridge.start():
			failed.emit(_bridge.error)
			return false
		_started = true
		_bridge.stopped.connect(_engine_stopped)
		_bridge.new_game()
	if not _search_fen.is_empty():
		if not _draining:
			_draining = true
			_bridge.stop_search()
	else:
		_begin_search()
	return true


func _process(_delta: float) -> void:
	if _started and _search_fen.is_empty() and not _fen.is_empty():
		_begin_search()


func _begin_search() -> void:
	if _bridge.engine_id.is_empty():
		return
	_search_fen = _fen
	_generation += 1
	_bridge.request_search(PackedStringArray([
			"setoption name Threads value %d" % maxi(1, OS.get_processor_count() - 1),
			"setoption name MultiPV value 2", "position fen " + _fen, "go infinite"]),
			_receive.bind(_generation))


func _receive(line: String, generation: int) -> void:
	if not _started or generation != _generation:
		return
	if line.begins_with("bestmove"):
		_search_fen = ""
		if _draining:
			_draining = false
			_begin_search()
		return
	if _draining or _search_fen != _fen:
		return
	var parsed := Analyser._parse_info(line)
	if parsed.is_empty():
		return
	var number: int = parsed.multipv
	parsed.erase("multipv")
	if _lines.has(number) and parsed.depth < _lines[number].depth:
		return
	_lines[number] = parsed
	var pv := []
	for n in [1, 2]:
		if _lines.has(n):
			pv.append(_lines[n].duplicate(true))
	updated.emit(_fen, {"fen": _fen, "pv": pv,
			"best_move": _lines[1].moves[0] if _lines.has(1) else ""})


func _engine_stopped() -> void:
	var message: String = _bridge.error
	stop()
	failed.emit(message)


func stop() -> void:
	_generation += 1
	_fen = ""
	_search_fen = ""
	_draining = false
	_lines.clear()
	if _started:
		_started = false
		_bridge.stopped.disconnect(_engine_stopped)
		_bridge.stop()
