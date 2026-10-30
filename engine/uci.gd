extends Node

# Runs a UCI engine (Lc0) as a child process and returns Maia's policy, §3.2. Generic UCI, so a
# second engine can be added without touching the game code. The engine's output is read on worker
# threads; poll(), called every frame, handles it on the main thread, which never waits on it.

signal policy_ready(policy: Dictionary)
signal stopped

const Board = preload("res://core/board.gd")
const ENGINE := "engine/lc0/lc0.exe"
# One VerboseMoveStats line per root move: "info string e2e4  (322 ) N: ... (P: 12.34%) ...".
const MOVE_LINE := "^info string ([a-h][1-8][a-h][1-8][qrbn]?) .*\\(P: *([0-9.]+)%\\)"

var available := false
var error := ""
var pid := -1

var _stdio: FileAccess
var _readers: Array[Thread] = []
var _mutex := Mutex.new()
var _lines := []
# Each step: [command lines, reply to wait for ("" for none), policy board, search callback].
var _steps := []
var _awaiting := ""
var _board
var _info := PackedStringArray()
var _callback := Callable()
var _engine_path: String
var _engine_name: String


func _init(engine_path := ENGINE, engine_name := "Lc0") -> void:
	_engine_path = engine_path
	_engine_name = engine_name


func _process(_delta: float) -> void:
	poll()


func _notification(what: int) -> void:
	# Freed with the scene tree when the app exits, so Lc0 stops with it.
	if what == NOTIFICATION_PREDELETE:
		stop()


# Next to the executable; also the project root when run from the editor, §3.1.
static func search_dirs() -> PackedStringArray:
	var dirs := PackedStringArray([OS.get_executable_path().get_base_dir()])
	if OS.has_feature("editor"):
		dirs.append(ProjectSettings.globalize_path("res://"))
	return dirs


# The first engine path under dirs that exists, or ""; defaults to engine/lc0/lc0.exe.
static func engine_path(dirs: PackedStringArray, engine := ENGINE) -> String:
	for dir in dirs:
		var path := dir.path_join(engine)
		if FileAccess.file_exists(path):
			return path
	return ""


# Maia's policy from the info-string lines of one search: legal move -> probability (0-1).
# board is the searched position; moves it does not allow are dropped.
static func parse_policy(lines: PackedStringArray, board) -> Dictionary:
	var pattern := RegEx.create_from_string(MOVE_LINE)
	var legal: PackedStringArray = board.legal_moves()
	var white: bool = board.side_to_move == "w"
	var policy := {}
	for line in lines:
		var found := pattern.search(line)
		if found == null:
			continue
		var move := found.get_string(1)
		# Lc0 may write castling as king takes rook (e1h1); Board writes the king's move (e1g1).
		if board.piece_at(move.substr(0, 2)) == ("K" if white else "k") \
				and board.piece_at(move.substr(2, 2)) == ("R" if white else "r"):
			move = move.substr(0, 2) + ("g" if move[2] > move[0] else "c") + move[3]
		if move in legal:
			policy[move] = found.get_string(2).to_float() / 100.0
	return policy


func start(dirs := search_dirs()) -> bool:
	if available:
		return true
	var path := engine_path(dirs, _engine_path)
	if path == "":
		error = "%s is missing (%s). Run scripts/fetch-engine.ps1 to download it." % [_engine_name, _engine_path]
		return false
	var pipe := OS.execute_with_pipe(path, [])
	if pipe.is_empty():
		error = "Could not start " + path
		return false
	_stdio = pipe.stdio
	pid = pipe.pid
	for stream: FileAccess in [pipe.stdio, pipe.stderr]:
		var reader := Thread.new()
		reader.start(_read.bind(stream, _lines if stream == pipe.stdio else null, _mutex))
		_readers.append(reader)
	available = true
	error = ""
	_queue(["uci"], "uciok")
	if _engine_path == ENGINE:
		_queue(["setoption name VerboseMoveStats value true"], "")
	return true


# Loads a Maia net (engine/weights/maia-<level>.pb.gz); later requests wait for readyok.
func set_level(net_path: String) -> void:
	if _engine_path == ENGINE:
		_queue(["ucinewgame", "setoption name WeightsFile value " + net_path, "isready"], "readyok")


func new_game() -> void:
	_queue(["ucinewgame"], "")


# Emits policy_ready on the main thread once Lc0 answers bestmove.
func request_policy(start_fen: String, moves: PackedStringArray) -> void:
	if _engine_path != ENGINE:
		return
	var board = Board.from_fen(start_fen)
	for move in moves:
		board.make_move(move)
	var position := "position fen " + start_fen + (" moves " + " ".join(moves) if moves else "")
	_queue([position, "go nodes 1"], "bestmove", board)


func request_search(commands: PackedStringArray, callback: Callable) -> void:
	_queue(commands, "bestmove", null, callback)


func poll() -> void:
	if not available:
		return
	if not OS.is_process_running(pid):
		_report_stopped(_engine_name + " stopped. Restart the app to play again. Run scripts/fetch-engine.ps1 if needed.")
		return
	_mutex.lock()
	var lines := _lines.duplicate()
	_lines.clear()
	_mutex.unlock()
	for line in lines:
		# A failed WeightsFile can produce readyok, then error, then a fallback bestmove.
		if line.begins_with("error "):
			_report_stopped(_engine_name + " stopped: " + line.trim_prefix("error ") + ". Run scripts/fetch-engine.ps1 if needed.")
			return
		if _awaiting == "bestmove" and _callback.is_valid() and (line.begins_with("info ") or line.begins_with("bestmove")):
			_callback.call(line)
		if _awaiting == "bestmove" and line.begins_with("info string "):
			_info.append(line)
		elif _awaiting != "" and line.begins_with(_awaiting):
			_awaiting = ""
			if line.begins_with("bestmove") and _board != null:
				policy_ready.emit(parse_policy(_info, _board))
			_send()


func _report_stopped(message: String) -> void:
	stop()
	error = message
	stopped.emit()


func stop() -> void:
	if pid != -1 and OS.is_process_running(pid):
		OS.kill(pid)
	# The readers return once the pipes break with the process.
	for reader in _readers:
		reader.wait_to_finish()
	_readers.clear()
	_stdio = null
	pid = -1
	available = false
	_steps.clear()
	_awaiting = ""
	_board = null
	_callback = Callable()
	_info.clear()
	_mutex.lock()
	_lines.clear()
	_mutex.unlock()


func _queue(lines: PackedStringArray, reply: String, board = null, callback := Callable()) -> void:
	if not available:
		return
	_steps.append([lines, reply, board, callback])
	_send()


# Writes queued commands until one waits for a reply.
func _send() -> void:
	while available and _awaiting == "" and not _steps.is_empty():
		var step: Array = _steps.pop_front()
		for line in step[0]:
			_stdio.store_line(line)
		_awaiting = step[1]
		_board = step[2]
		_callback = step[3]
		_info.clear()


# Worker thread: blocks on the pipe until it breaks. stderr (lines null) is drained so Lc0 never
# stalls on it. Static because a thread inside a method locks the node, and free() then fails.
static func _read(stream: FileAccess, lines, mutex: Mutex) -> void:
	while true:
		var line := stream.get_line()
		if stream.get_error() != OK:
			return
		if lines != null:
			mutex.lock()
			lines.append(line)
			mutex.unlock()
