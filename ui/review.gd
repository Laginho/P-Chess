extends Control

signal rematch_requested
signal setup_requested

# Clock snapshots are the mover's remaining milliseconds after each move (HIST-001).
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")
const Board = preload("res://core/board.gd")
const Game = preload("res://core/game.gd")
const Uci = preload("res://engine/uci.gd")
const Analyser = preload("res://engine/analyser.gd")
const Tunables = preload("res://core/tunables.gd")
const Classification = preload("res://core/classification.gd")
const Badges = preload("res://bot/badges.gd")

# System boundaries stay replaceable for headless tests.
var analysis_bridge_factory: Callable = func(): return Uci.new("engine/stockfish/stockfish.exe", "Stockfish")
var analyser_factory: Callable = func(bridge): return Analyser.new(bridge)
var _analysis_bridge
var _analyser
var _waiting_engine := false
var _analysis_path := ""
var _draw_at_end := false
var copy_text: Callable = DisplayServer.clipboard_set
var open_browser: Callable = OS.shell_open
var _pgn := ""
var _url := ""
var _game_moves := PackedStringArray()
var _ply := 0
var _positions := []
var _classes := []
var _move_rows := []
var _catalog := []
var _repertoire := []
var _colour := "w"
var _check_repertoire := false

@onready var _eval_bar = $Margin/Content/ReviewBody/EvalBar
@onready var _board_view = $Margin/Content/ReviewBody/BoardView

@onready var _result: Label = $Margin/Content/Result
@onready var _moves: Tree = $Margin/Content/Moves


func _ready() -> void:
	visibility_changed.connect(func():
		if not visible:
			_cancel_analysis())
	_moves.select_mode = Tree.SELECT_SINGLE
	_moves.item_selected.connect(func():
		var selected := _moves.get_selected()
		if selected:
			var ply = selected.get_metadata(_moves.get_selected_column())
			if ply != null:
				_show_ply(ply))
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


func open_analysis(path: String, draw_at_end: bool) -> void:
	show()
	if _analysis_bridge != null:
		return
	_analysis_path = path
	_draw_at_end = draw_at_end
	$Margin/Content/Progress.value = 0
	$Margin/Content/Progress.show()
	_analysis_bridge = analysis_bridge_factory.call()
	add_child(_analysis_bridge)
	_analysis_bridge.stopped.connect(_engine_stopped)
	if not _analysis_bridge.start():
		_analysis_error(_analysis_bridge.error)
		return
	_waiting_engine = true
	_check_engine()


func _process(_delta: float) -> void:
	if _waiting_engine:
		_check_engine()


func _check_engine() -> void:
	if _analysis_bridge == null or _analysis_bridge.engine_id.is_empty():
		return
	_waiting_engine = false
	var cached := Analyser.read_analysis(_analysis_path, _analysis_bridge.engine_id, Tunables.ANALYSIS_NODES)
	if cached.state == "analysed":
		var saved: Array = cached.data.positions
		if saved.size() == _positions.size():
			for i in saved.size():
				receive_position(i, saved[i])
			$Margin/Content/Progress.hide()
			return
	_analyser = analyser_factory.call(_analysis_bridge)
	add_child(_analyser)
	_analyser.position_ready.connect(receive_position)
	_analyser.progress.connect(func(done: int, total: int):
		$Margin/Content/Progress.value = 100.0 * done / maxi(total, 1))
	_analyser.finished.connect(func(success: bool, error: String):
		$Margin/Content/Progress.hide()
		if not success:
			_analysis_error(error))
	var fens := []
	for position in _positions:
		fens.append(position.fen)
	if not _analyser.analyse(fens, _analysis_path, true, _draw_at_end):
		_analysis_error("Could not start analysis")


func _engine_stopped() -> void:
	if visible and _analysis_bridge != null:
		_analysis_error(_analysis_bridge.error)


