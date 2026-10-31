extends Control

signal back_requested

const History = preload("res://core/history.gd")
const Setup = preload("res://ui/setup.gd")

var preferences


func _ready() -> void:
	$Margin/Content/Back.pressed.connect(func(): back_requested.emit())
	$Margin/Content/NameRow/SaveName.pressed.connect(_save_name)
	$Margin/Content/NameRow/PlayerName.text_submitted.connect(func(_text): _save_name())


func present(settings) -> void:
	preferences = settings
	$Margin/Content/NameRow/PlayerName.text = preferences.get_value("player_name")
	refresh(History.new())
	show()
	$Margin/Content/NameRow/PlayerName.grab_focus()


func refresh(history) -> void:
	var table: GridContainer = $Margin/Content/Scroll/Body/Results
	for child in table.get_children():
		table.remove_child(child)
		child.queue_free()
	for title in ["Level", "Time", "W", "D", "L", "Flag wins", "Flag losses"]:
		_cell(table, title)
	var rows := 0
	for level in Setup.LEVELS:
		for control in ["1+0", "3+2", "5+0"]:
			var counts: Dictionary = history.stats(level, control)
			if counts.wins + counts.draws + counts.losses == 0:
				continue
			rows += 1
			for value in [level.replace("maia-", "Maia "), control, counts.wins, counts.draws,
					counts.losses, counts.flag_wins, counts.flag_losses]:
				_cell(table, str(value))
	$Margin/Content/Scroll/Body/NoResults.visible = rows == 0


func _cell(table: GridContainer, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_child(label)


func _save_name() -> void:
	var input: LineEdit = $Margin/Content/NameRow/PlayerName
	var value := input.text.strip_edges()
	if preferences.set_value("player_name", value):
		input.text = value
		$Margin/Content/NameError.hide()
	else:
		$Margin/Content/NameError.show()
