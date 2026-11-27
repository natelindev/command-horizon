extends Button

const Factions = preload("res://source/match/FactionCatalog.gd")

var camp = null
var contract_index = 0
var queue = null
var queue_element = null


func _ready():
	if camp == null and (queue == null or queue_element == null):
		return
	var catalog = load("res://source/match/BastionCatalog.gd")
	var role = (
		camp.jobs[contract_index].role
		if camp != null
		else catalog.type_from_path(queue_element.unit_prototype.resource_path)
	)
	var faction = "bastion" if camp != null else queue.get_parent().player.faction
	theme_type_variation = "HudSlotButton"
	custom_minimum_size = Vector2(44, 44)
	text = ""
	icon = Factions.portrait(faction, role)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", 36)
	tooltip_text = tr(Factions.title(faction, role)) + tr(" — click to cancel and refund")
	tooltip_text += (
		"\n"
		+ (
			tr("Producer: %s")
			% (
				tr(camp.label_title)
				if camp != null
				else tr(Factions.title(faction, queue.get_parent().type))
			)
		)
	)
	accessibility_name = tooltip_text
	if camp != null:
		pressed.connect(func(): camp.cancel_hire(camp._match._get_human_player(), contract_index))
	else:
		queue_element.changed.connect(_on_queue_element_changed)
		pressed.connect(func(): queue.cancel(queue_element))
	_build_progress()
	if camp != null:
		_process(0)
	else:
		_on_queue_element_changed()


func _build_progress():
	var kit = load("res://source/match/hud/BattleTheme.gd")
	var label = find_child("Label")
	label.add_theme_font_override("font", kit.numeral_font())
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color("050607"))
	label.offset_right = -5
	label.offset_bottom = -6
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


func _display_progress(progress):
	find_child("Label").text = "%d%%" % int(progress * 100) if progress > 0 else ""
	get_node("Progress").value = progress


func _on_queue_element_changed():
	_display_progress(queue_element.progress())


func _process(_delta):
	if not is_instance_valid(camp) or contract_index >= camp.jobs.size():
		return
	var job = camp.jobs[contract_index]
	var duration = Factions.duration(camp.player, job.role)
	_display_progress(clampf(1.0 - job.left / duration, 0, 1) if contract_index == 0 else 0.0)
