extends "res://tests/run.gd".Test

const MainScene = preload("res://ui/main.tscn")
const Session = preload("res://tests/test_session.gd")


func test_course_navigation_unit_progress_and_clock():
	var folder := "user://course_screens_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("course.json")
	var course = load("res://core/course.gd").new(path)
	assert_true(course.save_rating(1600, "chess.com"))
	var main = MainScene.instantiate()
	main.course = course
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	main.get_node("Home/Center/Form/Course").pressed.emit()
	var map = main.get_node_or_null("CourseMap")
	assert_true(map != null and map.visible, "saved rating opens the course map")
	if map == null:
		main.free()
		Session.HistoryStorage.clean(folder)
		return
	assert_true(map.find_child("Stage", true, false).text.contains("Your stage"))
	var cards = map.find_child("Units", true, false)
	assert_eq(cards.get_child_count(), 1)
	cards.get_child(0).pressed.emit()
	var unit = main.get_node_or_null("Unit")
	assert_true(unit != null and unit.visible, "unit card opens the unit page")
	var parts = unit.find_child("Parts", true, false)
	assert_eq(parts.get_child_count(), 4)
	assert_eq(parts.get_child(0).find_child("Open", true, false).text, "Continue")
	for i in range(1, 4):
		assert_eq(parts.get_child(i).find_child("Open", true, false).text, "Open")
	var requests := []
	unit.part_requested.connect(func(selected, part): requests.append([selected.id, part]))
	for row in parts.get_children():
		row.find_child("Open", true, false).pressed.emit()
	assert_eq(requests, [["rook-endgames", "theory"], ["rook-endgames", "solving"], ["rook-endgames", "playouts"], ["rook-endgames", "test"]])
	assert_true(unit.visible, "a part without a screen leaves the unit visible")
	unit.find_child("NoClock", true, false).pressed.emit()
	assert_eq(load("res://core/course.gd").new(path).clock_choice(), "none")
	unit.present(load("res://core/course.gd").new(path), main.course.units()[0])
	assert_true(unit.find_child("NoClock", true, false).button_pressed, "saved clock is selected on reopening")
	assert_true(not unit.find_child("ClockOn", true, false).button_pressed)
	unit.find_child("Back", true, false).pressed.emit()
	assert_true(map.visible and not unit.visible)
	map.find_child("Edit", true, false).pressed.emit()
	assert_true(main.get_node("Home/Profile").visible, "Edit opens Profile")
	main.get_node("Home/Profile").find_child("Back", true, false).pressed.emit()
	assert_true(map.visible, "Profile returns to map")
	map.find_child("Back", true, false).pressed.emit()
	assert_true(main.get_node("Home").visible and not map.visible)
	main.free()
	Session.HistoryStorage.clean(folder)


func test_continue_moves_to_first_unfinished_part_and_disappears_when_done():
	var folder := "user://course_continue_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("course.json")
	var main = MainScene.instantiate()
	main.course = load("res://core/course.gd").new(path, "res://tests/fixtures/course/course.json")
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	var samples := [
		[{"theory_opened": true}, 1],
		[{"theory_opened": true, "practice": {"one": {"solved": true}, "two": {"solved": true}}}, 2],
		[{"theory_opened": true, "practice": {"one": {"solved": true}, "two": {"solved": true}}, "playouts": {"a": true, "b": true, "c": true, "d": true}}, 3],
		[{"theory_opened": true, "practice": {"one": {"solved": true}, "two": {"solved": true}}, "playouts": {"a": true, "b": true, "c": true, "d": true}, "test_attempts": [{"passed": true}]}, -1]
	]
	for sample in samples:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"rating": {"number": 1300, "site": "chess.com"}, "units": {"rook": sample[0]}}))
		file = null
		main.course = load("res://core/course.gd").new(path, "res://tests/fixtures/course/course.json")
		main._show_course_map()
		main.course_map.find_child("Units", true, false).get_child(0).pressed.emit()
		var parts = main.unit_page.find_child("Parts", true, false)
		for i in 4:
			assert_eq(parts.get_child(i).find_child("Open", true, false).text, "Continue" if i == sample[1] else "Open")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_new_rating_lands_on_the_map():
	var folder := "user://course_new_rating_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.course = load("res://core/course.gd").new(folder.path_join("course.json"))
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	main.get_node("Home/Center/Form/Course").pressed.emit()
	var dialog = main.rating_dialog
	assert_true(dialog.visible)
	var number: LineEdit = dialog.find_child("RatingNumber", true, false)
	number.text = "1600"
	number.text_changed.emit(number.text)
	dialog.confirmed.emit()
	assert_true(main.course_map.visible and not main.get_node("Home").visible, "saving the first rating opens the map")
	main.free()
	Session.HistoryStorage.clean(folder)
