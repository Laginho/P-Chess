extends Node

signal changed
signal position_ready(path: String, index: int, position: Dictionary)

var _runner
var _file: String
var _items := []
var _active := false
var _active_path := ""
var _priority := ""
var _paused := false
var _interrupting := false
var batch_total := 0
var batch_done := 0
var maximum := false
var percent := 0
var error := ""


func _init(runner = null, file := "user://analysis_queue.cfg") -> void:
	_runner = runner
	_file = file
	var config := ConfigFile.new()
	if config.load(_file) == OK:
		_items = config.get_value("queue", "games", [])
		_priority = config.get_value("queue", "priority", "")
		batch_total = config.get_value("queue", "total", _items.size())
		batch_done = config.get_value("queue", "done", 0)
	if _runner != null:
		_runner.finished.connect(_finished)
		_runner.progress.connect(_progress)


var _scan := 0.0


func _process(delta: float) -> void:
	_scan += delta
	if _scan < 1.0:
		return
	_scan = 0.0
	for path in _items.duplicate():
		if not FileAccess.file_exists(path):
			remove(path)


func _ready() -> void:
	if _runner == null:
		_runner = StockfishRunner.new()
		add_child(_runner)
		_runner.finished.connect(_finished)
		_runner.progress.connect(_progress)
		_runner.position_ready.connect(func(index, position): position_ready.emit(_active_path, index, position))
		_start_next()

func pending() -> Array:
	return _items.duplicate()


func current() -> String:
	return _active_path if _active else ""


func enqueue(path: String) -> void:
	if path not in _items:
		_items.append(path)
		batch_total += 1
		_save()
		_start_next()


func prioritize(path: String) -> void:
	if path not in _items:
		_items.push_front(path)
		batch_total += 1
	else:
		_items.erase(path)
		_items.push_front(path)
	_priority = path
	_save()
	_interrupt()
	_start_next()


func pause() -> void:
	_paused = true
	_interrupt()
	changed.emit()


func resume() -> void:
	_paused = false
	_start_next()
	changed.emit()


func remove(path: String) -> void:
	if path not in _items:
		return
	_items.erase(path)
	batch_total -= 1
	if _priority == path:
		_priority = ""
	_save()
	if _active_path == path:
		_interrupt()
	_start_next()


func _interrupt() -> void:
	if _active:
		_interrupting = true
		_runner.cancel()
		_interrupting = false


func _start_next() -> void:
	if _active or _paused or _runner == null or _items.is_empty():
		return
	_active = true
	_active_path = _items[0]
	percent = 0
	error = ""
	if not _runner.start(_active_path, _active_path == _priority or maximum):
		_active = false
		error = "Could not start analysis"
	changed.emit()


func _finished(success: bool, message: String) -> void:
	var path := _active_path
	_active = false
	_active_path = ""
	if success:
		_items.erase(path)
		batch_done += 1
		if _items.is_empty():
			batch_total = 0
			batch_done = 0
		if _priority == path:
			_priority = ""
		_save()
	elif message != "cancelled":
		error = message
		changed.emit()
		return
	if not _interrupting:
		_start_next()


func _progress(done: int, total: int) -> void:
	percent = int(100.0 * done / maxi(total, 1))
	changed.emit()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("queue", "games", _items)
	config.set_value("queue", "priority", _priority)
	config.set_value("queue", "total", batch_total)
	config.set_value("queue", "done", batch_done)
	config.save(_file)
	changed.emit()

class StockfishRunner extends Node:
	signal finished(success: bool, error: String)
	signal progress(done: int, total: int)
	signal position_ready(index: int, position: Dictionary)
	const Uci = preload("res://engine/uci.gd")
	const Analyser = preload("res://engine/analyser.gd")
	const Pgn = preload("res://core/pgn.gd")
	var bridge
	var analyser

	func start(path: String, maximum: bool) -> bool:
		if not FileAccess.file_exists(path):
			return false
		var parsed: Dictionary = Pgn.parse(FileAccess.get_file_as_string(path))
		if not parsed.error.is_empty() or parsed.games.size() != 1:
			return false
		var game: Dictionary = parsed.games[0]
		var positions: Array = Analyser.positions_from_game(game)
		if positions.is_empty():
			return false
		bridge = Uci.new("engine/stockfish/stockfish.exe", "Stockfish")
		add_child(bridge)
		if not bridge.start():
			bridge.queue_free()
			bridge = null
			return false
		bridge.stopped.connect(_stopped)
		analyser = Analyser.new(bridge)
		add_child(analyser)
		analyser.progress.connect(func(done, total): progress.emit(done, total))
		analyser.position_ready.connect(func(index, position): position_ready.emit(index, position))
		analyser.finished.connect(_done)
		var output := path.get_base_dir().get_base_dir().path_join("analysis").path_join(path.get_file() + ".json")
		if not analyser.analyse(positions, output, maximum, game.result == "1/2-1/2"):
			_cleanup()
			return false
		return true

	func cancel() -> void:
		if analyser != null:
			analyser.cancel()

	func _done(success: bool, message: String) -> void:
		_cleanup()
		finished.emit(success, message)

	func _stopped() -> void:
		var message: String = bridge.error
		_cleanup()
		finished.emit(false, message)

	func _cleanup() -> void:
		if analyser != null:
			analyser.queue_free()
			analyser = null
		if bridge != null:
			bridge.stop()
			bridge.queue_free()
			bridge = null
