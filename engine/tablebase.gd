extends Node

# One serialized, asynchronous probe for grading, play-outs and review (§L5).
# The bridge owns the pipe readers; all parsing and callbacks run on the main thread.
const UCI = preload("res://engine/uci.gd")
const Board = preload("res://core/board.gd")
const MATERIALS := ["KBvK", "KNvK", "KPvK", "KQRvK", "KQRvKR", "KQvK", "KQvKR",
		"KRBvK", "KRBvKR", "KRNvK", "KRNvKR", "KRPvK", "KRPvKR", "KRRvK", "KRRvKR",
		"KRvK", "KRvKB", "KRvKN", "KRvKP", "KRvKR"]
const RANKS := ["loss", "blessed-loss", "draw", "cursed-win", "win"]
const MISSING := "Tablebase probe is missing (engine/tbprobe/tbprobe.exe). Run scripts/build-tbprobe.ps1 to build it."

var available := false
var error := ""
var _bridge
var _owns_bridge := false
var _pending := []
var _active := {}
var _moves := {}
var _ranks := {}


func _init(bridge = null) -> void:
	_bridge = bridge
	_owns_bridge = bridge == null


func _process(_delta: float) -> void:
	poll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop()
		if _owns_bridge and is_instance_valid(_bridge):
			_bridge.free()


func start(dirs := UCI.search_dirs()) -> bool:
	if available:
		return true
	if not error.is_empty():
		return false
	var binary := "engine/tbprobe/tbprobe.exe" if OS.get_name() == "Windows" else "engine/tbprobe/tbprobe"
	var path := UCI.engine_path(dirs, binary)
	if path.is_empty():
		error = MISSING
		return false
	for material in MATERIALS:
		for suffix in [".rtbw", ".rtbz"]:
			var table := path.get_base_dir().path_join("../tablebase/" + material + suffix)
			if not FileAccess.file_exists(table):
				error = "Tablebase file is missing (%s). Run scripts/fetch-engine.ps1 to download it." % table
				return false
	if _bridge == null:
		_bridge = UCI.new(binary, "Tablebase probe")
	_bridge.stopped.connect(_on_stopped)
	if not _bridge.start(dirs):
		error = _bridge.error
		return false
	available = true
	# Reuse the bridge's existing command queue and readyok barrier, unchanged.
	_bridge._queue(["setoption name SyzygyPath value ../tablebase", "isready"], "readyok")
	return true


func poll() -> void:
	if available:
		_bridge.poll()


func probe(fen: String, callback: Callable) -> void:
	if not available:
		callback.call({"ok": false, "error": error if error else "Tablebase probe is unavailable."})
		return
	var board = Board.from_fen(fen)
	if board == null or board.squares.count("K") != 1 or board.squares.count("k") != 1:
		callback.call({"ok": false, "error": "Invalid tablebase FEN."})
		return
	if board.castling != "-":
		callback.call({"ok": false, "error": "Tablebase positions cannot have castling rights."})
		return
	var legal := Array(board.legal_moves())
	if legal.is_empty():
		callback.call({"ok": true, "result": "loss" if board.in_check() else "draw",
				"dtz": 0, "best": "", "moves": {}})
		return
	_pending.append({"fen": fen, "legal": legal, "callback": callback})
	_next()


func _next() -> void:
	if not available or not _active.is_empty() or _pending.is_empty():
		return
	_active = _pending.pop_front()
	_moves = {}
	_ranks = {}
	_bridge.request_search(PackedStringArray(["position fen " + _active.fen, "go"]), _on_line)


func _on_line(line: String) -> void:
	if _active.is_empty():
		return
	if line.begins_with("info string tbmove "):
		var pattern := RegEx.create_from_string("^info string tbmove ([a-h][1-8][a-h][1-8][qrbn]?) (win|cursed-win|draw|blessed-loss|loss) ([0-9]{1,4})$")
		var found := pattern.search(line)
		if found == null:
			stop("Invalid tablebase line: " + line)
			return
		var move := found.get_string(1)
		var wdl := found.get_string(2)
		var dtz := found.get_string(3).to_int()
		if not move in _active.legal or _moves.has(move) or (wdl == "draw" and dtz != 0):
			stop("Invalid tablebase move: " + line)
			return
		_moves[move] = {"result": _result(wdl), "dtz": dtz}
		_ranks[move] = RANKS.find(wdl)
	elif line.begins_with("bestmove"):
		var words := line.split(" ")
		if words.size() != 2 or not words[1] in _active.legal or _moves.size() != _active.legal.size():
			stop("Tablebase move set differs from Board.legal_moves(): " + line)
			return
		var ordered := _moves.keys()
		ordered.sort_custom(_better)
		var best: String = ordered[0]
		_finish({"ok": true, "result": _moves[best].result, "dtz": _moves[best].dtz,
				"best": best, "moves": _moves})
	else:
		stop("Tablebase probe failed: " + line)


static func _result(wdl: String) -> String:
	return "draw" if wdl in ["cursed-win", "blessed-loss"] else wdl


func _better(a: String, b: String) -> bool:
	if _ranks[a] != _ranks[b]:
		return _ranks[a] > _ranks[b]
	if _moves[a].dtz != _moves[b].dtz:
		if _ranks[a] > 2:
			return _moves[a].dtz < _moves[b].dtz
		if _ranks[a] < 2:
			return _moves[a].dtz > _moves[b].dtz
	return a < b


func _finish(answer: Dictionary) -> void:
	var callback: Callable = _active.callback
	_active = {}
	callback.call(answer)
	_next()


func _on_stopped() -> void:
	stop(_bridge.error)


func stop(message := "Tablebase probe stopped.") -> void:
	available = false
	error = message
	if is_instance_valid(_bridge):
		_bridge.stop()
	var waiting := _pending.duplicate()
	_pending.clear()
	if not _active.is_empty():
		waiting.push_front(_active)
	_active = {}
	for request in waiting:
		request.callback.call({"ok": false, "error": error})
