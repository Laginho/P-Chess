extends RefCounted

# Catalog lines keep every position (including the start and final position), with one UCI
# move between adjacent keys. OPEN-002 can match transpositions without parsing SAN again.
const Board = preload("res://core/board.gd")
const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const VOLUMES := ["a", "b", "c", "d", "e"]

var entries: Array = []
var errors: Array[String] = []
var volume_counts := {}
var _prefixes := {}
var _numbers := RegEx.create_from_string(r"\d+\.+\s*")


func load_catalog(folder := "res://data/openings") -> void:
	entries.clear()
	errors.clear()
	volume_counts.clear()
	_prefixes.clear()
	for volume in VOLUMES:
		var path: String = folder.path_join(volume + ".tsv")
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			errors.append("Cannot read " + path)
			continue
		var before := entries.size()
		load_tsv(file.get_as_text(), path)
		volume_counts[volume] = entries.size() - before
	# The parsed lines are all the book needs; don't retain the temporary boards.
	_prefixes.clear()


# Also accepts small TSVs for import diagnostics; a bad row never discards valid neighbours.
func load_tsv(text: String, source := "TSV") -> void:
	if _prefixes.is_empty():
		var start = Board.from_fen(START)
		_prefixes[""] = {"board": start, "key": start.position_key(), "move": ""}
	var rows := text.split("\n")
	if rows.is_empty() or rows[0].strip_edges() != "eco\tname\tpgn":
		errors.append(source + ":1: expected eco, name and pgn columns")
		return
	for index in range(1, rows.size()):
		if rows[index].strip_edges().is_empty():
			continue
		var where := "%s:%d" % [source, index + 1]
		var fields := rows[index].strip_edges().split("\t")
		if fields.size() != 3 or fields[1].is_empty() or fields[2].is_empty():
			errors.append(where + ": expected three nonempty columns")
			continue
		var moves := PackedStringArray()
		var positions := PackedStringArray([_prefixes[""].key])
		var prefix := ""
		var valid := true
		for san in _numbers.sub(fields[2], "", true).split(" ", false):
			var next := prefix + " " + san
			if not _prefixes.has(next):
				var board = _prefixes[prefix].board.copy()
				var uci: String = board.parse_san(san)
				if uci.is_empty():
					errors.append(where + ": illegal SAN " + san)
					valid = false
					break
				board.make_move(uci)
				_prefixes[next] = {"board": board, "key": board.position_key(), "move": uci}
			moves.append(_prefixes[next].move)
			positions.append(_prefixes[next].key)
			prefix = next
		if not valid or moves.is_empty():
			continue
		entries.append({"id": fields[0] + ":" + fields[2], "eco": fields[0],
				"name": fields[1], "pgn": fields[2], "moves": moves, "positions": positions})
