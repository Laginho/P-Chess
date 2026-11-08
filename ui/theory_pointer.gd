extends Control

signal back_requested
signal solving_requested(unit: Dictionary)

var unit := {}


func _ready() -> void:
	$Margin/Content/Header/Back.pressed.connect(func(): back_requested.emit())
	$Margin/Content/Center/Scroll/Body/Footer/BackToUnit.pressed.connect(func(): back_requested.emit())
	$Margin/Content/Center/Scroll/Body/Footer/Next.pressed.connect(func(): solving_requested.emit(unit))


func present(course, selected: Dictionary) -> void:
	unit = selected
	var theory = unit.get("theory", {})
	if not theory is Dictionary:
		theory = {}
	$Margin/Content/Header/Heading/UnitName.text = "%s · Part 1" % unit.get("title", "")
	$Margin/Content/Center/Scroll/Body/GoalCard/GoalContent/Goal.text = str(theory.get("goal", ""))
	var terms := $Margin/Content/Center/Scroll/Body/SearchCard/SearchContent/Terms
	for child in terms.get_children():
		terms.remove_child(child)
		child.queue_free()
	var search_terms = theory.get("search_terms", [])
	if search_terms is Array:
		for term in search_terms:
			if not term is String:
				continue
			var button := Button.new()
			button.text = term
			button.custom_minimum_size.y = 44
			button.tooltip_text = "Copy to clipboard"
			button.pressed.connect(func(): DisplayServer.clipboard_set(term))
			terms.add_child(button)
	var books := $Margin/Content/Center/Scroll/Body/ReadCard/ReadContent/Books
	for child in books.get_children():
		books.remove_child(child)
		child.queue_free()
	var entries = theory.get("books", [])
	if entries is Array:
		for book in entries:
			if not book is Dictionary:
				continue
			var row := VBoxContainer.new()
			var title := Label.new()
			title.name = "Title"
			title.text = str(book.get("title", ""))
			title.theme_type_variation = "SemiboldText"
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(title)
			var chapter := Label.new()
			chapter.name = "Chapter"
			chapter.text = str(book.get("chapter", ""))
			chapter.theme_type_variation = "MutedText"
			chapter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(chapter)
			books.add_child(row)
	$Margin/Content/Center/Scroll/Body/ReadCard.visible = books.get_child_count() > 0
	$Margin/Content/Center/Scroll/Body/SaveError.visible = not course.open_theory(unit)
	show()
