extends RefCounted

const Board = preload("res://core/board.gd")
var probe

func _init(tablebase) -> void:
	probe = tablebase

func scan(positions: Array, side: String, callback: Callable) -> void:
	var candidates := []
	for i in range(positions.size() - 1):
		var board = Board.from_fen(positions[i].get("fen", ""))
		if board == null or board.side_to_move != side:
			continue
		var pieces: String = "".join(board.squares)
		if pieces.count("K") == 1 and pieces.count("k") == 1 and pieces.count("R") == 1 and pieces.count("r") == 1 and pieces.count("P") + pieces.count("p") == 1 and pieces.length() == 5:
			candidates.append(i)
	if candidates.is_empty() or probe == null:
		callback.call([])
		return
	if probe.has_method("start"):
		probe.start()
	_next({"positions": positions, "candidates": candidates, "index": 0, "markers": [], "callback": callback})

func _next(job: Dictionary) -> void:
	if job.index >= job.candidates.size():
		job.callback.call(job.markers)
		return
	var index: int = job.candidates[job.index]
	probe.probe(job.positions[index].fen, func(before: Dictionary):
		if not before.get("ok", false) or before.get("result", "") not in ["win", "draw", "loss"]:
			job.callback.call([])
			return
		probe.probe(job.positions[index + 1].fen, func(after: Dictionary):
			if not after.get("ok", false) or after.get("result", "") not in ["win", "draw", "loss"]:
				job.callback.call([])
				return
			var inverted: String = {"win": "loss", "draw": "draw", "loss": "win"}[after.result]
			if before.result != inverted:
				job.markers.append({"ply": index + 1, "fen": job.positions[index].fen, "before": before.result, "after": inverted})
			job.index += 1
			_next(job)))
