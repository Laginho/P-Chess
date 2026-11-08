extends AcceptDialog

signal saved

const Course = preload("res://core/course.gd")

var course


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.04, 0.035, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()
	get_parent().add_child(shade)
	get_parent().move_child(shade, get_index())
	visibility_changed.connect(func(): shade.visible = visible)
	var panel: StyleBox = get_theme_stylebox("panel", "CardPanel").duplicate()
	panel.set_content_margin_all(28)
	add_theme_stylebox_override("panel", panel)
	add_theme_constant_override("buttons_min_height", 48)
	get_ok_button().text = "Start the course"
	get_ok_button().theme_type_variation = "PrimaryButton"
	$Content/Row/RatingSite.add_item("chess.com")
	$Content/Row/RatingSite.add_item("lichess")
	$Content/Row/RatingNumber.text_changed.connect(func(_text): _update())
	$Content/Row/RatingSite.item_selected.connect(func(_index): _update())
	confirmed.connect(_save)
	_update()


func present(store) -> void:
	course = store
	$Content/Error.hide()
	_update()
	popup_centered(Vector2i(560, 280))
	$Content/Row/RatingNumber.grab_focus()


func _update() -> void:
	var text: String = $Content/Row/RatingNumber.text
	var valid := text.is_valid_int() and Course.valid_rating(int(text), $Content/Row/RatingSite.get_item_text($Content/Row/RatingSite.selected))
	get_ok_button().disabled = not valid
	var hint: Label = $Content/ScaleHint
	hint.visible = $Content/Row/RatingSite.selected == 1 and valid
	if hint.visible:
		hint.text = "Shown as %d on the chess.com scale" % (int(text) - 300)


func _save() -> void:
	_update()
	if not get_ok_button().disabled and course.save_rating(int($Content/Row/RatingNumber.text), $Content/Row/RatingSite.get_item_text($Content/Row/RatingSite.selected)):
		hide()
		saved.emit()
	else:
		$Content/Error.show()
