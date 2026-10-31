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
