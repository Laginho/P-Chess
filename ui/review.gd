extends Control

signal rematch_requested
signal setup_requested
signal back_history_requested

# Clock snapshots are the mover's remaining milliseconds after each move (HIST-001).
const ThemeLoader = preload("res://ui/theme_loader.gd")
const Clock = preload("res://core/clock.gd")
const Pgn = preload("res://core/pgn.gd")
const Board = preload("res://core/board.gd")
const Game = preload("res://core/game.gd")
const Uci = preload("res://engine/uci.gd")
const Analyser = preload("res://engine/analyser.gd")
const Tunables = preload("res://core/tunables.gd")
const Classification = preload("res://core/classification.gd")
const Accuracy = preload("res://core/accuracy.gd")
const Badges = preload("res://bot/badges.gd")

# System boundaries stay replaceable for headless tests.
var analysis_bridge_factory: Callable = func(): return Uci.new("engine/stockfish/stockfish.exe", "Stockfish")
var analyser_factory: Callable = func(bridge): return Analyser.new(bridge)
var analysis_queue
var _queue_path := ""
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
var _icons := {}
var _move_rows := []
var _catalog := []
var _repertoire := []
var _colour := "w"
var _check_repertoire := false
var _player_names := ["White", "Black"]
var _from_history := false
var _history_draw := false
const CLASS_NAMES := ["Brilliant", "Great", "Best", "Excellent", "Good", "Book", "Repertoire", "Forced", "Inaccuracy", "Mistake", "Miss", "Blunder"]

@onready var _eval_bar = $Margin/Content/ReviewBody/EvalBar
@onready var _board_view = $Margin/Content/ReviewBody/BoardView
@onready var _graph = $Margin/Content/ReviewBody/Side/EvalGraph

@onready var _result: Label = $Margin/Content/Result
@onready var _moves: Tree = $Margin/Content/ReviewBody/Side/Moves


func _ready() -> void:
	if analysis_queue != null:
		analysis_queue.position_ready.connect(_queue_position)
		analysis_queue.changed.connect(_queue_changed)
	_graph.ply_selected.connect(_show_ply)
	$Margin/Content/ReviewBody/Side/AccuracyHelp.tooltip_text = "Accuracy uses the change in win probability for each move.\nThe game score averages a volatility-weighted mean and\nthe harmonic mean of those move scores."
	# Tooltips need a mouse; Enter on the focused "?" shows the same text in a dialog.
	var help_dialog := AcceptDialog.new()
	help_dialog.name = "HelpDialog"
	add_child(help_dialog)
	for help: Button in [$Margin/Content/ReviewBody/Side/AccuracyHelp]:
		# Label height, so the review still fits 800x600; the focus box still shows.
		for style in ["normal", "hover", "pressed", "hover_pressed"]:
			help.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		help.pressed.connect(func():
			help_dialog.title = help.text.trim_suffix("?").strip_edges()
			help_dialog.dialog_text = help.tooltip_text
			help_dialog.popup_centered())
	var legend := AcceptDialog.new()
	legend.name = "ClassLegend"
	legend.title = "Move classes, best to worst"
	legend.dialog_text = ("Brilliant — The best move, and it sacrifices a piece.\n"
			+ "Great — The only good move here, or one that turns the game around.\n"
			+ "Best — The engine's top choice.\n"
			+ "Excellent — Almost as good as the best move (under 2%).\n"
			+ "Good — A solid move with a slightly better option (under 5%).\n"
			+ "Book — A known opening move, from opening theory.\n"
			+ "Repertoire — A move from your own repertoire.\n"
			+ "Inaccuracy — A weaker move that gives away a little (under 10%).\n"
			+ "Mistake — A bad move that gives away a clear edge (under 20%).\n"
			+ "Miss — An opponent's error was not punished.\n"
			+ "Blunder — A serious error that costs over 20%.\n"
			+ "Forced — The only legal move.")
	add_child(legend)
	$Margin/Content/ReviewBody/Side/ClassHelp.pressed.connect(func(): legend.popup_centered())
	var toggle: Button = $Margin/Content/ReviewBody/Side/ClassToggle
	toggle.pressed.connect(func(): $Margin/Content/ReviewBody/Side/Counts.visible = not $Margin/Content/ReviewBody/Side/Counts.visible)
	resized.connect(_resize_classes)
	_resize_classes()
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
	_moves.set_column_title(1, "White")
	_moves.set_column_title(2, "Black")
	_moves.set_column_expand(0, false)
	_moves.set_column_custom_minimum_width(0, 60)
	$Margin/Content/ReviewBody/Side/Navigation/First.pressed.connect(func(): _show_ply(0))
	$Margin/Content/ReviewBody/Side/Navigation/Previous.pressed.connect(func(): _show_ply(_ply - 1))
	$Margin/Content/ReviewBody/Side/Navigation/Next.pressed.connect(func(): _show_ply(_ply + 1))
	$Margin/Content/ReviewBody/Side/Navigation/Last.pressed.connect(func(): _show_ply(_game_moves.size()))
	$Margin/Content/Actions/CopyPgn.pressed.connect(func(): copy_text.call(_pgn))
	$Margin/Content/Actions/Lichess.pressed.connect(func(): open_browser.call(_url))
	$Margin/Content/Actions/Rematch.pressed.connect(func(): rematch_requested.emit())
	$Margin/Content/Actions/Setup.pressed.connect(func(): setup_requested.emit())
	var back := Button.new()
	back.name = "BackHistory"
	back.text = "Back to History (Esc)"
	back.pressed.connect(func(): back_history_requested.emit())
	$Margin/Content/Actions.add_child(back)
	back.hide()
	var analyze := Button.new()
	analyze.name = "Analyze"
	analyze.text = "Analyze"
	analyze.pressed.connect(func():
		analyze.hide()
		open_analysis(_analysis_path, _history_draw))
	$Margin/Content/ReviewBody/Side.add_child(analyze)
	$Margin/Content/ReviewBody/Side.move_child(analyze, $Margin/Content/ReviewBody/Side/Moves.get_index())
	analyze.hide()


