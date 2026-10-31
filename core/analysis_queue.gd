extends Node

signal changed

var _runner
var _file: String
var _items := []
var _active := false


func _init(runner = null, file := "user://analysis_queue.cfg") -> void:
	_runner = runner
	_file = file
	var config := ConfigFile.new()
	if config.load(_file) == OK:
		_items = config.get_value("queue", "games", [])
	if _runner != null:
		_runner.finished.connect(_finished)


func pending() -> Array:
	return _items.duplicate()


func enqueue(path: String) -> void:
	if path not in _items:
		_items.append(path)
		_save()
		_start_next()


func _start_next() -> void:
	if _active or _runner == null or _items.is_empty():
		return
	_active = true
	if not _runner.start(_items[0], false):
		_active = false


func _finished(success: bool, _error: String) -> void:
	_active = false
	if success and not _items.is_empty():
		_items.pop_front()
		_save()
	_start_next()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("queue", "games", _items)
	config.save(_file)
	changed.emit()
