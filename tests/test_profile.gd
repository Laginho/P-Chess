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


func test_profile_table_matches_stats_and_omits_empty_rows():
	var folder := "user://test_profile_stats_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var stats := ConfigFile.new()
	stats.set_value("maia-1500", "3+2", {"wins": 4, "draws": 2, "losses": 3, "flag_wins": 1, "flag_losses": 2})
	stats.set_value("maia-1100", "1+0", {"wins": 0, "draws": 1, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	stats.set_value("maia-1900", "5+0", {"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	stats.save(folder.path_join("stats.cfg"))
	var profile = load("res://ui/profile.tscn").instantiate()
	Engine.get_main_loop().root.add_child(profile)
	assert_true(profile.has_method("refresh"), "Profile can read the supplied history")
	if not profile.has_method("refresh"):
		profile.free()
		_clean(folder)
		return
	profile.present(Settings.new(folder.path_join("settings.cfg")))
	profile.refresh(History.new(folder))
	var table = profile.find_child("Results", true, false)
	var cells := []
	for cell in table.get_children():
		cells.append(cell.text)
	assert_eq(cells, ["Level", "Time", "W", "D", "L", "Flag wins", "Flag losses",
			"Maia 1100", "1+0", "0", "1", "0", "0", "0",
			"Maia 1500", "3+2", "4", "2", "3", "1", "2"])
	assert_true(not profile.find_child("NoResults", true, false).visible)
	stats.clear()
	stats.save(folder.path_join("stats.cfg"))
	profile.refresh(History.new(folder))
	assert_eq(table.get_child_count(), 7, "refresh clears previous rows")
	assert_true(profile.find_child("NoResults", true, false).visible, "empty stats have a readable state")
	profile.free()
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
