extends Control

# The setup screen (§9.1): your colour and Maia's level, then Start. Clocks and openings come later.

signal started(colour: String, level: String)

const COLOURS := ["White", "Black", "Random"]
const LEVELS := ["maia-1100", "maia-1200", "maia-1300", "maia-1400", "maia-1500", "maia-1600",
		"maia-1700", "maia-1800", "maia-1900"]

@onready var _colour: OptionButton = $Center/Form/Colour
@onready var _level: OptionButton = $Center/Form/Level
@onready var _start: Button = $Center/Form/Start
@onready var _missing: Label = $Center/Form/Missing


func _ready() -> void:
	for item in COLOURS:
		_colour.add_item(item)
	for item in LEVELS:
		_level.add_item(item)
	_level.selected = LEVELS.find("maia-1500")
	_start.pressed.connect(_on_start)


# The engine is missing: how to fetch it replaces Start.
func show_missing(message: String) -> void:
	_start.hide()
	_missing.text = message + "\n\npowershell -NoProfile -File scripts/fetch-engine.ps1"
	_missing.show()


func _on_start() -> void:
	var colour: String = ["w", "b", ["w", "b"].pick_random()][_colour.selected]
	started.emit(colour, LEVELS[_level.selected])
