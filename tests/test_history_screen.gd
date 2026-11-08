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
	var stopped_called := false
	func stop() -> void:
		stopped_called = true
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
		var card = _history_cards(screen.get_node("Margin/Content/Cards/List"))[0]
		card.get_node("Details/HBoxContainer/Review").pressed.emit()
		var review = main.get_node("Review")
		assert_true(review.visible)
		assert_true(review.get_node("Margin/Content/Actions/BackHistory").visible)
		assert_true(not review.get_node("Margin/Content/Actions/Rematch").visible)
		assert_true(review.get_node("Margin/Content/ReviewBody/Side/Analyze").visible)
		assert_eq(_exit_rows(review), PackedStringArray(), "no repertoire exit without a snapshot")
		review.get_node("Margin/Content/ReviewBody/Side/Analyze").pressed.emit()
		assert_true(fake.called and fake.maximum, "Analyze starts Max analysis")
		assert_true(review.get_node("Margin/Content/StopAnalysis").visible)
		review.receive_position(0, {"pv": [{"cp": 50, "moves": ["e2e4"]}], "best_move": "e2e4"})
		review.get_node("Margin/Content/StopAnalysis").pressed.emit()
		assert_eq(main.analysis_queue.pending(), [])
		assert_true(not review.get_node("Margin/Content/StopAnalysis").visible)
		assert_true(review.get_node("Margin/Content/ReviewBody/Side/Analyze").visible)
		assert_true(not review._positions[0].has("pv"), "stop discards streamed results")

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
	var card = _history_cards(screen.get_node("Margin/Content/Cards/List"))[0]
	var text: String = card.get_node("Details/Info/Players").text
	assert_true(text.contains("You") and text.contains("Maia 1500"), "human name comes first with both colours")
	assert_true(card.get_node("Details/Info/Metadata/Result").text.contains("Won"), "the game outcome is visible")
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
	var card = _history_cards(main.get_node("HistoryScreen/Margin/Content/Cards/List"))[0]
	card.get_node("Details/HBoxContainer/Review").pressed.emit()
	assert_eq(_exit_rows(main.review), PackedStringArray(["Left repertoire · expected 1.e4"]), "markers come from the saved snapshot")
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
	assert_eq(_history_cards(list)[0].get_node("Details/Thumbnail").game.moves.size(), 4)
	book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn\t1. e4 e5\n")
	main.get_node("Setup/OpeningPicker").catalog_ready.emit("")
	assert_eq(_history_cards(list)[0].get_node("Details/Thumbnail").game.moves.size(), 2, "catalog completion refreshes the thumbnail")
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
	assert_eq(_history_cards(cards).size(), 1)
	if _history_cards(cards).size() > 0:
		var text: String = _history_cards(cards)[0].get_node("Details/Info/Players").text
		assert_true(text.contains("You") and text.contains("Maia 1500"))
		assert_true(_history_cards(cards)[0].get_node("Details/Info/Metadata/Result").text.contains("Won on time"))
	tabs.current_tab = 2
	assert_eq(_history_cards(cards).size(), 0, "3+2 filters out 1+0")
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
	var review = main.get_node("Review")
	var old_position: Dictionary = fixture.positions[0]
	review.receive_position(0, {"pv": [{"cp": 999, "moves": ["e2e4"]}], "best_move": "e2e4"})
	review.get_node("Margin/Content/StopAnalysis").pressed.emit()
	assert_eq(review._positions[0], old_position, "Stop restores the previous complete cache")
	assert_true(not review.get_node("Margin/Content/ReviewBody/Side/Analyze").visible)

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
	var review: Button = _history_cards(screen.get_node("Margin/Content/Cards/List"))[0].get_node("Details/HBoxContainer/Review")
	review.grab_focus()
	runner.progress.emit(1, 2)
	var focused = screen.get_viewport().gui_get_focus_owner()
	assert_true(focused == review, "progress preserves the focused Review button")
	screen.free()
	queue.free()
	Storage.clean(folder)

