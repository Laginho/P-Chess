extends Control

var white_fraction := 0.5:
	set(value):
		white_fraction = clampf(value, 0.0, 1.0)
		queue_redraw()
var flipped := false:
	set(value):
		flipped = value
		queue_redraw()


func _draw() -> void:
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color("403d39")
	bar.set_corner_radius_all(4)
	draw_style_box(bar, Rect2(Vector2.ZERO, size))
	var height := size.y * white_fraction
	var white := bar.duplicate()
	white.bg_color = Color("ece9e4")
	draw_style_box(white, Rect2(0, 0.0 if flipped else size.y - height, size.x, height))
