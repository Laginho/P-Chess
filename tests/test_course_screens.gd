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
	assert_true(map.find_child("Stage", true, false).text.contains("Endgame foundations"))
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
		var theory = main.get_node_or_null("Theory")
		if theory != null and theory.visible:
			assert_true(theory.find_child("ReadCard", true, false).visible, "populated books section is visible")
			var without_books: Dictionary = main.course.units()[0].duplicate(true)
			without_books.theory.books = []
			theory.present(main.course, without_books)
			assert_true(not theory.find_child("ReadCard", true, false).visible, "empty books section is hidden")
			theory.find_child("Back", true, false).pressed.emit()
		var solving = main.get_node_or_null("Solving")
		if solving != null and solving.visible:
			solving.find_child("Back", true, false).pressed.emit()
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


func test_solving_entry_opens_next_position_limits_line_and_handles_keys():
	var folder := "user://solving_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("course.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"units": {"unit": {"practice": {"first": {"solved": true}}}}}))
	file = null
	var main = MainScene.instantiate()
	main.course = load("res://core/course.gd").new(path)
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	Engine.get_main_loop().root.add_child(main)
	var unit := {"id": "unit", "title": "Test", "positions": [
		{"id": "first", "pool": "practice", "fen": preload("res://core/game.gd").START, "line_length": 2, "side": "w", "goal": "win"},
		{"id": "next", "pool": "practice", "fen": preload("res://core/game.gd").START, "line_length": 2, "side": "w", "goal": "win"}]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "solving")
	var screen = main.get_node_or_null("Solving")
	assert_true(screen != null and screen.visible, "solving opens")
	if screen != null:
		assert_eq(screen.position_data.id, "next")
		var commits := []
		screen.line_committed.connect(func(position, uci, san): commits.append([position, uci, san]))
		var board = screen.find_child("BoardView", true, false)
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_ENTER
		screen._unhandled_key_input(key)
		assert_eq(commits.size(), 0, "a short line cannot be committed")
		for move in ["e2e4", "e7e5", "g1f3", "b8c6"]:
			board._commit(move, false)
		assert_eq(board.entry_moves.size(), 3, "line ends after two own moves")
		key.keycode = KEY_BACKSPACE
		screen._unhandled_key_input(key)
		assert_eq(board.entry_moves.size(), 2)
		board._commit("g1f3", false)
		key.keycode = KEY_ENTER
		screen._unhandled_key_input(key)
		assert_eq(commits.size(), 1)
		if commits.size() == 1:
			assert_eq(commits[0][1], PackedStringArray(["e2e4", "e7e5", "g1f3"]))
			assert_eq(commits[0][2], PackedStringArray(["e4", "e5", "Nf3"]))
		assert_eq(screen.find_child("Count", true, false).text, "2 of 2 moves")
		assert_true(screen.find_child("Moves", true, false).text.contains("1.  e4  e5"))
		screen.find_child("Undo", true, false).pressed.emit()
		assert_eq(board.entry_moves.size(), 2)
		screen.find_child("Clear", true, false).pressed.emit()
		assert_eq(board.entry_moves.size(), 0)
		screen.find_child("Commit", true, false).pressed.emit()
		assert_eq(commits.size(), 1)
		var progress = screen.find_child("Progress", true, false)
		assert_eq(progress.get_child_count(), 2)
		assert_true(progress.get_child(1).get_meta("current", false), "current position has an independent indicator")
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
		file.store_string(JSON.stringify({"rating": {"number": 1100, "site": "chess.com"}, "units": {"rook": sample[0]}}))
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


func _labels(node: Node) -> Array:
	var result := []
	if node is Label:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(_labels(child))
	return result