func _resize_classes() -> void:
	var compact := size.x <= 800
	var unanalysed: bool = $Margin/Content/ReviewBody/Side/UnanalysedNotice.visible
	$Margin/Content/ReviewBody/Side/ClassToggle.visible = compact and not unanalysed
	$Margin/Content/ReviewBody/Side/Counts.visible = not compact and not unanalysed
	$Margin/Content/ReviewBody/Side/ClassHelp.visible = not unanalysed
	$Margin/Content/ReviewBody/Side/AccuracyHelp.visible = not unanalysed
	_graph.visible = not unanalysed


func _class_help() -> String:
	return _wrap_help(("One final class per move. Forced: only legal move. Repertoire: your line; Book: catalog opening. "
			+ "Best: engine's first choice; Brilliant: best move sacrifices material; Great: only good move (second choice loses at least %s).\n"
			+ "By expected-points loss: Excellent ≤ %s, Good ≤ %s, Inaccuracy ≤ %s, Mistake ≤ %s, Blunder above %s. "
			+ "Miss replaces a mistake or blunder after the opponent's mistake or blunder when expected points fall from at least %s to at most %s with loss at least %s.\n"
			+ "A blunder is Good when still ahead by %s cp or already behind by %s cp. Mate rules: winning mate up to %s moves slower is Excellent, otherwise Good; lost mate grades Excellent/Good/Inaccuracy/Mistake at %s/%s/%s/%s cp. Allowing mate in ≤ %s is Blunder, ≤ %s Mistake, otherwise Inaccuracy. "
			+ "Great and Brilliant require at least %s expected points afterwards and a second line below %s cp; moves made while in check, promotions, free captures and recaptures are excluded.") % [
			Tunables.CLASSIFICATION_GREAT_LOSS, Tunables.CLASSIFICATION_EXCELLENT_LOSS, Tunables.CLASSIFICATION_GOOD_LOSS,
			Tunables.CLASSIFICATION_INACCURACY_LOSS, Tunables.CLASSIFICATION_MISTAKE_LOSS, Tunables.CLASSIFICATION_MISTAKE_LOSS,
			Tunables.CLASSIFICATION_MISS_BEFORE_EP, Tunables.CLASSIFICATION_MISS_AFTER_EP, Tunables.CLASSIFICATION_MISS_LOSS,
			Tunables.CLASSIFICATION_LENIENT_CP, Tunables.CLASSIFICATION_LENIENT_CP, Tunables.CLASSIFICATION_MATE_SLOWER,
			Tunables.CLASSIFICATION_MATE_EXCELLENT_CP, Tunables.CLASSIFICATION_MATE_GOOD_CP, Tunables.CLASSIFICATION_MATE_INACCURACY_CP,
			Tunables.CLASSIFICATION_MATE_MISTAKE_CP, Tunables.CLASSIFICATION_MATE_BLUNDER_MOVES, Tunables.CLASSIFICATION_MATE_MISTAKE_MOVES,
			Tunables.CLASSIFICATION_MIN_EP, Tunables.CLASSIFICATION_GREAT_PV2_CP])


func _wrap_help(text: String) -> String:
	var lines := PackedStringArray()
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			if line.length() + word.length() + 1 > 65:
				lines.append(line)
				line = ""
			line += (" " if not line.is_empty() else "") + word
		lines.append(line)
	return "\n".join(lines)


