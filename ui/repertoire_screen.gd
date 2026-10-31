extends PopupPanel

signal saved(name: String)

const Game = preload("res://core/game.gd")
const Board = preload("res://core/board.gd")
var repertoire
var _lines := []
var _line := -1
var _ply := 0
var _selection := ""

@onready var _list: ItemList = $Margin/Form/List
@onready var _picker = $OpeningPicker
@onready var _editor = $RepertoireEditor
# Child of this popup, so closing it hands focus back here instead of closing the screen too.
@onready var importer = $RepertoireImport
@onready var _line_list: ItemList = $Margin/Form/Viewer/Lines
@onready var _board = $Margin/Form/Viewer/Board
@onready var _status: Label = $Margin/Form/Status


func _ready() -> void:
	$Margin/Form/Buttons/Edit.pressed.connect(func(): _editor.present(repertoire, _selection, _line))
	_editor.saved.connect(_saved)
	$Margin/Form/Buttons/Import.pressed.connect(func(): importer.present())
	$Margin/Form/Buttons/FromOpenings.pressed.connect(func(): _picker.present_repertoire(repertoire))
	$Margin/Form/Buttons/Back.pressed.connect(hide)
	_picker.saved.connect(_saved)
	_list.item_selected.connect(_select_repertoire)
	_line_list.item_selected.connect(_select_line)
	$Margin/Form/Navigation/Previous.pressed.connect(func(): _step(-1))
	$Margin/Form/Navigation/Next.pressed.connect(func(): _step(1))


func present() -> void:
	if not importer.saved.is_connected(_saved):
		importer.saved.connect(_saved)
	_refresh()
	popup_centered(get_tree().root.size - Vector2i(32, 32))


func _refresh() -> void:
	_list.clear()
	for card in $Margin/Form/Viewer/CardScroll/Cards.get_children():
		card.free()
	_line_list.clear()
	$Margin/Form/Viewer/Lines/LineHeading.text = ""
	$Margin/Form/Viewer/Lines/LineDetail.text = ""
	_lines.clear()
	_selection = ""
	$Margin/Form/Buttons/Edit.disabled = true
	_line = -1
	_board.game = null
	_board.queue_redraw()
	_status.text = ""
	$Margin/Form/Navigation/Moves.text = ""
	for name in repertoire.names():
		_list.add_item(name)
		var index := _list.item_count - 1
		var card := HBoxContainer.new()
		$Margin/Form/Viewer/CardScroll/Cards.add_child(card)
		var select := Button.new()
		var saved = repertoire.get_script().new()
		saved.storage_dir = repertoire.storage_dir
		var error: String = saved.load_saved(name)
		var detail := ""
		if error.is_empty():
			detail = "%d lines" % saved.lines.size()
			if saved.source == "openings":
				detail += " · from openings"
			elif saved.source == "pgn":
				detail += " · imported PGN"
		select.text = ("● " if saved.colour == "w" else "○ ") + name + "\n" + detail
		select.alignment = HORIZONTAL_ALIGNMENT_LEFT
		select.toggle_mode = true
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.pressed.connect(func(): _select_repertoire(index))
		card.add_child(select)
		var edit := Button.new()
		edit.name = "Edit"
		edit.text = "✎"
		edit.tooltip_text = "Edit " + name
		edit.pressed.connect(func():
			_select_repertoire(index)
			if $Margin/Form/Buttons/Edit.disabled == false:
				_editor.present(repertoire, _selection, _line)
		)
		card.add_child(edit)


func _select_repertoire(index: int) -> void:
	_selection = _list.get_item_text(index)
	for i in $Margin/Form/Viewer/CardScroll/Cards.get_child_count():
		$Margin/Form/Viewer/CardScroll/Cards.get_child(i).get_child(0).button_pressed = i == index
	$Margin/Form/Buttons/Edit.disabled = true
	var error: String = repertoire.load_saved(_selection)
	_line_list.clear()
	$Margin/Form/Viewer/Lines/LineHeading.text = ""
	$Margin/Form/Viewer/Lines/LineDetail.text = ""
	_lines.clear()
	_line = -1
	_board.game = null
	_board.queue_redraw()
	_status.text = error
	if not error.is_empty():
		return
	$Margin/Form/Buttons/Edit.disabled = false
	_lines = repertoire.lines.duplicate(true)
	$Margin/Form/Viewer/Lines/LineHeading.text = _selection
	$Margin/Form/Viewer/Lines/LineDetail.text = "As %s · %d %s" % ["White" if repertoire.colour == "w" else "Black", _lines.size(), "line" if _lines.size() == 1 else "lines"]
	_board.flipped = repertoire.colour == "b"
	_show_names()
	if not _lines.is_empty():
		_select_line(0)
	var selected := _selection
	error = await _picker.ensure_catalog()
	if selected == _selection and error.is_empty():
		_show_names()


func _show_names() -> void:
	_line_list.clear()
	for line in _lines:
		var label: String = " ".join(line.moves)
		for entry in _picker.book.entries:
			if entry.moves == line.moves and entry.positions[0] == line.positions[0]:
				label = entry.name
				break
		_line_list.add_item(label + "\n" + _move_text(line))
	if _line >= 0 and _line < _line_list.item_count:
		_line_list.select(_line)


func _select_line(index: int) -> void:
	_line = index
	_line_list.select(index)
	_ply = _lines[index].moves.size()
	_show_position()


func _show_position() -> void:
	var line: Dictionary = _lines[_line]
	_board.game = Game.new(line.positions[_ply] + " 0 1")
	_board.game.moves = line.moves.slice(0, _ply)
	_board.queue_redraw()
	$Margin/Form/Navigation/Moves.text = _move_text(line, true)
	$Margin/Form/Navigation/Previous.disabled = _ply == 0
	$Margin/Form/Navigation/Next.disabled = _ply == line.moves.size()


func _move_text(line: Dictionary, highlight := false) -> String:
	var board = Board.from_fen(line.positions[0] + " 0 1")
	var moves := PackedStringArray()
	for i in line.moves.size():
		var san: String = board.san(line.moves[i])
		var text := ("%d." % (i / 2 + 1) if i % 2 == 0 else "") + san
		if highlight and i == _ply - 1:
			text = "[bgcolor=#45423d]" + text + "[/bgcolor]"
		moves.append(text)
		board.make_move(line.moves[i])
	return " ".join(moves)


func _step(delta: int) -> void:
	if _line < 0:
		return
	_ply = clampi(_ply + delta, 0, _lines[_line].moves.size())
	_show_position()


func _input(event: InputEvent) -> void:
	if visible and not _picker.visible and not _editor.visible:
		_unhandled_key_input(event)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _line < 0 or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		_step(-1 if event.keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()


func _saved(name: String) -> void:
	_refresh()
	saved.emit(name)

