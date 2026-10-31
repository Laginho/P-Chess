extends "res://tests/run.gd".Test

const Settings = preload("res://core/settings.gd")
const History = preload("res://core/history.gd")


func test_home_profile_rename_and_back():
	var folder := "user://test_profile_name_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder.path_join("games"))
	var settings = Settings.new(folder.path_join("settings.cfg"))
	settings.set_value("player_name", "You")
	var home = load("res://ui/home.tscn").instantiate()
	Engine.get_main_loop().root.add_child(home)
	home.configure(settings)
	var button = home.get_node_or_null("Center/Form/Profile")
	assert_true(button != null, "Home offers Profile")
	if button == null:
		home.free()
		_clean(folder)
		return
	button.pressed.emit()
	var profile = home.get_node_or_null("Profile")
	assert_true(profile != null and profile.is_visible_in_tree(), "Profile opens from Home")
	assert_true(not home.get_node("Center").visible, "Home controls are hidden")
	var input = profile.find_child("PlayerName", true, false)
	assert_eq(input.text, "You")
	input.text = "  Bruno  "
	profile.find_child("SaveName", true, false).pressed.emit()
	assert_eq(settings.get_value("player_name"), "Bruno")
	assert_eq(Settings.new(settings.path).get_value("player_name"), "Bruno", "rename survives restart")
	input.text = "   "
	input.text_submitted.emit(input.text)
	assert_eq(settings.get_value("player_name"), "Bruno", "blank name is rejected")
	var path := folder.path_join("games/legacy.pgn")
	_write(path, '[White "You"]\n[Black "Maia 1500"]\n[Result "0-1"]\n\n1. e4 0-1\n')
	var screen = load("res://ui/history_screen.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	screen.present(History.new(folder), settings)
	var text: String = screen.get_node("Margin/Content/Cards/List").get_child(0).get_node("Details/Text").text
	assert_true(text.contains("Bruno (White)"), "History immediately uses the new name for legacy games")
	assert_true(FileAccess.get_file_as_string(path).contains('[White "You"]'), "rename leaves saved PGN intact")
	screen.free()
	profile.find_child("Back", true, false).pressed.emit()
	assert_true(home.get_node("Center").visible, "Back restores Home")
	home.free()
	_clean(folder)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clean(folder: String) -> void:
	for child in DirAccess.get_directories_at(folder):
		_clean(folder.path_join(child))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
