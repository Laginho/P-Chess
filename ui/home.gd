extends Control

signal started(settings: Dictionary)
signal custom_requested
signal course_requested
signal continue_requested(target: Dictionary)
signal history_requested
signal settings_requested

const Setup = preload("res://ui/setup.gd")
const Profile = preload("res://ui/profile.tscn")
var store
var course
var target := {}


func _ready() -> void:
	$Center/Board.game = preload("res://core/game.gd").new()
	for button in $Center/Form/Quick.get_children() + [$Center/Form/Custom]:
		for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
			button.add_theme_color_override(colour, Color.TRANSPARENT)
		var artwork := TextureRect.new()
		artwork.name = "Artwork"
		artwork.texture = button.icon
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(artwork)
		var caption := Label.new()
		caption.name = "Caption"
		caption.text = button.text
		caption.theme_type_variation = "ExtraBoldText"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
	$Center/Form/Missing.visibility_changed.connect(_layout_home)
	resized.connect(_layout_home)
	_layout_home()


func _layout_home() -> void:
	var margin := 40.0 if size.x >= 1000 else 20.0
	var gap := 40.0 if size.x >= 1000 else 20.0
	var side := minf(size.y - margin * 2, size.x - margin * 2 - gap - 320.0)
	side = maxf(side, 0.0)
	var left := margin
	$Center/Board.position = Vector2(left, (size.y - side) / 2)
	$Center/Board.size = Vector2(side, side)
	var form: Control = $Center/Form
	form.position = Vector2(left + side + gap, margin)
	form.size = Vector2(size.x - form.position.x - margin, size.y - margin * 2)
	var width := form.size.x
	var row := (width - 12) / 2
	var missing: Label = form.get_node("Missing")
	var card_height := clampf(form.size.y * 0.245, 90, 176)
	if missing.visible:
		card_height = 90
	form.get_node("Title").position = Vector2(0, 8)
	form.get_node("Title").size = Vector2(width, 48)
	form.get_node("Continue").position = Vector2(0, 65)
	form.get_node("Continue").size = Vector2(width, card_height)
	var card: Button = form.get_node("Continue")
	var text_y := maxf(6, (card_height - 92) / 2)
	for item in [["Eyebrow", 0, 19], ["UnitTitle", 20, 30], ["Detail", 51, 22], ["Progress", 80, 5]]:
		var child: Control = card.get_node(item[0])
		child.position = Vector2(22, text_y + item[1])
		child.size = Vector2(maxf(0, width - 86), item[2])
	card.get_node("Chevron").position = Vector2(width - 52, (card_height - 30) / 2)
	card.get_node("Chevron").size = Vector2(30, 30)
	_fit_continue_title()
	_fit_continue_detail()
	form.get_node("Course").position = Vector2(0, 75 + card_height)
	var summary_label: Label = form.get_node("Course/Summary")
	var summary_width := maxf(0, width - 132)
	var summary_height := summary_label.get_theme_font("font").get_multiline_string_size(summary_label.text, HORIZONTAL_ALIGNMENT_RIGHT, summary_width, summary_label.get_theme_font_size("font_size"), -1, summary_label.autowrap_mode).y
	var course_height := maxf(44, summary_height + 12)
	form.get_node("Course").size = Vector2(width, course_height)
	form.get_node("Course/Icon").position = Vector2(16, (course_height - 20) / 2)
	form.get_node("Course/Icon").size = Vector2(20, 20)
	form.get_node("Course/Title").position = Vector2(48, 0)
	form.get_node("Course/Title").size = Vector2(62, course_height)
	form.get_node("Course/Summary").position = Vector2(116, 0)
	form.get_node("Course/Summary").size = Vector2(summary_width, course_height)
	var play_y := 130 + card_height + course_height - 44
	form.get_node("QuickLabel").position = Vector2(0, play_y)
	form.get_node("QuickLabel").size = Vector2(row, 36)
	# A chip as wide as its label, at the row's right end.
	var level: OptionButton = form.get_node("Level")
	level.size = Vector2(level.get_combined_minimum_size().x, 36)
	level.position = Vector2(width - level.size.x, play_y)
	var quick: Control = form.get_node("Quick")
	var tile_width := (width - 24) / 4
	var tile_y := play_y + 44
	var tile_height := minf(92, maxf(32, form.size.y - 114 - tile_y - (130 if missing.visible else 8)))
	quick.position = Vector2(0, tile_y)
	quick.size = Vector2(width, tile_height)
	for i in 3:
		var button: Button = quick.get_child(i)
		button.add_theme_font_size_override("font_size", 16 if width < 380 else 22)
		button.add_theme_constant_override("icon_max_width", 14 if width < 380 else 20)
		button.position = Vector2(i * (tile_width + 8), 0)
		button.size = Vector2(tile_width, tile_height)
	var custom: Button = form.get_node("Custom")
	custom.add_theme_font_size_override("font_size", 13 if width < 380 else 16)
	custom.add_theme_constant_override("icon_max_width", 12 if width < 380 else 16)
	custom.position = Vector2(3 * (tile_width + 8), tile_y)
	custom.size = Vector2(tile_width, tile_height)
	for button in quick.get_children() + [custom]:
		var compact: bool = tile_height < 60
		var icon_size := 14.0 if compact else 22.0
		var caption_size := 12 if compact else (15 if button == custom else 22)
		var caption_height := float(caption_size + 4)
		var spacing := 0.0 if compact else 8.0
		var top := maxf(0, (tile_height - icon_size - spacing - caption_height) / 2)
		var artwork: TextureRect = button.get_node("Artwork")
		artwork.position = Vector2((tile_width - icon_size) / 2, top)
		artwork.size = Vector2(icon_size, icon_size)
		artwork.modulate.a = 0.4 if missing.visible and button != custom else 1.0
		var caption: Label = button.get_node("Caption")
		caption.add_theme_font_size_override("font_size", caption_size)
		caption.position = Vector2(0, top + icon_size + spacing)
		caption.size = Vector2(tile_width, caption_height)
		caption.modulate.a = 0.4 if missing.visible and button != custom else 1.0
	for i in 4:
		var button: Button = form.get_node(["History", "Profile", "Settings", "Quit"][i])
		button.position = Vector2((i % 2) * (row + 12), form.size.y - 106 + (i / 2) * 58)
		button.size = Vector2(row, 48)
	missing.position = Vector2(0, tile_y + tile_height + 4)
	missing.size = Vector2(width, maxf(0, form.size.y - 114 - missing.position.y))


