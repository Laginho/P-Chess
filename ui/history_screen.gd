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
const TREND_ICON := '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#141412" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 17l5-6 4 4 8-9"/></svg>'
const CLOCK_ICON := '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#a8a49c" stroke-width="2.4" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>'
const WARNING_ICON := '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#f4bf44" stroke-width="2.4" stroke-linecap="round"><path d="M12 3l10 18H2z"/><path d="M12 10v4M12 17.5v.5"/></svg>'

var analysis_queue
var _selected := {}
var history
var preferences
var copy_text: Callable = DisplayServer.clipboard_set
var _delete_path := ""
var _compact := false


func _ready() -> void:
	_compact = size.x < 1000
	resized.connect(func():
		var compact := size.x < 1000
		if compact != _compact:
			_compact = compact
			call_deferred("_refresh"))
	var actions := HFlowContainer.new()
	actions.name = "BatchActions"
	actions.custom_minimum_size.y = 44
	$Margin/Content.add_child(actions)
	$Margin/Content.move_child(actions, 1)
	var selected := Button.new()
	selected.name = "AnalyzeSelected"
	selected.text = "Analyze selected"
	selected.icon = _icon(TREND_ICON)
	selected.theme_type_variation = "PrimaryButton"
	selected.custom_minimum_size.y = 40
	selected.pressed.connect(func():
		for path in _selected:
			if _selected[path] and analysis_queue != null:
				analysis_queue.enqueue(path))
	actions.add_child(selected)
	var all := Button.new()
	all.name = "AnalyzeAll"
	all.text = "Analyze all"
	all.custom_minimum_size.y = 40
	all.pressed.connect(_analyze_all)
	actions.add_child(all)
	var status := Label.new()
	status.name = "Status"
	status.custom_minimum_size.x = 200
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(status)
	var select_all := CheckBox.new()
	select_all.name = "SelectAll"
	select_all.toggled.connect(func(on):
		for card in $Margin/Content/Cards/List.get_children():
			card.get_node("Details/Select").button_pressed = on)
	actions.add_child(select_all)
	actions.move_child(select_all, 0)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var spinner := Label.new()
	spinner.name = "Spinner"
	spinner.text = "◌"
	spinner.visible = false
	spinner.add_theme_color_override("font_color", Color("7fa650"))
	actions.add_child(spinner)
	actions.move_child(spacer, 2)
	actions.move_child(spinner, 3)
	actions.move_child(status, 4)
	actions.move_child(all, 5)
	if analysis_queue != null:
		analysis_queue.changed.connect(_queue_changed)
	var tabs: TabBar = $Margin/Content/Header/Tabs
	for key in ["tab_selected", "tab_unselected", "tab_hovered"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("45423d") if key == "tab_selected" else Color("2b2a27")
		style.set_corner_radius_all(6)
		style.set_content_margin_all(12)
		tabs.add_theme_stylebox_override(key, style)
	for tab in TABS:
		tabs.add_tab(tab)
	$Margin/Content/Header/Tabs.tab_changed.connect(func(_index): _refresh())
	$Margin/Content/Header/Back.pressed.connect(func(): back_requested.emit())


func _process(delta: float) -> void:
	var spinner: Label = $Margin/Content/BatchActions/Spinner
	if spinner.visible:
		spinner.pivot_offset = spinner.size / 2
		spinner.rotation += delta * 3.0


func present(store, settings) -> void:
	history = store
	preferences = settings
	$Margin/Content/Header/Tabs.current_tab = TABS.find(settings.get_value("history_tab"))
	show()
	if analysis_queue != null:
		_queue_changed()
	else:
		_refresh()


func _refresh() -> void:
	if history == null:
		return
	var list = $Margin/Content/Cards/List
	# Queue progress rebuilds the cards; keep keyboard focus on the same control of the same game.
	var focus := get_viewport().gui_get_focus_owner()
	var focus_path := list.get_path_to(focus) if focus != null and list.is_ancestor_of(focus) else NodePath()
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var records: Array = history.games()
	var counts := [records.size(), 0, 0, 0]
	for record in records:
		var index := TABS.find(CONTROLS.get(record.game.headers.get("TimeControl", ""), ""))
		if index > 0:
			counts[index] += 1
	for index in TABS.size():
		$Margin/Content/Header/Tabs.set_tab_title(index, "%s %d" % [TABS[index], counts[index]])
	var selected: String = TABS[$Margin/Content/Header/Tabs.current_tab]
	for record in records:
		var game: Dictionary = record.game
		var control: String = CONTROLS.get(game.headers.get("TimeControl", ""), "")
		if selected != "All" and selected != control:
			continue
		_add_card(list, record)
	_update_selection()
	$Margin/Content/BatchActions/AnalyzeAll.text = "Analyze all in “%s”" % selected
	if not focus_path.is_empty() and list.has_node(focus_path):
		list.get_node(focus_path).grab_focus()


func _add_card(list: Node, record: Dictionary) -> void:
	var game: Dictionary = record.game
	var headers: Dictionary = game.headers
	var colour: String = history.human_colour(headers)
	var moves := PackedStringArray()
	for move in game.moves:
		moves.append(move.uci)
	var thumbnail: Dictionary = history.thumbnail(moves)
	var card := PanelContainer.new()
	card.name = record.path.get_file().validate_node_name()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size.y = 96
	list.add_child(card)
	var panel_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	panel_style.border_color = Color("7fa650") if _selected.get(record.path, false) else Color("45423d")
	card.add_theme_stylebox_override("panel", panel_style)
	var details := HBoxContainer.new()
	details.name = "Details"
	details.add_theme_constant_override("separation", 8)
	card.add_child(details)
	var select := CheckBox.new()
	select.name = "Select"
	select.tooltip_text = "Select game"
	select.custom_minimum_size.x = 44
	select.button_pressed = _selected.get(record.path, false)
	select.toggled.connect(func(on):
		_selected[record.path] = on
		panel_style.border_color = Color("7fa650") if on else Color("45423d")
		_update_selection())
	details.add_child(select)
	var board = BoardView.instantiate()
	board.name = "Thumbnail"
	board.custom_minimum_size = Vector2(64, 64) if _compact else Vector2(80, 80)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.flipped = colour == "b"
	board.game = Game.new()
	for i in thumbnail.ply:
		board.game.play(moves[i])
	details.add_child(board)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.custom_minimum_size.x = 150
	details.add_child(info)
	var date: String = headers.get("Date", record.path.get_file().left(10))
	var human: String = headers.get("White" if colour == "w" else "Black", "?")
	if not headers.has("HumanColor") and human == "You":
		human = preferences.get_value("player_name")
	var opponent: String = headers.get("Black" if colour == "w" else "White", "?")
	if not thumbnail.opening.is_empty():
		var opening := Label.new()
		opening.name = "Opening"
		opening.text = thumbnail.opening
		opening.theme_type_variation = "BoldText"
		opening.add_theme_font_size_override("font_size", 15)
		opening.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(opening)
	var players := Label.new()
	players.name = "Players"
	players.text = "%s %s  x  %s %s" % ["●" if colour == "w" else "○", human, "○" if colour == "w" else "●", opponent]
	players.tooltip_text = "%s: %s; %s: %s" % ["White" if colour == "w" else "Black", human, "Black" if colour == "w" else "White", opponent]
	players.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	players.add_theme_font_size_override("font_size", 14)
	info.add_child(players)
	var metadata := HFlowContainer.new()
	metadata.name = "Metadata"
	metadata.add_theme_constant_override("h_separation", 6)
	info.add_child(metadata)
	var date_label := Label.new()
	date_label.text = date + "  ·"
	date_label.theme_type_variation = "MutedText"
	date_label.add_theme_font_size_override("font_size", 13)
	metadata.add_child(date_label)
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color("2b2a27")
	chip_style.border_color = Color("45423d")
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(4)
	chip_style.content_margin_left = 5
	chip_style.content_margin_right = 5
	chip.add_theme_stylebox_override("panel", chip_style)
	metadata.add_child(chip)
	var control := Label.new()
	control.text = CONTROLS.get(headers.get("TimeControl", ""), headers.get("TimeControl", ""))
	control.theme_type_variation = "MutedText"
	control.add_theme_font_size_override("font_size", 13)
	chip.add_child(control)
	var move_count := Label.new()
	move_count.text = "·  %d moves" % ((moves.size() + 1) / 2)
	move_count.theme_type_variation = "MutedText"
	move_count.add_theme_font_size_override("font_size", 13)
	metadata.add_child(move_count)

	var outcome := Label.new()
	outcome.name = "Result"
	outcome.text = "·  " + _result_text(game, colour)
	outcome.add_theme_font_size_override("font_size", 13)
	var result_color := Color("a8a49c") if game.result == "1/2-1/2" else (Color("8fbc5a") if (game.result == "1-0") == (colour == "w") else Color("ee7a72"))
	outcome.add_theme_color_override("font_color", result_color)
	metadata.add_child(outcome)
	metadata.move_child(move_count, metadata.get_child_count() - 1)
	var state := _analysis_text(record.path, moves.size() + 1)

	var status := VBoxContainer.new()
	status.name = "AnalysisStatus"
	status.custom_minimum_size.x = 105 if _compact else 232
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_child(status)
	var cached := _cached_accuracy(record.path, moves.size() + 1)
	if not cached.is_empty() and not state.begins_with("Analysing") and state != "Queued":
		var heading := Label.new()
		heading.text = "Accuracy"
		heading.theme_type_variation = "MutedText"
		heading.add_theme_font_size_override("font_size", 12)
		status.add_child(heading)
		var boxes := HBoxContainer.new()
		for side in ["white", "black"]:
			var box := Label.new()
			box.name = "WhiteAccuracy" if side == "white" else "BlackAccuracy"
			box.text = _accuracy(cached[side])
			box.tooltip_text = side.capitalize() + " accuracy"
			box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			box.custom_minimum_size = Vector2(65, 32)
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var style := StyleBoxFlat.new()
			style.bg_color = Color("ece9e4") if side == "white" else Color("141412")
			style.set_corner_radius_all(6)
			box.add_theme_stylebox_override("normal", style)
			box.add_theme_color_override("font_color", Color("141412") if side == "white" else Color("ece9e4"))
			boxes.add_child(box)
		status.add_child(boxes)
		if state == "Stale":
			boxes.modulate.a = 0.5
	if state == "Stale":
		var stale_row := HBoxContainer.new()
		stale_row.add_theme_constant_override("separation", 6)
		status.add_child(stale_row)
		var warning := TextureRect.new()
		warning.name = "StaleIcon"
		warning.texture = _icon(WARNING_ICON)
		warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stale_row.add_child(warning)
		var reason := Label.new()
		reason.name = "StaleReason"
		var analysis_path: String = history.analysis_folder().path_join(record.path.get_file() + ".json")
		var data = JSON.parse_string(FileAccess.get_file_as_string(analysis_path))
		var reason_text := "invalid analysis data"
		if data is Dictionary:
			reason_text = "engine settings changed" if data.get("engine_version") != "Stockfish 19" or data.get("node_budget") != Tunables.ANALYSIS_NODES else "incomplete analysis"
		reason.text = "Stale: " + reason_text
		reason.add_theme_color_override("font_color", Color("f4bf44"))
		reason.add_theme_font_size_override("font_size", 12)
		stale_row.add_child(reason)
	elif state.begins_with("Analysing"):
		var label := Label.new()
		label.text = state
		status.add_child(label)
		var progress := ProgressBar.new()
		progress.name = "AnalysisProgress"
		progress.value = analysis_queue.percent
		progress.custom_minimum_size.y = 8
		progress.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("7fa650")
		fill.set_corner_radius_all(4)
		progress.add_theme_stylebox_override("fill", fill)
		status.add_child(progress)
	elif state == "Queued":
		var pill := PanelContainer.new()
		pill.name = "QueuePill"
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var pill_style := StyleBoxFlat.new()
		pill_style.bg_color = Color("363430")
		pill_style.set_corner_radius_all(14)
		pill_style.content_margin_left = 10
		pill_style.content_margin_right = 10
		pill_style.content_margin_top = 4
		pill_style.content_margin_bottom = 4
		pill.add_theme_stylebox_override("panel", pill_style)
		status.add_child(pill)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		pill.add_child(row)
		var clock := TextureRect.new()
		clock.name = "QueueIcon"
		clock.texture = _icon(CLOCK_ICON)
		clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(clock)
		var label := Label.new()
		var place: int = analysis_queue.pending().find(record.path) + (1 if analysis_queue.current().is_empty() else 0)
		label.text = "Queued · %d%s in line" % [place, _ordinal(place)]
		row.add_child(label)
	elif cached.is_empty():
		var label := Label.new()
		label.text = "Not analysed"
		label.theme_type_variation = "MutedText"
		status.add_child(label)
	var actions := HBoxContainer.new()
	actions.name = "HBoxContainer"
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.custom_minimum_size.x = 0 if _compact else 300
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_child(actions)
	var review := Button.new()
	review.name = "Review"
	review.text = "Review"
	review.custom_minimum_size.y = 40
	if not cached.is_empty() and state != "Queued" and not state.begins_with("Analysing"):
		review.theme_type_variation = "PrimaryButton"
	review.pressed.connect(func(): review_requested.emit(record.path, game))
	actions.add_child(review)
	if analysis_queue != null:
		var analyze := Button.new()
		analyze.name = "Analyze"
		analyze.text = "Re-analyze" if state == "Stale" or state.begins_with("White:") else "Analyze"
		analyze.disabled = record.path in analysis_queue.pending()
		if analyze.disabled:
			analyze.text = "Analysing…" if analysis_queue.current() == record.path else "Queued"
		if state == "Stale":
			analyze.add_theme_color_override("font_color", Color("f4bf44"))
		analyze.pressed.connect(func(): analysis_queue.enqueue(record.path))
		actions.add_child(analyze)
	var copy := Button.new()
	copy.name = "Copy"
	copy.icon = load("res://ui/icons/copy.svg")
	copy.tooltip_text = "Copy PGN"
	copy.custom_minimum_size = Vector2(40, 40)
	copy.pressed.connect(func(): copy_text.call(FileAccess.get_file_as_string(record.path)))
	actions.add_child(copy)
	var delete := Button.new()
	delete.name = "Delete"
	delete.icon = load("res://ui/icons/trash.svg")
	delete.tooltip_text = "Delete game"
	delete.custom_minimum_size = Vector2(40, 40)
	delete.pressed.connect(func():
		for other in list.get_children():
			other.get_node("Details/DeleteInline").hide()
			other.get_node("Details/HBoxContainer").show()
		_delete_path = record.path
		actions.hide()
		details.get_node("DeleteInline").show())
	actions.add_child(delete)
	var confirm := HBoxContainer.new()
	confirm.name = "DeleteInline"
	confirm.visible = _delete_path == record.path
	actions.visible = not confirm.visible
	confirm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_child(confirm)
	var question := Label.new()
	question.text = "Delete this game?"
	confirm.add_child(question)
	var yes := Button.new()
	yes.name = "Confirm"
	yes.text = "Delete"
	var red := StyleBoxFlat.new()
	red.bg_color = Color("c93230")
	red.set_corner_radius_all(8)
	red.set_content_margin_all(10)
	yes.add_theme_stylebox_override("normal", red)
	yes.pressed.connect(func(): _confirm_delete(record.path))
	confirm.add_child(yes)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "Cancel"
	cancel.pressed.connect(func():
		_delete_path = ""
		confirm.hide()
		actions.show())
	confirm.add_child(cancel)


func _icon(svg: String) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)


