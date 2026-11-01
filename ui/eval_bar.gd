extends Control

var white_fraction := 0.5:
	set(value):
		white_fraction = clampf(value, 0.0, 1.0)
		_fit_score()
		queue_redraw()
var flipped := false:
	set(value):
		flipped = value
		_fit_score()
		queue_redraw()


func _ready() -> void:
	resized.connect(_fit_score)


# The score reads dark on white and light on black: whichever fills the bar behind its middle.
func _fit_score() -> void:
	var score := get_node_or_null("Score") as Label
	if score == null:
		return
	var middle := score.position.y + score.size.y / 2
	var on_white := middle <= size.y * white_fraction if flipped else middle >= size.y * (1.0 - white_fraction)
	score.add_theme_color_override("font_color", Color("141412") if on_white else Color("ece9e4"))


func _draw() -> void:
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color("403d39")
	bar.set_corner_radius_all(4)
	draw_style_box(bar, Rect2(Vector2.ZERO, size))
	var height := size.y * white_fraction
	var white := bar.duplicate()
	white.bg_color = Color("ece9e4")
	draw_style_box(white, Rect2(0, 0.0 if flipped else size.y - height, size.x, height))
