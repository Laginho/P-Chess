extends RefCounted

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


static func _complete_pieces(folder: String) -> bool:
	for side in ["w", "b"]:
		for role in "KQRBNP":
			if not FileAccess.file_exists(folder.path_join(side + role + ".svg")):
				return false
	return true