func _ordinal(number: int) -> String:
	if number % 100 in [11, 12, 13]:
		return "th"
	return {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")


func _update_selection() -> void:
	var count := 0
	for path in _selected:
		if _selected[path]:
			count += 1
	var box: CheckBox = $Margin/Content/BatchActions/SelectAll
	box.text = "%d selected" % count
	var cards = $Margin/Content/Cards/List.get_children()
	var checked := not cards.is_empty()
	for card in cards:
		checked = checked and card.get_node("Details/Select").button_pressed
	box.set_pressed_no_signal(checked)


func _confirm_delete(path: String) -> void:
	if path != _delete_path:
		return
	if history.delete(path):
		var deleted := path
		_delete_path = ""
		_selected.erase(deleted)
		if analysis_queue != null:
			analysis_queue.remove(deleted)
		_refresh()
	else:
		$DeleteError.dialog_text = history.error
		$DeleteError.popup_centered()


func _result_text(game: Dictionary, colour: String) -> String:
	var result: String = game.result
	var outcome := "Draw" if result == "1/2-1/2" else ("Won" if (result == "1-0") == (colour == "w") else "Lost")
	var why: String = history.reason(game)
	if why.is_empty():
		return outcome
	return outcome + (" on time" if why == "time" else " by " + why)


func _analysis_text(path: String, count := -1) -> String:
	if analysis_queue != null and path in analysis_queue.pending():
		return "Analysing %d%%" % analysis_queue.percent if analysis_queue.current() == path else "Queued"
	var analysis_path: String = history.analysis_folder().path_join(path.get_file() + ".json")
	var analysis := Analyser.read_analysis(analysis_path, "Stockfish 19", Tunables.ANALYSIS_NODES)
	if analysis.state != "analysed":
		return analysis.state.capitalize()
	var accuracy := _cached_accuracy(path, count)
	if accuracy.is_empty():
		return "Stale"
	return "White: %s  Black: %s" % [_accuracy(accuracy.white), _accuracy(accuracy.black)]


func _cached_accuracy(path: String, count: int) -> Dictionary:
	var analysis_path: String = history.analysis_folder().path_join(path.get_file() + ".json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(analysis_path)) if FileAccess.file_exists(analysis_path) else null
	if not data is Dictionary:
		return {}
	var positions = data.get("positions")
	if not positions is Array or (count >= 0 and positions.size() != count) or positions.is_empty():
		return {}
	for position in positions:
		if not position is Dictionary or not position.get("pv") is Array:
			return {}
		var score = position.get("terminal_score")
		if not position.pv.is_empty():
			var line = position.pv[0]
			if not line is Dictionary:
				return {}
			score = line.get("cp", line.get("mate"))
		if not (score is int or score is float) or not is_finite(float(score)):
			return {}
	var fen = positions[0].get("fen")
	if not fen is String:
		return {}
	var fields: PackedStringArray = fen.split(" ")
	if fields.size() < 2 or fields[1] not in ["w", "b"]:
		return {}
	return Accuracy.evaluate(data)


func _accuracy(value) -> String:
	return "–" if value == null else "%.1f%%" % value

func _analyze_all() -> void:
	if history == null or analysis_queue == null:
		return
	var tab: String = TABS[$Margin/Content/Header/Tabs.current_tab]
	for record in history.games():
		var control: String = CONTROLS.get(record.game.headers.get("TimeControl", ""), "")
		if (tab == "All" or tab == control) and _analysis_text(record.path, record.game.moves.size() + 1) in ["Not Analysed", "Stale"]:
			analysis_queue.enqueue(record.path)
	# Also the retry after a failed analysis, which stays queued.
	analysis_queue.resume()


func _queue_changed() -> void:
	var count: int = analysis_queue.pending().size()
	var status: Label = $Margin/Content/BatchActions/Status
	$Margin/Content/BatchActions/Spinner.visible = count > 0 and not analysis_queue.current().is_empty()
	status.text = ("Analysing %d of %d · %s" % [analysis_queue.batch_done + 1, analysis_queue.batch_total, preferences.get_value("analysis_threads")]) if count and preferences != null else ""
	# A failed game stays queued and holds the batch, so say why and how to retry.
	if count and not analysis_queue.error.is_empty() and analysis_queue.current().is_empty():
		status.text = "Analysis failed: %s · Analyze all to retry" % analysis_queue.error
	if visible:
		_refresh()
