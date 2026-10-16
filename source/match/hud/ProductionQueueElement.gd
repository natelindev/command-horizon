extends Button

var queue = null
var queue_element = null


func _ready():
	if queue == null or queue_element == null:
		return
	queue_element.changed.connect(_on_queue_element_changed)
	pressed.connect(func(): queue.cancel(queue_element))
	var catalog = load("res://source/match/BastionCatalog.gd")
	var unit_type = catalog.type_from_path(queue_element.unit_prototype.resource_path)
	text = ""
	var factions = load("res://source/match/FactionCatalog.gd")
	var faction = queue.get_parent().player.faction
	# A missing portrait leaves the percentage readable on a plain key.
	icon = factions.portrait(faction, unit_type)
	expand_icon = true
	# Translate each part: the composed line has no catalog entry of its own.
	tooltip_text = (
		tr(factions.title(faction, unit_type))
		+ (tr(" · basic chip fitted") if queue_element.fitted_chip else "")
		+ (
			" · " + tr(queue_element.program_snapshot.title)
			if not queue_element.program_snapshot.is_empty()
			else ""
		)
		+ tr(" — click to cancel and refund")
		+ "\n"
		+ tr("Producer: %s") % tr(factions.title(faction, queue.get_parent().type))
	)
	var kit = load("res://source/match/hud/BattleTheme.gd")
	var label = find_child("Label")
	label.add_theme_font_override("font", kit.numeral_font())
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color("050607"))
	label.offset_right = -5
	label.offset_bottom = -6
	# A segmented progress strip along the key's lip.
	var bar = ProgressBar.new()
	bar.name = "Progress"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("fill", kit.bar_fill(kit.accent()))
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 5
	bar.offset_right = -5
	bar.offset_top = -9
	bar.offset_bottom = -4
	add_child(bar)
	_on_queue_element_changed()


func _on_queue_element_changed():
	var progress = queue_element.progress()
	# Waiting jobs stay quiet; only work in progress shows its percentage.
	find_child("Label").text = "{0}%".format([int(progress * 100.0)]) if progress > 0.0 else ""
	var bar = get_node_or_null("Progress")
	if bar != null:
		bar.value = progress
