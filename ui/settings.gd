extends Control

# The settings screen (§10): one row per setting of `store` (core/settings.gd), set before this
# enters the tree. Each edit goes straight to the store, which saves it and announces it.
# shortcut: the Open button sits in the window's top-right corner, clear of the top clock because
# the side panel is 240 px wide and the clock text narrower; move it into the panel if they collide.

const Settings = preload("res://core/settings.gd")
const ThemeLoader = preload("res://ui/theme_loader.gd")

var store
var _spins := {} # key -> [SpinBox, scale]

@onready var _panel: Control = $Panel
@onready var _form: GridContainer = $Panel/Center/Box/Form


func _ready() -> void:
	$Open.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	$Panel/Center/Box/Close.pressed.connect(_panel.hide)
	_choice("premove_style", "Premove style", Settings.CHOICES.premove_style)
	_check("click_click", "Click-click moves")
	_choice("auto_queen", "Auto-queen", Settings.CHOICES.auto_queen)
	_check("legal_dots", "Legal-move dots")
	_spin("animation_ms", "Animation length (ms)", 10)
	_choice("board_theme", "Board", _themes("boards"))
	_choice("piece_theme", "Pieces", _themes("pieces"))
	_spin("board_size", "Board size (px, 0 = fit)", 10)
	_choice("sound_theme", "Sounds", _themes("sounds"))
	_spin("volume", "Volume (%)", 1)
	_spin("tau", "Threshold τ (%)", 0.1, 100.0)
	_spin("temperature", "Temperature T", 0.1)
	_choice("panic", "Panic intensity", Settings.CHOICES.panic)
	_choice("book_intensity", "Book intensity", Settings.CHOICES.book_intensity)
	_check("auto_claim", "Auto-claim threefold")
	_check("check_repertoire", "Check my moves against my repertoire")
	var first: Control = _form.get_child(1)
	var close: Control = $Panel/Center/Box/Close
	first.focus_previous = first.get_path_to(close)
	close.focus_next = close.get_path_to(first)
	_panel.visibility_changed.connect(_focus_panel)
	store.changed.connect(_follow)


func _focus_panel() -> void:
	if _panel.visible:
		_form.get_child(1).grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()


func _input(event: InputEvent) -> void:
	if _panel.visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_ESCAPE or (event.ctrl_pressed and event.keycode == KEY_COMMA)):
		_panel.hide()
		get_viewport().set_input_as_handled()


# While open, the screen keeps keys from the game: Esc closes it instead of resigning.
func _unhandled_key_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	get_viewport().set_input_as_handled()


func _check(key: String, label: String) -> void:
	var box := CheckBox.new()
	box.button_pressed = store.get_value(key)
	box.toggled.connect(func(on: bool) -> void: store.set_value(key, on))
	_row(label, box)


# `scale` shows a fraction as a percentage.
func _spin(key: String, label: String, step: float, scale := 1.0) -> void:
	var spin := SpinBox.new()
	spin.min_value = Settings.RANGES[key][0] * scale
	spin.max_value = Settings.RANGES[key][1] * scale
	spin.step = step
	spin.value = store.get_value(key) * scale
	spin.value_changed.connect(func(value: float) -> void: store.set_value(key, value / scale))
	_spins[key] = [spin, scale]
	_row(label, spin)


# The board grip also writes board_size, so number rows follow the store. A method, not a lambda,
# so freeing this screen disconnects it from the longer-lived store.
func _follow(key: String, value) -> void:
	if key in _spins:
		_spins[key][0].set_value_no_signal(value * _spins[key][1])


func _choice(key: String, label: String, items: Array) -> void:
	var button := OptionButton.new()
	var current: String = store.get_value(key)
	items = items.duplicate()
	if not current in items:
		items.append(current)
	for item in items:
		button.add_item(item)
	button.selected = items.find(current)
	button.item_selected.connect(func(index: int) -> void: store.set_value(key, button.get_item_text(index)))
	_row(label, button)


func _themes(kind: String) -> Array:
	return ThemeLoader.new().list_themes(kind).keys()


func _row(label: String, control: Control) -> void:
	var text := Label.new()
	text.text = label
	_form.add_child(text)
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	_form.add_child(control)