func test_map_shows_only_selected_stage_and_unit_page_reports_progress():
	var folder := "user://course_display_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("course.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rating": {"number": 1499, "site": "lichess"}, "units": {"rook": {"theory_opened": true, "practice": {"one": {"solved": true, "first_try": true}, "two": {"solved": false, "first_try": false}}, "playouts": {"a": true}, "test_attempts": [{"passed": false}]}}}))
	file = null
	var main = MainScene.instantiate()
	main.course = load("res://core/course.gd").new(path, "res://tests/fixtures/course/course.json")
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	main.get_node("Home/Center/Form/Course").pressed.emit()
	var map = main.course_map
	var cards = map.find_child("Units", true, false)
	assert_eq(cards.get_child_count(), 1)
	var labels := _labels(cards)
	for expected in ["Rook endings", "Done", "1/2 solved", "1/4 passed", "Not Passed"]:
		assert_true(expected in labels, "map displays " + expected)
	assert_true("Club unit" not in labels)
	cards.get_child(0).pressed.emit()
	var parts = main.unit_page.find_child("Parts", true, false)
	var titles := ["Theory pointer", "Solving", "Play-outs", "Pass test"]
	var status := ["Done", "1/2 solved", "1/4 passed", "Not Passed"]
	for i in 4:
		var row_labels := _labels(parts.get_child(i))
		assert_true(titles[i] in row_labels, "part order includes " + titles[i])
		assert_true(status[i] in row_labels, "part displays " + status[i])
	assert_eq(main.unit_page.find_child("FirstTry", true, false).text, "50% (1 of 2)")
	assert_true(main.course.save_rating(1500, "lichess"))
	main._show_course_map()
	labels = _labels(cards)
	assert_true("Club unit" in labels and "Rook endings" not in labels, "different stage shows its own unit")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_theory_pointer_displays_data_copies_and_navigates():
	var folder := "user://course_theory_screen_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("progress.json")
	var index := folder.path_join("course.json")
	var file := FileAccess.open(index, FileAccess.WRITE)
	file.store_string(JSON.stringify({"stages": [{"name": "Fixture", "min_rating": 100, "max_rating": 3500, "units": ["unit.json"]}]}))
	file = FileAccess.open(folder.path_join("unit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"id": "fixture", "title": "Fixture unit", "theory": {"goal": "Hold the ending", "search_terms": ["first term", "second term", "third term"], "books": [{"title": "Book one", "chapter": "Chapter 7"}, {"title": "Book two", "chapter": "Chapter 3"}]}, "positions": [{"id": "one", "pool": "practice"}]}))
	file = null
	var course = load("res://core/course.gd").new(path, index)
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
	main.get_node("CourseMap").find_child("Units", true, false).get_child(0).pressed.emit()
	var unit = main.get_node("Unit")
	unit.find_child("Parts", true, false).get_child(0).find_child("Open", true, false).pressed.emit()
	var theory = main.get_node_or_null("Theory")
	assert_true(theory != null and theory.visible, "theory opens from the unit")
	if theory == null:
		main.free()
		Session.HistoryStorage.clean(folder)
		return
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	assert_true(theory.find_child("Scroll", true, false).size.y > 0, "the content viewport is laid out on screen")
	assert_eq(theory.find_child("Goal", true, false).text, "Hold the ending")
	var terms = theory.find_child("Terms", true, false)
	assert_eq(terms.get_child_count(), 3)
	assert_eq(terms.get_child(0).text, "first term")
	assert_eq(terms.get_child(1).text, "second term")
	assert_eq(terms.get_child(2).text, "third term")
	terms.get_child(1).pressed.emit()
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		assert_eq(DisplayServer.clipboard_get(), "second term")
	var books = theory.find_child("Books", true, false)
	assert_true(theory.find_child("ReadCard", true, false).visible, "populated books section is visible")
	assert_eq(books.get_child_count(), 2)
	assert_eq(books.get_child(0).find_child("Title", true, false).text, "Book one")
	assert_eq(books.get_child(0).find_child("Chapter", true, false).text, "Chapter 7")
	assert_eq(books.get_child(1).find_child("Title", true, false).text, "Book two")
	assert_eq(books.get_child(1).find_child("Chapter", true, false).text, "Chapter 3")
	assert_true(load("res://core/course.gd").new(path, index).unit_progress(course.units()[0]).theory_done)
	theory.find_child("BackToUnit", true, false).pressed.emit()
	assert_true(unit.visible and not theory.visible)
	unit.find_child("Parts", true, false).get_child(0).find_child("Open", true, false).pressed.emit()
	theory.find_child("Back", true, false).pressed.emit()
	assert_true(unit.visible and not theory.visible)
	var rows = unit.find_child("Parts", true, false)
	assert_eq(rows.get_child(0).find_child("Open", true, false).text, "Open")
	assert_eq(rows.get_child(1).find_child("Open", true, false).text, "Continue")
	assert_true(rows.get_child(0).get_child(0).get_child(1).text == "Done")
	var requests := []
	unit.part_requested.connect(func(selected, part): requests.append([selected.id, part]))
	rows.get_child(0).find_child("Open", true, false).pressed.emit()
	theory.find_child("Next", true, false).pressed.emit()
	assert_eq(requests, [["fixture", "theory"], ["fixture", "solving"]])
	main.free()
	DirAccess.remove_absolute(index)
	DirAccess.remove_absolute(folder.path_join("unit.json"))
	Session.HistoryStorage.clean(folder)
