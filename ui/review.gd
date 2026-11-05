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
const LiveAnalysis = preload("res://engine/live_analysis.gd")
const Tunables = preload("res://core/tunables.gd")
const Classification = preload("res://core/classification.gd")
const Accuracy = preload("res://core/accuracy.gd")
const Badges = preload("res://bot/badges.gd")

# System boundaries stay replaceable for headless tests.
var analysis_bridge_factory: Callable = func(): return Uci.new("engine/stockfish/stockfish.exe", "Stockfish")
var analyser_factory: Callable = func(bridge): return Analyser.new(bridge)
var analysis_queue
var settings_panel: Control
var _queue_path := ""
var _queue_was_pending := false
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
var _line_active := false
var _line_moves := PackedStringArray()
var _line_index := 0
var _line_classes := []
var _line_rows: Array[TreeItem] = []
var _engine_lines: VBoxContainer
var _live_analysis
var _live_bridge
var _live_position := {}
var _live_failed := false
var _game_error := ""
var _game_error_visible := false
var _line_progress_visible := false
var _line_progress_value := 0.0
var _direct_paused := false
var _leaving_for_game := false
var best_move_arrow_enabled := true:
	set(value):
		best_move_arrow_enabled = value
		if is_node_ready():
			_update_board_annotations()
var _positions := []
var _classes := []
var _icons := {}
var _move_rows := []
var _clock_cells := []
var _exit_rows: Array[TreeItem] = []
var _catalog := []
var _repertoire := []
var _colour := "w"
var _check_repertoire := false
var _player_names := ["White", "Black"]
var _from_history := false
var _history_draw := false
const CHART_ICON := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#7fa650" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19V5M4 19h16M8 15l4-5 3 3 5-6"/></svg>'
const HELP_ICON := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="#45423d"/><path d="M9.2 9.3a2.9 2.9 0 1 1 4.3 2.5c-.9.5-1.5 1.1-1.5 2.1v.5" fill="none" stroke="#ece9e4" stroke-width="2.6" stroke-linecap="round"/><circle cx="12" cy="18" r="1.5" fill="#ece9e4"/></svg>'
const NAV_ICONS := {"First": "M6 5v14M18 6l-7 6 7 6", "Previous": "M15 5l-7 7 7 7", "Next": "M9 5l7 7-7 7", "Last": "M18 5v14M6 6l7 6-7 6"}
const CARD_PADDING := 16
const CLASS_NAMES := ["Brilliant", "Great", "Best", "Excellent", "Good", "Book", "Repertoire", "Inaccuracy", "Mistake", "Miss", "Blunder", "Forced"]

@onready var _eval_bar = $Margin/Content/ReviewBody/EvalBar
@onready var _board_view = $Margin/Content/ReviewBody/BoardView
@onready var _graph = $Margin/Content/ReviewBody/Side/EvalGraph

@onready var _result: Label = $Margin/Content/Result
@onready var _moves: Tree = $Margin/Content/ReviewBody/Side/Moves


