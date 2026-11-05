extends "res://tests/run.gd".Test

const History = preload("res://core/history.gd")
const Game = preload("res://core/game.gd")
const Settings = preload("res://core/settings.gd")
const Storage = preload("res://tests/history_storage.gd")
const Queue = preload("res://core/analysis_queue.gd")

class CountingReview extends "res://ui/review.gd":
	var refreshes := 0
	func _refresh_classes() -> void:
		refreshes += 1
		super._refresh_classes()

class FakeRunner extends RefCounted:
	signal progress(done: int, total: int)
	signal finished(success: bool, error: String)
	func start(_path: String, _maximum: bool) -> bool:
		return true
	func cancel() -> void:
		finished.emit(false, "cancelled")


func test_cached_review_classifies_once():
	var review = load("res://ui/review.tscn").instantiate()
	review.set_script(CountingReview)
	Engine.get_main_loop().root.add_child(review)
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	review.present(game, [60000, 60000], {"colour": "w", "level": "maia-1500", "control": "1+0"}, "")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	fixture.engine_version = "Stockfish 19"
	var path := "user://freezes-cache.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	review.refreshes = 0
	review.open_analysis(path, false)
	assert_eq(review.refreshes, 1, "cached positions trigger one classification")
	assert_eq(review._classes.size(), 2)
	assert_true(review.get_node("Margin/Content/ReviewBody/Side/Summary").visible)
	review.free()
	DirAccess.remove_absolute(path)


func test_history_progress_preserves_cards_and_updates_percent():
	var folder := "user://freezes_history_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var history = History.new(folder)
	var game = Game.new()
	game.play("e2e4")
	game.resign("b")
	var path: String = history.save(game, [60000], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var runner := FakeRunner.new()
	var queue = Queue.new(runner, folder.path_join("queue.cfg"))
	queue.enqueue(path)
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	var list = screen.get_node("Margin/Content/Cards/List")
	var card = list.get_child(0)
	var id: int = card.get_instance_id()
	for done in [1, 2, 3]:
		runner.progress.emit(done, 4)
	assert_eq(list.get_child(0).get_instance_id(), id, "progress must not rebuild a card")
	assert_eq(card.find_child("AnalysisPercent", true, false).text, "75%")
	assert_eq(card.find_child("AnalysisProgress", true, false).value, 75.0)
	queue.remove(path)
	assert_true(list.get_child(0).get_instance_id() != id, "queue membership changes rebuild cards")
	screen.free()
	queue.free()
	Storage.clean(folder)


func test_catalog_lookup_reuses_and_invalidates():
	var book = load("res://bot/book.gd").new()
	book.load_tsv("eco\tname\tpgn\nA00\tFirst\t1. e4\n")
	var badges = load("res://bot/badges.gd")
	var first: Dictionary = badges.catalog_index(book.entries)
	assert_true(is_same(first, badges.catalog_index(book.entries)))
	book.load_tsv("eco\tname\tpgn\nA00\tSecond\t1. d4\n")
	var second: Dictionary = badges.catalog_index(book.entries)
	assert_true(not is_same(first, second), "appended catalog rows invalidate the lookup")
	assert_true(second.continuations[Game.new().board.position_key()].has("d2d4"))
	var replacement: Array = book.entries.duplicate(true)
	assert_true(not is_same(second, badges.catalog_index(replacement)), "replacement catalogs invalidate even at equal size")


class ReusableBridge extends Node:
	signal stopped
	var engine_id := "Stockfish 19"
	var error := "fake engine stopped"
	var resets := 0
	var stops := 0
	var commands := []
	func new_game() -> void:
		resets += 1
	func request_search(lines: PackedStringArray, _callback: Callable) -> void:
		commands.append(lines)
	func stop_search() -> void:
		pass
	func stop() -> void:
		stops += 1


func test_runner_reuses_engine_after_game_and_cancel_but_discards_dead_engine():
	var folder := "user://freezes_runner_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var history = History.new(folder)
	var game = Game.new()
	game.play("e2e4")
	game.resign("b")
	var path: String = history.save(game, [60000], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var runner = Queue.StockfishRunner.new()
	var bridge := ReusableBridge.new()
	runner.bridge = bridge
	runner.add_child(bridge)
	bridge.stopped.connect(runner._stopped)
	Engine.get_main_loop().root.add_child(runner)
	assert_true(runner.start(path, false))
	# Deliver the two searches in reverse ply order, as the real engine does.
	runner.analyser._on_line("info depth 20 multipv 1 score cp 0 pv e7e5")
	runner.analyser._on_line("bestmove e7e5")
	runner.analyser._on_line("info depth 20 multipv 1 score cp 0 pv e2e4")
	runner.analyser._on_line("bestmove e2e4")
	assert_true(runner.analyser == null)
	assert_true(is_same(runner.bridge, bridge))
	assert_eq(bridge.stops, 0, "completion must not stop and join the engine")
	assert_true(runner.start(path, true))
	assert_eq(bridge.resets, 2, "each game still sends ucinewgame")
	runner.cancel()
	runner.analyser._on_line("bestmove e7e5")
	assert_true(runner.analyser == null)
	assert_true(is_same(runner.bridge, bridge), "cancel drains bestmove and retains the engine")
	bridge.stopped.emit()
	assert_true(runner.bridge == null, "an idle engine failure discards the bridge")
	assert_eq(bridge.stops, 1)
	runner.free()
	DirAccess.remove_absolute(history.analysis_folder().path_join(path.get_file() + ".json"))
	DirAccess.remove_absolute(history.analysis_folder())
	Storage.clean(folder)
