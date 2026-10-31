extends AcceptDialog

var store
var shade: ColorRect


func _ready() -> void:
	shade = ColorRect.new()
	shade.color = Color(0.04, 0.04, 0.035, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()
	get_parent().add_child(shade)
	get_parent().move_child(shade, get_index())
	visibility_changed.connect(func(): shade.visible = visible)
	var panel: StyleBox = get_theme_stylebox("panel", "CardPanel").duplicate()
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 28
	panel.content_margin_bottom = 28
	add_theme_stylebox_override("panel", panel)
	for child in get_ok_button().get_parent().get_children(true):
		child.size_flags_horizontal = Control.SIZE_EXPAND_FILL if child == get_ok_button() else 0
	get_ok_button().size_flags_vertical = Control.SIZE_EXPAND_FILL
	get_ok_button().theme_type_variation = "PrimaryButton"
	get_ok_button().custom_minimum_size.y = 48
	confirmed.connect(_confirm)
	$Content/Name.text_submitted.connect(func(_text): _confirm())
	$Content/Name.text_changed.connect(func(text): get_ok_button().disabled = text.strip_edges().is_empty())


func present(preferences) -> void:
	store = preferences
	if store.has_player_name():
		return
	$Content/Name.text = store.get_value("player_name")
	get_ok_button().disabled = false
	popup_centered(Vector2i(420, 280))
	$Content/Name.grab_focus()
	$Content/Name.select_all()


func _confirm() -> void:
	if store.set_value("player_name", $Content/Name.text.strip_edges()):
		hide()
