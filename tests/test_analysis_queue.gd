extends "res://tests/run.gd".Test

class FakeAnalyser extends RefCounted:
	signal finished(success: bool, error: String)
	signal progress(done: int, total: int)
	var starts := []
	func start(path: String, maximum: bool) -> bool:
		starts.append([path, maximum])
		return true
	func cancel() -> void:
		finished.emit(false, "cancelled")

func test_queue_runs_one_at_a_time_and_persists():
	var script = load("res://core/analysis_queue.gd")
	assert_true(script != null, "analysis queue exists")
	if script == null:
		return
	var file := "user://test_analysis_queue.cfg"
	DirAccess.remove_absolute(file)
	var runner := FakeAnalyser.new()
	var queue = script.new(runner, file)
	queue.enqueue("first.pgn")
	queue.enqueue("second.pgn")
	assert_eq(runner.starts, [["first.pgn", false]])
	var saved = script.new(FakeAnalyser.new(), file)
	assert_eq(saved.pending(), ["first.pgn", "second.pgn"])
	runner.finished.emit(true, "")
	assert_eq(runner.starts, [["first.pgn", false], ["second.pgn", false]])
	DirAccess.remove_absolute(file)
