extends "res://tests/run.gd".Test

const MainScene = preload("res://ui/main.tscn")
const Session = preload("res://tests/test_session.gd")


func test_launch_opens_home():
	var main = MainScene.instantiate()
	var folder := "user://test_home_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	var home = main.get_node_or_null("Home")
	assert_true(home != null and home.visible, "Home is visible on launch")
	assert_true(not main.setup.visible, "Custom game is initially hidden")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_quick_play_uses_defaults():
	var folder := "user://test_home_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("settings.cfg")

	var main = MainScene.instantiate()
	main.history = load("res://core/history.gd").new(folder)
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(path)
	Engine.get_main_loop().root.add_child(main)
	var home = main.get_node("Home")
	var quick = home.get_node_or_null("Center/Form/Quick/ThreeTwo")
	assert_true(quick != null, "3+2 quick play exists")
	if quick:
		quick.pressed.emit()
		await _wait_start(main)
		assert_eq(main.settings.get("level"), "maia-1500")
		assert_true(main.settings.get("colour") in ["w", "b"])
		assert_eq(main.settings.get("opening"), "Free")
		assert_eq(main.settings.get("control"), "3+2")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_custom_choices_survive_restart_and_new_game_returns_home():
	var folder := "user://test_home_last_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("settings.cfg")
	var main = MainScene.instantiate()
	main.history = load("res://core/history.gd").new(folder)
	main.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(path)
	Engine.get_main_loop().root.add_child(main)
	var home = main.get_node("Home")
	var custom = home.get_node_or_null("Center/Form/Custom")
	assert_true(custom != null, "Custom game exists")
	if custom:
		custom.pressed.emit()
		assert_true(main.setup.visible and not home.visible)
		main.setup.get_node("Center/Form/Colour").select(1)
		main.setup.get_node("Center/Form/Level").select(6)
		main.setup.get_node("Center/Form/Start").pressed.emit()
		await _wait_start(main)
		main.board_view.game.resign("w")
		main._show_result()
		main.board_view.get_node("GameOver/Panel/Content/NewGame").pressed.emit()
		assert_true(home.visible, "New game returns Home")
		assert_eq(main._human_score, 0, "match score reset")
		assert_eq(home.get_node("Center/Form/Level").get_item_text(home.get_node("Center/Form/Level").selected), "Maia 1700", "selector follows custom game")
	main.free()
	var next = MainScene.instantiate()
	next.history = load("res://core/history.gd").new(folder)
	next.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	next.uci.free()
	next.uci = Session.HeldBridge.new()
	next.maia = next.MaiaPlayer.new(next.uci)
	next.preferences = next.Settings.new(path)
	Engine.get_main_loop().root.add_child(next)
	var quick = next.get_node_or_null("Home/Center/Form/Quick/OneZero")
	if custom and quick:
		quick.pressed.emit()
		await _wait_start(next)
		assert_eq(next.settings.get("level"), "maia-1700")
		assert_eq(next.settings.get("colour"), "b")
		assert_eq(next.settings.get("opening"), "Free")
		assert_eq(next.settings.get("control"), "1+0")
	next.free()
	Session.HistoryStorage.clean(folder)


func test_missing_engine_disables_quick_play():
	var main = MainScene.instantiate()
	var folder := "user://test_home_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	main.uci.error = "Engine unavailable"
	main._on_engine_stopped()
	var home = main.get_node("Home")
	assert_true(home.visible)
	assert_true(home.get_node("Center/Form/Missing").visible)
	for button in home.get_node("Center/Form/Quick").get_children():
		assert_true(button.disabled, "quick play is disabled")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_home_settings_remain_available_after_focus_mode():
	var main = MainScene.instantiate()
	var folder := "user://test_home_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	main._set_focus(true)
	main._show_home()
	main.get_node("Home/Center/Form/Settings").pressed.emit()
	assert_true(main.settings_screen.is_visible_in_tree(), "Settings is accessible from Home")
	assert_true(main.settings_screen.get_node("Panel").visible)
	main.free()
	Session.HistoryStorage.clean(folder)


func test_custom_catalog_mode_is_reused_after_restart():
	var folder := "user://test_home_catalog_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	var book = main.get_node("Setup").book
	book.selection_dir = folder
	book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	book.set_checked("Fixture", true)
	assert_eq(book.save_selection("Practice"), "")
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.history = load("res://core/history.gd").new(folder)
	Engine.get_main_loop().root.add_child(main)
	main.get_node("Home/Center/Form/Custom").pressed.emit()
	var opening = main.setup.get_node("Center/Form/Opening")
	opening.select(1)
	opening.item_selected.emit(1)
	main.setup.get_node("Center/Form/Start").pressed.emit()
	await _wait_start(main)
	assert_eq(main.settings.get("opening"), "Catalog")
	main.free()
	var next = MainScene.instantiate()
	next.get_node("Setup").book.selection_dir = folder
	next.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	next.uci.free()
	next.uci = Session.HeldBridge.new()
	next.maia = next.MaiaPlayer.new(next.uci)
	next.preferences = next.Settings.new(folder.path_join("settings.cfg"))
	next.history = load("res://core/history.gd").new(folder)
	Engine.get_main_loop().root.add_child(next)
	next.get_node("Home/Center/Form/Quick/FiveZero").pressed.emit()
	await _wait_start(next)
	assert_eq(next.settings.get("opening"), "Catalog")
	assert_eq(next.settings.get("selection"), "Practice")
	assert_eq(next.settings.get("control"), "5+0")
	next.free()
	Session.HistoryStorage.clean(folder)


# Starts now cross a real asynchronous searching screen.
func _wait_start(main) -> void:
	while main._starting:
		await Engine.get_main_loop().process_frame


func test_home_shows_quick_play_and_navigation_icons():
	var home = load("res://ui/home.tscn").instantiate()
	Engine.get_main_loop().root.add_child(home)
	home.configure(load("res://core/settings.gd").new("res://tests/fixtures/no_session_settings.cfg"))
	for name in ["OneZero", "ThreeTwo", "FiveZero", "Custom", "History", "Profile", "Settings", "Quit"]:
		var button = home.find_child(name, true, false)
		assert_true(button is Button and button.icon != null, "%s has an icon" % name)
	var level: OptionButton = home.find_child("Level", true, false)
	assert_eq(level.get_item_text(level.selected), "Maia 1500")
	home.free()


func test_missing_engine_message_does_not_overlap_navigation_at_minimum_window():
	var home = load("res://ui/home.tscn").instantiate()
	home.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	home.size = Vector2(800, 600)
	Engine.get_main_loop().root.add_child(home)
	home.show_missing("Lc0 is missing (engine/lc0/lc0.exe). Run scripts/fetch-engine.ps1 to download it.")
	await Engine.get_main_loop().process_frame
	var message: Label = home.get_node("Center/Form/Missing")
	var history: Button = home.get_node("Center/Form/History")
	assert_true(message.get_global_rect().end.y <= history.get_global_rect().position.y, "engine guidance stays above navigation")
	home.free()


func test_profile_keeps_settings_available_after_opening_from_home():
	var main = MainScene.instantiate()
	var folder := "user://test_home_profile_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	await Engine.get_main_loop().process_frame
	var home = main.get_node("Home")
	home._show_profile()
	assert_true(main.settings_screen.get_node("Open").visible, "Settings remains available in Profile")
	main.free()
	Session.HistoryStorage.clean(folder)
