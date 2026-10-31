extends Control

signal back_requested

const History = preload("res://core/history.gd")
const Setup = preload("res://ui/setup.gd")
const Analyser = preload("res://engine/analyser.gd")
const Accuracy = preload("res://core/accuracy.gd")
const Tunables = preload("res://core/tunables.gd")

var preferences


func _ready() -> void:
	$Margin/Content/Back.pressed.connect(func(): back_requested.emit())
	$Margin/Content/NameRow/SaveName.pressed.connect(_save_name)
	$Margin/Content/NameRow/PlayerName.text_submitted.connect(func(_text): _save_name())


func present(settings) -> void:
	preferences = settings
	$Margin/Content/NameRow/PlayerName.text = preferences.get_value("player_name")
	refresh(History.new())
	show()
	$Margin/Content/NameRow/PlayerName.grab_focus()


func refresh(history, analysis_dir := "") -> void:
	if analysis_dir.is_empty():
		analysis_dir = history.analysis_folder()
	var table: GridContainer = $Margin/Content/Scroll/Body/Results
	for child in table.get_children():
		table.remove_child(child)
		child.queue_free()
	for title in ["Level", "Time", "W", "D", "L", "Flag wins", "Flag losses"]:
		_cell(table, title)
	var rows := 0
	for level in Setup.LEVELS:
		for control in ["1+0", "3+2", "5+0"]:
			var counts: Dictionary = history.stats(level, control)
			if counts.wins + counts.draws + counts.losses == 0:
				continue
			rows += 1
			for value in [level.replace("maia-", "Maia "), control, counts.wins, counts.draws,
					counts.losses, counts.flag_wins, counts.flag_losses]:
				_cell(table, str(value))
	$Margin/Content/Scroll/Body/NoResults.visible = rows == 0
	var series := []
	for record in history.games():
		var game: Dictionary = record.game
		if game.moves.is_empty():
			continue
		var cached := Analyser.read_analysis(analysis_dir.path_join(record.path.get_file() + ".json"),
				"Stockfish 19", Tunables.ANALYSIS_NODES)
		if cached.state != "analysed":
			continue
		var positions = cached.data.get("positions")
		if not _complete_analysis(positions, game.moves.size() + 1):
			continue
		var values := Accuracy.evaluate(cached.data)
		var value = values.white if History.human_colour(game.headers) == "w" else values.black
		if value == null:
			continue
		series.append({"date": game.headers.get("Date", record.path.get_file().left(10)),
				"accuracy": value, "path": record.path})
	series.sort_custom(func(a, b):
		var first: String = a.date.replace(".", "-")
		var second: String = b.date.replace(".", "-")
		return first < second if first != second else a.path < b.path)
	$Margin/Content/Scroll/Body/AccuracyChart.set_series(series)
	$Margin/Content/Scroll/Body/NoAccuracy.visible = series.is_empty()


# Cache metadata alone does not guarantee that every scored position was written.
func _complete_analysis(positions, count: int) -> bool:
	if not positions is Array or positions.size() != count:
		return false
	for position in positions:
		if not position is Dictionary or not position.get("pv") is Array:
			return false
		var score = position.get("terminal_score")
		if not position.pv.is_empty():
			var line = position.pv[0]
			if not line is Dictionary:
				return false
			score = line.get("cp", line.get("mate"))
		if not (score is int or score is float) or not is_finite(float(score)):
			return false
	var fen = positions[0].get("fen")
	if not fen is String:
		return false
	var fields: PackedStringArray = fen.split(" ")
	return fields.size() >= 2 and fields[1] in ["w", "b"]


func _cell(table: GridContainer, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_child(label)


func _save_name() -> void:
	var input: LineEdit = $Margin/Content/NameRow/PlayerName
	var value := input.text.strip_edges()
	if preferences.set_value("player_name", value):
		input.text = value
		$Margin/Content/NameError.hide()
	else:
		$Margin/Content/NameError.show()
