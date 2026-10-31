extends Control

var _spin := 0.0


func _ready() -> void:
	$Board.game = preload("res://core/game.gd").new()
	$Spinner.draw.connect(func(): $Spinner.draw_arc(Vector2(48, 48), 40, _spin, _spin + PI * 1.25, 32, Color("7fa650"), 8, true))
	visibility_changed.connect(_sync_settings_button)
	resized.connect(_layout_searching)
	_layout_searching()


func present(settings: Dictionary) -> void:
	$Center/Content/Match.text = "%s  ·  Maia %s" % [settings.control, settings.level.trim_prefix("maia-")]
	$Center/Content/ControlChip.text = settings.control + (" Bullet" if settings.control == "1+0" else " Blitz")
	$Center/Content/LevelChip.text = "Maia " + settings.level.trim_prefix("maia-")
	var preferences = get_parent().get("preferences")
	$Player.text = preferences.get_value("player_name") if preferences else settings.get("player_name", "You")
	$Avatar.text = $Player.text.left(1).to_upper()
	show()


func status(message: String) -> void:
	$Center/Content/Status.text = message


func _process(delta: float) -> void:
	if visible:
		_spin += delta * 3.0
		$Spinner.queue_redraw()


func _layout_searching() -> void:
	var margin := 40.0 if size.x >= 1000 else 20.0
	var gap := 40.0 if size.x >= 1000 else 20.0
	var side := maxf(0, minf(size.y - margin * 2, size.x - margin * 2 - gap - 280))
	$Board.position = Vector2(margin, (size.y - side) / 2)
	$Board.size = Vector2(side, side)
	var card: Control = $Card
	card.position = Vector2(margin + side + gap, (size.y - side) / 2)
	card.size = Vector2(size.x - card.position.x - margin, side)
	$Spinner.position = card.position + Vector2(card.size.x / 2 - 48, card.size.y / 2 - 128)
	$Spinner.size = Vector2(96, 96)
	$Robot.position = card.position + Vector2(22, 20)
	$Robot.size = Vector2(24, 24)
	$Avatar.position = card.position + Vector2(16, card.size.y - 50)
	$Avatar.size = Vector2(36, 36)
	$Opponent.position = card.position + Vector2(64, 0)
	$Opponent.size = Vector2(card.size.x - 80, 64)
	$Player.position = card.position + Vector2(64, card.size.y - 64)
	$Player.size = Vector2(card.size.x - 80, 64)
	$Center.position = card.position
	$Center.size = card.size
	var content: Control = $Center/Content
	content.size = card.size
	var middle := card.size.y / 2
	$Center/Content/Title.position = Vector2(0, middle - 8)
	$Center/Content/Title.size = Vector2(card.size.x, 34)
	$Center/Content/Status.position = Vector2(0, middle + 32)
	$Center/Content/Status.size = Vector2(card.size.x, 26)
	var chip_width := minf(135, (card.size.x - 40) / 2)
	$Center/Content/ControlChip.position = Vector2(card.size.x / 2 - chip_width - 5, middle + 78)
	$Center/Content/ControlChip.size = Vector2(chip_width, 36)
	$Center/Content/LevelChip.position = Vector2(card.size.x / 2 + 5, middle + 78)
	$Center/Content/LevelChip.size = Vector2(chip_width, 36)
	queue_redraw()


func _sync_settings_button() -> void:
	var open = get_parent().get_node_or_null("Settings/Open")
	if open:
		var home = get_parent().get_node_or_null("Home")
		open.visible = not visible and (home == null or not home.visible or not home.get_node("Center").visible)
