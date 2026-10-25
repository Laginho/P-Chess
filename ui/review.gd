extends Control

# Clock snapshots are the mover's remaining milliseconds after each move (HIST-001).
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")
const Board = preload("res://core/board.gd")

@onready var _result: Label = $Margin/Content/Result
@onready var _moves: Tree = $Margin/Content/Moves


func _ready() -> void:
	_moves.set_column_title(0, "Move")
	_moves.set_column_title(1, "White · time spent")
	_moves.set_column_title(2, "Black · time spent")
	_moves.set_column_expand(0, false)
	_moves.set_column_custom_minimum_width(0, 60)


func present(game, clocks: Array, settings: Dictionary, result_text: String) -> void:
	_result.text = result_text
	_moves.clear()
	var root := _moves.create_item()
	var board = Board.from_fen(Pgn.START)
	var times := move_times(clocks, settings.control)
	var row: TreeItem
	for i in game.moves.size():
		if i % 2 == 0:
			row = _moves.create_item(root)
			row.set_text(0, "%d." % (i / 2 + 1))
		row.set_text(i % 2 + 1, "%s (%.3f s)" % [board.san(game.moves[i]), times[i] / 1000.0])
		board.make_move(game.moves[i])
	show()


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
