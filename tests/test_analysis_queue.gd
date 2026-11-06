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

func test_corrupt_queue_load_keeps_valid_games_and_progresses():
	var file := "user://test_analysis_corrupt_%d.cfg" % Time.get_ticks_usec()
	var config := ConfigFile.new()
	config.set_value("queue", "games", [42, "", "valid.pgn"])
	config.set_value("queue", "priority", 7)
	config.set_value("queue", "done", -3)
	config.set_value("queue", "total", "x")
	config.save(file)
	var runner := FakeAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, file)
	assert_eq(queue.pending(), ["valid.pgn"])
	assert_eq(queue._priority, "")
	assert_eq(queue.batch_done, 0)
	assert_eq(queue.batch_total, 1)
	queue.resume()
	assert_eq(queue.current(), "valid.pgn")
	runner.finished.emit(true, "")
	assert_eq(queue.pending(), [])
	queue.free()
	DirAccess.remove_absolute(file)

func test_corrupt_queue_can_start_a_new_game():
	var file := "user://test_analysis_corrupt_empty_%d.cfg" % Time.get_ticks_usec()
	var config := ConfigFile.new()
	config.set_value("queue", "games", [42])
	config.set_value("queue", "done", -1)
	config.set_value("queue", "total", 0)
	config.save(file)
	var runner := FakeAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, file)
	queue.enqueue("new.pgn")
	assert_eq(queue.current(), "new.pgn")
	assert_eq(runner.starts, [["new.pgn", false]])
	queue.free()
	DirAccess.remove_absolute(file)

func test_queue_load_preserves_valid_counters_and_resets_inconsistent_ones():
	var file := "user://test_analysis_counters_%d.cfg" % Time.get_ticks_usec()
	var config := ConfigFile.new()
	config.set_value("queue", "games", ["valid.pgn"])
	config.set_value("queue", "priority", "valid.pgn")
	for counters in [[2, 3], [2, 2], [3, 2], [-1, 4], [0, -1], [1.0, 4], [1, 4.0]]:
		config.set_value("queue", "done", counters[0])
		config.set_value("queue", "total", counters[1])
		config.save(file)
		var queue = load("res://core/analysis_queue.gd").new(FakeAnalyser.new(), file)
		assert_eq(queue.batch_done, 2 if counters == [2, 3] else 0)
		assert_eq(queue.batch_total, 3 if counters == [2, 3] else 1)
		assert_eq(queue._priority, "valid.pgn")
		queue.free()
	DirAccess.remove_absolute(file)

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

func test_clear_cancels_active_discards_waiting_and_persists():
	var script = load("res://core/analysis_queue.gd")
	var file := "user://test_analysis_clear_%d.cfg" % Time.get_ticks_usec()
	var runner := DelayedAnalyser.new()
	var queue = script.new(runner, file)
	queue.enqueue("first.pgn")
	queue.enqueue("second.pgn")
	queue.clear()
	assert_eq(queue.pending(), [])
	assert_eq(queue.batch_done, 0)
	assert_eq(queue.batch_total, 0)
	assert_eq(runner.starts.size(), 1, "clear starts no waiting game")
	runner.finished.emit(false, "cancelled")
	assert_eq(queue.current(), "")
	assert_eq(queue.batch_done, 0, "cancelled game is not completed")
	var restored = script.new(FakeAnalyser.new(), file)
	assert_eq(restored.pending(), [])
	queue.enqueue("third.pgn")
	assert_eq(runner.starts.back(), ["third.pgn", false], "clear leaves queue usable")
	queue.free()
	restored.free()
	DirAccess.remove_absolute(file)

func test_remove_active_starts_next_without_counting_completion():
	var script = load("res://core/analysis_queue.gd")
	var file := "user://test_analysis_remove_%d.cfg" % Time.get_ticks_usec()
	var runner := FakeAnalyser.new()
	var queue = script.new(runner, file)
	queue.enqueue("first.pgn")
	queue.enqueue("second.pgn")
	queue.remove("first.pgn")
	assert_eq(queue.current(), "second.pgn")
	assert_eq(queue.batch_done, 0)
	assert_eq(queue.batch_total, 1)
	queue.free()
	DirAccess.remove_absolute(file)

class OwnedBridge extends Node:
	var stopped := false
	func stop() -> void:
		stopped = true

class OwnedAnalyser extends Node:
	signal finished(success: bool, message: String)
	var cancelled := false
	func cancel() -> void:
		cancelled = true

func test_stockfish_runner_stop_releases_engine_and_ignores_late_finish():
	var queue_script = load("res://core/analysis_queue.gd")
	var runner = queue_script.StockfishRunner.new()
	var bridge := OwnedBridge.new()
	var analyser := OwnedAnalyser.new()
	runner.bridge = bridge
	runner.analyser = analyser
	runner.add_child(bridge)
	runner.add_child(analyser)
	analyser.finished.connect(runner._done)
	var results := []
	runner.finished.connect(func(success, message): results.append([success, message]))
	runner.cancel()
	assert_true(bridge.stopped and analyser.cancelled)
	assert_true(runner.bridge == null and runner.analyser == null)
	analyser.finished.emit(true, "")
	assert_eq(results, [[false, "cancelled"]], "late result cannot complete the next game")
	runner.free()
