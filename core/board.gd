extends RefCounted

# A chess position: piece placement plus the other five FEN fields.

const PIECES := "pnbrqkPNBRQK"

# [file, rank] steps.
const KNIGHT_STEPS := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const ROOK_STEPS := [[1, 0], [0, 1], [-1, 0], [0, -1]]
const BISHOP_STEPS := [[1, 1], [-1, 1], [-1, -1], [1, -1]]
const KING_STEPS := [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, 1], [-1, -1], [1, -1]]

# The king and rook squares each castling right depends on.
const CASTLING_SQUARES := {"K": [4, 7], "Q": [4, 0], "k": [60, 63], "q": [60, 56]}

# 1 castling, 2 piece, 3 from file, 4 from rank, 5 target square, 6 promotion piece.
static var _san_pattern := RegEx.create_from_string(
		"^(?:(O-O-O|O-O)|([NBRQK])?([a-h])?([1-8])?x?([a-h][1-8])(?:=?([NBRQ]))?)[+#!?]*$")

# Index = rank * 8 + file, a1 = 0; "" is an empty square.
var squares := PackedStringArray()
var side_to_move := "w"
var castling := "-"
var en_passant := "-"
var halfmove_clock := 0
var fullmove_number := 1


func _init() -> void:
	squares.resize(64)


# Returns null for an invalid FEN. No push_error: bad input is expected (pasted FENs, imports).
static func from_fen(fen: String):
	var fields := fen.split(" ")
	if fields.size() != 6:
		return null
	var board = new()
	var ranks := fields[0].split("/")
	if ranks.size() != 8:
		return null
	for i in 8:
		var rank := 7 - i
		var file := 0
		for c in ranks[i]:
			if c in "12345678":
				file += c.to_int()
			elif c in PIECES and file < 8:
				board.squares[rank * 8 + file] = c
				file += 1
			else:
				return null
		if file != 8:
			return null

	var side := fields[1]
	if side != "w" and side != "b":
		return null
	var ep := fields[3]
	var ep_rank := "6" if side == "w" else "3"
	if ep != "-" and not (ep.length() == 2 and ep[0] in "abcdefgh" and ep[1] == ep_rank):
		return null
	if not _valid_castling(fields[2]):
		return null
	if not fields[4].is_valid_int() or not fields[5].is_valid_int():
		return null
	if fields[4].to_int() < 0 or fields[5].to_int() < 1:
		return null

	board.side_to_move = side
	board.castling = fields[2]
	board.en_passant = ep
	board.halfmove_clock = fields[4].to_int()
	board.fullmove_number = fields[5].to_int()
	return board


# "-" or a non-empty subset of KQkq in that order, each letter at most once.
static func _valid_castling(field: String) -> bool:
	if field == "-":
		return true
	var rest := "KQkq"
	for c in field:
		var i := rest.find(c)
		if i < 0:
			return false
		rest = rest.substr(i + 1)
	return field != ""


func to_fen() -> String:
	return "%s %d %d" % [position_key(), halfmove_clock, fullmove_number]


# FEN without the move counters: what repetition and the opening book match on.
func position_key() -> String:
	var ranks := PackedStringArray()
	for rank in range(7, -1, -1):
		var row := ""
		var empty := 0
		for file in 8:
			var piece := squares[rank * 8 + file]
			if piece == "":
				empty += 1
				continue
			if empty:
				row += str(empty)
				empty = 0
			row += piece
		if empty:
			row += str(empty)
		ranks.append(row)
	return " ".join(["/".join(ranks), side_to_move, castling, en_passant])


# Square in algebraic form ("e4"); "" when empty.
func piece_at(square: String) -> String:
	return squares[(square.unicode_at(1) - 49) * 8 + square.unicode_at(0) - 97]


func copy():
	return from_fen(to_fen())


