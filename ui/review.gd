extends Control

signal rematch_requested
signal setup_requested

# Clock snapshots are the mover's remaining milliseconds after each move (HIST-001).
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")
const Board = preload("res://core/board.gd")
const Badges = preload("res://bot/badges.gd")

# System boundaries stay replaceable for headless tests.
var copy_text: Callable = DisplayServer.clipboard_set
var open_browser: Callable = OS.shell_open
var _pgn := ""
var _url := ""

@onready var _result: Label = $Margin/Content/Result
@onready var _moves: Tree = $Margin/Content/Moves


func _ready() -> void:
	_moves.set_column_title(0, "Move")
	_moves.set_column_title(1, "White · time spent")
	_moves.set_column_title(2, "Black · time spent")
	_moves.set_column_title(3, "White · badges")
	_moves.set_column_title(4, "Black · badges")
	_moves.set_column_expand(0, false)
	_moves.set_column_custom_minimum_width(0, 60)
	$Margin/Content/Actions/CopyPgn.pressed.connect(func(): copy_text.call(_pgn))
	$Margin/Content/Actions/Lichess.pressed.connect(func(): open_browser.call(_url))
	$Margin/Content/Actions/Rematch.pressed.connect(func(): rematch_requested.emit())
	$Margin/Content/Actions/Setup.pressed.connect(func(): setup_requested.emit())


# Handle Space before the focused move list or a button consumes it as GUI input.
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		rematch_requested.emit()


func present(game, clocks: Array, settings: Dictionary, result_text: String,
		catalog: Array = [], repertoire: Array = [], check_repertoire := false) -> void:
	_result.text = result_text
	_moves.clear()
	var root := _moves.create_item()
	var board = Board.from_fen(Pgn.START)
	var times := move_times(clocks, settings.control)
	var badges := Badges.evaluate(game.moves, catalog, repertoire, settings.colour, check_repertoire)
	var exit_text := ""
	var row: TreeItem
	for i in game.moves.size():
		if i % 2 == 0:
			row = _moves.create_item(root)
			row.set_text(0, "%d." % (i / 2 + 1))
		row.set_text(i % 2 + 1, "%s (%.3f s)" % [board.san(game.moves[i]), times[i] / 1000.0])
		var text := _badge_text(badges[i])
		row.set_text(i % 2 + 3, text)
		row.set_tooltip_text(i % 2 + 3, text)
		if badges[i].left_repertoire:
			exit_text = "%d. %s: %s" % [i / 2 + 1, "White" if i % 2 == 0 else "Black", text]
		board.make_move(game.moves[i])
	# Keep expected moves readable even when a badge column is narrow.
	$Margin/Content/RepertoireExit.text = exit_text
	$Margin/Content/RepertoireExit.visible = not exit_text.is_empty()
	_pgn = Pgn.write(Pgn.finished_game(game, clocks, settings))
	_url = lichess_url(game)
	show()


static func _badge_text(mark: Dictionary) -> String:
	var labels := PackedStringArray()
	if mark.book:
		labels.append("Book")
	if mark.repertoire:
		labels.append("Repertoire")
	if mark.left_repertoire:
		labels.append("Left repertoire — " + ("No continuation in repertoire" if mark.expected.is_empty()
				else "expected: " + ", ".join(mark.expected)))
	return " · ".join(labels)


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
