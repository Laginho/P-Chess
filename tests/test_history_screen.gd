extends "res://tests/run.gd".Test

const History = preload("res://core/history.gd")
const Settings = preload("res://core/settings.gd")
const Game = preload("res://core/game.gd")
const Storage = preload("res://tests/history_storage.gd")
const MainScene = preload("res://ui/main.tscn")


class HeldEngine extends "res://engine/uci.gd":
	func start(_dirs := PackedStringArray()) -> bool:
		return true


class FakeAnalysisBridge extends Node:
	signal stopped
	var engine_id := "Stockfish 19"
	var error := ""
	func start() -> bool:
		return true


class FakeAnalyser extends Node:
	signal position_ready(index: int, position: Dictionary)
	signal progress(done: int, total: int)
	signal finished(success: bool, error: String)
	var maximum := false
	var called := false
	func analyse(_fens: Array, _path: String, max_threads: bool, _draw: bool) -> bool:
		called = true
		maximum = max_threads
		return true
	func cancel() -> void:
		pass


class FakeQueueAnalyser extends RefCounted:
	signal progress(done: int, total: int)
	signal finished(success: bool, error: String)
	var called := false
	var maximum := false
	func start(_path: String, max_threads: bool) -> bool:
		called = true
		maximum = max_threads
		return true
	func cancel() -> void:
		finished.emit(false, "cancelled")

