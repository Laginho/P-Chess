extends Control

var series: Array = []


static func axis_date(date: String) -> String:
	return date.substr(8, 2) + "/" + date.substr(5, 2) if date.length() >= 10 else date


func set_series(values: Array) -> void:
	series = values
	visible = not series.is_empty()
	var descriptions := PackedStringArray()
	for sample in series:
		descriptions.append("%s: %.1f%%" % [sample.date, sample.accuracy])
	tooltip_text = "\n".join(descriptions)
	queue_redraw()


func _draw() -> void:
	if series.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var plot := Rect2(52, 12, maxf(1, size.x - 70), maxf(1, size.y - 52))
	var muted := Color("a8a49c")
	var accent := Color("7fa650")
	for percent in [0, 50, 100]:
		var y: float = plot.end.y - plot.size.y * percent / 100.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("3a3834"))
		draw_string(font, Vector2(0, y + font_size / 3.0), "%d%%" % percent,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)
	var points := PackedVector2Array()
	for i in series.size():
		var x := plot.get_center().x if series.size() == 1 else plot.position.x + plot.size.x * i / (series.size() - 1.0)
		points.append(Vector2(x, plot.end.y - plot.size.y * series[i].accuracy / 100.0))
	if points.size() > 1:
		draw_polyline(points, accent, 2.0, true)
	for point in points:
		draw_circle(point, 4.0, accent, true, -1, true)
	var first := axis_date(series[0].date)
	var last := axis_date(series[-1].date)
	draw_string(font, Vector2(plot.position.x, size.y - 8), first,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)
	if series.size() > 1:
		var width := font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(plot.end.x - width, size.y - 8), last,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)
