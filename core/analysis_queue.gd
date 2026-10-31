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
	if _runner != null:
		_runner.finished.connect(_finished)
		_runner.progress.connect(_progress)


func pending() -> Array:
	return _items.duplicate()


func current() -> String:
	return _active_path if _active else ""


func enqueue(path: String) -> void:
	if path not in _items:
		_items.append(path)
		_save()
		_start_next()


func prioritize(path: String) -> void:
	if path not in _items:
		_items.push_front(path)
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
	config.save(_file)
	changed.emit()
