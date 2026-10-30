extends PopupPanel

signal saved(name: String)

var repertoire
var importer

@onready var _list: ItemList = $Margin/Form/List
@onready var _picker = $OpeningPicker


func _ready() -> void:
	$Margin/Form/Import.pressed.connect(func(): importer.present())
	$Margin/Form/FromOpenings.pressed.connect(func(): _picker.present_repertoire(repertoire))
	$Margin/Form/Back.pressed.connect(hide)
	_picker.saved.connect(_saved)


func present() -> void:
	if not importer.saved.is_connected(_saved):
		importer.saved.connect(_saved)
	_refresh()
	popup_centered(Vector2i(680, 540))


func _refresh() -> void:
	_list.clear()
	for name in repertoire.names():
		_list.add_item(name)


func _saved(name: String) -> void:
	_refresh()
	saved.emit(name)

