extends RefCounted

const BROWN_LIGHT := Color("#f0d9b5")
const BROWN_DARK := Color("#b58863")
const SOUND_EVENTS := ["move", "capture", "castle", "check", "promote", "premove", "low_time", "game_start", "game_end"]

# Folder themes (§8.6). User themes with the same name override bundled ones.
var _roots: Array[String]


func _init(builtin := "res://themes", custom := "user://themes") -> void:
	_roots = [builtin, custom]


# Name -> folder, sorted by name. Missing roots are normal on a fresh install.
func list_themes(kind: String) -> Dictionary:
	var found := {}
	if not kind in ["boards", "pieces", "sounds"]:
		return found
	for root in _roots:
		var parent := root.path_join(kind)
		if not DirAccess.dir_exists_absolute(parent):
			continue
		for name in DirAccess.get_directories_at(parent):
			var folder := parent.path_join(name)
			if kind != "pieces" or _complete_pieces(folder):
				found[name] = folder
	var sorted := {}
	var names := found.keys()
	names.sort()
	for name in names:
		sorted[name] = found[name]
	return sorted


# A texture covers the whole board; colours also provide contrasting coordinates.
func load_board(name: String) -> Dictionary:
	var folder: String = list_themes("boards").get(name, "")
	if folder and FileAccess.file_exists(folder.path_join("theme.json")):
		var json := JSON.new()
		json.parse(FileAccess.get_file_as_string(folder.path_join("theme.json")))
		var data = json.data
		if data is Dictionary:
			if data.get("texture") is String:
				var path := folder.path_join(data.texture)
				if FileAccess.file_exists(path):
					var texture := load_texture(path)
					if texture:
						return {"light": BROWN_LIGHT, "dark": BROWN_DARK, "texture": texture}
			elif data.get("light") is String and data.get("dark") is String:
				if Color.html_is_valid(data.light) and Color.html_is_valid(data.dark):
					return {"light": Color(data.light), "dark": Color(data.dark), "texture": null}
	push_warning("Invalid board theme '%s'; using brown." % name)
	return {"light": BROWN_LIGHT, "dark": BROWN_DARK, "texture": null}


# Missing files intentionally leave individual events silent.
func load_sounds(name: String) -> Dictionary:
	var streams := {}
	var folder: String = list_themes("sounds").get(name, "")
	if not folder:
		return streams
	for event in SOUND_EVENTS:
		var path := folder.path_join(event + ".ogg")
		if FileAccess.file_exists(path):
			var stream := AudioStreamOggVorbis.load_from_file(path)
			if stream:
				streams[event] = stream
	return streams


func load_pieces(name: String) -> Dictionary:
	var sets := list_themes("pieces")
	var folder: String = sets.get(name, "")
	if not folder:
		push_warning("Incomplete or missing piece theme '%s'; using cburnett." % name)
		folder = sets.get("cburnett", "")
	var textures := {}
	if folder:
		for piece in "KQRBNPkqrbnp":
			var file := ("w" if piece == piece.to_upper() else "b") + piece.to_upper() + ".svg"
			textures[piece] = load_texture(folder.path_join(file), 4.0)
	return textures


# Load raw files so themes also work in user://, without the editor's import cache.
static func load_texture(path: String, svg_scale := 1.0) -> Texture2D:
	var image := Image.new()
	var error: Error
	if path.get_extension().to_lower() == "svg":
		error = image.load_svg_from_string(FileAccess.get_file_as_string(path), svg_scale)
	else:
		error = image.load(path)
	if error != OK:
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _complete_pieces(folder: String) -> bool:
	for side in ["w", "b"]:
		for role in "KQRBNP":
			if not FileAccess.file_exists(folder.path_join(side + role + ".svg")):
				return false
	return true
