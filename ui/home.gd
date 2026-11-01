extends Control

signal started(settings: Dictionary)
signal custom_requested
signal history_requested
signal settings_requested

const Setup = preload("res://ui/setup.gd")
const Profile = preload("res://ui/profile.tscn")
var store


func _ready() -> void:
	$Center/Board.game = preload("res://core/game.gd").new()
	$Center/Form/Missing.visibility_changed.connect(_layout_home)
	resized.connect(_layout_home)
	_layout_home()


func _layout_home() -> void:
	var margin := 40.0 if size.x >= 1000 else 20.0
	var gap := 40.0 if size.x >= 1000 else 20.0
	var side := minf(size.y - margin * 2, size.x - margin * 2 - gap - 260.0)
	side = maxf(side, 0.0)
	var left := maxf(margin, minf((size.x - side) / 2, size.x - margin - gap - 260.0 - side))
	$Center/Board.position = Vector2(left, (size.y - side) / 2)
	$Center/Board.size = Vector2(side, side)
	var form: Control = $Center/Form
	form.position = Vector2(left + side + gap, margin)
	form.size = Vector2(size.x - form.position.x - margin, size.y - margin * 2)
	var width := form.size.x
	var row := (width - 12) / 2
	var missing: Label = form.get_node("Missing")
	var large := minf(160, (form.size.y - 282) / 2)
	if missing.visible:
		large = minf(large, maxf(36, (form.size.y - 424) / 2))
	form.get_node("Title").position = Vector2(0, 8)
	form.get_node("Title").size = Vector2(width, 60)
	form.get_node("QuickLabel").position = Vector2(0, 100)
	form.get_node("QuickLabel").size = Vector2(row, 36)
	# A chip as wide as its label, at the row's right end.
	var level: OptionButton = form.get_node("Level")
	level.size = Vector2(level.get_combined_minimum_size().x, 36)
	level.position = Vector2(width - level.size.x, 100)
	var quick: Control = form.get_node("Quick")
	quick.position = Vector2(0, 156)
	quick.size = Vector2(width, large * 2 + 12)
	for i in 3:
		var button: Button = quick.get_child(i)
		button.add_theme_font_size_override("font_size", 26 if width < 320 else 34)
		button.add_theme_constant_override("icon_max_width", 24 if width < 320 else 34)
		button.position = Vector2((i % 2) * (row + 12), (i / 2) * (large + 12))
		button.size = Vector2(row, large)
	var custom: Button = form.get_node("Custom")
	custom.add_theme_font_size_override("font_size", 18 if width < 320 else 24)
	custom.add_theme_constant_override("icon_max_width", 24 if width < 320 else 30)
	custom.position = Vector2(row + 12, 156 + large + 12)
	custom.size = Vector2(row, large)
	for i in 4:
		var button: Button = form.get_node(["History", "Profile", "Settings", "Quit"][i])
		button.position = Vector2((i % 2) * (row + 12), form.size.y - 106 + (i / 2) * 58)
		button.size = Vector2(row, 48)
	missing.position = Vector2(0, 156 + large * 2 + 20)
	missing.size = Vector2(width, maxf(0, form.size.y - 114 - missing.position.y))


func configure(preferences) -> void:
	store = preferences
	for key in ["board_theme", "piece_theme"]:
		_apply_board_theme(key, store.get_value(key))
	store.changed.connect(_apply_board_theme)
	var level: OptionButton = $Center/Form/Level
	level.add_theme_font_override("font", get_theme_font("font", "SemiboldText"))
	for item in Setup.LEVELS:
		level.add_icon_item(preload("res://ui/icons/robot.svg"), item.replace("maia-", "Maia "))
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
	$Center/Form/Profile.pressed.connect(_show_profile)
	$Center/Form/Settings.pressed.connect(func(): settings_requested.emit())
	$Center/Form/Quit.pressed.connect(func(): get_tree().quit())
	_layout_home()


func _show_profile() -> void:
	var profile = Profile.instantiate()
	add_child(profile)
	$Center.hide()
	profile.back_requested.connect(func():
		profile.hide()
		profile.queue_free()
		$Center.show()
		$Center/Form/Profile.grab_focus())
	profile.present(store)


func show_missing(message: String) -> void:
	$Center/Form/Missing.text = message + "\n\npowershell -NoProfile -File scripts/fetch-engine.ps1"
	$Center/Form/Missing.show()
	for button in $Center/Form/Quick.get_children():
		button.disabled = true


func sync_level() -> void:
	var index := Setup.LEVELS.find(store.last_game().get("level", "maia-1500"))
	$Center/Form/Level.select(index if index >= 0 else Setup.LEVELS.find("maia-1500"))


func _apply_board_theme(key: String, value) -> void:
	var board = $Center/Board
	if key == "board_theme" and board.board_theme != value:
		board.set_board_theme(value)
	elif key == "piece_theme" and board.piece_theme != value:
		board.set_piece_theme(value)