func _ready() -> void:
	_create_engine_lines()
	if analysis_queue != null:
		analysis_queue.position_ready.connect(_queue_position)
		analysis_queue.changed.connect(_queue_changed)
	var summary: Label = $Margin/Content/ReviewBody/Side/Summary
	summary.custom_minimum_size.y = 44
	summary.add_theme_color_override("font_color", Color.TRANSPARENT)
	var cards := GridContainer.new()
	cards.columns = 4
	cards.name = "AccuracyCards"
	cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary.add_child(cards)
	cards.add_theme_constant_override("h_separation", 10)
	for side in ["White", "Black"]:
		var tone := "Light" if side == "White" else "Dark"
		var card := PanelContainer.new()
		card.name = side + "Score"
		card.theme_type_variation = "AccuracyCard" + tone
		card.custom_minimum_size = Vector2(88, 44)
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = "AccuracyValue" + tone
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(value)
		cards.add_child(card)
		var name_label := Label.new()
		name_label.name = side + "Name"
		name_label.theme_type_variation = "SemiboldText"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if side == "Black":
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cards.add_child(name_label)
	cards.move_child(cards.get_node("BlackName"), 2)
	var table: GridContainer = $Margin/Content/ReviewBody/Side/Counts
	for label in CLASS_NAMES:
		var name_label := Label.new()
		name_label.name = label + "Label"
		name_label.text = label
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 13)
		table.add_child(name_label)
		var white := Label.new()
		white.name = label + "White"
		white.theme_type_variation = "BoldText"
		white.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		white.custom_minimum_size.x = 56
		white.add_theme_font_size_override("font_size", 13)
		table.add_child(white)
		var icon := TextureRect.new()
		icon.name = label + "Icon"
		icon.texture = _class_icon(label)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		table.add_child(icon)
		var black := Label.new()
		black.name = label + "Black"
		black.theme_type_variation = "BoldText"
		black.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		black.custom_minimum_size.x = 56
		black.add_theme_font_size_override("font_size", 13)
		table.add_child(black)
	$Margin/Content/StopAnalysis.pressed.connect(_stop_analysis)
	$Margin/Content/Progress.visibility_changed.connect(func():
		$Margin/Content/StopAnalysis.visible = $Margin/Content/Progress.visible
		$Margin/Content/ProgressText.visible = $Margin/Content/Progress.visible
		$Margin/Content/ProgressTitle.visible = $Margin/Content/Progress.visible
		$Margin/Content/ProgressNote.visible = $Margin/Content/Progress.visible
		_layout_review())
	# An error can appear after layout settles: place it when it shows.
	$Margin/Content/AnalysisError.visibility_changed.connect(_layout_review)
	_graph.ply_selected.connect(_show_ply.bind(true))
	_board_view.move_played.connect(_on_board_move)
	_board_view.resized.connect(_update_player_labels)
	_result.resized.connect(_layout_review)
	$Margin/Content/ReviewBody/Side.resized.connect(_layout_review)
	resized.connect(_layout_review)
	_layout_review.call_deferred()
	$Margin/Content/ReviewBody/Side.sort_children.connect(_place_rules)
	$Margin/Content/ReviewBody/Side/Counts.sort_children.connect(_place_rules)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("1f1e1c")
	track.set_corner_radius_all(5)
	$Margin/Content/Progress.add_theme_stylebox_override("background", track)
	var fill := track.duplicate()
	fill.bg_color = Color("7fa650")
	$Margin/Content/Progress.add_theme_stylebox_override("fill", fill)
	$Margin/Content/ReviewIcon.texture = _svg(CHART_ICON)
	for entry in [["AccuracyHelp", 24, 13], ["ClassHelp", 20, 12]]:
		var help: Button = get_node("Margin/Content/ReviewBody/Side/" + entry[0])
		help.icon = _svg(HELP_ICON % [entry[1], entry[1]])
		help.add_theme_font_override("font", get_theme_font("font", "BoldText"))
		help.add_theme_font_size_override("font_size", entry[2])
		# Flat, with no padding: the label starts at the column's edge as drawn; the focus box still shows.
		for style in ["normal", "hover", "pressed", "hover_pressed"]:
			help.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			help.add_theme_color_override(key, Color("a8a49c"))
	for button: Button in $Margin/Content/ReviewBody/Side/Navigation.get_children():
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon = _svg('<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ece9e4" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="%s"/></svg>' % NAV_ICONS[button.name])
	for button: Button in $Margin/Content/Actions.get_children():
		if button.theme_type_variation.is_empty():
			button.add_theme_font_override("font", get_theme_font("font", "SemiboldText"))
	$Margin/Content/Actions/Setup.add_theme_font_override("font", get_theme_font("font", "ExtraBoldText"))
	_moves.add_theme_font_override("font", get_theme_font("font", "SemiboldText"))
	for key in ["selected", "selected_focus"]:
		var chip := StyleBoxFlat.new()
		chip.bg_color = Color("4a4741")
		chip.set_corner_radius_all(4)
		_moves.add_theme_stylebox_override(key, chip)
	var list_space := StyleBoxEmpty.new()
	list_space.content_margin_top = 4
	list_space.content_margin_bottom = 4
	for key in ["panel", "focus"]:
		_moves.add_theme_stylebox_override(key, list_space)
	_moves.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	$Margin/Content/ReviewBody/Side/AccuracyHelp.tooltip_text = "Accuracy uses the change in win probability for each move.\nThe game score averages a volatility-weighted mean and\nthe harmonic mean of those move scores."
	# Tooltips need a mouse; Enter on the focused "?" shows the same text in a dialog.
	var help_dialog := AcceptDialog.new()
	help_dialog.name = "HelpDialog"
	add_child(help_dialog)
	for help: Button in [$Margin/Content/ReviewBody/Side/AccuracyHelp]:
		help.pressed.connect(func():
			help_dialog.title = help.text
			help_dialog.dialog_text = help.tooltip_text
			help_dialog.popup_centered())
	var legend := PopupPanel.new()
	legend.theme_type_variation = "LegendPanel"
	legend.name = "ClassLegend"
	var legend_text := ("Brilliant — The best move, and it sacrifices a piece.\n"
			+ "Great — The only good move here, or one that turns the game around.\n"
			+ "Best — The engine's top choice.\n"
			+ "Excellent — Almost as good as the best move (loses under 2% win chance).\n"
			+ "Good — A solid move with a slightly better option (under 5%).\n"
			+ "Book — A known opening move, from opening theory.\n"
			+ "Repertoire — A move from your own repertoire.\n"
			+ "Inaccuracy — A weaker move that gives away a little (under 10%).\n"
			+ "Mistake — A bad move that gives away a clear edge (under 20%).\n"
			+ "Miss — Your opponent erred and you didn't punish it, letting a winning position slip.\n"
			+ "Blunder — A serious error that costs over 20% win chance, often material or the game.\n"
			+ "Forced — The only legal move.")
	add_child(legend)
	var content := VBoxContainer.new()
	content.name = "Content"
	legend.add_child(content)
	var header := HBoxContainer.new()
	header.name = "Header"
	content.add_child(header)
	var heading := Label.new()
	heading.text = "Move classes, best to worst"
	heading.theme_type_variation = "ExtraBoldText"
	heading.add_theme_font_size_override("font_size", 15)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := Button.new()
	close.name = "Close"
	close.text = "×"
	close.tooltip_text = "Close"
	close.flat = true
	close.custom_minimum_size = Vector2(28, 28)
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", Color("a8a49c"))
	close.pressed.connect(legend.hide)
	header.add_child(close)
	var rows := VBoxContainer.new()
	rows.name = "LegendRows"
	rows.custom_minimum_size.x = 456
	rows.add_theme_constant_override("separation", 4)
	content.add_child(rows)
	for line in legend_text.split("\n"):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon := TextureRect.new()
		icon.texture = _class_icon(line.get_slice(" \u2014 ", 0))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.add_theme_constant_override("separation", 0)
		var title := Label.new()
		title.text = line.get_slice(" \u2014 ", 0)
		title.theme_type_variation = "BoldText"
		text.add_child(title)
		var description := Label.new()
		description.text = line.get_slice(" \u2014 ", 1)
		description.theme_type_variation = "MutedText"
		description.add_theme_font_size_override("font_size", 12)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# A known wrap width, so the popup sizes to its content.
		description.custom_minimum_size.x = 420
		text.add_child(description)
		row.add_child(text)
		rows.add_child(row)
	var class_help: Button = $Margin/Content/ReviewBody/Side/ClassHelp
	class_help.pressed.connect(func():
		for row: Control in legend.get_node("Content/LegendRows").get_children():
			row.custom_minimum_size.y = 44 if get_viewport_rect().size.y >= 700 else 0
		legend.popup(Rect2i(Vector2i.ZERO, Vector2i(484, 0)))
		await get_tree().process_frame
		if not legend.visible:
			return
		var bounds := Vector2i(get_viewport_rect().size)
		var anchor := Vector2i(class_help.global_position)
		var origin := Vector2i(clampi(anchor.x - legend.size.x - 8, 0, maxi(0, bounds.x - legend.size.x)),
				clampi(anchor.y - 60, 0, maxi(0, bounds.y - legend.size.y)))
		if not get_window().gui_embed_subwindows:
			origin += get_window().position
		legend.position = origin
		close.grab_focus())
	var toggle: Button = $Margin/Content/ReviewBody/Side/ClassToggle
	toggle.pressed.connect(func():
		var side: Control = $Margin/Content/ReviewBody/Side
		var expanded: bool = not side.get_node("Counts").visible
		side.get_node("Counts").visible = expanded
		side.get_node("AccuracyHelp").visible = not expanded
		side.get_node("EvalGraph").visible = not expanded
		side.get_node("Moves").visible = not expanded
		_update_engine_lines()
		_update_summary())
	resized.connect(_resize_classes)
	_resize_classes()
	visibility_changed.connect(func():
		if not visible:
			_discard_line()
			_cancel_analysis())
	_moves.select_mode = Tree.SELECT_SINGLE
	var clocks := Control.new()
	clocks.name = "Clocks"
	clocks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clocks.clip_contents = true
	_moves.add_child(clocks)
	clocks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clocks.offset_top = 4
	clocks.offset_bottom = -4
	clocks.draw.connect(_draw_clocks)
	_moves.draw.connect(clocks.queue_redraw)
	# Class icons are imported at 4x; mipmaps keep their strokes when drawn at 16-18 px.
	_moves.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_moves.resized.connect(func():
		_fit_exit_rows()
		_moves.ensure_cursor_is_visible.call_deferred())
	_moves.item_selected.connect(func():
		var selected := _moves.get_selected()
		if selected:
			var ply = selected.get_metadata(_moves.get_selected_column())
			if ply is Dictionary:
				if ply.has("back"):
					_back_to_game.call_deferred()
				else:
					_show_line.call_deferred(ply.index, true)
			elif ply != null:
				if _line_active:
					_show_ply.call_deferred(ply, true)
				else:
					_show_ply(ply, true))
	_moves.button_clicked.connect(func(_item: TreeItem, _column: int, _id: int, _button: int):
		_back_to_game.call_deferred())
	_moves.set_column_title(0, "Move")
	_moves.set_column_title(1, "White")
	_moves.set_column_title(2, "Black")
	_moves.set_column_expand(0, false)
	_moves.set_column_custom_minimum_width(0, 40)
	$Margin/Content/ReviewBody/Side/Navigation/First.pressed.connect(func(): _show_ply(0, true))
	$Margin/Content/ReviewBody/Side/Navigation/Previous.pressed.connect(func(): _step(-1))
	$Margin/Content/ReviewBody/Side/Navigation/Next.pressed.connect(func(): _step(1))
	$Margin/Content/ReviewBody/Side/Navigation/Last.pressed.connect(func(): _show_ply(_game_moves.size(), true))
	$Margin/Content/Actions/CopyPgn.pressed.connect(func(): copy_text.call(_pgn))
	$Margin/Content/Actions/Lichess.pressed.connect(func(): open_browser.call(_url))
	$Margin/Content/Actions/Rematch.pressed.connect(_request_rematch)
	$Margin/Content/Actions/Setup.pressed.connect(func(): setup_requested.emit())
	var back := Button.new()
	back.name = "BackHistory"
	back.text = "Back to History (Esc)"
	back.custom_minimum_size.y = 40
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_theme_font_override("font", get_theme_font("font", "SemiboldText"))
	back.pressed.connect(func(): back_history_requested.emit())
	$Margin/Content/Actions.add_child(back)
	back.hide()
	var notice: Label = $Margin/Content/ReviewBody/Side/UnanalysedNotice
	notice.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	notice.add_theme_font_size_override("font_size", 16)
	var title_space := StyleBoxEmpty.new()
	title_space.content_margin_top = 79
	notice.add_theme_stylebox_override("normal", title_space)
	var notice_bg := Panel.new()
	notice_bg.name = "NoticeCard"
	notice_bg.theme_type_variation = "EmptyAnalysisCard"
	notice_bg.show_behind_parent = true
	notice_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_child(notice_bg)
	notice_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice_bg.offset_top = 3
	notice_bg.offset_bottom = 80
	var notice_icon := TextureRect.new()
	notice_icon.name = "NoticeIcon"
	notice_icon.texture = _svg(CHART_ICON.replace("20", "40").replace("#7fa650", "#a8a49c").replace('stroke-width="2.2"', 'stroke-width="1.8"'))
	notice_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_child(notice_icon)
	notice_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_icon.position.y = 27
	var description := Label.new()
	description.name = "AnalysisDescription"
	description.text = "Stockfish classifies every move and scores both sides’ accuracy."
	description.theme_type_variation = "MutedText"
	description.add_theme_font_size_override("font_size", 13)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_child(description)
	notice.resized.connect(_fit_notice)
	# Wrapped text finishes measuring after the hidden notice is shown again.
	description.minimum_size_changed.connect(_fit_notice)
	var analyze := Button.new()
	analyze.name = "Analyze"
	analyze.custom_minimum_size = Vector2(124, 48)
	analyze.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	analyze.text = "Analyze"
	analyze.theme_type_variation = "PrimaryButton"
	analyze.add_theme_font_override("font", get_theme_font("font", "ExtraBoldText"))
	analyze.add_theme_font_size_override("font_size", 16)
	analyze.pressed.connect(func():
		analyze.hide()
		open_analysis(_analysis_path, _history_draw if _from_history else _draw_at_end))
	$Margin/Content/ReviewBody/Side.add_child(analyze)
	$Margin/Content/ReviewBody/Side.move_child(analyze, $Margin/Content/ReviewBody/Side/Moves.get_index())
	# The card's 24 px padding below the button, then 16 px before the move list.
	var notice_gap := Control.new()
	notice_gap.custom_minimum_size.y = 32
	analyze.visibility_changed.connect(func(): notice_gap.visible = analyze.visible)
	$Margin/Content/ReviewBody/Side.add_child(notice_gap)
	$Margin/Content/ReviewBody/Side.move_child(notice_gap, $Margin/Content/ReviewBody/Side/Moves.get_index())
	analyze.hide()


