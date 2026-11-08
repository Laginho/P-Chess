extends "res://tests/run.gd".Test

const MainScene = preload("res://ui/main.tscn")
const Session = preload("res://tests/test_session.gd")


func test_black_first_line_pairs_san_by_side_after_undo_and_clear():
	var screen = load("res://ui/solving.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	var unit := {"id": "black", "positions": [{"id": "one", "pool": "practice", "fen": "4k3/8/2r5/8/8/8/8/4K3 b - - 0 1", "line_length": 2, "side": "b", "goal": "win"}]}
	screen.present(load("res://core/course.gd").new("user://absent_black_line_test.json"), unit)
	var moves = screen.find_child("Moves", true, false)
	for move in ["c6c5", "e1f2", "c5c4"]:
		screen.board._commit(move, false)
	assert_eq(moves.text, "1...  Rc5\n2.  Kf2  Rc4")
	screen.find_child("Undo", true, false).pressed.emit()
	assert_eq(moves.text, "1...  Rc5\n2.  Kf2")
	screen.find_child("Clear", true, false).pressed.emit()
	assert_eq(moves.text, "")
	screen.free()


func test_enter_commits_only_full_line_even_when_action_buttons_have_focus():
	var root = Engine.get_main_loop().root
	var screen = load("res://ui/solving.tscn").instantiate()
	root.add_child(screen)
	var unit := {"id": "keys", "positions": [{"id": "one", "pool": "practice", "fen": preload("res://core/game.gd").START, "line_length": 2, "side": "w", "goal": "win"}]}
	screen.present(load("res://core/course.gd").new("user://absent_keys_test.json"), unit)
	var commits := []
	var backs := []
	screen.line_committed.connect(func(position, uci, san): commits.append([position, uci, san]))
	screen.back_requested.connect(func(): backs.append(true))
	await Engine.get_main_loop().process_frame
	for keycode in [KEY_ENTER, KEY_KP_ENTER]:
		for button_name in ["Undo", "Clear", "Back", "Commit"]:
			screen.board.clear_entry()
			for move in ["e2e4", "e7e5", "g1f3"]:
				screen.board._commit(move, false)
			var button = screen.find_child(button_name, true, false)
			button.grab_focus()
			assert_eq(root.gui_get_focus_owner(), button, button_name + " receives focus")
			var previous := commits.size()
			for pressed in [true, false]:
				var event := InputEventKey.new()
				event.keycode = keycode
				event.physical_keycode = keycode
				event.pressed = pressed
				root.push_input(event, true)
				await Engine.get_main_loop().process_frame
			assert_eq(commits.size(), previous + 1, button_name + " commits once")
			assert_eq(screen.board.entry_moves, PackedStringArray(["e2e4", "e7e5", "g1f3"]), button_name + " does not alter the line")
			assert_eq(backs.size(), 0, "Enter does not go back")
			if button_name != "Commit":
				screen.board.undo_entry()
				previous = commits.size()
				for pressed in [true, false]:
					var event := InputEventKey.new()
					event.keycode = keycode
					event.physical_keycode = keycode
					event.pressed = pressed
					root.push_input(event, true)
					await Engine.get_main_loop().process_frame
				assert_eq(commits.size(), previous, "short line cannot commit")
				assert_eq(screen.board.entry_moves, PackedStringArray(["e2e4", "e7e5"]), button_name + " leaves a short line intact")
				assert_eq(backs.size(), 0, "Enter on a short line does not go back")
	screen.free()


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
		assert_eq(screen.find_child("Position", true, false).text, "Position 2 of 2")
		assert_eq(screen.find_child("Instruction", true, false).text, "Enter 2 of your moves, with Black's replies in between.")
		assert_eq(screen.find_child("Goal", true, false).find_child("Title", true, false).text, "White to play and win")
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
			assert_eq(commits[0][0].id, "next")
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
		board._commit("e2e4", false)
		board._commit("e7e5", false)
		board._commit("g1f3", false)
		screen.find_child("Commit", true, false).pressed.emit()
		assert_eq(commits.size(), 2, "the button commits a full line")
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"units": {"unit": {"practice": {"first": {"solved": true, "first_try": true}, "next": {"solved": true}}}}}))
		file = null
		screen.present(load("res://core/course.gd").new(path), unit)
		assert_true(progress.get_child(0).get_meta("current", false), "the solved fallback is still current")
		assert_eq(progress.get_child(0).get_theme_stylebox("panel").bg_color, Color("#7fa650"))
		assert_eq(progress.get_child(0).get_theme_stylebox("panel").border_width_left, 2)
		assert_eq(progress.get_child(1).get_theme_stylebox("panel").bg_color, Color("#4f6a33"))
		var from_game: Dictionary = unit.duplicate(true)
		from_game.positions[0].from_your_game = true
		screen.present(load("res://core/course.gd").new(path), from_game)
		assert_true(screen.find_child("FromGame", true, false).visible)
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


