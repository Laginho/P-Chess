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
	stats.set_value("maia-1500", "5+0", {"wins": 1, "draws": 0, "losses": 1, "flag_wins": 1, "flag_losses": 1})
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
	var since = profile.find_child("PlayingSince", true, false)
	assert_true(since != null and not since.visible, "no games omits Playing since")
	var games = profile.find_child("GamesValue", true, false)
	assert_true(games != null, "Profile shows a games tile")
	if games != null:
		assert_eq(games.text, "12")
	for item in [["WdlValue", "5 / 3 / 4"], ["FlagValue", "2 / 3"], ["AccuracyValue", "–"]]:
		var label = profile.find_child(item[0], true, false)
		assert_true(label != null, "Profile shows " + item[0])
		if label != null:
			assert_eq(label.get_parsed_text() if label is RichTextLabel else label.text, item[1])
	var table = profile.find_child("Results", true, false)
	var cells := []
	for cell in table.get_children():
		cells.append(cell.text)
	assert_eq(cells, ["Level", "1+0 · W D L", "3+2 · W D L", "5+0 · W D L", "Flag wins", "Flag losses",
			"Maia 1100", "0  1  0", "–", "–", "0", "0",
			"Maia 1500", "–", "4  2  3", "1  0  1", "2", "3"])
	var header: Label = table.get_child(0)
	var level: Label = table.get_child(6)
	var flag_win: Label = table.get_child(16)
	var flag_loss: Label = table.get_child(17)
	assert_eq(header.get_theme_font_size("font_size"), 12, "table headers match the design")
	assert_eq(level.get_theme_font_size("font_size"), 14, "table rows are readable")
	assert_eq(level.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "level names align left")
	assert_eq(flag_win.get_theme_color("font_color"), Color("8fbc5a"), "flag wins are green")
	assert_eq(flag_loss.get_theme_color("font_color"), Color("ee7a72"), "flag losses are red")
	assert_true(profile.find_child("GamesCard", true, false).get_minimum_size().y >= 86, "tiles have the design's vertical space")
	assert_true(not profile.find_child("NoResults", true, false).visible)
	stats.clear()
	stats.save(folder.path_join("stats.cfg"))
	profile.refresh(History.new(folder))
	assert_eq(table.get_child_count(), 6, "refresh clears previous rows")
	assert_true(profile.find_child("NoResults", true, false).visible, "empty stats have a readable state")
	profile.free()
	_clean(folder)


func test_accuracy_chart_uses_dated_analysis_and_human_colour():
	var folder := "user://test_profile_accuracy_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder.path_join("games"))
	var analysis_dir := folder.path_join("analysis")
	DirAccess.make_dir_recursive_absolute(analysis_dir)
	# File names deliberately disagree with PGN dates; Black's one-move game is later.
	_write_game(folder, "a-later", "2026.10.03", "b", "1. e4 e5", analysis_dir, [0, 0, 0])
	_write_game(folder, "z-earlier", "2026.10.01", "w", "1. e4", analysis_dir, [0, 0])
	_write_game(folder, "unanalysed", "2026.09.01", "w", "1. e4", analysis_dir, [])
	_write_game(folder, "no-human-move", "2026.09.02", "b", "1. e4", analysis_dir, [0, 0])
	_write_game(folder, "zero-moves", "2026.09.03", "w", "", analysis_dir, [0])
	_write(folder.path_join("games/2025-08-01T10-00-00_1.pgn"), '[White "You"]\n[Black "Maia 1500"]\n[Result "0-1"]\n\n1. e4 0-1\n')
	_write_game(folder, "stale", "2026.09.04", "w", "1. e4", analysis_dir, [0, 0])
	var stale_path := analysis_dir.path_join("stale.pgn.json")
	var stale: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(stale_path))
	stale.engine_version = "Stockfish 18"
	_write(stale_path, JSON.stringify(stale))
	# In the middle, Black loses about 47.54 Win% points; White's accuracy remains 100.
	_write_game(folder, "black-loss", "2026.10.02", "b", "1. e4 e5", analysis_dir, [0, 0, 1000])
	var profile = load("res://ui/profile.tscn").instantiate()
	Engine.get_main_loop().root.add_child(profile)
	profile.present(Settings.new(folder.path_join("settings.cfg")))
	var chart = profile.find_child("AccuracyChart", true, false)
	assert_true(chart != null, "Profile includes an accuracy chart")
	if chart == null:
		profile.free()
		_clean(folder)
		return
	profile.refresh(History.new(folder), analysis_dir)
	var since = profile.find_child("PlayingSince", true, false)
	assert_true(since != null, "Profile shows the first saved game date")
	if since != null:
		assert_eq(since.text, "Playing since Aug 2025")
	var average = profile.find_child("AccuracyValue", true, false)
	assert_true(average != null, "Profile shows average accuracy")
	if average != null:
		assert_eq(average.text, "70.3")
	assert_eq(chart.series.size(), 3, "only analysed games where the human moved")
	assert_eq(chart.series[0].date, "2026.10.01")
	assert_eq(chart.series[1].date, "2026.10.02")
	assert_eq(chart.series[2].date, "2026.10.03")
	assert_eq(chart.series[0].accuracy, 100.0)
	# EP at 1000 cp is about 97.54%, so Black's drop is about 47.54 percentage points.
	assert_true(absf(chart.series[1].accuracy - 10.8500) < 0.01, "chart selects Black's accuracy")
	assert_eq(chart.series[2].accuracy, 100.0)
	assert_true(not profile.find_child("NoAccuracy", true, false).visible)
	profile.refresh(History.new(folder), folder.path_join("missing-analysis"))
	assert_eq(chart.series, [])
	assert_true(profile.find_child("NoAccuracy", true, false).visible, "no analysed games has an explicit message")
	profile.free()
	_clean(folder)


