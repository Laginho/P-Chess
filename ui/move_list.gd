extends RichTextLabel

# SAN moves, one numbered row per pair.
var _moves: Array[String] = []


func _ready() -> void:
	resized.connect(_render)


func reset() -> void:
	clear()
	_moves.clear()


func add(san: String) -> void:
	_moves.append(san)
	_render()


func _render() -> void:
	var scroll := get_v_scroll_bar()
	var position := scroll.value
	var following := position >= scroll.max_value - scroll.page
	scroll_following = false
	clear()
	push_table(3)
	set_table_column_expand(1, true, 1, false)
	set_table_column_expand(2, true, 1, false)
	for i in range(0, _moves.size(), 2):
		_cell("%d. " % (i / 2 + 1), i, false, 48)
		_cell(_moves[i] + ("   " if i + 1 < _moves.size() else ""), i, i == _moves.size() - 1, maxf(0, (size.x - 48) / 2 - 16))
		_cell(_moves[i + 1] if i + 1 < _moves.size() else "", i, i + 1 == _moves.size() - 1, maxf(0, (size.x - 48) / 2 - 16))
	pop()
	if following:
		scroll_following = true
	else:
		scroll.value = position


func _cell(value: String, row: int, current: bool, width := 0) -> void:
	push_cell()
	var background := Color("#2f2e2a") if row % 4 == 0 else Color("#2b2a27")
	set_cell_row_background_color(background, background)
	set_cell_size_override(Vector2(width, 24), Vector2(10000, 10000))
	set_cell_padding(Rect2(8, 4, 8, 4))
	if current:
		push_bgcolor(Color("#4a4741"))
	add_text(value)
	if current:
		pop()
	pop()
