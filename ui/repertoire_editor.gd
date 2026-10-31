extends PopupPanel

signal saved(name: String)

const Game = preload("res://core/game.gd")
const Repertoire = preload("res://bot/repertoire.gd")
const Board = preload("res://core/board.gd")
const TRASH = preload("res://ui/icons/trash.svg")

# Analysis positions accept legal moves even after an automatic draw.
class EditorGame extends Game:
	func is_over() -> bool:
		return false

var repertoire
var saved_name := ""
var edited := {}
var root_key := ""
var path := PackedStringArray()
var _move_buttons: Array[Button] = []

@onready var board = $Margin/Form/Content/Board
@onready var tree: ScrollContainer = $Margin/Form/Content/Card/Panel/Tree
@onready var rows: VBoxContainer = $Margin/Form/Content/Card/Panel/Tree/Rows
@onready var status: Label = $Margin/Form/Content/Card/Panel/Status


func _ready() -> void:
	board.move_played.connect(_played)
	$Margin/Form/Content/Card/Panel/Buttons/Save.pressed.connect(save)
	$Margin/Form/Content/Card/Panel/Buttons/Cancel.pressed.connect(hide)


func present(source, name: String, line: int = -1) -> void:
	repertoire = source
	saved_name = name
	edited = source.tree.duplicate(true)
	root_key = source.lines[line].positions[0] if line >= 0 else edited.keys()[0]
	path = source.lines[line].moves.duplicate() if line >= 0 else PackedStringArray()
	board.flipped = source.colour == "b"
	$Margin/Form/Content/Card/Panel/HeadingRow/Heading.text = ("● " if source.colour == "w" else "○ ") + name
	status.text = ""
	_refresh()
	popup_centered(get_tree().root.size - Vector2i(64, 64))
	if get_tree().root.gui_embed_subwindows:
		size = get_tree().root.size - Vector2i(64, 64)


func _node() -> Dictionary:
	var node: Dictionary = edited[root_key]
	for move in path:
		node = node.children[move]
	return node


func _show_position() -> void:
	board.game = EditorGame.new(_node().position + " 0 1")
	board.game.moves = path.duplicate()
	board.queue_redraw()


func _played(_san: String) -> void:
	var move: String = board.game.moves[-1]
	var node := _node()
	if not node.children.has(move):
		node.children[move] = Repertoire._node(board.game.board.position_key())
	path.append(move)
	_refresh()


func _refresh() -> void:
	$Margin/Form/Content/Card/Panel/HeadingRow/Unsaved.visible = edited != repertoire.tree
	_move_buttons.clear()
	for row in rows.get_children():
		row.free()
	for key in edited:
		var root_button := Button.new()
		root_button.text = "Start position"
		root_button.flat = true
		root_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		root_button.pressed.connect(func(): _select_move(key, PackedStringArray()))
		rows.add_child(root_button)
		_populate(edited[key], key, PackedStringArray(), 0)
	_show_position()


func _populate(node: Dictionary, key: String, prefix: PackedStringArray, depth: int) -> void:
	for move in node.children:
		var moves := prefix.duplicate()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", depth * 20)
		rows.add_child(margin)
		var line := HFlowContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("h_separation", 6)
		margin.add_child(line)
		var current: Dictionary = node
		var next_move: String = move
		while true:
			var at = Board.from_fen(current.position + " 0 1")
			moves.append(next_move)
			var san: String = at.san(next_move)
			var ply := moves.size() - 1 + (1 if key.split(" ")[1] == "b" else 0)
			if at.side_to_move == "w":
				san = "%d.%s" % [ply / 2 + 1, san]
			elif moves.size() == 1:
				san = "1..." + san
			_add_move(line, key, moves.duplicate(), san)
			current = current.children[next_move]
			if current.children.size() != 1:
				break
			next_move = current.children.keys()[0]
		_populate(current, key, moves, depth + 1)


func _add_move(line: HFlowContainer, key: String, moves: PackedStringArray, san: String) -> void:
	var group := HBoxContainer.new()
	line.add_child(group)
	var button := Button.new()
	button.text = san
	button.toggle_mode = true
	button.button_pressed = key == root_key and moves == path
	button.set_meta("move_path", moves)
	button.set_meta("move_root", key)
	button.pressed.connect(func(): _select_move(key, moves))
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_delete_path(key, moves)
	)
	group.add_child(button)
	var selected_style := button.get_theme_stylebox("normal", "PrimaryButton")
	var normal_style := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		normal_style.set_content_margin(side, selected_style.get_content_margin(side))
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_color_override("font_pressed_color", Color("141412"))
	_move_buttons.append(button)
	var trash := Button.new()
	trash.icon = TRASH
	trash.tooltip_text = "Delete branch"
	trash.hide()
	trash.pressed.connect(func(): _delete_path(key, moves))
	group.add_child(trash)
	group.mouse_entered.connect(trash.show)
	group.mouse_exited.connect(func(): call_deferred("_hide_delete_if_idle", group, button, trash))
	button.focus_entered.connect(trash.show)
	button.focus_exited.connect(func(): call_deferred("_hide_delete_if_idle", group, button, trash))
	trash.focus_exited.connect(func(): call_deferred("_hide_delete_if_idle", group, button, trash))


func _hide_delete_if_idle(group, button, trash) -> void:
	if is_instance_valid(group) and is_instance_valid(button) and is_instance_valid(trash) and not button.has_focus() and not trash.has_focus() and not group.get_global_rect().has_point(group.get_global_mouse_position()):
		trash.hide()


func _select_move(key: String, moves: PackedStringArray) -> void:
	root_key = key
	path = moves.duplicate()
	for button in _move_buttons:
		button.button_pressed = button.get_meta("move_root") == key and button.get_meta("move_path") == moves
	_show_position()


func _delete_path(key: String, moves: PackedStringArray) -> void:
	root_key = key
	path = moves.duplicate()
	var move: String = path[path.size() - 1]
	path.remove_at(path.size() - 1)
	_node().children.erase(move)
	_refresh.call_deferred()


func save() -> void:
	var error: String = repertoire.save_edited(edited, saved_name)
	status.text = error
	if error.is_empty():
		$Margin/Form/Content/Card/Panel/HeadingRow/Unsaved.hide()
		hide()
		saved.emit(saved_name)
