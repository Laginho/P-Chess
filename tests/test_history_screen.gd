extends "res://tests/run.gd".Test

const History = preload("res://core/history.gd")
const Settings = preload("res://core/settings.gd")
const Game = preload("res://core/game.gd")
const Storage = preload("res://tests/history_storage.gd")
const MainScene = preload("res://ui/main.tscn")


class HeldEngine extends "res://engine/uci.gd":
	func start(_dirs := PackedStringArray()) -> bool:
		return true


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
