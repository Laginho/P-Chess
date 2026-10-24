extends RefCounted

# A chess position: piece placement plus the other five FEN fields.

const PIECES := "pnbrqkPNBRQK"

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
