extends AcceptDialog

var store


func _ready() -> void:
	confirmed.connect(_confirm)
	$Name.text_submitted.connect(func(_text): _confirm())
	$Name.text_changed.connect(func(text): get_ok_button().disabled = text.strip_edges().is_empty())


func present(preferences) -> void:
	store = preferences
	if store.has_player_name():
		return
	$Name.text = store.get_value("player_name")
	get_ok_button().disabled = false
	popup_centered()
	$Name.grab_focus()
	$Name.select_all()


func _confirm() -> void:
	if store.set_value("player_name", $Name.text.strip_edges()):
		hide()
