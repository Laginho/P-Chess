extends RefCounted

const Board = preload("res://core/board.gd")
var probe

func _init(tablebase) -> void:
	probe = tablebase

# Answers describe root moves from the mover's perspective, including their ply.
func grade(position: Dictionary, line: PackedStringArray, callback: Callable) -> void:
	var board = Board.from_fen(position.get("fen", ""))
	var job := {"board": board, "line": line.duplicate(), "callback": callback, "plies": []}
	_step(job)

func _step(job: Dictionary) -> void:
	var index: int = job.plies.size()
	if index == job.line.size():
		job.callback.call({"ok": true, "solved": true, "failed_ply": -1, "plies": job.plies})
		return
	probe.probe(job.board.to_fen(), func(answer: Dictionary):
		if not answer.ok:
			job.callback.call(answer)
			return
		var move: String = job.line[index]
		job.plies.append({"uci": move, "san": job.board.san(move), "mark": "✓" if index % 2 == 0 else ""})
		job.board.make_move(move)
		_step(job))