func configure(preferences, course_store = null) -> void:
	store = preferences
	course = course_store
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
	$Center/Form/Course.pressed.connect(func(): course_requested.emit())
	$Center/Form/Continue.pressed.connect(func(): continue_requested.emit(target))
	$Center/Form/Custom.pressed.connect(func(): custom_requested.emit())
	$Center/Form/History.pressed.connect(func(): history_requested.emit())
	$Center/Form/Profile.pressed.connect(_show_profile)
	$Center/Form/Settings.pressed.connect(func(): settings_requested.emit())
	$Center/Form/Quit.pressed.connect(func(): get_tree().quit())
	_layout_home()
	refresh_continue()


func refresh_continue() -> void:
	if course == null:
		return
	var units: Array = course.units()
	var summary := "%d %s" % [units.size(), "unit" if units.size() == 1 else "units"]
	for status in ["new", "in progress", "mastered", "needs review"]:
		var count := 0
		for unit in units:
			if course.unit_progress(unit).status == status:
				count += 1
		if count > 0:
			summary += " · %d %s" % [count, status]
	$Center/Form/Course/Summary.text = summary
	_layout_home()
	var now: int = course.local_calendar_time(int(Time.get_unix_time_from_system()), int(Time.get_time_zone_from_system().bias))
	target = {"kind": "rating"} if course.rating().is_empty() else course.continue_target(now)
	var kind: String = target.kind
	var title := "Start the course"
	var eyebrow := "CONTINUE"
	var detail := ""
	if kind == "done":
		eyebrow = "UNIT DONE"
		title = "Unit done, go play some slow games"
		detail = "Choose Custom or a game below"
	elif kind != "rating":
		var unit: Dictionary = target.unit
		title = unit.get("title", "")
		match kind:
			"review":
				eyebrow = "REVIEW CHECK"
				detail = "3 positions · mastered %d days ago" % target.elapsed_days
			"from_game":
				eyebrow = "FROM YOUR GAME"
				detail = "1 new position from your games"
			"solving":
				var progress: Dictionary = course.unit_progress(unit)
				detail = "Solving · %d/%d" % [progress.solved, progress.total]
			"theory": detail = "Theory pointer"
			"playouts": detail = "Play-outs"
			"test": detail = "Pass test"
	$Center/Form/Continue.text = "%s\n%s%s" % [eyebrow, title, "\n" + detail if not detail.is_empty() else ""]
	$Center/Form/Continue/Eyebrow.text = eyebrow
	$Center/Form/Continue/UnitTitle.text = title
	_fit_continue_title()
	$Center/Form/Continue/Detail.text = detail
	_fit_continue_detail()
	var bar: ProgressBar = $Center/Form/Continue/Progress
	bar.visible = kind == "solving"
	if bar.visible:
		var progress: Dictionary = course.unit_progress(target.unit)
		bar.max_value = maxi(progress.total, 1)
		bar.value = progress.solved
	var position: Dictionary = target.get("position", {})
	if kind == "review" and not target.positions.is_empty():
		position = target.positions[0]
	elif kind == "theory":
		position = course.next_practice_position(target.unit)
	elif kind == "test":
		for item in target.unit.get("positions", []):
			if item.get("pool") == "test":
				position = item
				break
	var fen := str(position.get("fen", ""))
	$Center/Board.game = preload("res://core/game.gd").new(fen) if not fen.is_empty() else preload("res://core/game.gd").new()
	$Center/Board.queue_redraw()


func _fit_continue_title() -> void:
	var label: Label = $Center/Form/Continue/UnitTitle
	var font := label.get_theme_font("font")
	var font_size := 16 if target.get("kind") == "done" else 26
	while font_size > 10 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _fit_continue_detail() -> void:
	var label: Label = $Center/Form/Continue/Detail
	var font := label.get_theme_font("font")
	var font_size := 16
	while font_size > 9 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _show_profile() -> void:
	var profile = Profile.instantiate()
	add_child(profile)
	$Center.hide()
	profile.back_requested.connect(func():
		profile.hide()
		profile.queue_free()
		refresh_continue()
		$Center.show()
		$Center/Form/Profile.grab_focus())
	profile.present(store, course)


func show_missing(message: String) -> void:
	$Center/Form/Missing.text = message + "\n\npowershell -NoProfile -File scripts/fetch-engine.ps1"
	$Center/Form/Missing.show()
	for button in $Center/Form/Quick.get_children():
		button.disabled = true
	_layout_home()


func sync_level() -> void:
	var index := Setup.LEVELS.find(store.last_game().get("level", "maia-1500"))
	$Center/Form/Level.select(index if index >= 0 else Setup.LEVELS.find("maia-1500"))


func _apply_board_theme(key: String, value) -> void:
	var board = $Center/Board
	if key == "board_theme" and board.board_theme != value:
		board.set_board_theme(value)
	elif key == "piece_theme" and board.piece_theme != value:
		board.set_piece_theme(value)
