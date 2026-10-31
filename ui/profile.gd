extends Control

signal back_requested

var preferences


func _ready() -> void:
	$Margin/Content/Back.pressed.connect(func(): back_requested.emit())
	$Margin/Content/NameRow/SaveName.pressed.connect(_save_name)
	$Margin/Content/NameRow/PlayerName.text_submitted.connect(func(_text): _save_name())


func present(settings) -> void:
	preferences = settings
	$Margin/Content/NameRow/PlayerName.text = preferences.get_value("player_name")
	show()
	$Margin/Content/NameRow/PlayerName.grab_focus()


func _save_name() -> void:
	var input: LineEdit = $Margin/Content/NameRow/PlayerName
	var value := input.text.strip_edges()
	if preferences.set_value("player_name", value):
		input.text = value
		$Margin/Content/NameError.hide()
	else:
		$Margin/Content/NameError.show()
