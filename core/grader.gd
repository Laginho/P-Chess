extends RefCounted

const Board = preload("res://core/board.gd")
const Tunables = preload("res://core/tunables.gd")
const RESULTS := ["loss", "draw", "win"]
var probe

func _init(tablebase) -> void:
	probe = tablebase

# Root-move answers already express the result for the mover, and DTZ includes
# that move. Do not invert the result or add another ply to the distance.
func grade(position: Dictionary, line: PackedStringArray, callback: Callable) -> void:
	var board = Board.from_fen(position.get("fen", ""))
	var length := int(position.get("line_length", 0))
	if board == null or length < 1 or line.size() != 2 * length - 1 or position.get("side", board.side_to_move) != board.side_to_move:
		callback.call({"ok": false, "error": "Enter a complete legal line."})
		return
	var plies := []
	for move in line:
		if not move in board.legal_moves():
			callback.call({"ok": false, "error": "Enter a complete legal line."})
			return
		plies.append({"uci": move, "san": board.san(move), "mark": "", "grey": true, "better_defence": ""})
		board.make_move(move)
	var job := {"board": Board.from_fen(position.fen), "callback": callback, "index": 0,
		"result": {"ok": true, "solved": true, "reason": "", "failed_ply": -1, "plies": plies, "correct": [], "failure_fen": ""}}
	_step(job)

func _finish(job: Dictionary, result: Dictionary) -> void:
	if job.callback.is_valid():
		job.callback.call(result)

func _step(job: Dictionary) -> void:
	if job.index == job.result.plies.size():
		_finish(job, job.result)
		return
	probe.probe(job.board.to_fen(), func(answer: Dictionary):
		if not answer.get("ok", false):
			_finish(job, answer)
			return
		var ply: Dictionary = job.result.plies[job.index]
		var played: Dictionary = answer.moves[ply.uci]
		var best: Dictionary = answer.moves[answer.best]
		ply.grey = false
		if job.index % 2 == 0:
			var reason := ""
			if played.result != answer.result:
				reason = "result changed"
			elif answer.result == "win" and played.dtz > best.dtz + Tunables.COURSE_DTZ_MARGIN:
				reason = "too slow"
			ply.mark = "✓" if reason.is_empty() else "✗"
			if not reason.is_empty():
				job.result.solved = false
				job.result.reason = reason
				job.result.failed_ply = job.index
				job.result.failure_fen = job.board.to_fen()
				_correct(job, answer)
				return
		elif RESULTS.find(best.result) > RESULTS.find(played.result) or (best.result == "loss" and played.result == "loss" and best.dtz > played.dtz):
			ply.better_defence = job.board.san(answer.best)
		job.board.make_move(ply.uci)
		job.index += 1
		_step(job))

func _correct(job: Dictionary, answer: Dictionary) -> void:
	if not answer.get("ok", false):
		_finish(job, answer)
		return
	var move: String = answer.best
	if move.is_empty():
		_finish(job, job.result)
		return
	job.result.correct.append({"uci": move, "san": job.board.san(move)})
	job.board.make_move(move)
	if job.result.correct.size() == job.result.plies.size() or job.board.legal_moves().is_empty():
		_finish(job, job.result)
		return
	probe.probe(job.board.to_fen(), func(next: Dictionary): _correct(job, next))
