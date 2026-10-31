extends Control

signal started(settings: Dictionary)
signal custom_requested
signal history_requested
signal settings_requested

const Setup = preload("res://ui/setup.gd")
var store

func configure(preferences) -> void:
	store = preferences
	var level: OptionButton = $Center/Form/Level
	for item in Setup.LEVELS:
		level.add_item(item.replace("maia-", "Maia "))
	var last: Dictionary = store.last_game()
	var index := Setup.LEVELS.find(last.get("level", "maia-1500"))
	level.select(index if index >= 0 else Setup.LEVELS.find("maia-1500"))
	level.item_selected.connect(func(i):
		var saved: Dictionary = store.last_game()
		saved.level = Setup.LEVELS[i]
		store.save_last_game(saved))
	for button in $Center/Form/Quick.get_children():
		button.pressed.connect(func():
			var saved: Dictionary = store.last_game()
			var choice: String = saved.get("colour_choice", "random")
			saved.colour = ["w", "b"].pick_random() if choice == "random" else choice
			saved.colour_choice = choice
			saved.level = Setup.LEVELS[level.selected]
			saved.opening = saved.get("opening", "Free")
			saved.control = button.text
			started.emit(saved))
	$Center/Form/Custom.pressed.connect(func(): custom_requested.emit())
	$Center/Form/History.pressed.connect(func(): history_requested.emit())
	$Center/Form/Settings.pressed.connect(func(): settings_requested.emit())
	$Center/Form/Quit.pressed.connect(func(): get_tree().quit())


func show_missing(message: String) -> void:
	$Center/Form/Missing.text = message + "\n\npowershell -NoProfile -File scripts/fetch-engine.ps1"
	$Center/Form/Missing.show()
	for button in $Center/Form/Quick.get_children():
		button.disabled = true
