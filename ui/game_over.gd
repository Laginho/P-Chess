extends Control

var main
var game
var review_button: Button


func present(session, finished_game, side_review: Button) -> void:
	main = session
	game = finished_game
	review_button = side_review
	review_button.hide()
	$Panel/Content/Headline.text = {"1-0": "White won", "0-1": "Black won", "1/2-1/2": "Draw"}[game.result]
	$Panel/Content/Reason.text = "by " + game.reason
	$Panel/Content/Review.pressed.connect(_open_review)
	$Panel/Content/Rematch.pressed.connect(_rematch)
	$Panel/Content/NewGame.pressed.connect(_new_game)
	$Panel/Content/Close.pressed.connect(_close)
	review_button.pressed.connect(_open_review)


func _process(_delta: float) -> void:
	if main and (main.board_view.game != game or main.clock == null):
		review_button.hide()
		queue_free()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_rematch()


func _close() -> void:
	hide()
	review_button.show()


func _open_review() -> void:
	hide()
	review_button.hide()
	main.review.show()


func _rematch() -> void:
	hide()
	review_button.hide()
	main._start(main.rematch(main.settings))


func _new_game() -> void:
	hide()
	review_button.hide()
	main._show_setup()
