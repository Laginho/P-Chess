extends Control

# The setup screen (§9.1): your colour, Maia's level, the time control and the opening mode, then
# Start. Catalog selections and imported repertoires are stored separately.

# settings: colour ("w" or "b", random already drawn), level, control and opening.
# Catalog emits selection; My repertoire emits repertoire, with its saved human colour.
signal started(settings: Dictionary)

const Clock = preload("res://core/clock.gd")
const Book = preload("res://bot/book.gd")
const Repertoire = preload("res://bot/repertoire.gd")
const COLOURS := ["White", "Black", "Random"]
const LEVELS := ["maia-1100", "maia-1200", "maia-1300", "maia-1400", "maia-1500", "maia-1600",
		"maia-1700", "maia-1800", "maia-1900"]
const OPENINGS := ["Free", "Catalog", "My repertoire"]
var book = Book.new()
var repertoire = Repertoire.new()
var _engine_missing := false

@onready var _colour: OptionButton = $Center/Form/Colour
@onready var _level: OptionButton = $Center/Form/Level
@onready var _control: OptionButton = $Center/Form/Control
@onready var _opening: OptionButton = $Center/Form/Opening
@onready var _start: Button = $Center/Form/Start
@onready var _missing: Label = $Center/Form/Missing
@onready var _catalog_controls: HBoxContainer = $Center/Form/CatalogControls
@onready var _selections: OptionButton = $Center/Form/CatalogControls/Selections
@onready var _picker = $OpeningPicker
@onready var _repertoire_controls: HBoxContainer = $Center/Form/RepertoireControls
@onready var _repertoires: OptionButton = $Center/Form/RepertoireControls/Saved
@onready var _importer = $RepertoireImport


func _ready() -> void:
	for item in COLOURS:
		_colour.add_item(item)
	for item in LEVELS:
		_level.add_item(item)
	_level.selected = LEVELS.find("maia-1500")
	for item in Clock.CONTROLS:
		_control.add_item(item)
	for item in OPENINGS:
		_opening.add_item(item)
	_start.pressed.connect(_on_start)
	_opening.item_selected.connect(_on_opening_selected)
	$Center/Form/CatalogControls/Edit.pressed.connect(_open_catalog)
	_picker.book = book
	_picker.saved.connect(_refresh_selections)
	_importer.repertoire = repertoire
	_importer.saved.connect(_refresh_repertoires)
	$Center/Form/RepertoireControls/Import.pressed.connect(_importer.present)
	_repertoires.item_selected.connect(func(_index): _on_opening_selected(_opening.selected))
	visibility_changed.connect(func():
		if visible:
			_refresh_selections()
			_refresh_repertoires())
	_refresh_selections()
	_refresh_repertoires()


func _refresh_selections(preferred := "") -> void:
	if preferred.is_empty() and _selections.selected >= 0:
		preferred = _selections.get_item_text(_selections.selected)
	_selections.clear()
	for name in book.selection_names():
		_selections.add_item(name)
		if name == preferred:
			_selections.select(_selections.item_count - 1)
	_on_opening_selected(_opening.selected)


func _on_opening_selected(index: int) -> void:
	if not _engine_missing:
		_missing.hide()
	_catalog_controls.visible = OPENINGS[index] == "Catalog"
	_repertoire_controls.visible = OPENINGS[index] == "My repertoire"
	_colour.disabled = _repertoire_controls.visible
	_start.disabled = _catalog_controls.visible and _selections.item_count == 0
	if _repertoire_controls.visible:
		_start.disabled = _repertoires.item_count == 0
		if not _start.disabled:
			var error: String = repertoire.load_saved(_repertoires.get_item_text(_repertoires.selected))
			_start.disabled = not error.is_empty()
			if not _engine_missing:
				_missing.text = error
				_missing.visible = not error.is_empty()
			if error.is_empty():
				_colour.select(0 if repertoire.colour == "w" else 1)


func _refresh_repertoires(preferred := "") -> void:
	if preferred.is_empty() and _repertoires.selected >= 0:
		preferred = _repertoires.get_item_text(_repertoires.selected)
	_repertoires.clear()
	for name in repertoire.names():
		_repertoires.add_item(name)
		if name == preferred:
			_repertoires.select(_repertoires.item_count - 1)
	_on_opening_selected(_opening.selected)


func _open_catalog() -> void:
	var name := _selections.get_item_text(_selections.selected) if _selections.selected >= 0 else ""
	_picker.present(name)


# The engine is missing: how to fetch it replaces Start.
func show_missing(message: String) -> void:
	_engine_missing = true
	_start.hide()
	_missing.text = message + "\n\npowershell -NoProfile -File scripts/fetch-engine.ps1"
	_missing.show()


func _on_start() -> void:
	if _start.disabled:
		return
	var colour: String = ["w", "b", ["w", "b"].pick_random()][_colour.selected]
	var settings := {"colour": colour, "level": LEVELS[_level.selected],
			"control": _control.get_item_text(_control.selected), "opening": OPENINGS[_opening.selected]}
	if settings.opening == "Catalog":
		settings["selection"] = _selections.get_item_text(_selections.selected)
	elif settings.opening == "My repertoire":
		var name := _repertoires.get_item_text(_repertoires.selected)
		var error: String = repertoire.load_saved(name)
		if not error.is_empty():
			_missing.text = error
			_missing.show()
			return
		_colour.select(0 if repertoire.colour == "w" else 1)
		settings.colour = repertoire.colour
		settings["repertoire"] = name
	started.emit(settings)