# An exit callout that does not fit across both move columns wraps inside the first, on taller rows.
func _fit_exit_rows() -> void:
	var font := _moves.get_theme_font("font")
	for row in _exit_rows:
		var text_width := font.get_string_size(row.get_text(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 30
		var fits := text_width <= _moves.get_column_width(1) + _moves.get_column_width(2)
		var lines := 1 if fits else ceili(text_width / maxf(_moves.get_column_width(1), 1))
		row.set_autowrap_mode(1, TextServer.AUTOWRAP_OFF if fits else TextServer.AUTOWRAP_WORD_SMART)
		row.custom_minimum_height = 0 if fits else lines * 17 + 8


# The card grows with its wrapped title and description; the description sits 12 px under the title.
func _fit_notice() -> void:
	var notice: Label = $Margin/Content/ReviewBody/Side/UnanalysedNotice
	var description: Label = notice.get_node("AnalysisDescription")
	description.size = Vector2(maxf(notice.size.x - 48, 0), 0)
	var height := description.get_combined_minimum_size().y
	description.position = Vector2(24, notice.size.y - 4 - height)
	var style: StyleBoxEmpty = notice.get_theme_stylebox("normal")
	# Compact: no icon, so the move list keeps a few rows at 800x600.
	var top := 24 if _compact() else 79
	notice.get_node("NoticeIcon").visible = top == 79
	if style.content_margin_bottom != height + 16 or style.content_margin_top != top:
		style.content_margin_bottom = height + 16
		style.content_margin_top = top
		notice.update_minimum_size()


func _compact() -> bool:
	return size.x <= 800 or size.y * 4 >= size.x * 3


func _layout_review() -> void:
	var compact := _compact()
	var content: Control = $Margin/Content
	var body: Control = $Margin/Content/ReviewBody
	var side: Control = $Margin/Content/ReviewBody/Side
	var at := side.global_position - content.global_position
	# The card is the side column plus its padding; the body leaves room for the board's name rows.
	var card: Control = $Margin/Content/Card
	card.position = Vector2(at.x - CARD_PADDING, 0)
	card.size = Vector2(side.size.x + 2 * CARD_PADDING, content.size.y)
	var title: Label = $Margin/Content/Title
	var title_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
	$Margin/Content/ReviewIcon.position = card.position + Vector2(CARD_PADDING, 14)
	title.position = card.position + Vector2(CARD_PADDING + 30, 0)
	title.size = Vector2(title_width, 48)
	var result: Label = $Margin/Content/Result
	# Wide: the meta line sits right-aligned on the title row; compact: below the title.
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT
	result.position = card.position + (Vector2(CARD_PADDING, 40) if compact else Vector2(title.position.x - card.position.x + title_width + 10, 0))
	result.size = Vector2(card.size.x - (result.position.x - card.position.x) - CARD_PADDING, 0 if compact else 48)
	var rule_y := maxf(48.0, result.position.y + result.size.y + 6)
	$Margin/Content/HeaderRule.position = card.position + Vector2(0, rule_y)
	$Margin/Content/HeaderRule.size = Vector2(card.size.x, 1)
	var progress: Control = $Margin/Content/Progress
	var top := rule_y + 14
	if $Margin/Content/AnalysisError.visible:
		var error: Control = $Margin/Content/AnalysisError
		error.position = Vector2(at.x, top)
		error.size = Vector2(side.size.x, 0)
		top = error.position.y + error.get_combined_minimum_size().y + 8
	$Margin/Content/ProgressTitle.position = Vector2(at.x, top)
	$Margin/Content/ProgressTitle.size = Vector2(side.size.x, 22)
	var progress_text: Label = $Margin/Content/ProgressText
	var count_line := 22 if compact else 0
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT
	progress_text.position = Vector2(at.x, top + 2 + count_line)
	progress_text.size = Vector2(side.size.x, 20)
	progress.position = Vector2(at.x, top + 30 + count_line)
	progress.size = Vector2(side.size.x - 74, 10)
	var stop: Button = $Margin/Content/StopAnalysis
	stop.position = Vector2(at.x + side.size.x - 64, progress.position.y - 10)
	stop.size = Vector2(64, 32)
	var note: Label = $Margin/Content/ProgressNote
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.position = Vector2(at.x, top + 46 + count_line)
	note.size = Vector2(side.size.x, 0)
	var content_top := note.position.y + note.get_combined_minimum_size().y + 11 if progress.visible else top - 1
	$Margin/Content/ReviewBody/Side/HeaderSpace.custom_minimum_size.y = maxf(0, content_top - at.y - 8)
	var actions: HFlowContainer = $Margin/Content/Actions
	var shown := 0
	for button in actions.get_children():
		shown += 1 if button.visible else 0
	var rows := 2 if compact and shown > 2 else 1
	# Compact: two buttons per row, long labels wrapping inside them, as drawn.
	for button: Button in actions.get_children():
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = floorf((side.size.x - 8) / 2) - 1 if compact else 0.0
	var actions_height := rows * (44 if compact else 40) + (rows - 1) * 8
	actions.size = Vector2(side.size.x, actions_height)
	actions.position = Vector2(at.x, content.size.y - 14 - actions_height)
	# The navigation ends 8 px above the actions.
	# A state change can temporarily overflow the side's minimum height. Using that
	# inflated height here would grow the spacer again on every container sort.
	$Margin/Content/ReviewBody/Side/FooterSpace.custom_minimum_size.y = maxf(0, content.size.y + body.offset_bottom - actions.position.y + 4)
	$Margin/Content/ReviewBody/CardGap.custom_minimum_size.x = 8 if compact else 24


# Rules and the class table's name header follow the side column's children once they are placed.
func _place_rules() -> void:
	var content: Control = $Margin/Content
	var side: Control = $Margin/Content/ReviewBody/Side
	var at := side.global_position - content.global_position
	var card: Control = $Margin/Content/Card
	# Rules above the move list and the navigation run the card's full width.
	var moves: Control = $Margin/Content/ReviewBody/Side/Moves
	$Margin/Content/ListRule.position = Vector2(card.position.x, moves.position.y + at.y)
	$Margin/Content/ListRule.size = Vector2(card.size.x, 1)
	var navigation: Control = $Margin/Content/ReviewBody/Side/Navigation
	$Margin/Content/NavRule.position = Vector2(card.position.x, navigation.position.y + at.y - 8)
	$Margin/Content/NavRule.size = Vector2(card.size.x, 1)
	var heads := [$Margin/Content/WhiteHead, $Margin/Content/BlackHead]
	var counts: Control = $Margin/Content/ReviewBody/Side/Counts
	for index in 2:
		var cell: Control = counts.get_node("Best" + ("White" if index == 0 else "Black"))
		heads[index].visible = counts.visible
		heads[index].position = Vector2(at.x + counts.position.x + cell.position.x, at.y + $Margin/Content/ReviewBody/Side/ClassHelp.position.y)
		heads[index].size = Vector2(cell.size.x, $Margin/Content/ReviewBody/Side/ClassHelp.size.y)


func _resize_classes() -> void:
	var compact := _compact()
	var collapsed := compact or _line_active
	var side: Control = $Margin/Content/ReviewBody/Side
	side.custom_minimum_size.x = 190 if compact else 220
	# 1280 wide: a 680 board beside a 460 column, as drawn.
	side.size_flags_stretch_ratio = 0.4 if compact else 0.676
	var margin: MarginContainer = $Margin
	margin.add_theme_constant_override("margin_top", 12 if compact else 16)
	margin.add_theme_constant_override("margin_bottom", 12 if compact else 16)
	margin.add_theme_constant_override("margin_left", 16 if compact else 24)
	margin.add_theme_constant_override("margin_right", 16 + CARD_PADDING if compact else 24 + CARD_PADDING)
	var body: Control = $Margin/Content/ReviewBody
	body.offset_top = 36 if compact else 44
	body.offset_bottom = -body.offset_top
	# 800x600 as drawn: a narrower eval bar and navigation, each accuracy as a name then its card.
	_eval_bar.custom_minimum_size.x = 20 if compact else 28
	_graph.custom_minimum_size.y = 60 if compact else 72
	for button: Control in $Margin/Content/ReviewBody/Side/Navigation.get_children():
		button.custom_minimum_size.x = 44 if compact else 64
	var cards: GridContainer = $Margin/Content/ReviewBody/Side/Summary/AccuracyCards
	cards.move_child(cards.get_node("WhiteScore"), 1 if compact else 0)
	for side_name in ["WhiteScore", "BlackScore"]:
		cards.get_node(side_name).custom_minimum_size.x = 64 if compact else 88
	$Margin/Content/ReviewBody/Side/Summary/AccuracyCards.columns = 2 if compact else 4
	$Margin/Content/ReviewBody/Side/Summary.custom_minimum_size.y = 88 if compact else 44
	var unanalysed: bool = $Margin/Content/ReviewBody/Side/UnanalysedNotice.visible
	$Margin/Content/ReviewBody/Side/ClassToggle.visible = collapsed and not unanalysed
	$Margin/Content/ReviewBody/Side/Counts.visible = not collapsed and not unanalysed
	$Margin/Content/ReviewBody/Side/ClassHelp.visible = not unanalysed
	$Margin/Content/ReviewBody/Side/AccuracyHelp.visible = not unanalysed
	_moves.visible = true
	_graph.visible = not unanalysed
	_update_engine_lines()
	_update_summary()


# Both layouts keep two fixed-height rows; the SAN text yields width to score and depth.
func _create_engine_lines() -> void:
	var side := $Margin/Content/ReviewBody/Side
	_engine_lines = VBoxContainer.new()
	_engine_lines.name = "EngineLines"
	_engine_lines.add_theme_constant_override("separation", 2)
	side.add_child(_engine_lines)
	side.move_child(_engine_lines, side.get_node("Moves").get_index())
	for number in [1, 2]:
		var row := HBoxContainer.new()
		row.name = "Row%d" % number
		row.add_theme_constant_override("separation", 6)
		_engine_lines.add_child(row)
		var chip := Button.new()
		chip.name = "Score"
		chip.custom_minimum_size = Vector2(48, 24)
		chip.add_theme_font_size_override("font_size", 12)
		row.add_child(chip)
		chip.pressed.connect(func(): _play_engine_line(number - 1, 0))
		var pv := RichTextLabel.new()
		pv.name = "PV"
		pv.bbcode_enabled = true
		pv.scroll_active = false
		pv.custom_minimum_size.y = 24
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv.add_theme_font_size_override("normal_font_size", 12)
		row.add_child(pv)
		pv.meta_clicked.connect(func(index): _play_engine_line(number - 1, int(str(index))))
		var depth := Label.new()
		depth.name = "Depth"
		depth.add_theme_font_size_override("font_size", 10)
		depth.theme_type_variation = "MutedText"
		depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		depth.visible = number == 1
		row.add_child(depth)
	_engine_lines.resized.connect(_update_engine_lines)
	_engine_lines.hide()


func _request_rematch() -> void:
	_leaving_for_game = true
	rematch_requested.emit()


func _pause_for_line() -> void:
	_live_failed = false
	_game_error = $Margin/Content/AnalysisError.text
	_game_error_visible = $Margin/Content/AnalysisError.visible
	_line_progress_visible = $Margin/Content/Progress.visible
	_line_progress_value = $Margin/Content/Progress.value
	_direct_paused = _analysis_bridge != null
	if analysis_queue != null:
		analysis_queue.pause()
	if _direct_paused:
		_cancel_analysis()


func _search_shown_position() -> void:
	var fen: String = _board_view.game.board.to_fen()
	if _live_position.get("fen", "") != fen:
		_live_position = {"fen": fen}
	var terminal: bool = _board_view.game.is_over()
	if terminal:
		_live_position = {"fen": fen, "pv": [], "best_move": "",
				"terminal_score": -1000 if _board_view.game.reason == "checkmate" else 0}
	if _live_analysis == null:
		_live_bridge = analysis_bridge_factory.call()
		add_child(_live_bridge)
		_live_analysis = LiveAnalysis.new(_live_bridge)
		add_child(_live_analysis)
		_live_analysis.updated.connect(func(searched_fen: String, position: Dictionary):
			if _line_active and searched_fen == _board_view.game.board.to_fen():
				_live_position = position
				_update_engine_lines()
				_update_eval_bar()
				_update_board_annotations())
		_live_analysis.settled.connect(func(_fen: String, _position: Dictionary):
			_search_shown_position()
			_update_board_annotations())
		_live_analysis.failed.connect(func(message: String):
			_live_failed = true
			_live_position = {"fen": _board_view.game.board.to_fen()}
			$Margin/Content/AnalysisError.text = "Analysis: " + message
			$Margin/Content/AnalysisError.show()
			_update_engine_lines()
			_update_eval_bar()
			_update_board_annotations())
	if terminal:
		_live_analysis.remember(_live_position)
	var positions := _line_positions()
	var retained := []
	for position: Dictionary in positions:
		retained.append(position.fen)
		if position.has("pv"):
			_live_analysis.remember(position)
	_live_analysis.retain(retained)
	_refresh_line_classes()
	var required := _line_requirements(positions)
	if terminal and required.is_empty():
		_live_analysis.stop(false)
	elif not _live_failed:
		_live_analysis.search("" if terminal else fen, required)


# Only walk farther into game history when an earlier undecided class needs it.
func _line_requirements(positions: Array) -> Array:
	if _line_index == 0:
		return []
	var moves := _game_moves.slice(0, _ply)
	moves.append_array(_line_moves)
	var classes := Classification.evaluate(moves, {"positions": positions},
			_catalog, _repertoire, _colour, _check_repertoire)
	var first := maxi(0, _ply - 1)
	while first > 0 and classes[first] == null and positions[first].has("pv") and positions[first + 1].has("pv"):
		first -= 1
	var required := []
	for i in range(first, _ply + _line_index):
		if not positions[i].has("pv"):
			required.append(positions[i].fen)
	return required


# Keep the game prefix so Book, Repertoire, Great and Miss see the same history.
func _line_positions() -> Array:
	var positions := _positions.slice(0, _ply + 1).duplicate(true)
	var board = Board.from_fen(_positions[_ply].fen)
	for move in _line_moves:
		board.make_move(move)
		positions.append({"fen": board.to_fen()})
	if _live_analysis != null:
		for i in positions.size():
			if not positions[i].has("pv"):
				var cached: Dictionary = _live_analysis.result(positions[i].fen)
				if not cached.is_empty():
					positions[i] = cached
	return positions


func _refresh_line_classes() -> void:
	if not _line_active:
		return
	var moves := _game_moves.slice(0, _ply)
	moves.append_array(_line_moves)
	var classes := Classification.evaluate(moves, {"positions": _line_positions()},
			_catalog, _repertoire, _colour, _check_repertoire)
	_line_classes.resize(_line_moves.size())
	for i in _line_moves.size():
		if _line_classes[i] == null and classes[_ply + i] != null:
			_line_classes[i] = classes[_ply + i]
		if i < _line_rows.size() and _line_classes[i] != null:
			_line_rows[i].set_icon(1, _class_icon(_line_classes[i].class))


func _stop_live_process() -> void:
	if _live_analysis != null:
		_live_analysis.stop()
		_live_analysis.queue_free()
		_live_analysis = null
	if _live_bridge != null:
		_live_bridge.queue_free()
		_live_bridge = null
	_live_position.clear()


func _exit_tree() -> void:
	_stop_live_process()


func _finish_line_analysis() -> void:
	_stop_live_process()
	$Margin/Content/AnalysisError.text = _game_error
	$Margin/Content/AnalysisError.visible = _game_error_visible
	if analysis_queue != null and not _leaving_for_game:
		analysis_queue.resume()
	if _direct_paused:
		_direct_paused = false
		if not _leaving_for_game and visible:
			open_analysis(_analysis_path, _draw_at_end)


func _play_engine_line(number: int, last_move: int) -> void:
	var lines: Array = _shown_engine_position().get("pv", [])
	if number >= lines.size():
		return
	# Freeze the clicked PV before each played move replaces the displayed position.
	var moves: Array = lines[number].get("moves", []).duplicate()
	for i in mini(last_move + 1, moves.size()):
		if not _board_view.play(moves[i]):
			break


func _shown_engine_position() -> Dictionary:
	if _line_active:
		return _live_position
	return _positions[_ply] if not _positions.is_empty() else {}


func _update_engine_lines() -> void:
	if _engine_lines == null or _positions.is_empty():
		return
	var position := _shown_engine_position()
	_engine_lines.visible = _moves.visible and (_line_active or position.has("pv") or _board_view.game.is_over())
	if not _engine_lines.visible:
		return
	if _board_view.game.is_over():
		var first := _engine_lines.get_node("Row1")
		first.show()
		first.get_node("Score").hide()
		first.get_node("Depth").text = ""
		var reason: String = _board_view.game.reason
		first.get_node("PV").text = "Checkmate" if reason == "checkmate" else ("Stalemate" if reason == "stalemate" else "Draw")
		_engine_lines.get_node("Row2").hide()
		return
	var lines: Array = position.get("pv", [])
	var white: bool = _board_view.game.board.side_to_move == "w"
	for i in 2:
		var row := _engine_lines.get_child(i)
		row.show()
		var chip: Button = row.get_node("Score")
		var pv: RichTextLabel = row.get_node("PV")
		var depth: Label = row.get_node("Depth")
		depth.text = ""
		pv.text = ""
		chip.visible = i < lines.size()
		if i >= lines.size():
			pv.text = "[color=#a8a49c]Stockfish is thinking…[/color]" if _line_active else ""
			continue
		var line: Dictionary = lines[i]
		var score: int = line.get("cp", 1000 if line.get("mate", 0) > 0 else -1000)
		if not white:
			score = -score
		chip.text = "M%d" % absi(int(line.mate)) if line.has("mate") else ("+" if score > 0 else "") + "%.1f" % (score / 100.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ece9e4") if score >= 0 else Color("30302d")
		style.set_corner_radius_all(3)
		for state in ["normal", "hover", "pressed", "focus"]:
			chip.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			chip.add_theme_color_override(state, Color("242321") if score >= 0 else Color("ece9e4"))
		if i == 0:
			depth.text = "depth %d" % int(line.get("depth", 0))
		var board = _board_view.game.board.copy()
		var text := ""
		var markup := ""
		var move_index := 0
		var font := pv.get_theme_font("normal_font")
		var width := maxf(0, _engine_lines.size.x - 48 - 12 - (depth.get_minimum_size().x if i == 0 else 0))
		for move: String in line.get("moves", []):
			if not move in board.legal_moves():
				break
			var san: String = board.san(move)
			var next := text + (" " if not text.is_empty() else "") + san
			if font.get_string_size(next + " …", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > width:
				markup += " …"
				break
			markup += (" " if not text.is_empty() else "") + "[url=%d]%s[/url]" % [move_index, san]
			move_index += 1
			text = next
			board.make_move(move)
		pv.text = markup.strip_edges()


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
	_update_summary()
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
		receive_positions(positions)
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
			receive_positions(saved)
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


func _stop_analysis() -> void:
	_direct_paused = false
	if analysis_queue != null and _queue_path in analysis_queue.pending():
		analysis_queue.remove(_queue_path)
	else:
		_cancel_analysis()
		_restore_analysis()


# Rebuild from FENs so streamed PVs and classifications cannot survive a stop.
# The analyser writes atomically on completion, so an older cache is still safe.
func _restore_analysis() -> void:
	$Margin/Content/Progress.hide()
	if not (_line_active and _live_failed):
		$Margin/Content/AnalysisError.hide()
	$Margin/Content/ProgressText.text = "0 of %d moves" % _game_moves.size()
	for i in _classes.size():
		if _classes[i] != null:
			var column := i % 2 + 1
			var tooltip: String = _move_rows[i].get_tooltip_text(column)
			_move_rows[i].set_tooltip_text(column, tooltip.trim_prefix(_classes[i].class + ": "))
	for i in _positions.size():
		_positions[i] = {"fen": _positions[i].fen}
	var cached := Analyser.read_analysis(_analysis_path, "Stockfish 19", Tunables.ANALYSIS_NODES)
	var positions = cached.get("data", {}).get("positions", [])
	var complete: bool = cached.state == "analysed" and positions is Array and positions.size() == _positions.size()
	if complete:
		for i in positions.size():
			if not positions[i] is Dictionary or not positions[i].has("pv") or positions[i].get("fen") != _positions[i].fen:
				complete = false
				break
	$Margin/Content/ReviewBody/Side/UnanalysedNotice.visible = not complete
	$Margin/Content/ReviewBody/Side/Analyze.visible = not complete
	if complete:
		receive_positions(positions)
	else:
		_refresh_classes()
		_update_summary()
		_update_board_annotations()
		_update_eval_bar()
	_resize_classes()


func _cancel_analysis() -> void:
	_waiting_engine = false
	if _analyser != null:
		for event in ["position_ready", "progress", "finished"]:
			for connection in _analyser.get_signal_connection_list(event):
				_analyser.disconnect(event, connection.callable)
		_analyser.cancel()
		_analyser.queue_free()
		_analyser = null
	if _analysis_bridge != null:
		_analysis_bridge.stop()
		_analysis_bridge.queue_free()
		_analysis_bridge = null


# Handle review shortcuts before focused controls consume them as GUI input.
func _input(event: InputEvent) -> void:
	if settings_panel and settings_panel.visible:
		return
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if not _from_history:
			_request_rematch()
	elif visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE and (_line_active or _from_history):
		get_viewport().set_input_as_handled()
		if _line_active:
			_back_to_game()
		else:
			back_history_requested.emit()
	elif visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_F:
		get_viewport().set_input_as_handled()
		_board_view.flipped = not _board_view.flipped
		_update_player_labels()
		_update_eval_bar()
	elif visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode in [KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()
		_step(-1 if event.keycode == KEY_LEFT else 1)


func _update_player_labels() -> void:
	var side: float = minf(_board_view.size.x, _board_view.size.y)
	var corner: Vector2 = (_board_view.size - Vector2.ONE * side) / 2.0
	var top: Label = _board_view.get_node("TopPlayer")
	var bottom: Label = _board_view.get_node("BottomPlayer")
	top.text = _player_names[0 if _board_view.flipped else 1]
	bottom.text = _player_names[1 if _board_view.flipped else 0]
	# Each name row is centred 26 px off the board edge, the name 24 px in from the board's left.
	top.size.y = 0
	bottom.size.y = 0
	top.position = corner + Vector2(24, -26 - top.get_combined_minimum_size().y / 2)
	bottom.position = corner + Vector2(24, side + 26 - bottom.get_combined_minimum_size().y / 2)
	for entry in [["TopDot", top, _board_view.flipped], ["BottomDot", bottom, not _board_view.flipped]]:
		var dot: Panel = _board_view.get_node(entry[0])
		dot.size = Vector2(14, 14)
		dot.position = Vector2(corner.x, entry[1].position.y + entry[1].get_combined_minimum_size().y / 2 - 7)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ece9e4") if entry[2] else Color("141412")
		style.border_color = Color("8c887f")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", style)


# A single disposable variation branches from _ply; its cursor may also sit at the branch.
func _on_board_move(_san: String) -> void:
	var move: String = _board_view.game.moves[-1]
	if not _line_active:
		if _ply < _game_moves.size() and move == _game_moves[_ply]:
			_show_ply(_ply + 1, false, true)
			return
		_line_active = true
		_line_index = 0
		_line_moves.clear()
		_line_classes.clear()
		_pause_for_line()
		_resize_classes()
	if _line_index >= _line_moves.size() or _line_moves[_line_index] != move:
		_line_moves.resize(_line_index)
		_line_classes.resize(_line_index)
		_line_moves.append(move)
	_line_index += 1
	_build_line_rows()
	_show_line(_line_index, false, true)


func _build_line_rows() -> void:
	for row in _line_rows:
		row.free()
	_line_rows.clear()
	var root := _moves.get_root()
	var anchor: TreeItem = _move_rows[_ply - 1] if _ply > 0 else null
	var board = Board.from_fen(_positions[_ply].fen)
	for i in _line_moves.size():
		var row := _moves.create_item(root)
		if anchor:
			row.move_after(anchor)
		elif root.get_first_child() != row:
			row.move_before(root.get_first_child())
		anchor = row
		var number := _ply + i
		row.set_text(1, "%d%s%s" % [number / 2 + 1, ". " if number % 2 == 0 else "… ", board.san(_line_moves[i])])
		row.set_icon_max_width(1, 18)
		if i < _line_classes.size() and _line_classes[i] != null:
			row.set_icon(1, _class_icon(_line_classes[i].class))
		row.set_expand_right(1, true)
		row.set_custom_color(1, Color("7db8ee"))
		row.set_custom_bg_color(1, Color("263e50"), true)
		row.set_metadata(1, {"index": i + 1})
		for column in [0, 2]:
			row.set_selectable(column, false)
		_line_rows.append(row)
		board.make_move(_line_moves[i])
	var back := _moves.create_item(root)
	if anchor:
		back.move_after(anchor)
	back.set_text(1, "Back to game")
	back.set_custom_color(1, Color("7db8ee"))
	back.set_metadata(1, {"back": true})
	# The text and the adjacent button both return to the game.
	back.add_button(2, _svg('<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#7db8ee" stroke-width="2"><path d="M10 5l-7 7 7 7M3 12h12a6 6 0 0 1 0 12"/></svg>'), 0, false, "Back to game")
	_line_rows.append(back)


func _show_line(index: int, announce := false, already_played := false) -> void:
	if not _line_active:
		return
	var before := _line_index
	_line_index = clampi(index, 0, _line_moves.size())
	var position = Game.new()
	for i in _ply:
		position.play(_game_moves[i])
	var san := ""
	for i in _line_index:
		if i == _line_index - 1:
			san = position.board.san(_line_moves[i])
		position.play(_line_moves[i])
	if not already_played:
		_board_view.game = position
	_moves.set_block_signals(true)
	if _line_index > 0:
		_line_rows[_line_index - 1].select(1)
	else:
		_moves.deselect_all()
	_moves.set_block_signals(false)
	if announce and before != _line_index and _line_index > 0:
		_board_view.request_move_sounds(san)
	_search_shown_position()
	_update_board_annotations()
	_update_eval_bar()
	_update_engine_lines()
	_board_view.queue_redraw()


func _step(delta: int) -> void:
	if _line_active:
		_show_line(_line_index + delta, true)
	else:
		_show_ply(_ply + delta, true)


func _discard_line() -> void:
	if not _line_active:
		return
	_line_active = false
	_finish_line_analysis()
	_line_index = 0
	_line_moves.clear()
	_line_classes.clear()
	for row in _line_rows:
		row.free()
	_line_rows.clear()
	_resize_classes()


func _back_to_game() -> void:
	_show_ply(_ply)


# Navigation (announce) plays the shown last move's sounds once, as the game did; opening the review is silent.
func _show_ply(ply: int, announce := false, already_played := false) -> void:
	_discard_line()
	var before := _ply
	_ply = clampi(ply, 0, _game_moves.size())
	_moves.set_block_signals(true)
	if _ply > 0 and _ply <= _move_rows.size():
		_move_rows[_ply - 1].select((_ply - 1) % 2 + 1)
		_moves.ensure_cursor_is_visible.call_deferred()
	elif _moves.get_selected() != null:
		_moves.deselect_all()
	_moves.set_block_signals(false)
	var position = Game.new()
	var san := ""
	for i in _ply:
		if i == _ply - 1:
			san = position.board.san(_game_moves[i])
		position.play(_game_moves[i])
	if not already_played:
		_board_view.game = position
	if announce and _ply != before and _ply > 0:
		_board_view.request_move_sounds(san)
	_update_board_annotations()
	_board_view.queue_redraw()
	_update_eval_bar()
	_update_engine_lines()


func receive_position(index: int, position: Dictionary) -> void:
	if index < 0 or index >= _positions.size():
		return
	_positions[index].merge(position, true)
	_positions_changed()


func receive_positions(positions: Array) -> void:
	for i in mini(positions.size(), _positions.size()):
		_positions[i].merge(positions[i], true)
	_positions_changed()


func _positions_changed() -> void:
	var settled := 0
	for i in range(1, _positions.size()):
		if _positions[i - 1].has("pv") and _positions[i].has("pv"):
			settled += 1
	$Margin/Content/ProgressText.text = "%d of %d moves" % [settled, _game_moves.size()]
	_refresh_classes()
	_refresh_line_classes()
	_update_summary()
	_update_board_annotations()
	_update_eval_bar()
	_update_engine_lines()


func _update_summary() -> void:
	var counts := {}
	for label in CLASS_NAMES:
		counts[label] = [0, 0]
	for i in _classes.size():
		if _classes[i] != null:
			counts[_classes[i].class][i % 2] += 1
	var table: GridContainer = $Margin/Content/ReviewBody/Side/Counts
	for label in CLASS_NAMES:
		for side in 2:
			var value: Label = table.get_node(label + ("White" if side == 0 else "Black"))
			value.text = str(counts[label][side])
			value.add_theme_color_override("font_color", Color("8a857c") if counts[label][side] == 0 else Color("ece9e4"))
	var summary: Label = $Margin/Content/ReviewBody/Side/Summary
	$Margin/Content/ReviewBody/Side/AccuracyHelp.hide()
	if _positions.is_empty():
		summary.hide()
		return
	for position in _positions:
		if not position.has("pv"):
			summary.hide()
			return
	var accuracy: Dictionary = Accuracy.evaluate({"positions": _positions})
	var white := "–" if accuracy.white == null else "%.1f%%" % accuracy.white
	var black := "–" if accuracy.black == null else "%.1f%%" % accuracy.black
	summary.text = "White: %s  %s\nBlack: %s  %s" % [_player_names[0], white, _player_names[1], black]
	for side in ["White", "Black"]:
		var index := 0 if side == "White" else 1
		summary.get_node("AccuracyCards/" + side + "Score/Value").text = white if index == 0 else black
		summary.get_node("AccuracyCards/" + side + "Name").text = _player_names[index]
	summary.visible = not $Margin/Content/ReviewBody/Side/UnanalysedNotice.visible and not (_compact() and $Margin/Content/ReviewBody/Side/Counts.visible)
	$Margin/Content/ReviewBody/Side/AccuracyHelp.visible = summary.visible


func _refresh_classes() -> void:
	_classes = Classification.evaluate(_game_moves, {"positions": _positions}, _catalog, _repertoire, _colour, _check_repertoire)
	for i in _classes.size():
		var icon: Texture2D = _class_icon("Pending" if _classes[i] == null else _classes[i].class)
		_move_rows[i].set_icon(i % 2 + 1, icon)
		if _classes[i] != null:
			var detail: String = _move_rows[i].get_tooltip_text(i % 2 + 1)
			if not detail.begins_with(_classes[i].class + ":"):
				_move_rows[i].set_tooltip_text(i % 2 + 1, _classes[i].class + ": " + detail)


func _svg(svg: String) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)


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
			_icons[label] = load(path) if ResourceLoader.exists(path) else ThemeLoader.load_texture(path, 4.0)
	return _icons[label]


func _update_board_annotations() -> void:
	_board_view.review_square = ""
	_board_view.review_arrow = ""
	_board_view.review_icon = null
	_board_view.best_move_arrow = ""
	if _line_active:
		if _line_index > 0:
			var before: Dictionary = _line_positions()[_ply + _line_index - 1]
			if before.has("pv"):
				_board_view.review_arrow = before.get("best_move", "")
			if _line_classes.size() >= _line_index and _line_classes[_line_index - 1] != null:
				_board_view.review_square = _line_moves[_line_index - 1].substr(2, 2)
				_board_view.review_icon = _class_icon(_line_classes[_line_index - 1].class)
		if best_move_arrow_enabled and not _board_view.game.is_over():
			_board_view.best_move_arrow = _live_position.get("best_move", "")
		_board_view.queue_redraw()
		return
	if best_move_arrow_enabled and not _positions.is_empty() and not _board_view.game.is_over():
		_board_view.best_move_arrow = _positions[_ply].get("best_move", "")
	if _ply > 0:
		var before: Dictionary = _positions[_ply - 1]
		_board_view.review_arrow = before.get("best_move", "")
		if _classes.size() >= _ply and _classes[_ply - 1] != null:
			_board_view.review_square = _game_moves[_ply - 1].substr(2, 2)
			_board_view.review_icon = _class_icon(_classes[_ply - 1].class)
	_board_view.queue_redraw()


func _update_eval_bar() -> void:
	_graph.positions = _positions
	_graph.classes = _classes
	_graph.current_ply = _ply
	_graph.flipped = _board_view.flipped
	_graph.queue_redraw()
	_eval_bar.flipped = _board_view.flipped
	_eval_bar.white_fraction = 0.5
	_eval_bar.get_node("Score").text = ""
	var position := _shown_engine_position()
	if not position.has("pv"):
		return
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
	_discard_line()
	_leaving_for_game = false
	_from_history = false
	_queue_was_pending = false
	$Margin/Content/ReviewBody/Side/UnanalysedNotice.hide()
	_resize_classes()
	$Margin/Content/Actions/Rematch.show()
	$Margin/Content/Actions/Setup.show()
	$Margin/Content/Actions/BackHistory.hide()
	$Margin/Content/ReviewBody/Side/Analyze.hide()
	$Margin/Content/AnalysisError.hide()
	_game_moves = game.moves.duplicate()
	$Margin/Content/ProgressText.text = "0 of %d moves" % _game_moves.size()
	_classes = []
	_move_rows = []
	_catalog = catalog
	_repertoire = repertoire
	_colour = settings.colour
	var headers: Dictionary = Pgn.finished_game(game, clocks, settings).headers
	_player_names = [headers.White, headers.Black]
	# The class table's columns are narrow: a Maia level reads as "Maia", as drawn.
	for index in 2:
		get_node("Margin/Content/" + ["WhiteHead", "BlackHead"][index]).text = "Maia" if _player_names[index].begins_with("Maia ") else _player_names[index]
	_check_repertoire = check_repertoire
	_positions = []
	var position = Game.new()
	_positions.append({"fen": position.board.to_fen()})
	for move in _game_moves:
		position.play(move)
		_positions.append({"fen": position.board.to_fen()})
	_board_view.flipped = settings.colour == "b"
	_update_player_labels()
	_show_ply(_game_moves.size())
	var moves: int = (game.moves.size() + 1) / 2
	_result.text = "%s \u00b7 %s \u00b7 %d %s" % [settings.get("control", ""), result_text.replace("\nSpace for a rematch", ""), moves, "move" if moves == 1 else "moves"]
	_moves.clear()
	_exit_rows.clear()
	_clock_cells.clear()
	var root := _moves.create_item()
	var board = Board.from_fen(Pgn.START)
	var badges := Badges.evaluate(game.moves, catalog, repertoire, settings.colour, check_repertoire)
	var row: TreeItem
	for i in game.moves.size():
		if i % 2 == 0:
			row = _moves.create_item(root)
			row.set_text(0, "%d." % (i / 2 + 1))
			row.set_custom_color(0, Color("a8a49c"))
		if i < clocks.size() and clocks[i] >= 0:
			_clock_cells.append([row, i % 2 + 1, Clock.format(clocks[i])])
		row.set_icon_max_width(i % 2 + 1, 18)
		row.set_text(i % 2 + 1, board.san(game.moves[i]))
		row.set_metadata(i % 2 + 1, i + 1)
		if badges[i].repertoire or badges[i].book:
			row.set_icon(i % 2 + 1, _class_icon("Repertoire" if badges[i].repertoire else "Book"))
		_move_rows.append(row)
		var text := _badge_text(badges[i])
		row.set_tooltip_text(i % 2 + 1, text)
		if badges[i].left_repertoire:
			var exit_row := _moves.create_item(root)
			var expected := PackedStringArray()
			for move in badges[i].expected:
				expected.append("%d%s%s" % [i / 2 + 1, "." if i % 2 == 0 else "…", move])
			exit_row.set_text(1, "Left repertoire · " + ("expected " + ", ".join(expected) if not expected.is_empty() else "no continuation in repertoire"))
			exit_row.set_expand_right(1, true)
			_exit_rows.append(exit_row)
			exit_row.set_icon(1, _class_icon("Repertoire"))
			exit_row.set_icon_max_width(1, 16)
			exit_row.set_custom_color(1, Color("7db8ee"))
			exit_row.set_custom_font_size(1, 12)
			exit_row.set_custom_bg_color(1, Color("3f94e0"), true)
			for column in 3:
				exit_row.set_selectable(column, false)
		board.make_move(game.moves[i])
	_update_summary()
	_show_ply(_game_moves.size())
	_fit_exit_rows()
	_pgn = Pgn.write(Pgn.finished_game(game, clocks, settings))
	_url = lichess_url(game)
	show()


func present_history(path: String, analysis_path: String, draw_at_end: bool) -> void:
	_queue_path = path
	_from_history = true
	_analysis_path = analysis_path
	_history_draw = draw_at_end
	_pgn = FileAccess.get_file_as_string(path)
	var saved := Pgn.parse(_pgn)
	if saved.error.is_empty() and saved.games.size() == 1:
		var time_control: String = saved.games[0].headers.get("TimeControl", "")
		for control in Clock.CONTROLS:
			var values: Array = Clock.CONTROLS[control]
			if time_control == "%d+%d" % [values[0] / 1000, values[1] / 1000]:
				_result.text = control + _result.text.substr(_result.text.find(" ·"))
				break
	$Margin/Content/Actions/Rematch.hide()
	$Margin/Content/Actions/Setup.hide()
	$Margin/Content/Actions/BackHistory.show()
	var cached := Analyser.read_analysis(analysis_path, "Stockfish 19", Tunables.ANALYSIS_NODES)
	var positions = cached.get("data", {}).get("positions", [])
	if cached.state == "analysed" and positions is Array and positions.size() == _positions.size():
		receive_positions(positions)
	else:
		$Margin/Content/ReviewBody/Side/Analyze.show()
		$Margin/Content/ReviewBody/Side/UnanalysedNotice.show()
		$Margin/Content/ReviewBody/Side/Summary.hide()
		_resize_classes()
	if analysis_queue != null and path in analysis_queue.pending():
		$Margin/Content/ReviewBody/Side/Analyze.hide()
		open_analysis(analysis_path, draw_at_end)


# Lichess-style: small muted clock at each move cell's right end, dropped where the move would run into it.
# An overlay paints them: the tree draws its selection chip over anything drawn in a cell.
func _draw_clocks() -> void:
	var overlay: Control = _moves.get_node("Clocks")
	var font := get_theme_font("font", "Label")
	var move_font := _moves.get_theme_font("font")
	for cell in _clock_cells:
		var rect: Rect2 = _moves.get_item_area_rect(cell[0], cell[1])
		rect.position -= overlay.position
		if rect.end.y < 0 or rect.position.y > overlay.size.y:
			continue
		var width := font.get_string_size(cell[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var san := move_font.get_string_size(cell[0].get_text(cell[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, _moves.get_theme_font_size("font_size")).x
		if rect.size.x - 6 - width < 6 + 4 + 18 + 6 + san + 8:
			continue
		var baseline := rect.position.y + (rect.size.y + font.get_ascent(11) - font.get_descent(11)) / 2
		overlay.draw_string(font, Vector2(rect.end.x - 6 - width, baseline), cell[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a8a49c"))


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
	if visible and not _line_active and path == _queue_path and path in analysis_queue.pending():
		receive_position(index, position)


func _queue_changed() -> void:
	if not visible or analysis_queue == null or _queue_path.is_empty():
		return
	var pending: bool = _queue_path in analysis_queue.pending()
	if _queue_was_pending and not pending:
		_queue_was_pending = false
		_restore_analysis()
	_queue_was_pending = pending
	if _line_active:
		$Margin/Content/Progress.visible = pending and _line_progress_visible
		$Margin/Content/Progress.value = _line_progress_value
		return
	var active: bool = analysis_queue.current() == _queue_path and pending
	$Margin/Content/Progress.visible = active
	if active:
		$Margin/Content/Progress.value = analysis_queue.percent
	if pending and not analysis_queue.error.is_empty():
		_analysis_error(analysis_queue.error)
