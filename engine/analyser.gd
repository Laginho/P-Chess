extends Node

const Tunables = preload("res://core/tunables.gd")
const Board = preload("res://core/board.gd")
const Pgn = preload("res://core/pgn.gd")

signal progress(done: int, total: int)
signal position_ready(index: int, position: Dictionary)
signal finished(success: bool, error: String)

var _bridge
var _fens := []
var _positions := []
var _path := ""
var _index := -1
var _cancelled := false
var _active := false
var _stop_sent := false
var _lines := {}
var _depths := {}
var _completed := {}
var _setup := PackedStringArray()
var _waiting_for_engine := false
var _draw_at_end := false
var _search_active := false


func _init(bridge = null) -> void:
	_bridge = bridge


func analyse(fens: Array, path: String, maximum: bool, draw_at_end := false) -> bool:
	if _active or _bridge == null or fens.is_empty():
		return false
	for fen in fens:
		if not _valid_position(fen):
			return false
	_fens = fens.duplicate()
	_positions.resize(fens.size())
	_path = path
	_draw_at_end = draw_at_end
	_index = fens.size() - 1
	_cancelled = false
	_active = true
	var threads := maxi(1, OS.get_processor_count() - 1) if maximum else 1
	_setup = PackedStringArray(["setoption name Threads value %d" % threads,
			"setoption name MultiPV value 2"])
	_bridge.new_game()
	_waiting_for_engine = _bridge.engine_id.is_empty()
	if not _waiting_for_engine:
		_next()
	return true


func _process(_delta: float) -> void:
	if _waiting_for_engine and (_cancelled or not _bridge.engine_id.is_empty()):
		_waiting_for_engine = false
		_next()


func cancel() -> void:
	if _active and not _cancelled:
		_cancelled = true
		if not _stop_sent and _search_active:
			_stop_sent = true
			_bridge.stop_search()


