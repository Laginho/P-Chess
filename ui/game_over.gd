extends Control

var main
var game


func present(session, finished_game) -> void:
	main = session
	game = finished_game
	$Panel/Content/Headline.text = {"1-0": "White won", "0-1": "Black won", "1/2-1/2": "Draw"}[game.result]
	$Panel/Content/Reason.text = "by " + game.reason
	$Panel/Content/Score.text = main.match_score_text()
	$Panel/Content/Review.pressed.connect(_open_review)
	$Panel/Content/Rematch.pressed.connect(_rematch)
	$Panel/Content/NewGame.pressed.connect(_new_game)
	$Panel/Content/Close.pressed.connect(_close)


func _process(_delta: float) -> void:
	if main and (main.board_view.game != game or main.clock == null):
		queue_free()


func _input(event: InputEvent) -> void:
	if main and main.settings_screen.get_node("Panel").visible:
		return
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_rematch()


func _close() -> void:
	hide()


func _open_review() -> void:
	hide()
	main.review.open_analysis(main.review_analysis_path, game.result == "1/2-1/2")


func _rematch() -> void:
	hide()
	main._start(main.rematch(main.settings))


func _new_game() -> void:
	hide()
	main._show_home()
