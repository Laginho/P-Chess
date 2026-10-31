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
	var history_button = main.get_node_or_null("Setup/Center/Form/History")
	assert_true(history_button != null, "setup opens history")
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
	var analysis_path := "user://analysis".path_join(path.get_file() + ".json")
	DirAccess.make_dir_recursive_absolute("user://analysis")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/analysis/rev003-opening.json"))
	fixture.engine_version = "Stockfish 19"
	var file := FileAccess.open(analysis_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var screen = load("res://ui/history_screen.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	screen.present(history, Settings.new(folder.path_join("settings.cfg")))
	var card = screen.get_node("Margin/Content/Cards/List").get_child(0)
	var text: String = card.get_node("Details/Text").text
	assert_true(text.contains("You (Black) x Maia 1500 (White)"), "human name comes first with both colours")
	assert_true(text.contains("1-0") or text.contains("0-1"), "the PGN result is visible")
	assert_true(text.contains("White: 100.0%") and text.contains("Black: 100.0%"), "both cached accuracies are visible")
	screen.free()
	DirAccess.remove_absolute(analysis_path)
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
	main.get_node("Setup/Center/Form/History").pressed.emit()
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
	main.get_node("Setup/Center/Form/History").pressed.emit()
	var list = main.get_node("HistoryScreen/Margin/Content/Cards/List")
	assert_eq(list.get_child(0).get_child(0).game.moves.size(), 4)
	book.load_tsv("eco\tname\tpgn\nC20\tKing's Pawn\t1. e4 e5\n")
	main.get_node("Setup/OpeningPicker").catalog_ready.emit("")
	assert_eq(list.get_child(0).get_child(0).game.moves.size(), 2, "catalog completion refreshes the thumbnail")
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
	var tabs = screen.get_node("Margin/Content/Tabs")
	assert_eq(tabs.current_tab, 1)
	var cards = screen.get_node("Margin/Content/Cards/List")
	assert_eq(cards.get_child_count(), 1)
	if cards.get_child_count() > 0:
		var text: String = cards.get_child(0).get_node("Details/Text").text
		assert_true(text.contains("You") and text.contains("Maia 1500"))
		assert_true(text.contains("Won on time"))
	tabs.current_tab = 2
	assert_eq(cards.get_child_count(), 0, "3+2 filters out 1+0")
	screen.free()
	Storage.clean(folder)

