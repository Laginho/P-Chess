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
	var file := "user://test_analysis_queue_%d.cfg" % Time.get_ticks_usec()
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
	queue.free()
	saved.free()
	DirAccess.remove_absolute(file)

func test_priority_pause_resume_and_removal():
	var script = load("res://core/analysis_queue.gd")
	var file := "user://test_analysis_queue_priority_%d.cfg" % Time.get_ticks_usec()
	DirAccess.remove_absolute(file)
	var runner := FakeAnalyser.new()
	var queue = script.new(runner, file)
	queue.enqueue("first.pgn")
	queue.enqueue("second.pgn")
	queue.prioritize("second.pgn")
	assert_eq(runner.starts, [["first.pgn", false], ["second.pgn", true]])
	queue.pause()
	assert_eq(runner.starts.size(), 2, "pausing starts no other game")
	queue.resume()
	assert_eq(runner.starts.back(), ["second.pgn", true])
	runner.finished.emit(true, "")
	assert_eq(runner.starts.back(), ["first.pgn", false])
	queue.remove("first.pgn")
	assert_eq(queue.pending(), [])
	queue.free()
	DirAccess.remove_absolute(file)

class DelayedAnalyser extends FakeAnalyser:
	func cancel() -> void:
		pass

func test_delayed_cancel_never_overlaps_and_batch_uses_max_setting():
	var script = load("res://core/analysis_queue.gd")
	var file := "user://test_analysis_queue_delayed_%d.cfg" % Time.get_ticks_usec()
	DirAccess.remove_absolute(file)
	var runner := DelayedAnalyser.new()
	var queue = script.new(runner, file)
	queue.maximum = true
	queue.enqueue("first.pgn")
	queue.enqueue("second.pgn")
	queue.prioritize("second.pgn")
	assert_eq(runner.starts, [["first.pgn", true]], "wait for cancellation")
	runner.finished.emit(false, "cancelled")
	assert_eq(runner.starts.back(), ["second.pgn", true])
	queue.remove("second.pgn")
	assert_eq(runner.starts.size(), 2, "deletion also waits for cancellation")
	runner.finished.emit(false, "cancelled")
	assert_eq(runner.starts.back(), ["first.pgn", true])
	queue.free()
	DirAccess.remove_absolute(file)
