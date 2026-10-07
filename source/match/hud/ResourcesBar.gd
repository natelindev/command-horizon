extends PanelContainer

const MATERIALS_ICON = preload("res://assets/ui/economy/materials.svg")
const ELECTRONICS_ICON = preload("res://assets/ui/economy/electronics.svg")
const UNITS_ICON = preload("res://assets/ui/economy/units.svg")
const POWER_ICON = preload("res://assets/ui/economy/power.svg")
const Assignments = preload("res://source/match/EconomyAssignments.gd")

var player = null
var _materials: Label
var _electronics: Label
var _population: Label
var _power_title: Label
var _power_status: Label
var _power_meter: ProgressBar
var _power_fill: StyleBoxFlat
var _power_icon: TextureRect
var _elapsed = 0.0
var _assignment_buttons = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("19212bf2")
	panel.set_corner_radius_all(6)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	add_theme_stylebox_override("panel", panel)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	_materials = _stat(
		row,
		"MATERIALS",
		120,
		MATERIALS_ICON,
		"Recover industrial stock and armor salvage with workers. Used for construction and units."
	)
	_electronics = _stat(
		row,
		"ELECTRONICS",
		125,
		ELECTRONICS_ICON,
		"Recover circuitry with workers. Used for advanced units, chips and research."
	)
	_add_assignments(_materials, 1)
	_add_assignments(_electronics, 2)
	_population = _stat(
		row,
		"UNITS",
		100,
		UNITS_ICON,
		"Active units / unit limit. Units in production also reserve capacity."
	)
	row.add_child(VSeparator.new())
	_power_icon = _icon(row, POWER_ICON)
	var power = VBoxContainer.new()
	power.custom_minimum_size.x = 270
	power.add_theme_constant_override("separation", 1)
	row.add_child(power)
	_power_title = Label.new()
	_power_title.add_theme_font_size_override("font_size", 12)
	power.add_child(_power_title)
	_power_meter = ProgressBar.new()
	_power_meter.custom_minimum_size.y = 5
	_power_meter.show_percentage = false
	var background = StyleBoxFlat.new()
	background.bg_color = Color("0d141c")
	background.set_corner_radius_all(2)
	_power_fill = StyleBoxFlat.new()
	_power_fill.set_corner_radius_all(2)
	_power_meter.add_theme_stylebox_override("background", background)
	_power_meter.add_theme_stylebox_override("fill", _power_fill)
	power.add_child(_power_meter)
	_power_status = Label.new()
	_power_status.add_theme_font_size_override("font_size", 12)
	power.add_child(_power_status)


func _icon(row, texture):
	var icon = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	return icon


func _stat(row, title, width, texture, description):
	var group = HBoxContainer.new()
	group.custom_minimum_size.x = width
	group.add_theme_constant_override("separation", 8)
	group.tooltip_text = description
	row.add_child(group)
	_icon(group, texture)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	group.add_child(column)
	var heading = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color("a5b4c4"))
	column.add_child(heading)
	var amount = Label.new()
	amount.add_theme_font_size_override("font_size", 18)
	column.add_child(amount)
	return amount


func setup(a_player):
	if is_instance_valid(player) and player.changed.is_connected(_refresh):
		player.changed.disconnect(_refresh)
	player = a_player
	player.changed.connect(_refresh)
	_refresh()


func _add_assignments(amount, kind):
	var column = amount.get_parent()
	column.remove_child(amount)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	row.add_child(amount)
	var button = Button.new()
	button.name = "SelectMaterialEngineers" if kind == 1 else "SelectElectronicsEngineers"
	button.flat = true
	button.add_theme_font_size_override("font_size", 11)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_select_assignments.bind(kind))
	row.add_child(button)
	_assignment_buttons[kind] = button


func _selection_panel():
	var match_node = find_parent("Match")
	if (
		match_node == null
		or not "hud" in match_node
		or not is_instance_valid(match_node.hud)
		or not "battle_plan" in match_node.hud
		or player != match_node._get_human_player()
	):
		return null
	return match_node.hud.battle_plan


func _select_assignments(kind):
	var panel = _selection_panel()
	if is_instance_valid(panel):
		panel._select(Assignments.workers(player.get_children(), kind))
	_refresh()


func _refresh_assignments():
	var panel = _selection_panel()
	for kind in _assignment_buttons:
		var button = _assignment_buttons[kind]
		button.visible = is_instance_valid(panel)
		if not button.visible:
			continue
		var count = Assignments.workers(player.get_children(), kind).size()
		var resource = "materials" if kind == 1 else "electronics"
		button.text = "%d engineer%s" % [count, "" if count == 1 else "s"]
		button.disabled = count == 0
		button.tooltip_text = (
			(
				"Select engineers assigned to %s. Queued next jobs count here; "
				+ "selecting keeps cargo and orders."
			)
			% resource
		)
		button.accessibility_description = (
			resource.capitalize() + ": " + button.text + ". " + button.tooltip_text
		)


func _process(delta):
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	if _elapsed >= 0.5:
		_elapsed = 0.0
		_refresh()


func _refresh():
	if not is_instance_valid(player) or _power_meter == null:
		return
	var mission = player.find_parent("Match")
	if mission != null and mission.settings.mission_id == "supply_line":
		var row = _power_icon.get_parent()
		var population_group = _population.get_parent().get_parent()
		for item in row.get_children():
			item.visible = item == population_group
		_population.get_parent().get_child(0).text = "FIELD FORCE"
		_population.text = str(player.population())
		population_group.tooltip_text = "Surviving escorts and trucks; no base economy."
		size.x = 0
		return
	_materials.text = str(player.resource_a)
	_electronics.text = str(player.resource_b)
	_refresh_assignments()
	_population.text = "%d / 100" % player.population()
	var power = player.power_totals()
	var spare = power.x - power.y
	var low = spare < 0
	var near_capacity = not low and spare <= power.x * 0.1
	var color = Color("79d3c5")
	if low:
		color = Color("ffad75")
	elif near_capacity:
		color = Color("e7c578")
	_power_icon.modulate = color
	_power_title.text = "POWER   %d used / %d supply" % [power.y, power.x]
	_power_meter.max_value = maxi(1, power.x)
	_power_meter.value = mini(power.y, power.x)
	# A deficit with no generators still needs a visible warning meter.
	if low and power.x == 0:
		_power_meter.value = 1
	_power_fill.bg_color = color
	_power_status.add_theme_color_override("font_color", color)
	if low:
		_power_status.text = "LOW POWER · %d deficit · 35%% speed" % -spare
	elif power.x == 0:
		_power_status.text = "No generation · build a power plant"
	elif spare == 0:
		_power_status.text = "At capacity · build more power"
	elif near_capacity:
		_power_status.text = "%d available · build power soon" % spare
	else:
		_power_status.text = "%d power available" % spare
	tooltip_text = (
		"Power meter: demand / supply. Only completed structures supply or consume power. "
		+ "Low power runs production, chip installation, research and depot repair at 35% speed. "
		+ (
			"Queued units reserve population. Structures: %d / 40 (includes foundations)."
			% player.structure_count()
		)
	)
