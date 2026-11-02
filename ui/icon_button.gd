extends Button

# Godot pins a left icon to the button's edge and centres the label in the space left over.
# The canvas centres icon and label as one group, or with `icon_left` set, centres the label on the
# whole button with the icon just left of it, at least `icon_left` from the edge (the font shrinks
# until both fit). So this button paints both itself:
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
	if clip_text and label + width + gap > size.x - 16:
		# Two 14 px lines fit above the confirmation's 4 px progress bar.
		font_size = 14
		var available := size.x - 16
		var height := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, available, font_size, -1, TextServer.AUTOWRAP_WORD_SMART).y
		draw_multiline_string(font, Vector2(8, (size.y - 4 - height) / 2 + font.get_ascent(font_size)), text,
				HORIZONTAL_ALIGNMENT_CENTER, available, font_size, -1, _colours[get_draw_mode()])
		return
	var placed := placement()
	font_size = int(placed.z)
	if icon:
		var height := width * icon.get_height() / icon.get_width()
		draw_texture_rect(icon, Rect2(placed.x, (size.y - height) / 2, width, height), false, _icon_colours[disabled])
	draw_string(font, Vector2(placed.y, (size.y - font.get_height(font_size)) / 2 + font.get_ascent(font_size)),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _colours[get_draw_mode()])


# The one-line layout: icon x, label x and font size.
func placement() -> Vector3:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var label := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := float(get_theme_constant("icon_max_width")) if icon else 0.0
	var gap := float(get_theme_constant("h_separation")) if icon else 0.0
	if icon and icon_left >= 0:
		while font_size > 12 and (size.x - label) / 2 - gap - width < icon_left:
			font_size -= 1
			label = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := (size.x - width - gap - label) / 2
	var text_x := x + width + gap
	# A button too narrow even at the smallest font falls back to the group, so the icon never runs into the label.
	if icon and icon_left >= 0 and (size.x - label) / 2 - gap - width >= icon_left:
		text_x = (size.x - label) / 2
		x = text_x - gap - width
	return Vector3(x, text_x, font_size)
