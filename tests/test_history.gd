extends "res://tests/run.gd".Test

# The real history store and PGN reader, with files isolated from the player's data.
const History = preload("res://core/history.gd")
const Game = preload("res://core/game.gd")
const Pgn = preload("res://core/pgn.gd")
const SETTINGS := {"colour": "w", "level": "maia-1500", "control": "3+2", "opening": "Free"}


func _folder() -> String:
	return "user://test_history_%d" % Time.get_ticks_usec()


func _clean(folder: String) -> void:
	var games := folder.path_join("games")
	for file in DirAccess.get_files_at(games):
		DirAccess.remove_absolute(games.path_join(file))
	DirAccess.remove_absolute(games)
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


func test_finished_game_saves_one_pgn_with_headers_moves_and_exact_clocks():
	var folder := _folder()
	var history = History.new(folder)
	var game = Game.new()
	for move in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		assert_true(game.play(move))
	var path: String = history.save(game, [180000, 180000, 179534, 181001], SETTINGS)
	assert_eq(history.error, "")
	assert_eq(DirAccess.get_files_at(folder.path_join("games")).size(), 1)
	var parsed := Pgn.parse(FileAccess.get_file_as_string(path))
	assert_eq(parsed.error, "")
	assert_eq(parsed.games.size(), 1)
	if parsed.games.size() == 1:
		var saved: Dictionary = parsed.games[0]
		assert_eq(saved.headers, {"White": "You", "Black": "Maia 1500", "TimeControl": "180+2",
				"Result": "0-1", "Termination": "Normal"})
		assert_eq(saved.result, "0-1")
		assert_eq(saved.moves.map(func(move): return move.uci), ["f2f3", "e7e5", "g2g4", "d8h4"])
		assert_eq(saved.moves.map(func(move): return move.clock_ms), [180000, 180000, 179534, 181001])
	_clean(folder)


func test_stats_survive_reload_and_separate_level_control_and_human_colour():
	var folder := _folder()
	var history = History.new(folder)
	var flag_win = Game.new()
	flag_win.flag("b")
	history.save(flag_win, [], SETTINGS)
	var draw = Game.new()
	for move in ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"]:
		assert_true(draw.play(move))
	draw.claim_draw()
	history.save(draw, [180000, 180000, 180000, 180000, 180000, 180000, 180000, 180000], SETTINGS)
	var as_black := SETTINGS.duplicate()
	as_black.colour = "b"
	var loss = Game.new()
	loss.flag("b")
	history.save(loss, [], as_black)
	var normal_win = Game.new()
	normal_win.resign("b")
	history.save(normal_win, [], SETTINGS)
	var other := SETTINGS.duplicate()
	other.level = "maia-1700"
	other.control = "1+0"
	history.save(normal_win, [], other)
	var reloaded = History.new(folder)
	assert_eq(reloaded.stats("maia-1500", "3+2"), {"wins": 2, "draws": 1, "losses": 1, "flag_wins": 1, "flag_losses": 1})
	assert_eq(reloaded.stats("maia-1700", "1+0"), {"wins": 1, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	assert_eq(reloaded.stats("maia-1500", "1+0"), {"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0})
	assert_eq(DirAccess.get_files_at(folder.path_join("games")).size(), 5, "rapid saves never overwrite a PGN")
	_clean(folder)
