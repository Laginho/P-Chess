extends Control

signal back_requested

const History = preload("res://core/history.gd")
const Setup = preload("res://ui/setup.gd")
const Analyser = preload("res://engine/analyser.gd")
const Accuracy = preload("res://core/accuracy.gd")
const Tunables = preload("res://core/tunables.gd")

var preferences


func _ready() -> void:
	%Back.pressed.connect(func(): back_requested.emit())
	%SaveName.pressed.connect(_save_name)
	%PlayerName.text_submitted.connect(func(_text): _save_name())


func present(settings) -> void:
	preferences = settings
	%PlayerName.text = preferences.get_value("player_name")
	_show_name(%PlayerName.text)
	refresh(History.new())
	show()
	%PlayerName.grab_focus()


func refresh(history, analysis_dir := "") -> void:
	if analysis_dir.is_empty():
		analysis_dir = history.analysis_folder()
	var table: GridContainer = %Results
	for child in table.get_children():
		table.remove_child(child)
		child.queue_free()
	for title in ["Level", "1+0 · W D L", "3+2 · W D L", "5+0 · W D L", "Flag wins", "Flag losses"]:
		_cell(table, title)
	var rows := 0
	var totals := {"wins": 0, "draws": 0, "losses": 0, "flag_wins": 0, "flag_losses": 0}
	for level in Setup.LEVELS:
		var values := []
		var flags := [0, 0]
		var played := 0
		for control in ["1+0", "3+2", "5+0"]:
			var counts: Dictionary = history.stats(level, control)
			for key in totals:
				totals[key] += counts[key]
			var count: int = counts.wins + counts.draws + counts.losses
			played += count
			flags[0] += counts.flag_wins
			flags[1] += counts.flag_losses
			values.append("%d  %d  %d" % [counts.wins, counts.draws, counts.losses] if count else "–")
		if played == 0:
			continue
		rows += 1
		for value in [level.replace("maia-", "Maia "), values[0], values[1], values[2], flags[0], flags[1]]:
			_cell(table, str(value))
	%GamesValue.text = str(totals.wins + totals.draws + totals.losses)
	%WdlValue.text = "[color=#8fbc5a]%d[/color] / [color=#a8a49c]%d[/color] / [color=#ee7a72]%d[/color]" % [totals.wins, totals.draws, totals.losses]
	%FlagValue.text = "[color=#8fbc5a]%d[/color] / [color=#ee7a72]%d[/color]" % [totals.flag_wins, totals.flag_losses]
	%NoResults.visible = rows == 0
	var records: Array = history.games()
	var first_date := ""
	for record in records:
		var date: String = record.game.headers.get("Date", "")
		var fields := date.split(".")
		if fields.size() >= 2 and fields[0].is_valid_int() and fields[1].is_valid_int() and int(fields[1]) in range(1, 13):
			if first_date.is_empty() or date < first_date:
				first_date = date
	%PlayingSince.visible = not first_date.is_empty()
	if not first_date.is_empty():
		var fields := first_date.split(".")
		var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		%PlayingSince.text = "Playing since %s %s" % [months[int(fields[1]) - 1], fields[0]]

	var series := []
	for record in records:
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
	%AccuracyChart.set_series(series)
	%NoAccuracy.visible = series.is_empty()
	var total_accuracy := 0.0
	for sample in series:
		total_accuracy += sample.accuracy
	%AccuracyValue.text = "–" if series.is_empty() else "%.1f" % (total_accuracy / series.size())


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
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table.add_child(label)


func _save_name() -> void:
	var input: LineEdit = %PlayerName
	var value := input.text.strip_edges()
	if preferences.set_value("player_name", value):
		input.text = value
		_show_name(value)
		%NameError.hide()
	else:
		%NameError.show()


func _show_name(value: String) -> void:
	%DisplayName.text = value
	%Avatar.text = value.left(1).to_upper()
