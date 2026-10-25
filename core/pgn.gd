extends RefCounted

# PGN in and out: saved games with %clk (§9.4) and imported repertoires with variations (§6.4).
# A game is {headers: {tag: value}, moves: [move], result, comment (before the first move)}.
# A move is {san, uci, comment, comment_before, nags: [int], clock_ms (-1 without %clk),
# variations: [[move]]}, each variation an alternative to the move that holds it. comment_before
# is the comment that opens a variation, kept on its first move; "" everywhere else.

const Board = preload("res://core/board.gd")
const Clock = preload("res://core/clock.gd")

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
# Move suffixes as the NAGs they stand for (PGN standard §10).
const SUFFIX_NAGS := {"!": 1, "?": 2, "!!": 3, "??": 4, "!?": 5, "?!": 6}

# 1-2 tag pair, 3 {comment}, 4 ;comment, 5 NAG, 6 result, then a move number (no group),
# 7 parenthesis, 8 move, 9 anything else.
static var _token := RegEx.create_from_string(
		r'\[\s*(\w+)\s+"((?:[^"\\]|\\.)*)"\s*\]|\{([^}]*)\}|;([^\n]*)|\$(\d+)'
		+ r'|(1-0|0-1|1/2-1/2|\*)|\d+\.*|([()])|([^\s(){}\[\];$]+)|(\S)')
static var _suffix := RegEx.create_from_string(r"^(.*?)([!?]*)$")
# PGN escapes only \\ and \" in a tag value.
static var _escape := RegEx.create_from_string(r"\\(.)")
static var _clock := RegEx.create_from_string(r"\[%clk\s+(\d+):(\d+):(\d+)(?:\.(\d+))?\]")


# Every game of a PGN text: {games, error}. On the first error, games is empty and error names
# the game (1-based) and, for an illegal move, its move number.
static func parse(text: String) -> Dictionary:
	var games := []
	var game = null
	# Position after the current line's last move, and before it; board is null before the movetext.
	var board = null
	var before = null
	var line := []
	# [line, board, before] of each enclosing line.
	var stack := []
	# A comment opening a variation, waiting for its first move.
	var pending := ""
	for found in _token.search_all(text):
		var where := "Game %d" % (games.size() + 1)
		# A tag after movetext starts the next game, even when this one had no result.
		if game != null and board != null and found.get_start(1) != -1:
			if stack:
				return _error(where + ": unclosed variation")
			games.append(game)
			game = null
			where = "Game %d" % (games.size() + 1)
		if game == null:
			game = {"headers": {}, "moves": [], "result": "*", "comment": ""}
			board = null
			line = game.moves
		if found.get_start(1) != -1:
			game.headers[found.get_string(1)] = _escape.sub(found.get_string(2), "$1", true)
			continue
		if board == null:
			board = Board.from_fen(game.headers.get("FEN", START))
			if board == null:
				return _error(where + ": invalid FEN")
		if found.get_start(3) != -1 or found.get_start(4) != -1:
			var comment := (found.get_string(3) + found.get_string(4)).strip_edges()
			var holder = line.back() if line else (game if stack.is_empty() else null)
			if holder != null:
				holder.comment = (holder.comment + " " + comment).strip_edges()
			else:
				pending = (pending + " " + comment).strip_edges()
			if line and _clock_ms(comment) != -1:
				line.back().clock_ms = _clock_ms(comment)
		elif found.get_start(5) != -1:
			if line:
				line.back().nags.append(found.get_string(5).to_int())
		elif found.get_start(6) != -1:
			if stack:
				return _error(where + ": result inside a variation")
			game.result = found.get_string(6)
			games.append(game)
			game = null
		elif found.get_string(7) == "(":
			if line.is_empty():
				return _error(where + ": variation before any move")
			stack.append([line, board, before])
			var variation := []
			line.back().variations.append(variation)
			line = variation
			board = before.copy()
			before = null
		elif found.get_string(7) == ")":
			if stack.is_empty():
				return _error(where + ": ) without (")
			var outer: Array = stack.pop_back()
			line = outer[0]
			board = outer[1]
			before = outer[2]
			pending = ""
		elif found.get_start(8) != -1:
			var token := found.get_string(8)
			var parts := _suffix.search(token)
			var uci: String = board.parse_san(parts.get_string(1))
			if uci == "":
				return _error("%s, move %d%s: illegal move %s"
						% [where, board.fullmove_number, "." if board.side_to_move == "w" else "...", token])
			var move := {"san": parts.get_string(1), "uci": uci, "comment": "", "comment_before": pending, "nags": [],
					"clock_ms": -1, "variations": []}
			pending = ""
			if SUFFIX_NAGS.has(parts.get_string(2)):
				move.nags.append(SUFFIX_NAGS[parts.get_string(2)])
			line.append(move)
			before = board.copy()
			board.make_move(uci)
		elif found.get_start(9) != -1:
			return _error("%s: unexpected %s" % [where, found.get_string(9)])
	if stack:
		return _error("Game %d: unclosed variation" % (games.size() + 1))
	if game != null:
		games.append(game)
	return {"games": games, "error": ""}