func open_analysis(path: String, draw_at_end: bool) -> void:
	show()
	$Margin/Content/ReviewBody/Side/UnanalysedNotice.hide()
	$Margin/Content/ReviewBody/Side/Analyze.hide()
	_resize_classes()
	var cached := Analyser.read_analysis(path, "Stockfish 19", Tunables.ANALYSIS_NODES)
	var positions = cached.get("data", {}).get("positions", [])
	var current_cache: bool = cached.state == "analysed" and positions is Array and positions.size() == _positions.size()
	if analysis_queue != null:
		# The analysis folder sits beside the games folder: <root>/analysis/x.pgn.json -> <root>/games/x.pgn.
		var game_path := _queue_path if _from_history else path.get_base_dir().get_base_dir().path_join("games").path_join(path.get_file().trim_suffix(".json"))
		if FileAccess.file_exists(game_path) and (_from_history or game_path in analysis_queue.pending() or not current_cache):
			_queue_path = game_path
			_analysis_path = path
			analysis_queue.prioritize(game_path)
			_queue_changed()
			return
	if _analysis_bridge != null:
		return
	_analysis_path = path
	_draw_at_end = draw_at_end
	# A current cache needs no engine, so a missing or broken Stockfish cannot hide it.
	if current_cache:
		for i in positions.size():
			receive_position(i, positions[i])
		return
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


# Handle review shortcuts before focused controls consume them as GUI input.
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if not _from_history:
			rematch_requested.emit()
	elif visible and _from_history and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_history_requested.emit()
	elif visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_F:
		get_viewport().set_input_as_handled()
		_board_view.flipped = not _board_view.flipped
		_update_eval_bar()
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
	_update_summary()
	_update_board_annotations()
	_update_eval_bar()


func _update_summary() -> void:
	var counts := {}
	for label in CLASS_NAMES:
		counts[label] = [0, 0]
	for i in _classes.size():
		if _classes[i] != null:
			counts[_classes[i].class][i % 2] += 1
	var lines := PackedStringArray(["Class             White   Black"])
	for label in CLASS_NAMES:
		lines.append("%s:  %d   %d" % [label, counts[label][0], counts[label][1]])
	$Margin/Content/ReviewBody/Side/Counts.text = "\n".join(lines)
	var summary: Label = $Margin/Content/ReviewBody/Side/Summary
	for position in _positions:
		if not position.has("pv"):
			summary.hide()
			return
	var accuracy: Dictionary = Accuracy.evaluate({"positions": _positions})
	var white := "–" if accuracy.white == null else "%.1f%%" % accuracy.white
	var black := "–" if accuracy.black == null else "%.1f%%" % accuracy.black
	summary.text = "White: %s  %s\nBlack: %s  %s" % [_player_names[0], white, _player_names[1], black]
	summary.show()


func _refresh_classes() -> void:
	# ponytail: reevaluate all plies as positions land; incremental classification if long games stutter.
	_classes = Classification.evaluate(_game_moves, {"positions": _positions}, _catalog, _repertoire, _colour, _check_repertoire)
	for i in _classes.size():
		var icon: Texture2D = _class_icon("Pending" if _classes[i] == null else _classes[i].class)
		_move_rows[i].set_icon(i % 2 + 1, icon)
		if _classes[i] != null:
			var detail: String = _move_rows[i].get_tooltip_text(i % 2 + 1)
			if not detail.begins_with(_classes[i].class + ":"):
				_move_rows[i].set_tooltip_text(i % 2 + 1, _classes[i].class + ": " + detail)


func _class_icon(label: String) -> Texture2D:
	if not _icons.has(label):
		if label == "Pending":
			var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for degrees in range(0, 360, 8):
				if degrees % 64 < 40:
					var angle := deg_to_rad(float(degrees))
					image.set_pixel(roundi(7.5 + 6.0 * cos(angle)), roundi(7.5 + 6.0 * sin(angle)), Color(0.65, 0.64, 0.61))
			_icons[label] = ImageTexture.create_from_image(image)
		else:
			var path := "res://ui/icons/classes/" + label.to_lower() + ".svg"
			_icons[label] = load(path) if ResourceLoader.exists(path) else ThemeLoader.load_texture(path)
	return _icons[label]


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
	_graph.positions = _positions
	_graph.current_ply = _ply
	_graph.flipped = _board_view.flipped
	_graph.queue_redraw()
	_eval_bar.flipped = _board_view.flipped
	_eval_bar.white_fraction = 0.5
	_eval_bar.get_node("Score").text = ""
	if _positions.is_empty() or not _positions[_ply].has("pv"):
		return
	var position: Dictionary = _positions[_ply]
	var line: Dictionary = position.pv[0] if not position.pv.is_empty() else {"cp": position.get("terminal_score", 0)}
	var cp: int = line.get("cp", 1000 if line.get("mate", 0) > 0 else -1000)
	var black_to_move: bool = Board.from_fen(position.fen).side_to_move == "b"
	if black_to_move:
		cp = -cp
	if line.has("mate"):
		var mate: int = -line.mate if black_to_move else line.mate
		_eval_bar.get_node("Score").text = ("+" if mate > 0 else "-") + "M%d" % absi(mate)
	else:
		_eval_bar.get_node("Score").text = ("+" if cp > 0 else "") + "%.1f" % (cp / 100.0)
	_eval_bar.white_fraction = 1.0 / (1.0 + exp(-0.00368208 * clampi(cp, -1000, 1000)))