func _feedback_setup(probe) -> Dictionary:
	var folder := "user://feedback_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var course = load("res://core/course.gd").new(folder.path_join("course.json"))
	var screen = load("res://ui/solving.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	var feedback = screen.find_child("Feedback", true, false)
	assert_true(feedback != null, "solving has a feedback state")
	if feedback == null:
		screen.free()
		Session.HistoryStorage.clean(folder)
		return {}
	var sample = load("res://tests/test_grader.gd")
	var second: Dictionary = sample.position()
	second.id = "two"
	var unit := {"id": "rook", "title": "Rook endings", "positions": [sample.position(), second]}
	screen.probe = probe
	screen.present(course, unit)
	return {"screen": screen, "course": course, "unit": unit, "folder": folder}


func _feedback_cleanup(fixture: Dictionary) -> void:
	fixture.screen.free()
	Session.HistoryStorage.clean(fixture.folder)


func test_commit_feedback_replays_marks_retry_next_and_updates_unit_counts():
	var sample = load("res://tests/test_grader.gd")
	var fixture := _feedback_setup(sample.winning_probe())
	if fixture.is_empty():
		return
	var screen = fixture.screen
	for move in sample.LINE:
		screen.board._commit(move, false)
	screen.find_child("Commit", true, false).pressed.emit()
	assert_true(screen.find_child("Feedback", true, false).visible)
	assert_true(not screen.find_child("Actions", true, false).visible)
	assert_eq(screen.find_child("BannerTitle", true, false).text, "Solved, first try")
	assert_true(not screen.board.entry_mode)
	assert_eq(screen.board.game.board.to_fen(), sample.FEN, "playback starts at root")
	var timer = screen.find_child("Playback", true, false)
	timer.timeout.emit()
	assert_true(screen.find_child("FeedbackMoves", true, false).get_child(0).text.contains("✓"))
	assert_eq(screen.board.game.moves.size(), 1)
	timer.timeout.emit()
	timer.timeout.emit()
	assert_eq(screen.board.game.moves, PackedStringArray(sample.LINE))
	assert_true(timer.is_stopped())
	assert_eq(fixture.course.unit_progress(fixture.unit).solved, 1)
	screen.find_child("Retry", true, false).pressed.emit()
	assert_eq(screen.position_data.id, "one")
	assert_eq(screen.board.entry_moves.size(), 0)
	assert_true(screen.board.entry_mode)
	for move in sample.LINE:
		screen.board._commit(move, false)
	screen.find_child("Commit", true, false).pressed.emit()
	assert_eq(screen.find_child("BannerTitle", true, false).text, "Solved", "only the first passing commit gets first-try feedback")
	screen.find_child("Next", true, false).pressed.emit()
	assert_eq(screen.position_data.id, "two")
	assert_eq(screen.board.entry_moves.size(), 0)
	for move in sample.LINE:
		screen.board._commit(move, false)
	screen.find_child("Commit", true, false).pressed.emit()
	assert_true(fixture.course.unit_progress(fixture.unit).solving_done)
	assert_true(fixture.course.open_theory(fixture.unit))
	var unit_page = load("res://ui/unit_page.tscn").instantiate()
	Engine.get_main_loop().root.add_child(unit_page)
	unit_page.present(fixture.course, fixture.unit)
	assert_eq(unit_page.find_child("FirstTry", true, false).text, "100% (2 of 2)")
	var parts = unit_page.find_child("Parts", true, false)
	assert_true("2/2 solved" in _labels(parts.get_child(1)))
	assert_eq(parts.get_child(2).find_child("Open", true, false).text, "Continue")
	unit_page.free()
	_feedback_cleanup(fixture)


func test_failed_feedback_stops_before_bad_move_with_arrow_and_grey_tail():
	var sample = load("res://tests/test_grader.gd")
	var fixture := _feedback_setup(sample.failing_probe("win", 99))
	if fixture.is_empty():
		return
	var screen = fixture.screen
	fixture.unit.positions[0].line_length = 3
	screen.present(fixture.course, fixture.unit)
	for move in ["c6c5", "e1f2", "c5c4", "f2e2", "c4c3"]:
		screen.board._commit(move, false)
	screen.find_child("Commit", true, false).pressed.emit()
	assert_eq(screen.find_child("BannerTitle", true, false).text, "Not solved")
	assert_true(screen.find_child("BannerReason", true, false).text.contains("too slow"))
	var timer = screen.find_child("Playback", true, false)
	for i in 5:
		timer.timeout.emit()
	assert_eq(screen.board.game.moves, PackedStringArray(["c6c5", "e1f2"]))
	assert_eq(screen.board.best_move_arrow, "c5c3")
	assert_true(timer.is_stopped())
	var rows = screen.find_child("FeedbackMoves", true, false)
	assert_true(rows.get_child(0).text.contains("✓"))
	assert_true(rows.get_child(2).text.contains("✗"))
	assert_true(not rows.get_child(4).text.contains("✓") and not rows.get_child(4).text.contains("✗"))
	assert_eq(rows.get_child(4).get_theme_color("font_color"), Color("#8a857c"))
	assert_true(screen.find_child("CorrectLine", true, false).text.contains("Rc3"))
	assert_true(screen.find_child("CorrectLine", true, false).text.contains("Ke2"))
	assert_eq(fixture.course.unit_progress(fixture.unit).solved, 0)
	# A failed first commit followed by a passing retry is solved, never first try.
	screen.find_child("Retry", true, false).pressed.emit()
	fixture.unit.positions[0].line_length = 2
	screen.probe = sample.winning_probe()
	screen.present(fixture.course, fixture.unit)
	for move in sample.LINE:
		screen.board._commit(move, false)
	screen.find_child("Commit", true, false).pressed.emit()
	assert_eq(screen.find_child("BannerTitle", true, false).text, "Solved")
	assert_eq(fixture.course.unit_progress(fixture.unit).first_try, "0% (0 of 1)")
	_feedback_cleanup(fixture)


func test_probe_failure_and_cancelled_async_commit_record_nothing():
	var sample = load("res://tests/test_grader.gd")
	var probe = sample.FakeProbe.new()
	probe.held = true
	probe.answers[sample.FEN] = {"ok": false, "error": "Engine or tablebase missing"}
	var fixture := _feedback_setup(probe)
	if fixture.is_empty():
		return
	var screen = fixture.screen
	for move in sample.LINE:
		screen.board._commit(move, false)
	var commit = screen.find_child("Commit", true, false)
	commit.pressed.emit()
	commit.pressed.emit()
	assert_eq(probe.pending.size(), 1, "Commit is serialized while the probe answers")
	probe.reply()
	assert_true(screen.find_child("ProbeError", true, false).visible)
	assert_true(screen.find_child("ProbeError", true, false).text.contains("Engine or tablebase missing"))
	assert_true(not screen.find_child("Feedback", true, false).visible)
	assert_eq(fixture.course.practice_result(fixture.unit, screen.position_data), {})
	assert_true(not commit.disabled, "line can be committed again after an error")
	# A delayed answer after leaving the screen cannot record or overwrite a new position.
	probe.answers = sample.winning_probe().answers
	commit.pressed.emit()
	screen.hide()
	while not probe.pending.is_empty():
		probe.reply()
	assert_eq(fixture.course.practice_result(fixture.unit, screen.position_data), {})
	_feedback_cleanup(fixture)


func test_feedback_replays_legal_hold_line_through_material_and_fifty_move_draws():
	var sample = load("res://tests/test_grader.gd")
	var examples := [
		["4k3/8/8/8/8/8/5r2/4K3 w - - 0 1", ["e1f2", "e8d7", "f2g3"], "8/3k4/8/8/8/6K1/8/8 b - - 2 2"],
		["4k3/8/2r5/8/8/8/8/4K3 b - - 99 1", ["c6c5", "e1f2", "c5c4"], "4k3/8/8/8/2r5/8/5K2/8 w - - 102 3"]]
	for example in examples:
		var probe = sample.FakeProbe.new()
		var board = load("res://core/board.gd").from_fen(example[0])
		var side: String = board.side_to_move
		for move in example[1]:
			probe.answers[board.to_fen()] = sample.answer("draw", move, {move: {"result": "draw", "dtz": 0}})
			board.make_move(move)
		var fixture := _feedback_setup(probe)
		if fixture.is_empty():
			return
		fixture.unit.positions[0].fen = example[0]
		fixture.unit.positions[0].side = side
		fixture.unit.positions[0].goal = "hold"
		var screen = fixture.screen
		screen.present(fixture.course, fixture.unit)
		for move in example[1]:
			screen.board._commit(move, false)
		screen.find_child("Commit", true, false).pressed.emit()
		assert_eq(screen.find_child("BannerTitle", true, false).text, "Solved, first try")
		for i in 3:
			screen.get_node("Playback").timeout.emit()
		assert_eq(screen.board.game.moves, PackedStringArray(example[1]), "playback follows every legal entry ply even after a drawn position")
		assert_eq(screen.board.game.board.to_fen(), example[2])
		_feedback_cleanup(fixture)


class LifecycleProbe extends Node:
	var delegate
	var events: Array
	func _init(scripted, lifecycle: Array):
		delegate = scripted
		events = lifecycle
	func start() -> bool:
		events.append("started")
		return true
	func probe(fen: String, callback: Callable) -> void:
		delegate.probe(fen, callback)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			events.append("freed")


func test_main_owns_starts_injects_and_frees_the_solving_probe():
	var sample = load("res://tests/test_grader.gd")
	var folder := "user://main_probe_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	assert_eq(main.tablebase.get_script(), load("res://engine/tablebase.gd"), "Main constructs the shared tablebase adapter")
	main.tablebase.free()
	var events := []
	var scripted = sample.winning_probe()
	var probe := LifecycleProbe.new(scripted, events)
	main.tablebase = probe
	main.course = load("res://core/course.gd").new(folder.path_join("course.json"))
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	Engine.get_main_loop().root.add_child(main)
	assert_eq(main.get_node_or_null("Tablebase"), probe)
	assert_eq(main.solving.probe, probe)
	var unit := {"id": "main-probe", "positions": [sample.position()]}
	main._show_unit(unit)
	main._show_course_part(unit, "solving")
	for move in sample.LINE:
		main.solving.board._commit(move, false)
	main.solving.find_child("Commit", true, false).pressed.emit()
	assert_eq(events, ["started"], "Commit starts the owned adapter")
	assert_eq(scripted.requests.size(), 3)
	assert_true(main.solving.find_child("Feedback", true, false).visible)
	main.free()
	assert_eq(events, ["started", "freed"], "probe is freed with the other engine nodes")
	if is_instance_valid(probe):
		probe.free()
	Session.HistoryStorage.clean(folder)


func test_feedback_shows_better_defence_beside_the_opponent_move():
	var sample = load("res://tests/test_grader.gd")
	var probe = sample.winning_probe()
	var board = load("res://core/board.gd").from_fen(sample.FEN)
	board.make_move("c6c5")
	probe.answers[board.to_fen()] = sample.answer("loss", "e1d2", {
		"e1d2": {"result": "loss", "dtz": 9}, "e1f2": {"result": "loss", "dtz": 4}})
	var fixture := _feedback_setup(probe)
	if fixture.is_empty():
		return
	var screen = fixture.screen
	for move in sample.LINE:
		screen.board._commit(move, false)
	screen.find_child("Commit", true, false).pressed.emit()
	for i in 3:
		screen.get_node("Playback").timeout.emit()
	var rows = screen.find_child("FeedbackMoves", true, false)
	assert_true(rows.get_child(1).text.contains("Kf2"))
	assert_true(rows.get_child(1).text.contains("Better defence: Kd2"))
	assert_true(not rows.get_child(1).text.contains("✗"))
	assert_eq(screen.find_child("BannerTitle", true, false).text, "Solved, first try")
	_feedback_cleanup(fixture)


func test_playout_starts_from_unit_and_failing_move_ends_before_maia_without_history():
	var folder := "user://course_playout_ui_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.course = load("res://core/course.gd").new(folder.path_join("course.json"))
	main.course.save_rating(1250, "chess.com")
	main.course.save_clock_choice("none")
	main.history = load("res://core/history.gd").new(folder)
	main.uci.free()
	main.uci = Session.HeldBridge.new()
	main.maia = main.MaiaPlayer.new(main.uci)
	main.preferences = main.Settings.new(folder.path_join("settings.cfg"))
	main.preferences.set_value("player_name", "You")
	var sample = load("res://tests/test_grader.gd")
	var probe = sample.FakeProbe.new()
	probe.answers[sample.FEN] = sample.answer("win", "c6c5", {"c6c5": {"result": "win", "dtz": 3}, "c6c4": {"result": "draw", "dtz": 0}})
	main.tablebase.free()
	# Main owns the injected probe as a node.
	var adapter = LifecycleProbe.new(probe, [])
	main.tablebase = adapter
	Engine.get_main_loop().root.add_child(main)
	var position := {"id": "a", "fen": sample.FEN, "side": "b", "goal": "convert"}
	var unit := {"id": "rook", "title": "Rook endings", "playouts": [position, position, position, position]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "playouts")
	var screen = main.get_node_or_null("Playout")
	assert_true(screen != null and screen.visible, "unit opens the play-out start")
	if screen == null:
		main.free()
		Session.HistoryStorage.clean(folder)
		return
	assert_true(screen.find_child("Heading", true, false).text.contains("Play-out 1 of 4"))
	screen.find_child("Start", true, false).pressed.emit()
	while main._starting:
		await Engine.get_main_loop().process_frame
	assert_eq(main.board_view.game.start_fen, sample.FEN)
	assert_eq(main.human, "b")
	assert_eq(main.settings.level, "maia-1600")
	assert_eq(main.settings.control, "none")
	assert_true(main.board_view.play("c6c4"))
	assert_true(screen.visible, "end card opens")
	assert_eq(screen.find_child("Heading", true, false).text, "Play-out failed")
	assert_true(screen.find_child("Reason", true, false).text.contains("Rc4"))
	assert_true(screen.find_child("Reason", true, false).text.contains("Rc5"))
	assert_eq(screen.board.game.moves, PackedStringArray(["c6c4"]))
	assert_eq(screen.board.review_square, "c4")
	assert_true(screen.board.review_icon != null, "the failing move has the blunder icon")
	assert_eq(main.uci.requests.size(), 0, "Maia does not reply to a failed move")
	assert_true(main.history.games().is_empty(), "play-out does not enter history")
	screen.find_child("Back", true, false).pressed.emit()
	var session = Session.new()
	session._key(main, KEY_ESCAPE)
	session._key(main, KEY_ESCAPE)
	session._key(main, KEY_SPACE)
	assert_true(main.history.games().is_empty(), "game shortcuts cannot save after returning to the unit")
	assert_true(not FileAccess.file_exists(folder.path_join("stats.cfg")))
	assert_true(not main._starting, "game shortcuts cannot start a rematch on the unit page")
	main.free()
	Session.HistoryStorage.clean(folder)


func test_playout_promotion_records_pass_and_next_opens_next_position():
	var session = Session.new()
	var main = await session._session(Session.ManualWaits.new(), false)
	var folder: String = main.history._root
	main.course = load("res://core/course.gd").new(folder.path_join("course.json"))
	main.course.save_rating(1400, "chess.com")
	var sample = load("res://tests/test_grader.gd")
	var fen := "7k/P7/5K2/8/8/8/8/8 w - - 0 1"
	var probe = sample.FakeProbe.new()
	probe.answers[fen] = sample.answer("win", "a7a8q", {"a7a8q": {"result": "win", "dtz": 1}})
	main.tablebase.queue_free()
	var adapter = LifecycleProbe.new(probe, [])
	main.tablebase = adapter
	main.add_child(adapter)
	var first := {"id": "a", "fen": fen, "side": "w", "goal": "convert"}
	var second := {"id": "b", "fen": fen, "side": "w", "goal": "convert"}
	var unit := {"id": "rook", "playouts": [first, second, second, second]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "playouts")
	assert_true(main.playout.find_child("Details", true, false).text.contains("5+5"))
	main.playout.find_child("Start", true, false).pressed.emit()
	while main._starting:
		await Engine.get_main_loop().process_frame
	assert_true(main.board_view.play("a7a8q"))
	assert_eq(main.playout.find_child("Heading", true, false).text, "Converted")
	assert_true(main.playout.find_child("Reason", true, false).text.contains("promoted"))
	assert_true(main.course.playout_passed(unit, first))
	assert_true(main.playout.find_child("Next", true, false).visible)
	assert_true(not FileAccess.file_exists(folder.path_join("stats.cfg")))
	assert_true(main.history.games().is_empty())
	main.playout.find_child("Next", true, false).pressed.emit()
	assert_eq(main.playout.find_child("Heading", true, false).text, "Play-out 2 of 4")
	assert_true(main.playout.find_child("States", true, false).text.contains("Passed"))
	main.free()


func test_playout_flag_fails_without_history_and_retry_returns_to_start():
	var session = Session.new()
	var main = await session._session(Session.ManualWaits.new(), false)
	var folder: String = main.history._root
	main.course = load("res://core/course.gd").new(folder.path_join("course.json"))
	main.course.save_rating(1400, "chess.com")
	var position := {"id": "a", "fen": "R7/8/4k3/1P6/K7/8/8/2r5 w - - 0 1", "side": "w", "goal": "convert"}
	var unit := {"id": "rook", "playouts": [position]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "playouts")
	main.playout.find_child("Start", true, false).pressed.emit()
	while main._starting:
		await Engine.get_main_loop().process_frame
	main._on_flagged("w")
	assert_eq(main.playout.find_child("Heading", true, false).text, "Out of time")
	assert_true(not main.course.playout_passed(unit, position))
	assert_true(main.history.games().is_empty())
	main.playout.find_child("Retry", true, false).pressed.emit()
	assert_eq(main.playout.find_child("Heading", true, false).text, "Play-out 1 of 4")
	main.free()


func test_playout_shows_engine_start_error_and_can_return_to_unit():
	var session = Session.new()
	var main = await session._session(Session.ManualWaits.new(), false)
	main.course = load("res://core/course.gd").new(main.history._root.path_join("course.json"))
	main.course.save_rating(1400, "chess.com")
	var position := {"id": "a", "fen": "R7/8/4k3/1P6/K7/8/8/2r5 w - - 0 1", "side": "w", "goal": "convert"}
	var unit := {"id": "rook", "playouts": [position]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "playouts")
	main.uci.error = "Engine missing"
	main.playout.find_child("Start", true, false).pressed.emit()
	assert_true(main.playout.visible, "an engine error leaves an actionable screen")
	assert_true(main.playout.find_child("Reason", true, false).text.contains("Engine missing"))
	main.playout.find_child("Back", true, false).pressed.emit()
	assert_true(main.unit_page.visible)
	main.free()


func test_playout_waits_for_probe_before_maia():
	var session = Session.new()
	var main = await session._session(Session.ManualWaits.new(), false)
	main.course = load("res://core/course.gd").new(main.history._root.path_join("course.json"))
	main.course.save_rating(1400, "chess.com")
	var sample = load("res://tests/test_grader.gd")
	var probe = sample.FakeProbe.new()
	probe.held = true
	probe.answers[sample.FEN] = sample.answer("win", "c6c5", {"c6c5": {"result": "win", "dtz": 3}})
	main.tablebase.queue_free()
	var adapter = LifecycleProbe.new(probe, [])
	main.tablebase = adapter
	main.add_child(adapter)
	var position := {"id": "a", "fen": sample.FEN, "side": "b", "goal": "convert"}
	var unit := {"id": "rook", "playouts": [position]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "playouts")
	main.playout.find_child("Start", true, false).pressed.emit()
	while main._starting:
		await Engine.get_main_loop().process_frame
	main.board_view.play("c6c5")
	assert_eq(main.uci.requests.size(), 0, "the tablebase must answer before Maia is asked")
	probe.reply()
	assert_eq(main.uci.requests.size(), 2, "a kept result lets Maia reply")
	if not main.uci.requests.is_empty():
		assert_eq(main.uci.requests[-1][0], sample.FEN)
		assert_eq(main.uci.requests[-1][1], PackedStringArray(["c6c5"]))
	main.free()


func test_playout_disables_sandbox_actions_and_hotkeys_do_not_save_a_game():
	var session = Session.new()
	var main = await session._session(Session.ManualWaits.new(), false)
	main.course = load("res://core/course.gd").new(main.history._root.path_join("course.json"))
	main.course.save_rating(1400, "chess.com")
	var position := {"id": "a", "fen": "R7/8/4k3/1P6/K7/8/8/2r5 w - - 0 1", "side": "w", "goal": "convert"}
	var unit := {"id": "rook", "playouts": [position]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "playouts")
	main.playout.find_child("Start", true, false).pressed.emit()
	while main._starting:
		await Engine.get_main_loop().process_frame
	assert_true(not main.resign_button.visible and not main.draw_button.visible)
	assert_true(main.claim_draw.disabled)
	session._key(main, KEY_ESCAPE)
	session._key(main, KEY_ESCAPE)
	assert_true(not main.board_view.game.is_over(), "Esc cannot resign a course game")
	assert_true(main.history.games().is_empty())
	main._on_flagged("w")
	session._key(main, KEY_SPACE)
	assert_true(main.playout.visible and not main._starting, "Space cannot rematch from the end card")
	assert_true(main.history.games().is_empty())
	assert_true(not FileAccess.file_exists(main.history._root.path_join("stats.cfg")))
	main.free()


func test_playout_flag_during_terminal_move_takes_precedence_over_mate():
	var session = Session.new()
	var main = await session._session(Session.ManualWaits.new(), false)
	main.course = load("res://core/course.gd").new(main.history._root.path_join("course.json"))
	main.course.save_rating(1400, "chess.com")
	var sample = load("res://tests/test_grader.gd")
	var fen := "7k/8/5KQ1/8/8/8/8/8 w - - 0 1"
	var probe = sample.FakeProbe.new()
	probe.answers[fen] = sample.answer("win", "g6g7", {"g6g7": {"result": "win", "dtz": 1}})
	main.tablebase.queue_free()
	var adapter = LifecycleProbe.new(probe, [])
	main.tablebase = adapter
	main.add_child(adapter)
	var position := {"id": "a", "fen": fen, "side": "w", "goal": "convert"}
	var unit := {"id": "rook", "playouts": [position]}
	main._show_unit(unit)
	main.unit_page.part_requested.emit(unit, "playouts")
	main.playout.find_child("Start", true, false).pressed.emit()
	while main._starting:
		await Engine.get_main_loop().process_frame
	main.clock._now = func(): return 2
	main.clock._left.w = 1
	main.clock._moved.w = true
	main.clock._running = "w"
	main.clock._since = 0
	main.board_view.play("g6g7")
	assert_eq(main.playout.find_child("Heading", true, false).text, "Out of time")
	assert_true(not main.course.playout_passed(unit, position))
	main.free()


func test_playout_start_describes_task_rules_and_all_states_including_replay():
	var path := "user://playout_start_%d.json" % Time.get_ticks_usec()
	var course = load("res://core/course.gd").new(path)
	course.save_rating(1250, "chess.com")
	course.save_clock_choice("none")
	var fen := "8/8/1RK5/r3k3/2P5/8/8/8 b - - 20 54"
	var positions := []
	for i in 4:
		positions.append({"id": str(i), "fen": fen, "side": "b", "goal": "hold"})
	var unit := {"id": "rook", "playouts": positions}
	course.record_playout_pass(unit, positions[0])
	var screen = load("res://ui/playout.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	screen.present_start(course, unit, 0)
	var states: String = screen.find_child("States", true, false).text
	assert_true(states.contains("1 Passed") and states.contains("Current"), "a replay is both passed and current")
	assert_true(states.contains("2 To do") and states.contains("3 To do") and states.contains("4 To do"))
	var details: String = screen.find_child("Details", true, false).text
	assert_true(details.contains("Black to play and draw") and details.contains("Maia 1600") and details.contains("No clock"))
	var rules: String = screen.find_child("Reason", true, false).text
	assert_true(rules.contains("pawn") and rules.contains("30 moves") and rules.contains("time"))
	screen.free()
	DirAccess.remove_absolute(path)


func test_fourth_playout_pass_offers_back_to_unit_without_next():
	var screen = load("res://ui/playout.tscn").instantiate()
	Engine.get_main_loop().root.add_child(screen)
	var position := {"fen": "4k3/8/8/8/8/8/4p2R/K7 w - - 0 1", "side": "w", "goal": "hold"}
	var game = load("res://core/game.gd").new(position.fen)
	game.play("h2e2")
	screen.present_end(position, game, "Held", "You captured the pawn and kept the draw.", "", false)
	assert_eq(screen.find_child("Heading", true, false).text, "Held")
	assert_true(screen.find_child("Reason", true, false).text.contains("captured"))
	assert_true(not screen.find_child("Next", true, false).visible)
	assert_true(screen.find_child("Back", true, false).visible)
	var backs := []
	screen.back_requested.connect(func(): backs.append(true))
	screen.find_child("Back", true, false).pressed.emit()
	assert_eq(backs, [true])
	screen.free()
