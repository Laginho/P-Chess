extends "res://tests/run.gd".Test

const MainScene = preload("res://ui/main.tscn")
const Session = preload("res://tests/test_session.gd")


func test_launch_opens_home():
	var main = MainScene.instantiate()
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new("res://tests/fixtures/no_session_settings.cfg")
	Engine.get_main_loop().root.add_child(main)
	var home = main.get_node_or_null("Home")
	assert_true(home != null and home.visible, "Home is visible on launch")
	assert_true(not main.setup.visible, "Custom game is initially hidden")
	main.free()


func test_quick_play_uses_defaults():
	var path := "user://test_home_settings.cfg"
	DirAccess.remove_absolute(path)

	var main = MainScene.instantiate()
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
		assert_eq(main.settings.get("level"), "maia-1500")
		assert_true(main.settings.get("colour") in ["w", "b"])
		assert_eq(main.settings.get("opening"), "Free")
		assert_eq(main.settings.get("control"), "3+2")
	main.free()
	DirAccess.remove_absolute(path)


func test_custom_choices_survive_restart_and_new_game_returns_home():
	var path := "user://test_home_last.cfg"
	DirAccess.remove_absolute(path)
	var main = MainScene.instantiate()
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
		main.board_view.game.resign("w")
		main._show_result()
		main.board_view.get_node("GameOver/Panel/Content/NewGame").pressed.emit()
		assert_true(home.visible, "New game returns Home")
		assert_eq(main._human_score, 0, "match score reset")
	main.free()
	var next = MainScene.instantiate()
	next.get_node("Setup").book.load_tsv("eco\tname\tpgn\nA00\tFixture\t1. h3\n")
	next.uci.free()
	next.uci = Session.HeldBridge.new()
	next.maia = next.MaiaPlayer.new(next.uci)
	next.preferences = next.Settings.new(path)
	Engine.get_main_loop().root.add_child(next)
	var quick = next.get_node_or_null("Home/Center/Form/Quick/OneZero")
	if custom and quick:
		quick.pressed.emit()
		assert_eq(next.settings.get("level"), "maia-1700")
		assert_eq(next.settings.get("colour"), "b")
		assert_eq(next.settings.get("opening"), "Free")
		assert_eq(next.settings.get("control"), "1+0")
	next.free()
	DirAccess.remove_absolute(path)