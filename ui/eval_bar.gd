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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.16, 0.18))
	var height := size.y * white_fraction
	var top := 0.0 if flipped else size.y - height
	draw_rect(Rect2(0, top, size.x, height), Color(0.92, 0.92, 0.91))
