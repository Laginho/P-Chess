extends Control

# Clock snapshots are the mover's remaining milliseconds after each move (HIST-001).
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")


static func move_times(clocks: Array, control: String) -> Array:
	var start: int = Clock.CONTROLS[control][0]
	var increment: int = Clock.CONTROLS[control][1]
	var previous := [start, start]
	var times := []
	for i in clocks.size():
		var side := i % 2
		var awarded := increment if i >= 2 and clocks[i] > 0 else 0
		times.append(previous[side] - clocks[i] + awarded)
		previous[side] = clocks[i]
	return times


static func lichess_url(game) -> String:
	var moves := []
	for move in game.moves:
		moves.append({"uci": move})
	var text := Pgn.write({"headers": {}, "moves": moves, "result": game.result}).strip_edges()
	return "https://lichess.org/analysis/pgn/" + text.uri_encode()