func test_queue_finish_updates_only_affected_visible_cards():
	var folder := "user://history_incremental_%d" % Time.get_ticks_usec()
	var history = History.new(folder)
	var game = Game.new()
	game.play("e2e4")
	game.play("e7e5")
	game.resign("w")
	var paths := []
	for index in 4:
		paths.append(history.save(game, [60000, 60000], {"colour": "w", "level": "maia-1500", "control": "1+0"}))
	var runner := FakeQueueAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	for index in [0, 1, 3]:
		queue.enqueue(paths[index])
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	var list = screen.get_node("Margin/Content/Cards/List")
	var unrelated = list.get_node(paths[2].get_file().validate_node_name())
	var waiting = list.get_node(paths[3].get_file().validate_node_name())
	var heading = list.get_child(0)
	var titles := []
	var tabs = screen.get_node("Margin/Content/Header/Tabs")
	for index in tabs.tab_count:
		titles.append(tabs.get_tab_title(index))
	var analysis_path: String = folder.path_join("analysis").path_join(paths[0].get_file() + ".json")
	DirAccess.make_dir_recursive_absolute(analysis_path.get_base_dir())
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	fixture.engine_version = "Stockfish 19"
	var file := FileAccess.open(analysis_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	runner.finished.emit(true, "")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var finished_card = list.get_node(paths[0].get_file().validate_node_name())
	assert_true(finished_card.find_child("WhiteAccuracy", true, false) != null, "finished game shows accuracy")
	assert_eq(finished_card.find_child("WhiteAccuracy", true, false).text, "100.0%")
	var active = list.get_node(paths[1].get_file().validate_node_name())
	assert_true(active.find_child("AnalysisProgress", true, false) != null, "next game shows Analysing")
	assert_eq(active.find_child("Analyze", true, false).text, "Stop")
	assert_true(is_instance_valid(unrelated) and unrelated == list.get_node(paths[2].get_file().validate_node_name()), "unrelated card survives the transition")
	assert_true(is_instance_valid(waiting) and waiting == list.get_node(paths[3].get_file().validate_node_name()), "still-queued card is not rebuilt")
	assert_true(is_instance_valid(heading) and heading == list.get_child(0), "date heading is retained")
	var queued = list.get_node(paths[3].get_file().validate_node_name())
	var labels = queued.find_child("QueuePill", true, false).find_children("*", "Label", true, false)
	assert_eq(labels[0].text, "Queued · 1st in line", "queue position updates without rebuilding")
	for index in tabs.tab_count:
		assert_eq(tabs.get_tab_title(index), titles[index], "tab counts stay unchanged")
	screen.free()
	queue.free()
	DirAccess.remove_absolute(analysis_path)
	DirAccess.remove_absolute(analysis_path.get_base_dir())
	Storage.clean(folder)


func test_queue_replacement_preserves_selection_focus_paging_and_delete_confirmation():
	var folder := "user://history_incremental_focus_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var screen = _paging_screen()
	var runner := FakeQueueAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	screen.analysis_queue = queue
	queue.changed.connect(screen._queue_changed)
	screen.present(screen.history, screen.preferences)
	var list = screen.get_node("Margin/Content/Cards/List")
	list.get_node("ShowMore").pressed.emit()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var record: Dictionary = screen._tab_records[10]
	var card = list.get_node(record.path.get_file().validate_node_name())
	var index: int = card.get_index()
	card.get_node("Details/Select").button_pressed = true
	card.get_node("Details/HBoxContainer/Review").grab_focus()
	var scroll = screen.get_node("Margin/Content/Cards")
	scroll.scroll_vertical = 100
	var offset: int = scroll.scroll_vertical
	assert_true(offset > 0, "fixture has a scrollable list")
	var siblings: Array = list.get_children()
	queue.enqueue(record.path)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	card = list.get_node(record.path.get_file().validate_node_name())
	assert_eq(card.get_index(), index, "rebuilt card keeps its list position")
	assert_true(card.get_node("Details/Select").button_pressed, "rebuilt card stays selected")
	assert_eq(screen.get_viewport().gui_get_focus_owner(), card.get_node("Details/HBoxContainer/Review"), "focus follows the rebuilt Review button")
	assert_eq(scroll.scroll_vertical, offset, "replacement preserves scroll offset after layout")
	for sibling_index in siblings.size():
		if sibling_index != index:
			assert_true(is_instance_valid(siblings[sibling_index]) and siblings[sibling_index] == list.get_child(sibling_index), "other cards, headings and paging footer are untouched")
	assert_eq(screen._visible_cards().size(), 40, "loaded pages are retained")
	assert_eq(screen.get_node("Margin/Content/BatchActions/SelectAll").text, "1 selected")
	card.get_node("Details/HBoxContainer/Delete").pressed.emit()
	card.get_node("Details/DeleteInline/Cancel").grab_focus()
	runner.finished.emit(false, "Stockfish crashed")
	card = list.get_node(record.path.get_file().validate_node_name())
	assert_true(card.get_node("Details/DeleteInline").visible, "failure preserves inline confirmation")
	assert_true(card.get_node("Details/Select").button_pressed)
	assert_eq(screen.get_viewport().gui_get_focus_owner(), card.get_node("Details/DeleteInline/Cancel"), "failure keeps confirmation focus")
	queue.resume()
	queue.remove(record.path)
	card = list.get_node(record.path.get_file().validate_node_name())
	assert_true(card.get_node("Details/DeleteInline").visible, "retry and removal keep inline confirmation")
	assert_eq(screen.get_viewport().gui_get_focus_owner(), card.get_node("Details/DeleteInline/Cancel"))
	assert_eq(card.get_node("Details/HBoxContainer/Analyze").text, "Analyze", "removed game is no longer queued")
	card.get_node("Details/DeleteInline/Cancel").pressed.emit()
	siblings = list.get_children()
	queue.enqueue(screen._tab_records[44].path)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	assert_eq(list.get_children(), siblings, "off-page queue changes leave the loaded page intact")
	assert_eq(scroll.scroll_vertical, offset)
	screen.hide()
	runner.finished.emit(true, "")
	screen.present(screen.history, screen.preferences)
	assert_eq(screen._visible_cards().size(), 40, "present still performs a full refresh of loaded pages")
	assert_true(list.get_child(index) != card, "present replaces the previous cards")
	screen.history.records.clear()
	screen.present(screen.history, screen.preferences)
	queue.enqueue("user://off-page.pgn")
	assert_eq(screen._visible_cards().size(), 0, "queue changes work with an empty History")
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
	assert_true(screen.find_child("AnalyzeSelected", true, false).icon != null, "batch analysis has its trend icon")
	assert_true(queued.find_child("QueueIcon", true, false) != null and queued.find_child("QueuePill", true, false) != null, "queued state has its clock and pill")
	var action: Button = queued.get_node("Details/HBoxContainer/Analyze")
	assert_true(not action.disabled and action.text == "Remove from queue", "queued action identifies its state")
	queued.get_node("Details/HBoxContainer/Delete").pressed.emit()
	var confirmation = queued.find_child("DeleteInline", true, false)
	assert_true(confirmation != null and confirmation.visible, "delete confirmation appears inside its card")
	assert_true(FileAccess.file_exists(second), "opening confirmation does not delete the game")
	screen.free()
	queue.free()
	Storage.clean(folder)

func test_delete_confirmation_stays_with_its_game_after_refresh():
	var folder := "user://history_delete_switch_%d" % Time.get_ticks_usec()
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
	var cards = screen.get_node("Margin/Content/Cards/List")
	var a = cards.get_node(first.get_file().validate_node_name())
	var b = cards.get_node(second.get_file().validate_node_name())
	a.get_node("Details/HBoxContainer/Delete").pressed.emit()
	b.get_node("Details/HBoxContainer/Delete").pressed.emit()
	assert_true(not a.get_node("Details/DeleteInline").visible, "opening B closes A's confirmation")
	assert_true(b.get_node("Details/DeleteInline").visible, "B is the only game awaiting confirmation")
	runner.progress.emit(1, 2)
	b = cards.get_node(second.get_file().validate_node_name())
	assert_true(b.get_node("Details/DeleteInline").visible, "queue refresh preserves B's confirmation")
	b.get_node("Details/DeleteInline/Cancel").pressed.emit()
	assert_true(FileAccess.file_exists(first) and FileAccess.file_exists(second), "cancel keeps both games")
	a = cards.get_node(first.get_file().validate_node_name())
	a.get_node("Details/HBoxContainer/Delete").pressed.emit()
	a.get_node("Details/DeleteInline/Confirm").pressed.emit()
	assert_true(not FileAccess.file_exists(first) and FileAccess.file_exists(second), "confirmation deletes only its own game")
	screen.free()
	queue.free()
	Storage.clean(folder)

func test_long_analysis_error_keeps_toolbar_inside_minimum_window():
	var folder := "user://history_error_layout_%d" % Time.get_ticks_usec()
	var history = History.new(folder)
	var game = Game.new()
	game.resign("b")
	var path: String = history.save(game, [], {"colour": "w", "level": "maia-1500", "control": "1+0"})
	var runner := FakeQueueAnalyser.new()
	var queue = load("res://core/analysis_queue.gd").new(runner, folder.path_join("queue.cfg"))
	var root: Window = Engine.get_main_loop().root
	var old_size: Vector2i = root.size
	root.size = Vector2i(1280, 800)
	var screen = load("res://ui/history_screen.tscn").instantiate()
	screen.analysis_queue = queue
	root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	queue.enqueue(path)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var status: Label = screen.get_node("Margin/Content/BatchActions/Status")
	var text_width := status.get_theme_font("font").get_string_size(status.text, HORIZONTAL_ALIGNMENT_LEFT, -1, status.get_theme_font_size("font_size")).x
	assert_true(status.size.x - text_width <= 12, "short queue status stays beside Analyze all without an empty gap")
	root.size = Vector2i(800, 600)
	runner.finished.emit(false, "Stockfish stopped. Restart the app to play again. Run scripts/fetch-engine.ps1 if needed.")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	for node_path in ["Header/Back", "Header/Title", "BatchActions/SelectAll", "BatchActions/AnalyzeSelected", "BatchActions/Status", "BatchActions/AnalyzeAll"]:
		var control: Control = screen.get_node("Margin/Content/" + node_path)
		var rect := control.get_global_rect()
		assert_true(root.get_visible_rect().encloses(rect), node_path + " stays inside the window")
	assert_true(status.text.contains("fetch-engine.ps1") and status.size.y >= status.get_line_height() * 2, "the full error wraps and remains readable")
	screen.free()
	queue.free()
	root.size = old_size
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
		assert_true(not action.disabled and action.text == "Stop")
		var waiting: String = second if current == first else first
		var waiting_card = screen.get_node("Margin/Content/Cards/List").get_node(waiting.get_file().validate_node_name())
		assert_eq(waiting_card.find_child("Analyze", true, false).text, "Remove from queue")
		waiting_card.find_child("Analyze", true, false).pressed.emit()
		assert_eq(queue.pending(), [current])
		queue.enqueue(waiting)
		card = screen.get_node("Margin/Content/Cards/List").get_node(current.get_file().validate_node_name())
		card.find_child("Analyze", true, false).pressed.emit()
		assert_eq(queue.current(), waiting, "History Stop advances to the next queued game")
		assert_eq(queue.batch_done, 0)
		var stop_all = screen.find_child("StopAll", true, false)
		assert_true(stop_all.visible)
		stop_all.pressed.emit()
		assert_eq(queue.pending(), [])
		assert_true(not stop_all.visible)
		card = screen.get_node("Margin/Content/Cards/List").get_node(current.get_file().validate_node_name())
		assert_eq(card.find_child("Analyze", true, false).text, "Analyze")

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
	var card = _history_cards(screen.get_node("Margin/Content/Cards/List"))[0]
	var reason = card.find_child("StaleReason", true, false)
	var white = card.find_child("WhiteAccuracy", true, false)
	var black = card.find_child("BlackAccuracy", true, false)
	assert_true(card.find_child("StaleIcon", true, false) != null, "stale state has its warning icon")
	assert_true(reason != null and reason.text.begins_with("Stale:"), "stale cache explains its state")
	assert_true(white != null and black != null and white.text.contains("100.0") and black.text.contains("100.0"), "stale cache retains both accuracies")
	assert_eq(card.find_child("Analyze", true, false).text, "Re-analyze")
	screen.analysis_queue.free()
	screen.free()
	Storage.clean(folder)


func _exit_rows(review) -> PackedStringArray:
	var rows := PackedStringArray()
	for row in review.get_node("Margin/Content/ReviewBody/Side/Moves").get_root().get_children():
		if row.get_text(1).begins_with("Left repertoire"):
			rows.append(row.get_text(1))
	return rows


class PagingHistory extends History:
	var records: Array = []
	func games() -> Array:
		return records.duplicate()
	func thumbnail(_moves: PackedStringArray) -> Dictionary:
		return {"ply": 0, "opening": ""}
	func delete(path: String) -> bool:
		records = records.filter(func(record): return record.path != path)
		return true


class PagingQueue extends RefCounted:
	signal changed
	var paths: Array = []
	func enqueue(path: String) -> void:
		paths.append(path)
	func resume() -> void:
		pass
	func pending() -> Array:
		return paths


func _paging_screen():
	var history := PagingHistory.new()
	for index in 45:
		var control := "60+0" if index < 42 else "180+2"
		var days_ago := 0 if index < 8 else (1 if index < 16 else 14)
		var today: int = Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system() + "T00:00:00")
		var date := Time.get_date_string_from_unix_time(today - days_ago * 86400)
		history.records.append({"path": "user://paging-%02d.pgn" % index, "modified": 45 - index,
			"game": {"headers": {"Date": date.replace("-", "."), "TimeControl": control, "White": "You", "Black": "Maia 1500"},
			"moves": [], "result": "1-0"}})
	# Deliberately shuffled by date and modification time; rendering restores newest first.
	history.records.reverse()
	var screen = load("res://ui/history_screen.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new("user://paging-unused-settings.cfg"))
	return screen


func test_date_sections_use_game_dates_and_monday_calendar_week():
	var screen = load("res://ui/history_screen.tscn").instantiate()
	var record := {"path": "2026-01-01.pgn", "game": {"headers": {}}}
	for pair in [["2026.11.05", "Today"], ["2026.11.04", "Yesterday"],
			["2026.11.02", "This week"], ["2026.11.01", "Earlier"], ["????.??.??", "Earlier"]]:
		record.game.headers.Date = pair[0]
		assert_eq(screen._date_group(record, "2026-11-05"), pair[1])
	record.game.headers.Date = "2026.11.08"
	assert_eq(screen._date_group(record, "2026-11-09"), "Yesterday", "Sunday remains Yesterday on Monday")
	record.game.headers.Date = "2026.11.07"
	assert_eq(screen._date_group(record, "2026-11-09"), "Earlier", "week starts Monday")
	record.game.headers.Date = "2026.02.30"
	assert_eq(screen._record_day(record), screen._parse_day("2026-01-01"), "invalid dates use filename")
	screen.free()


func test_paging_appends_preserves_cards_and_refresh_delete_keep_loaded_count():
	var screen = _paging_screen()
	var list = screen.get_node("Margin/Content/Cards/List")
	assert_eq(screen._visible_cards().size(), 20)
	var headings: Array = list.get_children().filter(func(node): return node is Label).map(func(node): return node.text)
	assert_eq(headings, ["Today", "Yesterday", "Earlier"])
	var original = screen._visible_cards()[0]
	assert_eq(str(original.name), "paging-00.pgn".validate_node_name(), "game date then newest modification orders cards")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var scroll = screen.get_node("Margin/Content/Cards")
	scroll.scroll_vertical = 100
	var offset: int = scroll.scroll_vertical
	list.get_node("ShowMore").pressed.emit()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	assert_eq(screen._visible_cards().size(), 40)
	assert_eq(screen._visible_cards()[0], original, "existing cards are retained")
	assert_eq(scroll.scroll_vertical, offset, "append preserves scroll position")
	assert_eq(list.get_children().filter(func(node): return node is Label).size(), 3, "page boundary does not repeat heading")
	screen._refresh()
	assert_eq(screen._visible_cards().size(), 40, "refresh retains loaded limit")
	screen._delete_path = screen._tab_records[0].path
	screen._confirm_delete(screen._delete_path)
	assert_eq(screen._visible_cards().size(), 40, "delete backfills the loaded limit")
	list.get_node("ShowMore").pressed.emit()
	assert_eq(screen._visible_cards().size(), 44)
	assert_true(not list.has_node("ShowMore"), "no footer after last page")
	screen.get_node("Margin/Content/Header/Tabs").current_tab = 1
	assert_eq(screen._visible_cards().size(), 20, "switching tabs resets the page")
	assert_eq(screen.get_node("Margin/Content/Header/Tabs").get_tab_title(1), "1+0 41")
	screen.free()


func test_analyze_all_includes_unshown_games_and_selection_only_shown():
	var screen = _paging_screen()
	var queue := PagingQueue.new()
	screen.analysis_queue = queue
	var select = screen.get_node("Margin/Content/BatchActions/SelectAll")
	select.button_pressed = true
	assert_eq(screen._selected.size(), 20)
	assert_eq(select.text, "20 selected")
	screen.get_node("Margin/Content/Header/Tabs").current_tab = 1
	assert_eq(screen._selected.size(), 0, "tab switch clears selection")
	assert_eq(select.text, "Select shown")
	screen.get_node("Margin/Content/BatchActions/AnalyzeAll").pressed.emit()
	assert_eq(queue.paths.size(), 42, "Analyze all includes all matching records beyond page one")
	assert_true(not queue.paths.has("user://paging-44.pgn"), "other tabs are excluded")
	screen.free()


# Date headings and the paging footer share the list with game cards.
func _history_cards(list: Node) -> Array:
	return list.get_children().filter(func(node): return node is PanelContainer)

func test_review_stop_cancels_owned_analyser_and_engine():
	var review = load("res://ui/review.tscn").instantiate()
	Engine.get_main_loop().root.add_child(review)
	var game = Game.new()
	game.play("e2e4")
	game.resign("b")
	review.present(game, [60000], {"colour": "w", "level": "maia-1500", "control": "1+0"}, "Won")
	var bridge := FakeAnalysisBridge.new()
	var analyser := FakeAnalyser.new()
	review.analysis_bridge_factory = func(): return bridge
	review.analyser_factory = func(_engine): return analyser
	review.open_analysis("user://missing_stop_%d.json" % Time.get_ticks_usec(), false)
	assert_true(analyser.called)
	review.get_node("Margin/Content/StopAnalysis").pressed.emit()
	assert_true(bridge.stopped_called, "Stop releases the owned engine immediately")
	assert_true(review._analyser == null and review._analysis_bridge == null)
	assert_true(review.get_node("Margin/Content/ReviewBody/Side/Analyze").visible)
	assert_true(not review.get_node("Margin/Content/AnalysisError").visible)
	for frame in 5:
		await Engine.get_main_loop().process_frame
	var footer = review.get_node("Margin/Content/ReviewBody/Side/FooterSpace")
	assert_true(footer.custom_minimum_size.y < 100, "returning to not analysed does not grow the footer")
	review.free()