func present(game, clocks: Array, settings: Dictionary, result_text: String,
		catalog: Array = [], repertoire: Array = [], check_repertoire := false) -> void:
	_from_history = false
	$Margin/Content/ReviewBody/Side/UnanalysedNotice.hide()
	_resize_classes()
	$Margin/Content/Actions/Rematch.show()
	$Margin/Content/Actions/Setup.show()
	$Margin/Content/Actions/BackHistory.hide()
	$Margin/Content/ReviewBody/Side/Analyze.hide()
	$Margin/Content/AnalysisError.hide()
	_game_moves = game.moves.duplicate()
	_classes = []
	_move_rows = []
	_catalog = catalog
	_repertoire = repertoire
	_colour = settings.colour
	var headers: Dictionary = Pgn.finished_game(game, clocks, settings).headers
	_player_names = [headers.White, headers.Black]
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
	var badges := Badges.evaluate(game.moves, catalog, repertoire, settings.colour, check_repertoire)
	var exit_text := ""
	var row: TreeItem
	for i in game.moves.size():
		if i % 2 == 0:
			row = _moves.create_item(root)
			row.set_text(0, "%d." % (i / 2 + 1))
		row.set_text(i % 2 + 1, board.san(game.moves[i]) + (" (left)" if badges[i].left_repertoire else ""))
		row.set_metadata(i % 2 + 1, i + 1)
		if badges[i].repertoire or badges[i].book:
			row.set_icon(i % 2 + 1, _class_icon("Repertoire" if badges[i].repertoire else "Book"))
		_move_rows.append(row)
		var text := _badge_text(badges[i])
		row.set_tooltip_text(i % 2 + 1, text)
		if badges[i].left_repertoire:
			exit_text = "%d. %s: %s" % [i / 2 + 1, "White" if i % 2 == 0 else "Black", text]
		board.make_move(game.moves[i])
	# Keep expected moves readable even when a badge column is narrow.
	$Margin/Content/ReviewBody/Side/RepertoireExit.text = exit_text
	$Margin/Content/ReviewBody/Side/RepertoireExit.visible = not exit_text.is_empty()
	_update_summary()
	_pgn = Pgn.write(Pgn.finished_game(game, clocks, settings))
	_url = lichess_url(game)
	show()


func present_history(path: String, analysis_path: String, draw_at_end: bool) -> void:
	_queue_path = path
	_from_history = true
	_analysis_path = analysis_path
	_history_draw = draw_at_end
	_pgn = FileAccess.get_file_as_string(path)
	$Margin/Content/Actions/Rematch.hide()
	$Margin/Content/Actions/Setup.hide()
	$Margin/Content/Actions/BackHistory.show()
	var cached := Analyser.read_analysis(analysis_path, "Stockfish 19", Tunables.ANALYSIS_NODES)
	var positions = cached.get("data", {}).get("positions", [])
	if cached.state == "analysed" and positions is Array and positions.size() == _positions.size():
		for i in positions.size():
			receive_position(i, positions[i])
	else:
		$Margin/Content/ReviewBody/Side/Analyze.show()
		$Margin/Content/ReviewBody/Side/UnanalysedNotice.show()
		_resize_classes()
	if analysis_queue != null and path in analysis_queue.pending():
		$Margin/Content/ReviewBody/Side/Analyze.hide()
		open_analysis(analysis_path, draw_at_end)


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

func _queue_position(path: String, index: int, position: Dictionary) -> void:
	if visible and path == _queue_path:
		receive_position(index, position)


func _queue_changed() -> void:
	if not visible or analysis_queue == null or _queue_path.is_empty():
		return
	var active: bool = analysis_queue.current() == _queue_path
	$Margin/Content/Progress.visible = active
	if active:
		$Margin/Content/Progress.value = analysis_queue.percent
	elif not _queue_path in analysis_queue.pending():
		var cached := Analyser.read_analysis(_analysis_path, "Stockfish 19", Tunables.ANALYSIS_NODES)
		var positions = cached.get("data", {}).get("positions", [])
		if positions is Array and positions.size() == _positions.size():
			for i in positions.size():
				receive_position(i, positions[i])
	if not analysis_queue.error.is_empty():
		_analysis_error(analysis_queue.error)
