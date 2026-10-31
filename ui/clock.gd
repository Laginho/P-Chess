extends Label

# One side's clock on the side panel (§8.7): redrawn every frame from core/clock.gd.

const Clock = preload("res://core/clock.gd")

# "w" or "b".
@export var side := "w"
# A core/clock.gd; blank until a game starts.
var clock
var _active := StyleBoxFlat.new()
var _inactive := StyleBoxFlat.new()
var _was_running := false


func _ready() -> void:
	_active.bg_color = Color("#ece9e4")
	_inactive.bg_color = Color("#1f1e1c")
	for style in [_active, _inactive]:
		style.set_corner_radius_all(6)
		style.content_margin_right = 12
	add_theme_stylebox_override("normal", _inactive)
	add_theme_color_override("font_color", Color("#a8a49c"))


func _process(_delta: float) -> void:
	text = Clock.format(clock.left(side)) if clock else ""
	var running: bool = clock != null and clock._running == side
	if running != _was_running:
		_was_running = running
		add_theme_stylebox_override("normal", _active if running else _inactive)
		add_theme_color_override("font_color", Color("#141412") if running else Color("#a8a49c"))
