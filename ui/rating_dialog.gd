extends AcceptDialog

var course


func _ready() -> void:
	get_ok_button().text = "Start the course"
	get_ok_button().theme_type_variation = "PrimaryButton"
	$Content/RatingSite.add_item("chess.com")
	$Content/RatingSite.add_item("lichess")
	$Content/RatingNumber.text_changed.connect(func(_text): _update())
	$Content/RatingSite.item_selected.connect(func(_index): _update())
	confirmed.connect(_save)
	_update()


func present(store) -> void:
	course = store
	$Content/Error.hide()
	_update()
	popup_centered(Vector2i(440, 250))
	$Content/RatingNumber.grab_focus()


func _update() -> void:
	var text: String = $Content/RatingNumber.text
	var valid := text.is_valid_int() and text == str(int(text)) and int(text) >= 100 and int(text) <= 3500
	get_ok_button().disabled = not valid
	var hint: Label = $Content/ScaleHint
	hint.visible = $Content/RatingSite.selected == 1 and valid
	if hint.visible:
		hint.text = "Shown as %d on the chess.com scale" % (int(text) - 300)


func _save() -> void:
	_update()
	if not get_ok_button().disabled and course.save_rating(int($Content/RatingNumber.text), $Content/RatingSite.get_item_text($Content/RatingSite.selected)):
		hide()
	else:
		$Content/Error.show()
