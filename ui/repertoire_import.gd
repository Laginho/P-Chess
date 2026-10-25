extends PopupPanel

signal saved(name: String)

const Repertoire = preload("res://bot/repertoire.gd")
var repertoire = Repertoire.new()

@onready var _path: LineEdit = $Margin/Form/FileRow/Path
@onready var _name: LineEdit = $Margin/Form/Name
@onready var _colour: OptionButton = $Margin/Form/Colour
@onready var _status: Label = $Margin/Form/Status
@onready var _files: FileDialog = $Files


func _ready() -> void:
	$Margin/Form/FileRow/Browse.pressed.connect(func(): _files.popup_centered_ratio(0.7))
	_files.file_selected.connect(func(path: String):
		_path.text = path
		if _name.text.is_empty():
			_name.text = path.get_file().get_basename())
	$Margin/Form/Import.pressed.connect(func():
		_status.text = import_file(_path.text, _name.text.strip_edges(), ["w", "b"][_colour.selected]))
	$Margin/Form/Done.pressed.connect(hide)


func present() -> void:
	_status.text = ""
	popup_centered(Vector2i(540, 320))


func import_file(path: String, name: String, human_colour: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Cannot read the PGN file."
	var error: String = repertoire.import_pgn(file.get_as_text(), human_colour, name)
	if error.is_empty():
		hide()
		saved.emit(name)
	return error