# PGN text for one game {headers, moves: [{uci, clock_ms}], result}: headers, then each move
# with its clock, then the result. Clocks are written to the millisecond, trailing zeros dropped.
# shortcut: comments, NAGs and variations are not written; add them when a caller exports a tree.
static func write(game: Dictionary) -> String:
	var text := ""
	for tag in game.headers:
		text += '[%s "%s"]\n' % [tag, game.headers[tag].replace("\\", "\\\\").replace('"', '\\"')]
	var board = Board.from_fen(game.headers.get("FEN", START))
	var tokens := PackedStringArray()
	# Black's move takes its own number after a comment, as Lichess writes it.
	var black_numbered := true
	for move in game.moves:
		if board.side_to_move == "w":
			tokens.append("%d." % board.fullmove_number)
		elif black_numbered:
			tokens.append("%d..." % board.fullmove_number)
		tokens.append(board.san(move.uci))
		board.make_move(move.uci)
		var clock: int = move.get("clock_ms", -1)
		black_numbered = clock != -1
		if clock != -1:
			tokens.append("{ [%%clk %s] }" % _clock_text(clock))
	tokens.append(game.get("result", "*"))
	return text + "\n" + " ".join(tokens) + "\n"


# The game write() takes for a finished game against Maia: player names, time control, result,
# termination and one clock per move, then the Opening header when one is named.
static func finished_game(game, clocks: Array, settings: Dictionary, opening_name := "") -> Dictionary:
	var maia_name: String = "Maia " + settings.level.trim_prefix("maia-")
	var control: Array = Clock.CONTROLS[settings.control]
	var headers := {
		"White": "You" if settings.colour == "w" else maia_name,
		"Black": maia_name if settings.colour == "w" else "You",
		"TimeControl": "%d+%d" % [control[0] / 1000, control[1] / 1000],
		"Result": game.result,
		"Termination": "Time forfeit" if game.reason == "time" else "Normal",
	}
	if opening_name:
		headers.Opening = opening_name
	var moves := []
	for i in game.moves.size():
		moves.append({"uci": game.moves[i], "clock_ms": clocks[i]})
	return {"headers": headers, "moves": moves, "result": game.result}


static func _error(message: String) -> Dictionary:
	return {"games": [], "error": message}


# The %clk of a comment in milliseconds, or -1.
static func _clock_ms(comment: String) -> int:
	var found := _clock.search(comment)
	if found == null:
		return -1
	var seconds := (found.get_string(1).to_int() * 60 + found.get_string(2).to_int()) * 60 \
			+ found.get_string(3).to_int()
	return seconds * 1000 + (found.get_string(4) + "00").left(3).to_int()


static func _clock_text(ms: int) -> String:
	var text := "%d:%02d:%02d" % [ms / 3600000, ms / 60000 % 60, ms / 1000 % 60]
	return text + ((".%03d" % (ms % 1000)).rstrip("0") if ms % 1000 else "")
