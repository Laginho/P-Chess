extends Control

signal back_requested
signal review_requested(path: String, game: Dictionary)

const Game = preload("res://core/game.gd")
const BoardView = preload("res://ui/board_view.tscn")
const Analyser = preload("res://engine/analyser.gd")
const Accuracy = preload("res://core/accuracy.gd")
const Tunables = preload("res://core/tunables.gd")
const TABS := ["All", "1+0", "3+2", "5+0"]
const CONTROLS := {"60+0": "1+0", "180+2": "3+2", "300+0": "5+0"}

var analysis_queue
var _selected := {}
var history
var preferences
var copy_text: Callable = DisplayServer.clipboard_set


func _ready() -> void:
	var actions := HBoxContainer.new()
	actions.name = "BatchActions"
	$Margin/Content.add_child(actions)
	$Margin/Content.move_child(actions, 2)
	var selected := Button.new()
	selected.text = "Analyze selected"
	selected.pressed.connect(func():
		for path in _selected:
			if _selected[path] and analysis_queue != null:
				analysis_queue.enqueue(path))
	actions.add_child(selected)
	var all := Button.new()
	all.text = "Analyze all"
	all.pressed.connect(_analyze_all)
	actions.add_child(all)
	var status := Label.new()
	status.name = "Status"
	actions.add_child(status)
	if analysis_queue != null:
		analysis_queue.changed.connect(_queue_changed)
	for tab in TABS:
		$Margin/Content/Tabs.add_tab(tab)
	$Margin/Content/Tabs.tab_changed.connect(func(_index): _refresh())
	$Margin/Content/Back.pressed.connect(func(): back_requested.emit())


func present(store, settings) -> void:
	history = store
	preferences = settings
	$Margin/Content/Tabs.current_tab = TABS.find(settings.get_value("history_tab"))
	_refresh()
	show()


func _refresh() -> void:
	if history == null:
		return
	var list = $Margin/Content/Cards/List
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var selected: String = TABS[$Margin/Content/Tabs.current_tab]
	for record in history.games():
		var game: Dictionary = record.game
		var control: String = CONTROLS.get(game.headers.get("TimeControl", ""), "")
		if selected != "All" and selected != control:
			continue
		_add_card(list, record)


func _add_card(list: Node, record: Dictionary) -> void:
	var game: Dictionary = record.game
	var headers: Dictionary = game.headers
	var colour := "w" if headers.get("White", "") == "You" else "b"
	var moves := PackedStringArray()
	for move in game.moves:
		moves.append(move.uci)
	var thumbnail: Dictionary = history.thumbnail(moves)
	var card := HBoxContainer.new()
	list.add_child(card)
	var board = BoardView.instantiate()
	board.custom_minimum_size = Vector2(140, 140)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.flipped = colour == "b"
	board.game = Game.new()
	for i in thumbnail.ply:
		board.game.play(moves[i])
	card.add_child(board)
	var select := CheckBox.new()
	select.button_pressed = _selected.get(record.path, false)
	select.toggled.connect(func(on): _selected[record.path] = on)
	card.add_child(select)
	var details := VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(details)
	var text := Label.new()
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var date: String = headers.get("Date", record.path.get_file().left(10))
	var opening: String = thumbnail.opening + "\n" if not thumbnail.opening.is_empty() else ""
	var human: String = headers.get("White" if colour == "w" else "Black", "?")
	var opponent: String = headers.get("Black" if colour == "w" else "White", "?")
	text.text = "%s%s  ·  %s (%s) x %s (%s)\n%s (%s)  ·  %d moves\n%s" % [opening, date, human, "White" if colour == "w" else "Black", opponent, "Black" if colour == "w" else "White", _result_text(game, colour), game.result, (moves.size() + 1) / 2, _analysis_text(record.path)]
	details.add_child(text)
	var actions := HBoxContainer.new()
	actions.name = "HBoxContainer"
	details.add_child(actions)
	var review := Button.new()
	review.name = "Review"
	review.text = "Review"
	review.pressed.connect(func(): review_requested.emit(record.path, game))
	actions.add_child(review)
	if analysis_queue != null:
		var analyze := Button.new()
		analyze.text = "Re-analyze" if _analysis_text(record.path) == "Stale" else "Analyze"
		analyze.disabled = record.path in analysis_queue.pending()
		analyze.pressed.connect(func(): analysis_queue.enqueue(record.path))
		actions.add_child(analyze)
	var copy := Button.new()
	copy.text = "⧉"
	copy.tooltip_text = "Copy PGN"
	copy.custom_minimum_size = Vector2(44, 44)
	copy.pressed.connect(func(): copy_text.call(FileAccess.get_file_as_string(record.path)))
	actions.add_child(copy)


func _result_text(game: Dictionary, colour: String) -> String:
	var result: String = game.result
	var outcome := "Draw" if result == "1/2-1/2" else ("Won" if (result == "1-0") == (colour == "w") else "Lost")
	var why: String = history.reason(game)
	if why.is_empty():
		return outcome
	return outcome + (" on time" if why == "time" else " by " + why)


func _analysis_text(path: String) -> String:
	if analysis_queue != null and path in analysis_queue.pending():
		return "Analysing %d%%" % analysis_queue.percent if analysis_queue.current() == path else "Queued"
	var analysis_path := "user://analysis".path_join(path.get_file() + ".json")
	var analysis := Analyser.read_analysis(analysis_path, "Stockfish 19", Tunables.ANALYSIS_NODES)
	if analysis.state != "analysed":
		return analysis.state.capitalize()
	if not analysis.data.get("positions") is Array:
		return "Stale"
	var accuracy := Accuracy.evaluate(analysis.data)
	return "White: %s  Black: %s" % [_accuracy(accuracy.white), _accuracy(accuracy.black)]


func _accuracy(value) -> String:
	return "–" if value == null else "%.1f%%" % value

func _analyze_all() -> void:
	if history == null or analysis_queue == null:
		return
	var tab: String = TABS[$Margin/Content/Tabs.current_tab]
	for record in history.games():
		var control: String = CONTROLS.get(record.game.headers.get("TimeControl", ""), "")
		if (tab == "All" or tab == control) and _analysis_text(record.path) in ["Not Analysed", "Stale"]:
			analysis_queue.enqueue(record.path)


func _queue_changed() -> void:
	var count: int = analysis_queue.pending().size()
	var status: Label = $Margin/Content/BatchActions/Status
	status.text = ("Analysing · %d queued · %s" % [count, preferences.get_value("analysis_threads")]) if count and preferences != null else ""
	if visible:
		_refresh()