# Legal moves in UCI form: "e2e4", promotions "e7e8q", castling as the king's move "e1g1".
func legal_moves() -> PackedStringArray:
	var moves := PackedStringArray()
	var white := side_to_move == "w"
	var king := squares.find("K" if white else "k")
	for from in 64:
		var piece := squares[from]
		if piece == "" or _is_white(piece) != white:
			continue
		match piece.to_lower():
			"p":
				_add_pawn_moves(moves, from, white, king)
			"n":
				_add_piece_moves(moves, from, KNIGHT_STEPS, false, white, king)
			"b":
				_add_piece_moves(moves, from, BISHOP_STEPS, true, white, king)
			"r":
				_add_piece_moves(moves, from, ROOK_STEPS, true, white, king)
			"q":
				_add_piece_moves(moves, from, KING_STEPS, true, white, king)
			"k":
				_add_piece_moves(moves, from, KING_STEPS, false, white, king)
				_add_castling(moves, from, white)
	return moves


func in_check() -> bool:
	var white := side_to_move == "w"
	return _attacked(squares.find("K" if white else "k"), not white)


# The side ("w" or "b") cannot mate by any legal sequence, as scalachess's InsufficientMatingMaterial
# for one colour: a lone king; one knight against nothing but queens; or bishops, when the opponent
# has no knight or pawn and no two bishops on the board stand on opposite colours.
func cannot_mate(side: String) -> bool:
	var own := ""
	var theirs := ""
	var bishop_colours := {}
	for square in 64:
		var piece := squares[square].to_lower()
		if piece == "" or piece == "k":
			continue
		if piece == "b":
			bishop_colours[(square % 8 + square / 8) % 2] = true
		if _is_white(squares[square]) == (side == "w"):
			own += piece
		else:
			theirs += piece
	if own == "":
		return true
	if own == "n":
		return theirs.replace("q", "") == ""
	if own.replace("b", "") == "":
		return bishop_colours.size() < 2 and not ("n" in theirs or "p" in theirs)
	return false


# Plays a move from legal_moves(). No legality check: callers holding outside input (the UI,
# an engine) check it against legal_moves() first.
func make_move(move: String) -> void:
	var from := _index(move, 0)
	var to := _index(move, 2)
	var piece := squares[from]
	var white := side_to_move == "w"
	var pawn := piece == "P" or piece == "p"
	var capture := squares[to] != ""
	if pawn and move.substr(2, 2) == en_passant:
		squares[to - 8 if white else to + 8] = ""
		capture = true
	squares[to] = piece
	squares[from] = ""
	if move.length() == 5:
		squares[to] = move[4].to_upper() if white else move[4]
	if (piece == "K" or piece == "k") and absi(to - from) == 2:
		var rook := from + 3 if to > from else from - 4
		squares[(from + to) / 2] = squares[rook]
		squares[rook] = ""
	for right in CASTLING_SQUARES:
		if from in CASTLING_SQUARES[right] or to in CASTLING_SQUARES[right]:
			castling = castling.replace(right, "")
	if castling == "":
		castling = "-"
	halfmove_clock = 0 if pawn or capture else halfmove_clock + 1
	if not white:
		fullmove_number += 1
	side_to_move = "b" if white else "w"
	# Only when the capture is legal, as Lichess and python-chess write FEN: otherwise the position
	# key would differ from the same position reached without a double push.
	en_passant = "-"
	if pawn and absi(to - from) == 16:
		var king := squares.find("k" if white else "K")
		for taker: int in [to - 1, to + 1]:
			if taker / 8 == to / 8 and squares[taker] == ("p" if white else "P") \
					and _king_safe_after(taker, (from + to) / 2, king, not white, to):
				en_passant = _name((from + to) / 2)


# SAN of a move from legal_moves(): "Nbd2", "exd8=Q+", "O-O", "Qh4#".
func san(move: String) -> String:
	var text := _san_without_check(move, legal_moves())
	var after = copy()
	after.make_move(move)
	if after.in_check():
		text += "#" if after.legal_moves().is_empty() else "+"
	return text