func _analysis_error(message: String) -> void:
	_waiting_engine = false
	$Margin/Content/Progress.hide()
	$Margin/Content/AnalysisError.text = "Analysis: " + message
	$Margin/Content/AnalysisError.show()


func _cancel_analysis() -> void:
	_waiting_engine = false
	if _analyser != null:
		_analyser.cancel()
		_analyser.queue_free()
		_analyser = null
	if _analysis_bridge != null:
		_analysis_bridge.queue_free()
		_analysis_bridge = null


# Handle Space before the focused move list or a button consumes it as GUI input.
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		rematch_requested.emit()
	elif visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()
		_show_ply(_ply + (-1 if event.keycode == KEY_LEFT else 1))


func _show_ply(ply: int) -> void:
	_ply = clampi(ply, 0, _game_moves.size())
	var position = Game.new()
	for i in _ply:
		position.play(_game_moves[i])
	_board_view.game = position
	_update_board_annotations()
	_board_view.queue_redraw()
	_update_eval_bar()


func receive_position(index: int, position: Dictionary) -> void:
	if index < 0 or index >= _positions.size():
		return
	_positions[index].merge(position, true)
	_refresh_classes()
	_update_board_annotations()
	_update_eval_bar()


func _refresh_classes() -> void:
	# ponytail: reevaluate all plies as positions land; incremental classification if long games stutter.
	_classes = Classification.evaluate(_game_moves, {"positions": _positions}, _catalog, _repertoire, _colour, _check_repertoire)
	for i in _classes.size():
		var icon: Texture2D = null if _classes[i] == null else _class_icon(_classes[i].class)
		_move_rows[i].set_icon(i % 2 + 1, icon)
		if _classes[i] != null:
			_move_rows[i].set_tooltip_text(i % 2 + 1, _classes[i].class)


func _class_icon(label: String) -> Texture2D:
	return load("res://ui/icons/classes/" + label.to_lower() + ".svg")


func _update_board_annotations() -> void:
	_board_view.review_square = ""
	_board_view.review_arrow = ""
	_board_view.review_icon = null
	if _ply > 0:
		var before: Dictionary = _positions[_ply - 1]
		_board_view.review_arrow = before.get("best_move", "")
		if _classes.size() >= _ply and _classes[_ply - 1] != null:
			_board_view.review_square = _game_moves[_ply - 1].substr(2, 2)
			_board_view.review_icon = _class_icon(_classes[_ply - 1].class)
	_board_view.queue_redraw()


func _update_eval_bar() -> void:
	_eval_bar.flipped = _board_view.flipped
	_eval_bar.white_fraction = 0.5
	if _positions.is_empty() or not _positions[_ply].has("pv"):
		return
	var position: Dictionary = _positions[_ply]
	var line: Dictionary = position.pv[0] if not position.pv.is_empty() else {"cp": position.get("terminal_score", 0)}
	var cp: int = line.get("cp", 1000 if line.get("mate", 0) > 0 else -1000)
	if Board.from_fen(position.fen).side_to_move == "b":
		cp = -cp
	_eval_bar.white_fraction = 1.0 / (1.0 + exp(-0.00368208 * clampi(cp, -1000, 1000)))


func present(game, clocks: Array, settings: Dictionary, result_text: String,
		catalog: Array = [], repertoire: Array = [], check_repertoire := false) -> void:
	$Margin/Content/AnalysisError.hide()
	_game_moves = game.moves.duplicate()
	_classes = []
	_move_rows = []
	_catalog = catalog
	_repertoire = repertoire
	_colour = settings.colour
	_check_repertoire = check_repertoire
	_positions = []
	var position = Game.new()
	_positions.append({"fen": position.board.to_fen()})
	for move in _game_moves:
		position.play(move)
		_positions.append({"fen": position.board.to_fen()})
	_board_view.flipped = settings.colour == "b"
	_show_ply(_game_moves.size())
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
		row.set_metadata(i % 2 + 1, i + 1)
		_move_rows.append(row)
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