func test_profile_skips_incomplete_or_corrupt_analysis_and_handles_one_point():
	var folder := "user://test_profile_single_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder.path_join("games"))
	var analysis_dir := folder.path_join("analysis")
	DirAccess.make_dir_recursive_absolute(analysis_dir)
	_write_game(folder, "legacy", "2026.10.01", "w", "1. e4", analysis_dir, [0, 0])
	_write(folder.path_join("games/legacy.pgn"), '[White "You"]\n[Black "Maia 1500"]\n[Date "2026.10.01"]\n[Result "0-1"]\n\n1. e4 0-1\n')
	for stem in ["partial", "corrupt", "missing-fields"]:
		_write_game(folder, stem, "2026.10.02", "w", "1. e4", analysis_dir, [0])
	_write(analysis_dir.path_join("corrupt.pgn.json"), '{"engine_version":"Stockfish 19","node_budget":3000000,"positions":[null,null]}')
	_write(analysis_dir.path_join("missing-fields.pgn.json"), '{"engine_version":"Stockfish 19","node_budget":3000000,"positions":[{},{}]}')
	var profile = load("res://ui/profile.tscn").instantiate()
	Engine.get_main_loop().root.add_child(profile)
	profile.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	profile.size = Vector2(800, 600)
	profile.present(Settings.new(folder.path_join("settings.cfg")))
	profile.refresh(History.new(folder), analysis_dir)
	var chart = profile.find_child("AccuracyChart", true, false)
	assert_eq(chart.series.size(), 1, "legacy human identity, incomplete and corrupt analysis")
	assert_eq(chart.series[0].accuracy, 100.0)
	assert_true(chart.tooltip_text.contains("2026.10.01: 100.0%"))
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var table = profile.find_child("Results", true, false)
	var scroll = profile.find_child("Scroll", true, false)
	var back = profile.find_child("Back", true, false)
	assert_true(table.size.x <= scroll.size.x, "table fits the minimum window width")
	assert_true(back.global_position.y >= 0 and back.global_position.y + back.size.y <= 600,
			"Back stays inside the minimum window")
	assert_true(chart.size.x > 70 and chart.size.y >= 200, "single-point plot has drawing space")
	profile.free()
	_clean(folder)


func _write_game(folder: String, stem: String, date: String, human: String, moves: String,
		analysis_dir: String, scores: Array) -> void:
	_write(folder.path_join("games/" + stem + ".pgn"),
			'[Date "%s"]\n[White "Maia 1500"]\n[Black "Maia 1500"]\n[HumanColor "%s"]\n[Result "0-1"]\n\n%s 0-1\n' % [date, human, moves])
	if scores.is_empty():
		return
	var positions := []
	for score in scores:
		positions.append({"pv": [{"cp": score}]})
	positions[0].fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	_write(analysis_dir.path_join(stem + ".pgn.json"), JSON.stringify({
			"engine_version": "Stockfish 19", "node_budget": 3000000, "positions": positions}))


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