# The legal move a SAN names, in UCI form; "" when it is illegal, ambiguous or not SAN.
# Trailing + # ! ? are ignored; extra disambiguation and a missing "x" are tolerated.
func parse_san(text: String) -> String:
	var found := _san_pattern.search(text)
	if found == null:
		return ""
	var moves := legal_moves()
	if found.get_string(1) != "":
		var home := "e1" if side_to_move == "w" else "e8"
		var castle := home + ("g" if found.get_string(1) == "O-O" else "c") + home[1]
		# A rook on e1 can also play e1g1.
		return castle if castle in moves and squares[_index(castle, 0)].to_upper() == "K" else ""
	var piece := found.get_string(2) if found.get_string(2) != "" else "P"
	var from_file := found.get_string(3)
	var from_rank := found.get_string(4)
	var to := found.get_string(5)
	var promotion := found.get_string(6).to_lower()
	var named := ""
	for move in moves:
		if squares[_index(move, 0)].to_upper() != piece or move.substr(2, 2) != to \
				or move.substr(4) != promotion or (from_file != "" and move[0] != from_file) \
				or (from_rank != "" and move[1] != from_rank):
			continue
		if named != "":
			return ""
		named = move
	return named


func _san_without_check(move: String, moves: PackedStringArray) -> String:
	var from := _index(move, 0)
	var to := move.substr(2, 2)
	var piece := squares[from].to_upper()
	if piece == "K" and absi(_index(move, 2) - from) == 2:
		return "O-O" if move[2] == "g" else "O-O-O"
	var capture := "x" if squares[_index(move, 2)] != "" or (piece == "P" and move[0] != move[2]) else ""
	if piece == "P":
		var promotion := "=" + move[4].to_upper() if move.length() == 5 else ""
		return (move[0] + capture if capture else "") + to + promotion
	# Other pieces of the same kind that can legally reach the same square.
	var same_file := false
	var same_rank := false
	var rivals := false
	for other in moves:
		if other.substr(2, 2) == to and other[0] + other[1] != move[0] + move[1] \
				and squares[_index(other, 0)] == squares[from]:
			rivals = true
			same_file = same_file or other[0] == move[0]
			same_rank = same_rank or other[1] == move[1]
	var from_hint := ""
	if rivals:
		if not same_file:
			from_hint = move[0]
		elif not same_rank:
			from_hint = move[1]
		else:
			from_hint = move.substr(0, 2)
	return piece + from_hint + capture + to


func _add_pawn_moves(moves: PackedStringArray, from: int, white: bool, king: int) -> void:
	var step := 8 if white else -8
	var to := from + step
	if to < 0 or to > 63:
		return
	var promotes := to / 8 == (7 if white else 0)
	if squares[to] == "":
		_add(moves, from, to, white, king, promotes)
		if from / 8 == (1 if white else 6) and squares[to + step] == "":
			_add(moves, from, to + step, white, king, false)
	var ep := _index(en_passant, 0) if en_passant != "-" else -1
	for side: int in [-1, 1]:
		if from % 8 + side < 0 or from % 8 + side > 7:
			continue
		var target := squares[to + side]
		if target != "" and _is_white(target) != white:
			_add(moves, from, to + side, white, king, promotes)
		elif target == "" and to + side == ep:
			_add(moves, from, to + side, white, king, false, to + side - step)


# One step along each direction, or sliding until blocked.
func _add_piece_moves(moves: PackedStringArray, from: int, steps: Array, slides: bool, white: bool, king: int) -> void:
	for step in steps:
		var file: int = from % 8 + step[0]
		var rank: int = from / 8 + step[1]
		while file >= 0 and file < 8 and rank >= 0 and rank < 8:
			var target := squares[rank * 8 + file]
			if target != "" and _is_white(target) == white:
				break
			_add(moves, from, rank * 8 + file, white, king, false)
			if target != "" or not slides:
				break
			file += step[0]
			rank += step[1]


