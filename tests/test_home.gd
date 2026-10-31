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


func test_quick_play_uses_defaults_and_last_custom_choices():
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
