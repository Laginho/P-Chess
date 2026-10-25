extends RefCounted

# Catalog lines keep every position (including the start and final position), with one UCI
# move between adjacent keys. OPEN-002 can match transpositions without parsing SAN again.
const Board = preload("res://core/board.gd")
const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const VOLUMES := ["a", "b", "c", "d", "e"]

var entries: Array = []
var errors: Array[String] = []
var volume_counts := {}
var roots: Array[String] = []
# A node groups all rows under its name, including a row named after the family itself.
var nodes := {}
var _checked := {}
var _prefixes := {}
var _numbers := RegEx.create_from_string(r"\d+\.+\s*")


func load_catalog(folder := "res://data/openings") -> void:
	entries.clear()
	errors.clear()
	volume_counts.clear()
	roots.clear()
	nodes.clear()
	_checked.clear()
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
		_add_name(entries.back())


func _add_name(entry: Dictionary) -> void:
	var labels: PackedStringArray = entry.name.replace(": ", ", ").split(", ", false)
	var parent := ""
	for index in labels.size():
		var path: String = labels[index] if index == 0 else parent + (": " if index == 1 else ", ") + labels[index]
		if not nodes.has(path):
			nodes[path] = {"label": labels[index], "parent": parent, "children": [], "lines": []}
			if parent.is_empty():
				roots.append(path)
			else:
				nodes[parent].children.append(path)
		nodes[path].lines.append(entry.id)
		parent = path


# Return visible paths in tree order. Full paths include ancestor labels, so searching a
# family keeps its descendants, while a variation match brings its ancestors back into view.
func search(query: String) -> Array[String]:
	var visible := {}
	for path in nodes:
		if not query.is_empty() and not query.to_lower() in path.to_lower():
			continue
		var ancestor: String = path
		while not ancestor.is_empty():
			visible[ancestor] = true
			ancestor = nodes[ancestor].parent
	var result: Array[String] = []
	for path in nodes:
		if visible.has(path):
			result.append(path)
	return result


func set_checked(path: String, checked: bool) -> void:
	if not nodes.has(path):
		return
	for id in nodes[path].lines:
		if checked:
			_checked[id] = true
		else:
			_checked.erase(id)


# 0 unchecked, 1 checked, 2 partial (including the node's own line, if present).
func check_state(path: String) -> int:
	var count := 0
	for id in nodes[path].lines:
		if _checked.has(id):
			count += 1
	if count == 0:
		return 0
	return 1 if count == nodes[path].lines.size() else 2


func selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		if _checked.has(entry.id):
			ids.append(entry.id)
	return ids
