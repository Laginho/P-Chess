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


func test_class_icons_render_their_white_glyph_at_4x_with_mipmaps():
	for icon in ["brilliant", "great", "best", "excellent", "good", "book", "repertoire", "inaccuracy", "mistake", "miss", "blunder", "forced"]:
		var path := "res://ui/icons/classes/%s.svg" % icon
		var image := Image.new()
		assert_eq(image.load_svg_from_string(FileAccess.get_file_as_string(path), 4.0), OK, icon)
		var white := 0
		for x in image.get_width():
			for y in image.get_height():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.9 and pixel.r > 0.95 and pixel.g > 0.95 and pixel.b > 0.95:
					white += 1
		# Godot's SVG renderer ignores stroke/fill set on a nested <svg>; such glyphs came out black or empty.
		assert_true(white > 300, "%s glyph renders white (%d px)" % [icon, white])
		var texture: Texture2D = load(path)
		assert_eq(texture.get_width(), 128, icon + " imports at svg/scale 4")
		assert_true(texture.get_image().has_mipmaps(), icon + " imports with mipmaps")


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


# WCAG 1.4.3: placeholder text reads at 4.5:1 or more on the ground colour.
func test_placeholder_text_meets_contrast_on_the_ground():
	var theme: Theme = load("res://ui/theme/p_chess.tres")
	var lum := func(c: Color) -> float:
		var l := 0.0
		for i in [[c.r, 0.2126], [c.g, 0.7152], [c.b, 0.0722]]:
			var v: float = i[0]
			l += i[1] * (v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
		return l
	var fg: float = lum.call(theme.get_color("font_placeholder_color", "LineEdit"))
	var bg: float = lum.call(Color("#1f1e1c"))
	assert_true((fg + 0.05) / (bg + 0.05) >= 4.5, "LineEdit placeholder contrast on #1f1e1c")


# Checks the weight the TextServer applies, not the stored dictionary: a "wght" string key is stored but never applied.
func test_font_variations_render_their_weights():
	var theme: Theme = load("res://ui/theme/p_chess.tres")
	var ts := TextServerManager.get_primary_interface()
	var wght := ts.name_to_tag("wght")
	var weights := {"BoldText": 700, "ExtraBoldText": 800, "MediumText": 500, "PrimaryButton": 700, "SectionLabel": 700, "SemiboldText": 600}
	for type in weights:
		var font := theme.get_font("font", type)
		assert_true(font is FontVariation, "%s uses a FontVariation" % type)
		if font is FontVariation:
			var coords: Dictionary = ts.font_get_variation_coordinates(font.get_rids()[0])
			assert_eq(coords.get(wght), weights[type], "%s renders weight %d" % [type, weights[type]])
