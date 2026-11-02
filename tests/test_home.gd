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


func test_profile_has_no_extra_settings_button_and_shortcut_opens_settings():
	var main = MainScene.instantiate()
	var folder := "user://test_home_profile_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	DirAccess.make_dir_recursive_absolute(folder)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	await Engine.get_main_loop().process_frame
	var home = main.get_node("Home")
	home._show_profile()
	assert_true(main.settings_screen.get_node_or_null("Open") == null, "Profile has no extra Settings button")
	var viewport = main.get_viewport()
	var panel = main.settings_screen.get_node("Panel")
	Session.new()._push_key(viewport, KEY_COMMA, true)
	assert_true(panel.visible, "Ctrl+, opens Settings in Profile")
	Session.new()._push_key(viewport, KEY_COMMA, true)
	assert_true(not panel.visible, "Ctrl+, closes Settings in Profile")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_home_and_searching_boards_follow_theme_preferences():
	var main = MainScene.instantiate()
	var folder := "user://test_home_themes_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	var home_board = main.get_node("Home/Center/Board")
	var search_board = main.get_node("Searching/Board")
	search_board.board_theme = "stale"
	search_board.piece_theme = "stale"
	main.searching.present({"control": "3+2", "level": "maia-1500"})
	assert_eq(search_board.board_theme, "brown", "Searching loads the saved board theme")
	assert_eq(search_board.piece_theme, "cburnett", "Searching loads the saved piece theme")
	home_board.board_theme = "stale"
	home_board.piece_theme = "stale"
	search_board.board_theme = "stale"
	search_board.piece_theme = "stale"
	main.preferences.changed.emit("board_theme", "brown")
	main.preferences.changed.emit("piece_theme", "cburnett")
	for board in [home_board, search_board]:
		assert_eq(board.board_theme, "brown", "board follows theme changes")
		assert_eq(board.piece_theme, "cburnett", "pieces follow theme changes")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_home_restores_quick_play_size_when_engine_warning_is_hidden():
	var home = load("res://ui/home.tscn").instantiate()
	home.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	home.size = Vector2(800, 600)
	Engine.get_main_loop().root.add_child(home)
	home.show_missing("Engine unavailable")
	var quick: Button = home.get_node("Center/Form/Quick/OneZero")
	var compact_height := quick.size.y
	home.get_node("Center/Form/Missing").hide()
	assert_true(quick.size.y > compact_height, "quick play grows after the warning is hidden")
	home.free()


func test_searching_keeps_long_player_name_inside_card_at_minimum_window():
	var main = MainScene.instantiate()
	var folder := "user://test_home_long_name_%d" % Time.get_ticks_usec()
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	var name := "Alexandria Catherine Montgomery de Albuquerque"
	main.preferences.set_value("player_name", name)
	Engine.get_main_loop().root.add_child(main)
	var screen: Control = main.searching
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(800, 600)
	screen.present({"control": "3+2", "level": "maia-1500"})
	await Engine.get_main_loop().process_frame
	var player: Label = screen.get_node("Player")
	var card: Control = screen.get_node("Card")
	assert_true(player.get_global_rect().end.x <= card.get_global_rect().end.x, "player name stays inside the card")
	assert_eq(player.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "long names are visibly truncated")
	assert_eq(main.preferences.get_value("player_name"), name, "the full name remains saved")
	main.free()
	Session.HistoryStorage.clean(folder)


# Bruno's QA follow-up: each quick-play label sits at its tile's centre with the icon just left of it,
# and the tiles stay landscape however narrow the panel gets.
func test_quick_play_tiles_are_landscape_with_centred_labels():
	var home = load("res://ui/home.tscn").instantiate()
	home.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	Engine.get_main_loop().root.add_child(home)
	for canvas in [Vector2(1422, 800), Vector2(1280, 960), Vector2(1911, 800), Vector2(800, 600)]:
		home.size = canvas
		for name in ["OneZero", "ThreeTwo", "FiveZero", "Custom"]:
			var tile: Button = home.find_child(name, true, false)
			assert_true(tile.size.x > tile.size.y, "%s is landscape at %s (%s)" % [name, canvas, tile.size])
			var placed: Vector3 = tile.placement()
			var label: float = tile.get_theme_font("font").get_string_size(tile.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(placed.z)).x
			assert_true(absf(placed.y + label / 2 - tile.size.x / 2) <= 1.0, "%s label centred at %s" % [name, canvas])
			var icon_end: float = placed.x + tile.get_theme_constant("icon_max_width")
			assert_true(placed.x >= tile.icon_left and icon_end <= placed.y and placed.y - icon_end <= 12, "%s icon just left of its label at %s: %s" % [name, canvas, placed])
	home.free()
