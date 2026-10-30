extends PopupPanel

signal saved(name: String)

const Game = preload("res://core/game.gd")
const Repertoire = preload("res://bot/repertoire.gd")
var repertoire
var saved_name := ""
var edited := {}
var root_key := ""
var path := PackedStringArray()

@onready var board = $Margin/Form/Content/Board
@onready var tree: Tree = $Margin/Form/Content/Tree
@onready var status: Label = $Margin/Form/Status


func _ready() -> void:
	board.move_played.connect(_played)
	tree.item_selected.connect(_selected)
	tree.item_mouse_selected.connect(_mouse_selected)
	$Margin/Form/Buttons/Save.pressed.connect(save)
	$Margin/Form/Buttons/Cancel.pressed.connect(hide)


func present(source, name: String, line: int = -1) -> void:
	repertoire = source
	saved_name = name
	edited = source.tree.duplicate(true)
	root_key = source.lines[line].positions[0] if line >= 0 else edited.keys()[0]
	path = source.lines[line].moves.duplicate() if line >= 0 else PackedStringArray()
	board.flipped = source.colour == "b"
	status.text = ""
	_refresh()
	popup_centered(Vector2i(760, 520))


func _node() -> Dictionary:
	var node: Dictionary = edited[root_key]
	for move in path:
		node = node.children[move]
	return node


func _show_position() -> void:
	board.game = Game.new(_node().position + " 0 1")
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
		item.set_text(0, move)
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
	_refresh()


func save() -> void:
	var error: String = repertoire.save_edited(edited, saved_name)
	status.text = error
	if error.is_empty():
		hide()
		saved.emit(saved_name)
