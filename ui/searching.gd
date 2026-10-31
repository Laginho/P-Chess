extends Control


func present(settings: Dictionary) -> void:
	$Center/Content/Match.text = "%s  ·  Maia %s" % [settings.control, settings.level.trim_prefix("maia-")]
	show()


func status(message: String) -> void:
	$Center/Content/Status.text = message
