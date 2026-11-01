extends Button

# Godot pins a left icon to the button's edge and centres the label in the space left over.
# The canvas centres icon and label as one group, or with `icon_left` set, pins the icon that far
# from the left edge and centres the label on the whole button. So this button paints both itself:
# Godot still lays it out from `text` and `icon` (minimum size, accessibility) but draws them clear.

@export var icon_left := -1.0
# A theme Label variation whose font this label uses, for the canvas's weight (e.g. SemiboldText).
@export var font_type := &""

const COLOURS := {DRAW_NORMAL: "font_color", DRAW_HOVER: "font_hover_color", DRAW_PRESSED: "font_pressed_color",
		DRAW_HOVER_PRESSED: "font_hover_pressed_color", DRAW_DISABLED: "font_disabled_color"}
const HIDDEN := ["font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color",
		"icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]

var _colours := {}
var _icon_colours := {}


func _ready() -> void:
	if font_type:
		add_theme_font_override("font", get_theme_font("font", font_type))
	for mode in COLOURS:
		_colours[mode] = get_theme_color(COLOURS[mode])
	for is_disabled in [false, true]:
		_icon_colours[is_disabled] = get_theme_color("icon_disabled_color" if is_disabled else "icon_normal_color")
	for name in COLOURS.values() + HIDDEN:
		add_theme_color_override(name, Color.TRANSPARENT)


func _draw() -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var label := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := float(get_theme_constant("icon_max_width")) if icon else 0.0
	var gap := float(get_theme_constant("h_separation")) if icon else 0.0
	var x := (size.x - width - gap - label) / 2
	var text_x := x + width + gap
	# A narrow button falls back to the group, so the icon never runs into the label.
	if icon and icon_left >= 0 and (size.x - label) / 2 - icon_left - width >= gap:
		x = icon_left
		text_x = (size.x - label) / 2
	if icon:
		var height := width * icon.get_height() / icon.get_width()
		draw_texture_rect(icon, Rect2(x, (size.y - height) / 2, width, height), false, _icon_colours[disabled])
	draw_string(font, Vector2(text_x, (size.y - font.get_height(font_size)) / 2 + font.get_ascent(font_size)),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _colours[get_draw_mode()])
