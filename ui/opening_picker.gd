extends PopupPanel

signal saved(name: String)
signal catalog_ready(error: String)

const Book = preload("res://bot/book.gd")
var book = Book.new()
var _items := {}
var _worker: Thread
var _loaded := false
var _requested_selection := ""
# Optional system boundary for thread-start failures; normal callers use Thread.start.
var start_catalog_worker := Callable()
var _catalog_error := ""

@onready var _search: LineEdit = $Margin/Form/Search
@onready var _tree: Tree = $Margin/Form/Tree
@onready var _name: LineEdit = $Margin/Form/SaveRow/Name
@onready var _save: Button = $Margin/Form/SaveRow/Save
@onready var _saved: OptionButton = $Margin/Form/LoadRow/Saved
@onready var _load: Button = $Margin/Form/LoadRow/Load
@onready var _status: Label = $Margin/Form/Status


func _ready() -> void:
	_search.text_changed.connect(func(_text): _rebuild())
	_tree.item_edited.connect(_on_item_edited)
	_save.pressed.connect(_save_selection)
	_load.pressed.connect(_load_selection)
	$Margin/Form/Done.pressed.connect(hide)
	_loaded = not book.entries.is_empty()
	_refresh_names()
	if _loaded:
		_rebuild()


func present(selection := "") -> void:
	_requested_selection = selection
	popup_centered(Vector2i(680, 540))
	if not _loaded and book.entries.is_empty():
		_status.text = "Loading opening catalog…"
		_search.editable = false
		_save.disabled = true
		_load.disabled = true
	var error: String = await ensure_catalog()
	if not error.is_empty():
		_status.text = error
	elif visible:
		_catalog_ready()


# Main can await the same load without opening this popup or applying an old selection.
# A nonempty catalog supplied before loading is already ready (including imported fixtures).
func ensure_catalog() -> String:
	if _worker == null and not book.entries.is_empty():
		_loaded = true
	if _loaded:
		return ""
	if _worker == null:
		_worker = Thread.new()
		var status: int = start_catalog_worker.call(_worker, book.load_catalog) \
				if start_catalog_worker.is_valid() else _worker.start(book.load_catalog)
		if status != OK:
			_worker = null
			return "Cannot start catalog loading. Close and try again."
	await catalog_ready
	return _catalog_error


func _process(_delta: float) -> void:
	if _worker != null and not _worker.is_alive():
		_worker.wait_to_finish()
		_worker = null
		_loaded = not book.entries.is_empty()
		_catalog_error = "" if _loaded else "Cannot load opening catalog. " + "\n".join(book.errors)
		catalog_ready.emit(_catalog_error)


func _exit_tree() -> void:
	if _worker != null:
		_worker.wait_to_finish()


func _catalog_ready() -> void:
	_search.editable = true
	_save.disabled = book.entries.is_empty()
	_refresh_names(_requested_selection)
	_rebuild()
	if not _requested_selection.is_empty():
		_name.text = _requested_selection
		var error: String = book.load_selection(_requested_selection)
		_refresh_checks()
		if not error.is_empty():
			_status.text = error
	_search.grab_focus()


func _rebuild() -> void:
	_tree.clear()
	_items.clear()
	var root := _tree.create_item()
	for path in book.search(_search.text):
		var node: Dictionary = book.nodes[path]
		var parent: TreeItem = root if node.parent.is_empty() else _items[node.parent]
		var item := _tree.create_item(parent)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_text(0, node.label)
		item.set_metadata(0, path)
		item.set_tooltip_text(0, "%s\n%d catalog lines" % [path, node.lines.size()])
		item.collapsed = _search.text.is_empty() and not node.children.is_empty()
		_items[path] = item
	_refresh_checks()


func _on_item_edited() -> void:
	var item := _tree.get_edited()
	if item == null:
		return
	book.set_checked(item.get_metadata(0), item.is_checked(0))
	_refresh_checks()


func _refresh_checks() -> void:
	for path in _items:
		var state: int = book.check_state(path)
		_items[path].set_indeterminate(0, false)
		_items[path].set_checked(0, state == 1)
		_items[path].set_indeterminate(0, state == 2)
	_status.text = "%d of %d lines selected" % [book.selected_ids().size(), book.entries.size()]
	if not book.errors.is_empty():
		_status.text += "; %d catalog errors (see tooltip)" % book.errors.size()
	_status.tooltip_text = "\n".join(book.errors)


func _refresh_names(preferred := "") -> void:
	_saved.clear()
	for name in book.selection_names():
		_saved.add_item(name)
		if name == preferred:
			_saved.select(_saved.item_count - 1)
	_load.disabled = _saved.item_count == 0


func _save_selection() -> void:
	var name := _name.text.strip_edges()
	var error: String = book.save_selection(name)
	if not error.is_empty():
		_status.text = error
		return
	_refresh_names(name)
	_status.text = "Saved “%s”." % name
	saved.emit(name)


func _load_selection() -> void:
	if _saved.selected < 0:
		return
	var name := _saved.get_item_text(_saved.selected)
	var error: String = book.load_selection(name)
	if not error.is_empty():
		_status.text = error
		return
	_name.text = name
	_refresh_checks()
