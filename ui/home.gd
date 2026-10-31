extends Control

signal started(settings: Dictionary)

const Setup = preload("res://ui/setup.gd")

func _ready() -> void:
	var level: OptionButton = $Center/Form/Level
	for item in Setup.LEVELS:
		level.add_item(item.replace("maia-", "Maia "))
	level.select(Setup.LEVELS.find("maia-1500"))
	for button in $Center/Form/Quick.get_children():
		button.pressed.connect(func():
			started.emit({"level": Setup.LEVELS[level.selected], "colour": ["w", "b"].pick_random(),
					"opening": "Free", "control": button.text}))
