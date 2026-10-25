extends RefCounted

# Shared cleanup for a harness's isolated History root: removes only `folder` and its `games`
# child (child first, since a non-empty directory cannot be removed), skipping absent ones.


static func clean(folder: String) -> void:
	for subdir in [folder.path_join("games"), folder]:
		if DirAccess.dir_exists_absolute(subdir):
			for file in DirAccess.get_files_at(subdir):
				DirAccess.remove_absolute(subdir.path_join(file))
			DirAccess.remove_absolute(subdir)