static func read_analysis(path: String, version: String, budget: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": "not analysed"}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("engine_version", "") != version or data.get("node_budget", 0) != budget:
		return {"state": "stale"}
	return {"state": "analysed", "data": data}


static func positions_from_game(game: Dictionary) -> Array:
	var board = Board.from_fen(game.get("headers", {}).get("FEN", Pgn.START))
	if board == null:
		return []
	var positions := [board.to_fen()]
	for move: Dictionary in game.get("moves", []):
		var uci: String = move.get("uci", "")
		if not uci in board.legal_moves():
			return []
		board.make_move(uci)
		positions.append(board.to_fen())
	return positions


static func _valid_position(fen: String) -> bool:
	var board = Board.from_fen(fen)
	if board == null or board.squares.count("K") != 1 or board.squares.count("k") != 1:
		return false
	for i in range(8):
		if board.squares[i].to_lower() == "p" or board.squares[i + 56].to_lower() == "p":
			return false
	# Stockfish exits on these: per side more than 8 pawns, or more promoted pieces than missing pawns.
	for pieces in ["PNBRQ", "pnbrq"]:
		var pawns: int = board.squares.count(pieces[0])
		var extra := maxi(board.squares.count(pieces[1]) - 2, 0) + maxi(board.squares.count(pieces[2]) - 2, 0) 				+ maxi(board.squares.count(pieces[3]) - 2, 0) + maxi(board.squares.count(pieces[4]) - 1, 0)
		if pawns > 8 or extra > 8 - pawns:
			return false
	if board.halfmove_clock > 32767 or board.fullmove_number > 100000:
		return false
	var other = board.copy()
	other.side_to_move = "b" if board.side_to_move == "w" else "w"
	if other.in_check():
		return false
	for right: String in board.castling:
		if right == "-":
			continue
		var white := right == right.to_upper()
		var king := "e1" if white else "e8"
		var rook := ("h" if right.to_lower() == "k" else "a") + ("1" if white else "8")
		if board.piece_at(king) != ("K" if white else "k") or board.piece_at(rook) != ("R" if white else "r"):
			return false
	return true


func _next() -> void:
	if _cancelled:
		_active = false
		finished.emit(false, "cancelled")
		return
	if _index < 0:
		_write_result()
		return
	var board = Board.from_fen(_fens[_index])
	var legal: PackedStringArray = board.legal_moves()
	if (_draw_at_end and _index == _fens.size() - 1) or legal.is_empty() or board.halfmove_clock >= 100 or (board.cannot_mate("w") and board.cannot_mate("b")):
		# Terminal scores use the side to move, just like UCI scores.
		_positions[_index] = {"fen": _fens[_index], "pv": [], "best_move": "",
				"terminal_score": -1000 if legal.is_empty() and board.in_check() else 0}
		_advance()
		return
	_lines = {}
	_depths = {}
	_completed = {}
	_stop_sent = false
	var commands := _setup
	_setup = PackedStringArray()
	commands.append("position fen " + _fens[_index])
	commands.append("go nodes %d" % Tunables.ANALYSIS_NODES)
	_search_active = true
	_bridge.request_search(commands, _on_line)


func _on_line(line: String) -> void:
	if not _active:
		return
	if line.begins_with("bestmove"):
		_search_active = false
		if _cancelled:
			_next()
			return
		var pv := []
		for number in [1, 2]:
			if _lines.has(number):
				pv.append(_lines[number])
		var legal: PackedStringArray = Board.from_fen(_fens[_index]).legal_moves()
		if legal.size() == 1 and pv.size() > 1:
			pv.resize(1)
		_positions[_index] = {"fen": _fens[_index], "pv": pv,
				"best_move": line.split(" ", false)[1]}
		_advance()
	elif not _cancelled and line.begins_with("info "):
		var parsed := _parse_info(line)
		if parsed.is_empty():
			return
		var number: int = parsed.multipv
		parsed.erase("multipv")
		if not _lines.has(number) or parsed.depth >= _lines[number].depth:
			_lines[number] = parsed
		if number == 1:
			_depths[parsed.depth] = {"depth": parsed.depth, "move": parsed.moves[0]}
			if parsed.has("cp"):
				_depths[parsed.depth].cp = parsed.cp
			else:
				_depths[parsed.depth].mate = parsed.mate
		var completed: bool = number == 2 or Board.from_fen(_fens[_index]).legal_moves().size() == 1
		if completed and _depths.has(parsed.depth):
			_completed[parsed.depth] = _depths[parsed.depth]
			var depths := _completed.keys()
			depths.sort()
			var samples := []
			for depth in depths:
				samples.append(_completed[depth])
			if not _stop_sent and converged(samples):
				_stop_sent = true
				_bridge.stop_search()


static func _parse_info(line: String) -> Dictionary:
	var words := line.split(" ", false)
	var d := words.find("depth")
	var m := words.find("multipv")
	var s := words.find("score")
	var p := words.find("pv")
	if d < 0 or d + 1 >= words.size() or s < 0 or s + 2 >= words.size() or p < 0 or p + 1 >= words.size():
		return {}
	if not words[d + 1].is_valid_int() or not words[s + 2].is_valid_int() or not words[s + 1] in ["cp", "mate"]:
		return {}
	if s + 3 < words.size() and words[s + 3] in ["lowerbound", "upperbound"]:
		return {}
	var number := words[m + 1].to_int() if m >= 0 and m + 1 < words.size() else 1
	if number < 1 or number > 2:
		return {}
	var result := {"depth": words[d + 1].to_int(), "multipv": number, "moves": Array(words.slice(p + 1))}
	result[words[s + 1]] = words[s + 2].to_int()
	return result


func _advance() -> void:
	position_ready.emit(_index, _positions[_index].duplicate(true))
	_index -= 1
	progress.emit(_fens.size() - _index - 1, _fens.size())
	_next()


func _write_result() -> void:
	var folder := _path.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(folder)
	var temporary := _path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE) if error == OK else null
	if file == null:
		_active = false
		finished.emit(false, "Could not write analysis")
		return
	file.store_string(JSON.stringify({"engine_version": _bridge.engine_id,
			"node_budget": Tunables.ANALYSIS_NODES, "positions": _positions}))
	file.close()
	error = DirAccess.rename_absolute(temporary, _path)
	_active = false
	finished.emit(error == OK, "" if error == OK else "Could not replace analysis")


# Samples are completed PV1 depths, in ascending order, from the mover's side.
static func converged(samples: Array) -> bool:
	if samples.size() < Tunables.ANALYSIS_STABLE_DEPTHS:
		return false
	var recent := samples.slice(-Tunables.ANALYSIS_STABLE_DEPTHS)
	if recent.back().depth < Tunables.ANALYSIS_MIN_DEPTH:
		return false
	var first: Dictionary = recent[0]
	var low := 1.0
	var high := 0.0
	var previous := -1
	for sample: Dictionary in recent:
		if sample.move != first.move or sample.depth <= previous:
			return false
		previous = sample.depth
		var cp: int = clampi(sample.get("cp", 1000 if sample.get("mate", 0) > 0 else -1000), -1000, 1000)
		var ep := 1.0 / (1.0 + exp(-0.00368208 * cp))
		low = minf(low, ep)
		high = maxf(high, ep)
	return high - low < Tunables.ANALYSIS_EP_CHANGE
