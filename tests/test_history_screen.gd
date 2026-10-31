extends "res://tests/run.gd".Test

const History = preload("res://core/history.gd")
const Settings = preload("res://core/settings.gd")
const Game = preload("res://core/game.gd")
const Storage = preload("res://tests/history_storage.gd")


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
