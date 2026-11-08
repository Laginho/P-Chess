extends Control

signal back_requested

const Course = preload("res://core/course.gd")
const History = preload("res://core/history.gd")
const Setup = preload("res://ui/setup.gd")
const Analyser = preload("res://engine/analyser.gd")
const Accuracy = preload("res://core/accuracy.gd")
const Tunables = preload("res://core/tunables.gd")

var preferences
var course


func _ready() -> void:
	%Back.pressed.connect(func(): back_requested.emit())
	%SaveName.pressed.connect(_save_name)
	%RatingSite.add_item("chess.com")
	%RatingSite.add_item("lichess")
	%RatingNumber.text_changed.connect(func(_text): _update_rating())
	%RatingSite.item_selected.connect(func(_index): _update_rating())
	%SaveRating.pressed.connect(_save_rating)
	%PlayerName.text_submitted.connect(func(_text): _save_name())
	%Results.resized.connect(_fit_headers)
	%SaveName.add_theme_font_override("font", get_theme_font("font", "BoldText"))
	for label in [%WdlValue, %FlagValue]:
		label.add_theme_font_override("normal_font", get_theme_font("font", "ExtraBoldText"))


func present(settings, course_store = null) -> void:
	preferences = settings
	course = course_store if course_store != null else Course.new()
	var rating: Dictionary = course.rating()
	%RatingNumber.text = str(rating.number) if not rating.is_empty() else ""
	%RatingSite.select(1 if rating.get("site") == "lichess" else 0)
	_update_rating()
	%PlayerName.text = preferences.get_value("player_name")
	_show_name(%PlayerName.text)
	refresh(History.new())
	show()
	# Keyboard focus starts on Back without a ring; the design shows the name field idle on arrival.
	%Back.grab_focus(true)


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
	if table.size.x > 0:
		_fit_headers()
	%GamesValue.text = str(totals.wins + totals.draws + totals.losses)
	%WdlValue.text = "[color=#8fbc5a]%d[/color] / [color=#a8a49c]%d[/color] / [color=#ee7a72]%d[/color]" % [totals.wins, totals.draws, totals.losses]
	%FlagValue.text = "[color=#8fbc5a]%d[/color] / [color=#ee7a72]%d[/color]" % [totals.flag_wins, totals.flag_losses]
	%NoResults.visible = rows == 0
	var records: Array = history.games()
	var first_date := ""
	for record in records:
		var date: String = record.game.headers.get("Date", record.path.get_file().left(10))
		var fields := date.replace("-", ".").split(".")
		if fields.size() >= 2 and fields[0].is_valid_int() and fields[1].is_valid_int() and int(fields[1]) in range(1, 13):
			date = "%s.%02d" % [fields[0], int(fields[1])]
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
				"Stockfish 19", Tunables.ANALYSIS_NODES, Analyser.positions_from_game(game))
		if cached.state != "analysed":
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


func _fit_headers() -> void:
	var table: GridContainer = %Results
	if table.get_child_count() < 6:
		return
	var narrow := table.size.x < 500
	var titles := ["Level", "1+0 · W D L", "3+2 · W D L", "5+0 · W D L", "Flag wins", "Flag losses"]
	var compact := ["Level", "1+0\nW D L", "3+2\nW D L", "5+0\nW D L", "Flag\nwins", "Flag\nlosses"]
	for i in 6:
		var label: Label = table.get_child(i)
		label.text = compact[i] if narrow else titles[i]
		label.custom_minimum_size.y = 42 if narrow else 30


func _cell(table: GridContainer, value: String) -> void:
	var index := table.get_child_count()
	var header := index < 6
	var column := index % 6
	var label := Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.y = 30 if header else 34
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column == 0 else HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = "BoldText" if header else ("SemiboldText" if column == 0 else "")
	label.add_theme_font_size_override("font_size", 12 if header else 14)
	if header:
		label.add_theme_color_override("font_color", Color("a8a49c"))
	elif column == 4:
		label.add_theme_color_override("font_color", Color("8fbc5a") if value != "0" else Color("8a857c"))
	elif column == 5:
		label.add_theme_color_override("font_color", Color("ee7a72") if value != "0" else Color("8a857c"))
	var line := StyleBoxFlat.new()
	line.draw_center = false
	line.content_margin_left = 8 if column == 0 else 0
	if not header:
		line.border_width_top = 1
		line.border_color = Color("3a3834")
	label.add_theme_stylebox_override("normal", line)
	table.add_child(label)


func _save_name() -> void:
	var input: LineEdit = %PlayerName
	var value := input.text.strip_edges()
	if preferences.set_value("player_name", value):
		input.text = value
		_show_name(value)
		%NameError.hide()
	else:
		%NameError.text = "Please enter a name." if value.is_empty() else "Could not save your name. Please try again."
		%NameError.show()


func _show_name(value: String) -> void:
	%DisplayName.text = value
	%Avatar.text = value.left(1).to_upper()


func _update_rating() -> void:
	var text: String = %RatingNumber.text
	var valid := text.is_valid_int() and Course.valid_rating(int(text), %RatingSite.get_item_text(%RatingSite.selected))
	%SaveRating.disabled = not valid
	%RatingHint.visible = valid and %RatingSite.selected == 1
	if %RatingHint.visible:
		%RatingHint.text = "Shown as %d on the chess.com scale" % (int(text) - 300)


func _save_rating() -> void:
	_update_rating()
	if not %SaveRating.disabled and course.save_rating(int(%RatingNumber.text), %RatingSite.get_item_text(%RatingSite.selected)):
		%RatingError.hide()
	else:
		%RatingError.show()
