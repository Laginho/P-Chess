extends Control

var main
var game


func present(session, finished_game) -> void:
	main = session
	game = finished_game
	var draw: bool = game.result == "1/2-1/2"
	var won: bool = not draw and ((game.result == "1-0") == (main.human == "w"))
	$Panel/Content/Headline.text = "Draw" if draw else ("You won!" if won else "You lost")
	$Panel/Content/Reason.text = "on time" if game.reason == "time" else "by " + game.reason
	$Panel/Content/Score.text = "%s – %s" % [main._format_score(main._human_score), main._format_score(main._maia_score)]
	var player_name: String = main.preferences.get_value("player_name")
	$Panel/Content/HumanName.text = player_name
	$Panel/Content/Human/Initial.text = player_name.left(1).to_upper()
	$Panel/Content/Icon.visible = not draw
	$Panel/Content/Half.visible = draw
	if not draw and not won:
		$Panel/Content/Icon.texture = load("res://ui/icons/flag.svg")
		$Panel/Content/Icon.modulate = Color("a8a49c")
	var tint := Color("a8a49c") if draw else (Color("7fa650") if won else Color("c93230"))
	var gradient = $Panel/Content/Tint.texture.duplicate(true)
	gradient.gradient.set_color(0, Color(tint, 0.22 if draw else (0.32 if won else 0.28)))
	gradient.gradient.set_color(1, Color(tint, 0))
	$Panel/Content/Tint.texture = gradient
	for avatar in [$Panel/Content/Human, $Panel/Content/Bot]:
		var style = avatar.get_theme_stylebox("panel").duplicate()
		if not draw and (avatar == $Panel/Content/Human) == won:
			style.set_border_width_all(3)
			style.border_color = Color("f4bf44")
		avatar.add_theme_stylebox_override("panel", style)
	$Panel/Content/CopyPgn.pressed.connect(func(): main.review.get_node("Margin/Content/Actions/CopyPgn").pressed.emit())
	$Panel/Content/Review.pressed.connect(_open_review)
	$Panel/Content/Rematch.pressed.connect(_rematch)
	$Panel/Content/NewGame.pressed.connect(_new_game)
	$Panel/Content/Close.pressed.connect(_close)
	resized.connect(_layout_card)
	_layout_card()


func _layout_card() -> void:
	var card_size := Vector2(340, 394)
	var factor := minf(1.0, minf(size.x / card_size.x, size.y / card_size.y))
	$Panel.scale = Vector2.ONE * factor
	$Panel.position = (size - card_size * factor) / 2


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
			var focused = get_viewport().gui_get_focus_owner()
			if focused is Button and $Panel.is_ancestor_of(focused):
				if not focused.disabled:
					focused.pressed.emit()
			else:
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
