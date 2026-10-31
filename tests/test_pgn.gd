extends "res://tests/run.gd".Test

# PGN in and out (CORE-006).

const Pgn = preload("res://core/pgn.gd")
const Game = preload("res://core/game.gd")

const FIXTURES := "res://tests/fixtures/pgn/"


func test_finished_game_records_only_a_selected_practice_target():
	var game = Game.new()
	game.resign("w")
	var settings := {"colour": "w", "level": "maia-1500", "control": "3+2"}
	var targeted: Dictionary = Pgn.finished_game(game, [], settings, "", "line-1")
	assert_eq(Pgn.parse(Pgn.write(targeted)).games[0].headers.PracticeTarget, "line-1")
	assert_true(not Pgn.finished_game(game, [], settings).headers.has("PracticeTarget"))


func _read(file: String) -> Dictionary:
	return Pgn.parse(FileAccess.get_file_as_string(FIXTURES + file))


static func _field(moves: Array, key: String) -> Array:
	return moves.map(func(move): return move[key])


func test_headers_mainline_comments_nags_and_result_parse():
	var parsed := _read("variations.pgn")
	assert_eq(parsed.error, "")
	assert_eq(parsed.games.size(), 1)
	var game: Dictionary = parsed.games[0]
	assert_eq(game.headers, {"Event": "Variations", "White": "Alice", "Black": "Bob", "Result": "1-0"})
	assert_eq(game.result, "1-0")
	assert_eq(game.comment, "A short opening.")
	assert_eq(_field(game.moves, "san"), ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"])
	assert_eq(_field(game.moves, "uci"), ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6"])
	assert_eq(_field(game.moves, "comment"), ["King's pawn", "", "", "rest of line", "", ""])
	# $1 as written; !? and ?! as their NAGs, 5 and 6.
	assert_eq(_field(game.moves, "nags"), [[1], [], [5], [6], [], []])


func test_variations_nest_under_the_move_they_replace():
	var moves: Array = _read("variations.pgn").games[0].moves
	assert_eq(moves[0].variations, [])
	assert_eq(moves[1].variations.size(), 1)
	var sicilian: Array = moves[1].variations[0]
	assert_eq(_field(sicilian, "uci"), ["c7c5", "g1f3", "d7d6"])
	assert_eq(sicilian[1].variations.size(), 1)
	var alapin: Array = sicilian[1].variations[0]
	assert_eq(_field(alapin, "uci"), ["c2c3", "d7d5"])
	assert_eq(alapin[1].variations.size(), 1)
	assert_eq(_field(alapin[1].variations[0], "uci"), ["g8f6", "e4e5"])


func test_a_comment_opening_a_variation_is_kept_on_its_first_move():
	var parsed := Pgn.parse("1. e4 e5 ({Better is} 1... c5 {Sicilian}) 2. Nf3 *")
	assert_eq(parsed.error, "")
	var game: Dictionary = parsed.games[0]
	var first: Dictionary = game.moves[1].variations[0][0]
	assert_eq(first.get("comment_before"), "Better is")
	assert_eq(first.comment, "Sicilian")
	assert_eq(game.comment, "")
	assert_eq(_field(game.moves, "comment"), ["", "", ""])
	assert_eq(_field(game.moves, "comment_before"), ["", "", ""])


func test_every_game_of_a_file_is_returned():
	var parsed := _read("several.pgn")
	assert_eq(parsed.error, "")
	assert_eq(parsed.games.map(func(game): return game.headers.Event), ["One", "Two", "Three"])
	assert_eq(parsed.games.map(func(game): return game.result), ["1-0", "0-1", "*"])
	assert_eq(parsed.games.map(func(game): return game.moves.size()), [7, 4, 1])
	assert_eq(parsed.games[0].moves[6].uci, "h5f7")


func test_clk_comments_give_each_move_its_clock_in_milliseconds():
	var parsed := _read("clocks.pgn")
	assert_eq(parsed.error, "")
	# 0:03:00, 0:02:59.5, 1:02:03 behind an %eval, and no clock on the last move.
	assert_eq(_field(parsed.games[0].moves, "clock_ms"), [180000, 179500, 3723000, -1])


func test_written_game_reads_back_with_the_same_headers_moves_and_clocks():
	var headers := {
		"Event": "Bruno's \"blitz\" \\ test",
		"White": "Maia 1500",
		"Black": "You",
		"TimeControl": "300+3",
		"Result": "0-1",
		"Termination": "Normal",
		"Opening": "Bird Opening",
	}
	var uci := ["f2f4", "e7e5", "g2g4", "d8h4"]
	var clocks := [300000, 297500, 3723400, 59900]
	var moves := []
	for i in uci.size():
		moves.append({"uci": uci[i], "clock_ms": clocks[i]})
	var parsed: Dictionary = Pgn.parse(Pgn.write({"headers": headers, "moves": moves, "result": "0-1"}))
	assert_eq(parsed.error, "")
	assert_eq(parsed.games.size(), 1)
	var game: Dictionary = parsed.games[0]
	assert_eq(game.headers, headers)
	assert_eq(_field(game.moves, "uci"), uci)
	assert_eq(_field(game.moves, "clock_ms"), clocks)
	assert_eq(game.result, "0-1")


func test_finished_game_builds_the_headers_and_clock_records_both_exports_share():
	var game = Game.new()
	for move in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		assert_true(game.play(move))
	var built: Dictionary = Pgn.finished_game(game, [180000, 180000, 179534, 181001],
			{"colour": "w", "level": "maia-1500", "control": "3+2"})
	assert_eq(built.headers, {"White": "You", "Black": "Maia 1500", "TimeControl": "180+2",
			"Result": "0-1", "Termination": "Normal", "Reason": "checkmate"})
	assert_eq(built.moves, [{"uci": "f2f3", "clock_ms": 180000}, {"uci": "e7e5", "clock_ms": 180000},
			{"uci": "g2g4", "clock_ms": 179534}, {"uci": "d8h4", "clock_ms": 181001}])
	assert_eq(built.result, "0-1")


func test_finished_game_names_a_flag_and_an_optional_opening_last():
	var game = Game.new()
	for move in ["e2e4", "e7e5"]:
		assert_true(game.play(move))
	game.flag("w")
	var built: Dictionary = Pgn.finished_game(game, [60000, 59000],
			{"colour": "b", "level": "maia-1900", "control": "1+0"}, "King's Pawn Game")
	assert_eq(built.headers, {"White": "Maia 1900", "Black": "You", "TimeControl": "60+0",
			"Result": "0-1", "Termination": "Time forfeit", "Reason": "time", "Opening": "King's Pawn Game"})
	assert_eq(str(built.headers.keys().back()), "Opening")
	assert_eq(built.moves, [{"uci": "e2e4", "clock_ms": 60000}, {"uci": "e7e5", "clock_ms": 59000}])
	assert_eq(built.result, "0-1")

func test_header_backslashes_read_back_unchanged():
	# PGN escapes only \\ and \"; a C-style \n or \t must stay two characters.
	var headers := {"Event": "C:\\new\\test", "White": "a\\tb", "Black": "q\\\"x\\", "Site": "\\a\\b\\f\\v\\'\\?\\r"}
	var parsed: Dictionary = Pgn.parse(Pgn.write({"headers": headers, "moves": [], "result": "*"}))
	assert_eq(parsed.error, "")
	assert_eq(parsed.games[0].headers, headers)


func test_clocks_read_back_to_the_millisecond():
	var uci := ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6"]
	var clocks := [297534, 180050, 300000, 297500, 1, 3723999]
	var moves := []
	for i in uci.size():
		moves.append({"uci": uci[i], "clock_ms": clocks[i]})
	var parsed: Dictionary = Pgn.parse(Pgn.write({"headers": {}, "moves": moves, "result": "*"}))
	assert_eq(parsed.error, "")
	assert_eq(_field(parsed.games[0].moves, "clock_ms"), clocks)


func test_an_illegal_move_is_an_error_naming_the_game_and_move_number():
	var parsed := _read("illegal.pgn")
	assert_eq(parsed.error, "Game 2, move 3...: illegal move Nf3")
	assert_eq(parsed.games, [])
	assert_eq(Pgn.parse("1. e4 e5 2. Ke3 *").error, "Game 1, move 2.: illegal move Ke3")


func test_malformed_text_is_an_error_not_a_crash():
	assert_eq(Pgn.parse(""), {"games": [], "error": ""})
	for text in ["1. e4 ) e5 *", "( 1. e4 ) *", "1. e4 (1. d4 *", "1. e4 {unclosed", "1. e4 (1... e5) *"]:
		var parsed: Dictionary = Pgn.parse(text)
		assert_true(parsed.error.begins_with("Game 1"), "%s gave %s" % [text, parsed.error])
		assert_eq(parsed.games, [], text)


func test_finished_game_records_resignation_reason():
	var game = Game.new()
	game.resign("w")
	var built: Dictionary = Pgn.finished_game(game, [],
			{"colour": "w", "level": "maia-1500", "control": "3+2"})
	assert_eq(built.headers.Reason, "resignation")
