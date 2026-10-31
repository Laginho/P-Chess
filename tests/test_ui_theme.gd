extends "res://tests/run.gd".Test


func test_project_theme_uses_noto_sans():
	var path: String = ProjectSettings.get_setting("gui/theme/custom", "")
	assert_eq(path, "res://ui/theme/p_chess.tres")
	if not ResourceLoader.exists(path):
		return
	var theme = load(path)
	assert_true(theme is Theme, "project theme is a Theme")
	if theme is Theme:
		assert_true(theme.default_font != null, "default font is bundled")
		if theme.default_font:
			assert_true("NotoSans" in theme.default_font.resource_path, "default font is Noto Sans")


func test_class_icon_colours_match_canvas():
	var colours := {
		"brilliant": "#1baaa6", "great": "#5b8baf", "best": "#98bc49",
		"excellent": "#98bc49", "good": "#9db57a", "book": "#a88764",
		"repertoire": "#3f94e0", "inaccuracy": "#f4bf44", "mistake": "#e28c28",
		"miss": "#ff7769", "blunder": "#c93230", "forced": "#96bc4b",
	}
	for icon in colours:
		var svg := FileAccess.get_file_as_string("res://ui/icons/classes/%s.svg" % icon)
		assert_true(colours[icon] in svg.to_lower(), "%s uses canvas colour %s" % [icon, colours[icon]])


func test_trash_icon_uses_canvas_delete_glyph():
	var svg := FileAccess.get_file_as_string("res://ui/icons/trash.svg")
	assert_true('d="M4 7h16M10 7V4.5h4V7M6.5 7l1 13h9l1-13"' in svg, "Delete game glyph from History.dc.html")


func test_primary_button_focus_ring_contrasts_with_its_fill():
	var theme: Theme = load("res://ui/theme/p_chess.tres")
	var focus := theme.get_stylebox("focus", "PrimaryButton") as StyleBoxFlat
	var normal := theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	assert_true(focus != null and normal != null, "PrimaryButton has flat focus and normal styles")
	if focus and normal:
		assert_eq(focus.border_color, theme.get_color("font_color", "PrimaryButton"), "focus ring uses the text-on-accent colour")
		assert_true(focus.border_color != normal.bg_color, "focus ring is visible on the green fill")