# Not out of, through or into check; _add checks the landing square.
func _add_castling(moves: PackedStringArray, king: int, white: bool) -> void:
	var home := 4 if white else 60
	if king != home or _attacked(home, not white):
		return
	var rook := "R" if white else "r"
	if castling.contains("K" if white else "k") and squares[home + 1] == "" and squares[home + 2] == "" \
			and squares[home + 3] == rook and not _attacked(home + 1, not white):
		_add(moves, home, home + 2, white, king, false)
	if castling.contains("Q" if white else "q") and squares[home - 1] == "" and squares[home - 2] == "" \
			and squares[home - 3] == "" and squares[home - 4] == rook and not _attacked(home - 1, not white):
		_add(moves, home, home - 2, white, king, false)


# Appends from-to (as all four promotions when it promotes) unless it leaves the mover's king
# attacked. victim is the square of a pawn taken en passant.
func _add(moves: PackedStringArray, from: int, to: int, white: bool, king: int, promotes: bool, victim := -1) -> void:
	if not _king_safe_after(from, to, king, white, victim):
		return
	var uci := _name(from) + _name(to)
	if promotes:
		for piece in "qrbn":
			moves.append(uci + piece)
	else:
		moves.append(uci)


func _king_safe_after(from: int, to: int, king: int, white: bool, victim := -1) -> bool:
	var moved := squares[from]
	var taken := squares[to]
	var victim_piece := ""
	if victim >= 0:
		victim_piece = squares[victim]
		squares[victim] = ""
	squares[to] = moved
	squares[from] = ""
	var safe := not _attacked(to if from == king else king, not white)
	squares[from] = moved
	squares[to] = taken
	if victim >= 0:
		squares[victim] = victim_piece
	return safe


# Pins do not matter here: a pinned piece still attacks.
func _attacked(square: int, by_white: bool) -> bool:
	if square < 0:
		return false  # a side without a king, which from_fen accepts
	var file := square % 8
	var rank := square / 8
	var pawn := "P" if by_white else "p"
	var pawn_rank := rank - 1 if by_white else rank + 1
	if _at(file - 1, pawn_rank) == pawn or _at(file + 1, pawn_rank) == pawn:
		return true
	var knight := "N" if by_white else "n"
	for step in KNIGHT_STEPS:
		if _at(file + step[0], rank + step[1]) == knight:
			return true
	var king := "K" if by_white else "k"
	for step in KING_STEPS:
		if _at(file + step[0], rank + step[1]) == king:
			return true
	var queen := "Q" if by_white else "q"
	var rook := "R" if by_white else "r"
	for step in ROOK_STEPS:
		var piece := _first(file, rank, step)
		if piece == rook or piece == queen:
			return true
	var bishop := "B" if by_white else "b"
	for step in BISHOP_STEPS:
		var piece := _first(file, rank, step)
		if piece == bishop or piece == queen:
			return true
	return false


# "" off the board.
func _at(file: int, rank: int) -> String:
	return squares[rank * 8 + file] if file >= 0 and file < 8 and rank >= 0 and rank < 8 else ""


# The first piece along a line, "" when the line leaves the board first.
func _first(file: int, rank: int, step: Array) -> String:
	file += step[0]
	rank += step[1]
	while file >= 0 and file < 8 and rank >= 0 and rank < 8:
		if squares[rank * 8 + file] != "":
			return squares[rank * 8 + file]
		file += step[0]
		rank += step[1]
	return ""


static func _is_white(piece: String) -> bool:
	return piece.unicode_at(0) < 97


# Square index of the two characters at `at` ("e2e4", 2 -> e4).
static func _index(text: String, at: int) -> int:
	return (text.unicode_at(at + 1) - 49) * 8 + text.unicode_at(at) - 97


static func _name(square: int) -> String:
	return "abcdefgh"[square % 8] + str(square / 8 + 1)
