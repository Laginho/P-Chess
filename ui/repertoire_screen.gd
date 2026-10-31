extends PopupPanel

signal saved(name: String)

const Game = preload("res://core/game.gd")
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


func present() -> void:
	if not importer.saved.is_connected(_saved):
		importer.saved.connect(_saved)
	_refresh()
	popup_centered(Vector2i(680, 540))


func _refresh() -> void:
	_list.clear()
	_line_list.clear()
	_lines.clear()
	_selection = ""
	$Margin/Form/Buttons/Edit.disabled = true
	_line = -1
	_board.game = null
	_board.queue_redraw()
	_status.text = ""
	for name in repertoire.names():
		_list.add_item(name)


func _select_repertoire(index: int) -> void:
	_selection = _list.get_item_text(index)
	$Margin/Form/Buttons/Edit.disabled = true
	var error: String = repertoire.load_saved(_selection)
	_line_list.clear()
	_lines.clear()
	_line = -1
	_board.game = null
	_board.queue_redraw()
	_status.text = error
	if not error.is_empty():
		return
	$Margin/Form/Buttons/Edit.disabled = false
	_lines = repertoire.lines.duplicate(true)
	_board.flipped = repertoire.colour == "b"
	_show_names()
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
		_line_list.add_item(label)
	if _line >= 0 and _line < _line_list.item_count:
		_line_list.select(_line)


func _select_line(index: int) -> void:
	_line = index
	_ply = _lines[index].moves.size()
	_show_position()


func _show_position() -> void:
	var line: Dictionary = _lines[_line]
	_board.game = Game.new(line.positions[_ply] + " 0 1")
	_board.game.moves = line.moves.slice(0, _ply)
	_board.queue_redraw()


func _input(event: InputEvent) -> void:
	if visible and not _picker.visible and not _editor.visible:
		_unhandled_key_input(event)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _line < 0 or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		_ply = clampi(_ply + (-1 if event.keycode == KEY_LEFT else 1), 0, _lines[_line].moves.size())
		_show_position()
		get_viewport().set_input_as_handled()


func _saved(name: String) -> void:
	_refresh()
	saved.emit(name)

