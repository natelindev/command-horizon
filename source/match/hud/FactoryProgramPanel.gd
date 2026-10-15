extends VBoxContainer

const Library = preload("res://source/match/programs/ProgramLibrary.gd")
var queue
var _options
var _summary
var _library = Library.new()
var _entries = []


func _ready():
	add_theme_constant_override("separation", 5)
	var row = HBoxContainer.new()
	add_child(row)
	_options = OptionButton.new()
	_options.name = "FactoryProgramVersion"
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.custom_minimum_size.x = 330
	_options.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_options.item_selected.connect(_select)
	row.add_child(_options)
	var reload_button = Button.new()
	reload_button.text = "Refresh library"
	reload_button.pressed.connect(reload_library)
	row.add_child(reload_button)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_theme_font_size_override("font_size", 12)
	add_child(_summary)
	reload_library()


func reload_library():
	_options.clear()
	_options.add_item("New units: Hold · built-in")
	_entries = [{}]
	var readable = _library.read_library(queue.program_library_path)
	var selected = 0
	if readable:
		for entry in _library.versions:
			var pin = load("res://source/match/programs/ProgramRecord.gd").pin(entry)
			_entries.append(pin)
			_options.add_item(
				(
					"New units: %s · v%d%s"
					% [
						entry.name,
						entry.version,
						" · " + entry.mode.capitalize() if entry.mode != "preset" else ""
					]
				)
			)
			if (
				queue.program_pin == pin
				or (
					queue.program_pin.get("name") == entry.name
					and queue.program_pin.get("version") == entry.version
					and not queue.program_pin.has("content_hash")
				)
			):
				selected = _entries.size() - 1
	if not queue.program_pin.is_empty() and selected == 0:
		_entries.append(queue.program_pin.duplicate())
		_options.add_item("Missing: %s · v%d" % [queue.program_pin.name, queue.program_pin.version])
		selected = _entries.size() - 1
	_options.select(selected)
	_summary.text = (
		(
			"Exact version applies to new jobs. Rally orders keep manual control; "
			+ "unsupported roles use Hold. Choose map assignments per unit."
		)
		if readable and (queue.program_pin.is_empty() or selected < _library.versions.size() + 1)
		else "Saved version unavailable. New jobs receive Hold until you choose another version."
	)


func _select(index):
	queue.program_pin = _entries[index].duplicate(true)
	_summary.text = "Factory updated. Existing units and queued jobs keep their current program."
