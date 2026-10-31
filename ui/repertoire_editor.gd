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
var _hovered: TreeItem

@onready var board = $Margin/Form/Content/Board
@onready var tree: Tree = $Margin/Form/Content/Card/Panel/Tree
@onready var status: Label = $Margin/Form/Content/Card/Panel/Status


func _ready() -> void:
	board.move_played.connect(_played)
	tree.item_selected.connect(_selected)
	tree.item_mouse_selected.connect(_mouse_selected)
	tree.gui_input.connect(_tree_input)
	tree.mouse_exited.connect(_clear_hover)
	tree.button_clicked.connect(func(item, _column, _id, _button): _delete_item(item))
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
	_hovered = null
	tree.clear()
	var invisible := tree.create_item()
	for key in edited:
		var item := tree.create_item(invisible)
		item.set_text(0, "Start position")
		item.set_metadata(0, {"root": key, "path": PackedStringArray()})
		_populate(item, edited[key], key, PackedStringArray())
		if key == root_key and path.is_empty():
			item.select(0)
	_show_position()


func _populate(parent: TreeItem, node: Dictionary, key: String, prefix: PackedStringArray) -> void:
	for move in node.children:
		var moves := prefix.duplicate()
		moves.append(move)
		var item := tree.create_item(parent)
		var board_at_parent = Board.from_fen(node.position + " 0 1")
		item.set_text(0, board_at_parent.san(move))
		item.set_metadata(0, {"root": key, "path": moves})
		if key == root_key and moves == path:
			item.select(0)
		_populate(item, node.children[move], key, moves)


func _selected() -> void:
	var item := tree.get_selected()
	if item == null:
		return
	var data: Dictionary = item.get_metadata(0)
	root_key = data.root
	path = data.path.duplicate()
	_show_position()


func _mouse_selected(position: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_RIGHT:
		return
	var item := tree.get_item_at_position(position)
	_delete_item(item)


func _tree_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var item := tree.get_item_at_position(event.position)
	if item == _hovered:
		return
	_clear_hover()
	if item != null and not item.get_metadata(0).path.is_empty():
		_hovered = item
		item.add_button(0, TRASH, 0, false, "Delete branch")


func _clear_hover() -> void:
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.erase_button(0, 0)
	_hovered = null


func _delete_item(item: TreeItem) -> void:
	if item == null:
		return
	var data: Dictionary = item.get_metadata(0)
	if data.path.is_empty():
		return
	root_key = data.root
	path = data.path.duplicate()
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