func test_open_review_from_history_and_return_with_escape():
	var folder := "user://history_review_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.history = History.new(folder)
	main.preferences = Settings.new(folder.path_join("settings.cfg"))
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	var game = Game.new()
	game.play("e2e4")
	game.resign("b")
	main.history.save(game, [60000], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var fake := FakeQueueAnalyser.new()
	main.analysis_queue = load("res://core/analysis_queue.gd").new(fake, folder.path_join("queue.cfg"))
	Engine.get_main_loop().root.add_child(main)
	var history_button = main.get_node_or_null("Home/Center/Form/History")
	assert_true(history_button != null, "Home opens history")
	if history_button != null:
		history_button.pressed.emit()
		var screen = main.get_node("HistoryScreen")
		assert_true(screen.visible)
		var card = screen.get_node("Margin/Content/Cards/List").get_child(0)
		card.get_node("Details/HBoxContainer/Review").pressed.emit()
		var review = main.get_node("Review")
		assert_true(review.visible)
		assert_true(review.get_node("Margin/Content/Actions/BackHistory").visible)
		assert_true(not review.get_node("Margin/Content/Actions/Rematch").visible)
		assert_true(review.get_node("Margin/Content/ReviewBody/Side/Analyze").visible)
		assert_true(not review.get_node("Margin/Content/ReviewBody/Side/RepertoireExit").visible)
		review.get_node("Margin/Content/ReviewBody/Side/Analyze").pressed.emit()
		assert_true(fake.called and fake.maximum, "Analyze starts Max analysis")
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = true
		review._input(space)
		assert_true(review.visible, "space does not start a rematch")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		review._input(escape)
		assert_true(screen.visible and not review.visible, "Esc returns to history")
	main.free()
	Storage.clean(folder)


func test_black_player_and_cached_analysis_appear_on_card():
	var folder := "user://history_card_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var history = History.new(folder)
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	game.resign("w")
	var path: String = history.save(game, [60000, 60000], {"colour": "b", "level": "maia-1500", "control": "1+0"})
	var analysis_path := folder.path_join("analysis").path_join(path.get_file() + ".json")
	DirAccess.make_dir_recursive_absolute(folder.path_join("analysis"))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	fixture.engine_version = "Stockfish 19"
	var file := FileAccess.open(analysis_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var screen = load("res://ui/history_screen.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	var card = screen.get_node("Margin/Content/Cards/List").get_child(0)
	var text: String = card.get_node("Details/Info/Players").text
	assert_true(text.contains("You") and text.contains("Maia 1500"), "human name comes first with both colours")
	assert_true(card.get_node("Details/Info/Result").text.contains("Won"), "the game outcome is visible")
	assert_true(card.find_child("WhiteAccuracy", true, false).text == "100.0%" and card.find_child("BlackAccuracy", true, false).text == "100.0%", "both cached accuracies are visible")
	screen.free()
	DirAccess.remove_absolute(analysis_path)
	DirAccess.remove_absolute(folder.path_join("analysis"))
	Storage.clean(folder)


func test_history_review_uses_saved_repertoire_snapshot():
	var folder := "user://history_snapshot_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.history = History.new(folder)
	main.preferences = Settings.new(folder.path_join("settings.cfg"))
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	var repertoire = load("res://bot/repertoire.gd").new()
	assert_eq(repertoire.parse("1. e4 e5 2. Nf3 *", "w"), "")
	var game = Game.new()
	game.play("d2d4")
	game.resign("b")
	main.history.save(game, [60000], {"colour": "w", "level": "maia-1500", "control": "1+0"}, "", "", repertoire.lines, "w")
	Engine.get_main_loop().root.add_child(main)
	main.get_node("Home/Center/Form/History").pressed.emit()
	var card = main.get_node("HistoryScreen/Margin/Content/Cards/List").get_child(0)
	card.get_node("Details/HBoxContainer/Review").pressed.emit()
	var exit_label = main.review.get_node("Margin/Content/ReviewBody/Side/RepertoireExit")
	assert_true(exit_label.visible and exit_label.text.contains("expected: e4"), "markers come from the saved snapshot")
	main.free()
	Storage.clean(folder)


func test_catalog_finishing_refreshes_visible_thumbnails():
	var folder := "user://history_catalog_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.history = History.new(folder)
	main.preferences = Settings.new(folder.path_join("settings.cfg"))
	var book = main.get_node("Setup").book
	book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	var game = Game.new()
	for move in ["e2e4", "e7e5", "g1f3", "b8c6"]:
		game.play(move)
	game.resign("w")
	main.history.save(game, [60000, 60000, 60000, 60000], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	Engine.get_main_loop().root.add_child(main)
	main.get_node("Home/Center/Form/History").pressed.emit()
	var list = main.get_node("HistoryScreen/Margin/Content/Cards/List")
	assert_eq(list.get_child(0).get_node("Details/Thumbnail").game.moves.size(), 4)
	book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn\t1. e4 e5\n")
	main.get_node("Setup/OpeningPicker").catalog_ready.emit("")
	assert_eq(list.get_child(0).get_node("Details/Thumbnail").game.moves.size(), 2, "catalog completion refreshes the thumbnail")
	main.free()
	Storage.clean(folder)


func test_tabs_and_won_on_time_card():
	var scene = load("res://ui/history_screen.tscn")
	assert_true(scene != null, "history screen exists")
	if scene == null:
		return
	var folder := "user://history_screen_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var history = History.new(folder)
	var game = Game.new()
	game.play("e2e4")
	game.flag("b")
	history.save(game, [60000], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var settings = Settings.new(folder.path_join("settings.cfg"))
	settings.set_value("history_tab", "1+0")
	var screen = scene.instantiate()
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, settings)
	var tabs = screen.get_node("Margin/Content/Header/Tabs")
	assert_eq(tabs.current_tab, 1)
	var cards = screen.get_node("Margin/Content/Cards/List")
	assert_eq(cards.get_child_count(), 1)
	if cards.get_child_count() > 0:
		var text: String = cards.get_child(0).get_node("Details/Info/Players").text
		assert_true(text.contains("You") and text.contains("Maia 1500"))
		assert_true(cards.get_child(0).get_node("Details/Info/Result").text.contains("Won on time"))
	tabs.current_tab = 2
	assert_eq(cards.get_child_count(), 0, "3+2 filters out 1+0")
	screen.free()
	Storage.clean(folder)


func test_review_prioritizes_a_queued_game_even_with_cached_analysis():
	var folder := "user://history_queued_cached_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.history = History.new(folder)
	main.preferences = Settings.new(folder.path_join("settings.cfg"))
	main.uci.free()
	main.uci = HeldEngine.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	game.resign("w")
	var path: String = main.history.save(game, [60000, 60000], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var analysis_path := folder.path_join("analysis").path_join(path.get_file() + ".json")
	DirAccess.make_dir_recursive_absolute(folder.path_join("analysis"))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	fixture.engine_version = "Stockfish 19"
	var file := FileAccess.open(analysis_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var fake := FakeQueueAnalyser.new()
	main.analysis_queue = load("res://core/analysis_queue.gd").new(fake, folder.path_join("queue.cfg"))
	Engine.get_main_loop().root.add_child(main)
	main.analysis_queue.enqueue(path)
	assert_true(not fake.maximum, "batch begins in Background")
	main._show_history()
	main._review_history_game(path, main.history.games()[0].game)
	assert_true(fake.maximum, "Review promotes even a previously analysed queued game to Max")
	main.free()
	DirAccess.remove_absolute(analysis_path)
	DirAccess.remove_absolute(folder.path_join("analysis"))
	Storage.clean(folder)

func test_post_game_review_reuses_current_cache_with_a_saved_game():
	var folder := "user://hist006_cache_%d" % Time.get_ticks_usec()
	var name := "cache.pgn"
	var game_path := folder.path_join("games").path_join(name)
	var analysis_path := folder.path_join("analysis").path_join(name + ".json")
	DirAccess.make_dir_recursive_absolute(game_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(analysis_path.get_base_dir())
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	var file := FileAccess.open(game_path, FileAccess.WRITE)
	file.store_string("[Event \"test\"]\n\n1. e4 e5 *")
	file.close()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	fixture.engine_version = "Stockfish 19"
	file = FileAccess.open(analysis_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var runner := FakeQueueAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	var review = load("res://ui/review.tscn").instantiate()
	review.analysis_queue = queue
	review.analysis_bridge_factory = func(): return FakeAnalysisBridge.new()
	Engine.get_main_loop().root.add_child(review)
	review.present(game, [60000, 60000], {"colour": "w", "level": "maia-1500", "control": "1+0"}, "")
	review.open_analysis(analysis_path, false)
	assert_true(not runner.called, "current cache does not start a new analysis")
	assert_true(review._positions[0].has("pv"), "cached positions are displayed")
	review.free()
	queue.free()
	DirAccess.remove_absolute(analysis_path)
	DirAccess.remove_absolute(analysis_path.get_base_dir())
	Storage.clean(folder)

func test_batch_status_advances_and_appears_after_restoring_queue():
	var folder := "user://history_batch_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var runner := FakeQueueAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	queue.enqueue("first.pgn")
	queue.enqueue("second.pgn")
	queue.enqueue("third.pgn")
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	Engine.get_main_loop().root.add_child(screen)
	screen.present(History.new(folder), Settings.new(folder.path_join("settings.cfg")))
	var status: Label = screen.get_node("Margin/Content/BatchActions/Status")
	assert_eq(status.text, "Analysing 1 of 3 · Background", "presenting an existing queue shows its status")
	runner.finished.emit(true, "")
	assert_eq(status.text, "Analysing 2 of 3 · Background", "status advances after a game finishes")
	runner.finished.emit(false, "Stockfish crashed")
	assert_eq(status.text, "Analysis failed: Stockfish crashed · Analyze all to retry", "a failure says why the batch stopped")
	screen.get_node("Margin/Content/BatchActions/AnalyzeAll").pressed.emit()
	assert_eq(status.text, "Analysing 2 of 3 · Background", "Analyze all retries the failed game")
	screen.free()
	queue.free()
	var restored = load("res://core/analysis_queue.gd").new(FakeQueueAnalyser.new(), folder.path_join("queue.cfg"))
	screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = restored
	Engine.get_main_loop().root.add_child(screen)
	screen.present(History.new(folder), Settings.new(folder.path_join("settings.cfg")))
	status = screen.get_node("Margin/Content/BatchActions/Status")
	assert_eq(status.text, "Analysing 2 of 3 · Background", "restored batch retains its progress")
	screen.free()
	restored.free()
	Storage.clean(folder)


func test_queue_progress_keeps_keyboard_focus_on_the_card():
	var folder := "user://history_focus_%d" % Time.get_ticks_usec()
	var history = History.new(folder)
	var game = Game.new()
	game.resign("w")
	var path: String = history.save(game, [], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var runner := FakeQueueAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	queue.enqueue(path)
	var review: Button = screen.get_node("Margin/Content/Cards/List").get_child(0).get_node("Details/HBoxContainer/Review")
	review.grab_focus()
	runner.progress.emit(1, 2)
	var focused = screen.get_viewport().gui_get_focus_owner()
	assert_true(focused != null and focused != review and focused.name == "Review", "the rebuilt card's Review keeps focus")
	screen.free()
	queue.free()
	Storage.clean(folder)

func test_counts_queue_and_inline_delete():
	var folder := "user://history_redo_%d" % Time.get_ticks_usec()
	var history = History.new(folder)
	var game = Game.new()
	game.resign("b")
	var first: String = history.save(game, [], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var second: String = history.save(game, [], {"colour": "w", "level": "maia-1500", "control": "3+2"})
	var queue = load("res://core/analysis_queue.gd").new(FakeQueueAnalyser.new(), folder.path_join("queue.cfg"))
	queue.enqueue(first)
	queue.enqueue(second)
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	var tabs = screen.get_node("Margin/Content/Header/Tabs")
	assert_eq(tabs.get_tab_title(0), "All 2")
	assert_eq(tabs.get_tab_title(1), "1+0 1")
	assert_eq(tabs.get_tab_title(2), "3+2 1")
	var cards = screen.get_node("Margin/Content/Cards/List")
	var queued = cards.get_node(second.get_file().validate_node_name())
	var action: Button = queued.get_node("Details/HBoxContainer/Analyze")
	assert_true(action.disabled and action.text == "Queued", "queued action identifies its state")
	queued.get_node("Details/HBoxContainer/Delete").pressed.emit()
	var confirmation = queued.find_child("DeleteInline", true, false)
	assert_true(confirmation != null and confirmation.visible, "delete confirmation appears inside its card")
	assert_true(FileAccess.file_exists(second), "opening confirmation does not delete the game")
	screen.free()
	queue.free()
	Storage.clean(folder)

func test_history_select_all_and_active_progress():
	var folder := "user://history_toolbar_%d" % Time.get_ticks_usec()
	var history = History.new(folder)
	var game = Game.new()
	game.resign("b")
	var first: String = history.save(game, [], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var second: String = history.save(game, [], {"colour": "w", "level": "maia-1500", "control": "3+2"})
	var runner := FakeQueueAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	var all = screen.find_child("SelectAll", true, false)
	assert_true(all != null, "toolbar offers select all")
	if all != null:
		all.button_pressed = true
		assert_true(all.text == "2 selected", "selection count updates")
		var selected = screen.find_child("AnalyzeSelected", true, false)
		selected.pressed.emit()
		assert_eq(queue.pending().size(), 2)
		var current: String = queue.current()
		var card = screen.get_node("Margin/Content/Cards/List").get_node(current.get_file().validate_node_name())
		var action: Button = card.find_child("Analyze", true, false)
		assert_true(action.disabled and action.text == "Analysing…")
		assert_true(card.find_child("AnalysisProgress", true, false) != null, "active analysis has a progress bar")
	screen.free()
	queue.free()
	Storage.clean(folder)

func test_history_stale_analysis_shows_cached_accuracy_and_reason():
	var folder := "user://history_stale_%d" % Time.get_ticks_usec()
	var history = History.new(folder)
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	game.resign("w")
	var path: String = history.save(game, [60000, 60000], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var analysis_path := folder.path_join("analysis").path_join(path.get_file() + ".json")
	DirAccess.make_dir_recursive_absolute(analysis_path.get_base_dir())
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	fixture.engine_version = "Stockfish 18"
	var file := FileAccess.open(analysis_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = load("res://core/analysis_queue.gd").new(FakeQueueAnalyser.new(), folder.path_join("queue.cfg"))
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	var card = screen.get_node("Margin/Content/Cards/List").get_child(0)
	var reason = card.find_child("StaleReason", true, false)
	var white = card.find_child("WhiteAccuracy", true, false)
	var black = card.find_child("BlackAccuracy", true, false)
	assert_true(reason != null and reason.text.begins_with("Stale:"), "stale cache explains its state")
	assert_true(white != null and black != null and white.text.contains("100.0") and black.text.contains("100.0"), "stale cache retains both accuracies")
	assert_eq(card.find_child("Analyze", true, false).text, "Re-analyze")
	screen.analysis_queue.free()
	screen.free()
	Storage.clean(folder)
