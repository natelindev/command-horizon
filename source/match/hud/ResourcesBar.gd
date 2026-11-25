extends PanelContainer

## Top-left console plate: resource readouts in recessed screens, assigned
## engineers, unit count and a segmented power gauge.

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")

const MATERIALS_ICON = preload("res://assets/ui/economy/materials.svg")
const ELECTRONICS_ICON = preload("res://assets/ui/economy/electronics.svg")
const UNITS_ICON = preload("res://assets/ui/economy/units.svg")
const POWER_ICON = preload("res://assets/ui/economy/power.svg")
const Assignments = preload("res://source/match/EconomyAssignments.gd")
const MATERIALS_TINT = Color("e3c48a")
const ELECTRONICS_TINT = Color("8fd3c6")

var player = null
var _materials: Label
var _electronics: Label
var _population: Label
var _power_title: Label
var _power_status: Label
var _power_meter: ProgressBar
var _power_fill: StyleBox
var _power_icon: TextureRect
var _elapsed = 0.0
var _assignment_buttons = {}
var _counters = {}
var _income_labels = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = BattleTheme.create()
	var plate = BattleTheme.strip(18, 0)
	# Hang below the top rail; the plate's own bevel carries the bottom edge.
	plate.content_margin_top = HudLayout.TOP_RAIL + 2
	plate.content_margin_bottom = 5
	plate.content_margin_right = 22
	add_theme_stylebox_override("panel", plate)
	custom_minimum_size.y = HudLayout.TOP_PLATE
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_materials = _stat(
		row,
		"Materials",
		MATERIALS_ICON,
		MATERIALS_TINT,
		"Recover industrial stock and armor salvage with workers. Used for construction and units."
	)
	_electronics = _stat(
		row,
		"Electronics",
		ELECTRONICS_ICON,
		ELECTRONICS_TINT,
		"Recover circuitry with workers. Used for advanced units and research."
	)
	_add_assignments(_materials, 1)
	_add_assignments(_electronics, 2)
	_population = _stat(
		row,
		"Units",
		UNITS_ICON,
		BattleTheme.IVORY,
		"Active units / unit limit. Units in production also reserve capacity."
	)
	_population.custom_minimum_size.x = 70
	row.add_child(VSeparator.new())
	_power_icon = _icon_socket(row, POWER_ICON, BattleTheme.SIGNAL_OK)
	var power = VBoxContainer.new()
	power.custom_minimum_size.x = 168
	power.alignment = BoxContainer.ALIGNMENT_CENTER
	power.add_theme_constant_override("separation", 2)
	row.add_child(power)
	_power_title = Label.new()
	_power_title.theme_type_variation = "HudCaption"
	_power_title.uppercase = true
	_power_title.add_theme_font_size_override("font_size", 12)
	_power_title.add_theme_color_override("font_color", Color("c9c4b6"))
	power.add_child(_power_title)
	_power_meter = ProgressBar.new()
	_power_meter.custom_minimum_size.y = 11
	_power_meter.show_percentage = false
	_power_fill = BattleTheme.bar_fill(BattleTheme.SIGNAL_OK)
	_power_meter.add_theme_stylebox_override("fill", _power_fill)
	power.add_child(_power_meter)
	_power_status = Label.new()
	_power_status.theme_type_variation = "HudCaption"
	_power_status.add_theme_font_size_override("font_size", 12)
	power.add_child(_power_status)


func _icon_socket(row, texture, tint):
	var socket = PanelContainer.new()
	socket.add_theme_stylebox_override("panel", BattleTheme.socket(5, 5))
	socket.custom_minimum_size = Vector2(32, 32)
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(socket)
	var icon = TextureRect.new()
	icon.texture = texture
	icon.modulate = tint
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket.add_child(icon)
	return icon


func _stat(row, title, texture, tint, description):
	# Icon socket + large tabular numeral; the name lives in the tooltip.
	var group = HBoxContainer.new()
	group.name = title + "Readout"
	group.add_theme_constant_override("separation", 7)
	group.tooltip_text = description
	group.accessibility_name = title
	row.add_child(group)
	_icon_socket(group, texture, tint)
	var column = HBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	group.add_child(column)
	var values = VBoxContainer.new()
	values.alignment = BoxContainer.ALIGNMENT_CENTER
	values.add_theme_constant_override("separation", 0)
	column.add_child(values)
	var amount = Label.new()
	amount.theme_type_variation = "HudNumeral"
	amount.custom_minimum_size.x = 40
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	values.add_child(amount)
	if title in ["Materials", "Electronics"]:
		var income = Label.new()
		income.name = "RefineryIncome"
		income.add_theme_font_size_override("font_size", 11)
		income.add_theme_color_override("font_color", tint)
		income.hide()
		values.add_child(income)
		_income_labels[1 if title == "Materials" else 2] = income
	return amount


func setup(a_player):
	if is_instance_valid(player) and player.changed.is_connected(_refresh):
		player.changed.disconnect(_refresh)
	player = a_player
	player.changed.connect(_refresh)
	_refresh()


func _add_assignments(amount, kind):
	var button = Button.new()
	button.name = "SelectMaterialEngineers" if kind == 1 else "SelectElectronicsEngineers"
	button.theme_type_variation = "BattleQuietButton"
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", BattleTheme.surface(Color.TRANSPARENT, 4, 2))
	button.add_theme_stylebox_override("hover", BattleTheme.glow(.55, 4, 2))
	button.add_theme_stylebox_override("pressed", BattleTheme.socket(4, 2))
	button.add_theme_stylebox_override("disabled", BattleTheme.surface(Color.TRANSPARENT, 4, 2))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_select_assignments.bind(kind))
	amount.get_parent().get_parent().add_child(button)
	_assignment_buttons[kind] = button


func _selection_panel():
	var match_node = find_parent("Match")
	if (
		match_node == null
		or not "hud" in match_node
		or not is_instance_valid(match_node.hud)
		or not match_node.hud.has_method("select_units")
		or player != match_node._get_human_player()
	):
		return null
	return match_node.hud


func _select_assignments(kind):
	var panel = _selection_panel()
	if is_instance_valid(panel):
		panel.select_units(Assignments.workers(player.get_children(), kind))
	_refresh()


func _refresh_assignments():
	var panel = _selection_panel()
	for kind in _assignment_buttons:
		var button = _assignment_buttons[kind]
		var count = Assignments.workers(player.get_children(), kind).size()
		# Only assigned engineers are worth a readout; zero is the default.
		button.visible = is_instance_valid(panel) and count > 0
		if not is_instance_valid(panel):
			continue
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


func _refresh_refinery_income():
	var payment = Vector2.ZERO
	var owned = 0
	var active = 0
	for site in get_tree().get_nodes_in_group("points_of_interest"):
		if site.kind not in ["refinery", "data_relay"] or site.player != player:
			continue
		owned += 1
		if site.operational() and site.income_payment() != Vector2i.ZERO:
			active += 1
			payment += Vector2(site.income_payment()) * 60.0 / site.income_interval()
	for kind in _income_labels:
		var label = _income_labels[kind]
		var amount = payment.x if kind == 1 else payment.y
		label.visible = owned > 0
		label.text = tr("+%d / min") % roundi(amount)
		label.tooltip_text = tr("Economic sites · %d / %d active") % [active, owned]
		label.accessibility_name = label.tooltip_text + ": " + label.text


func _count(label: Label, value: int):
	# Readouts roll to new totals and glint on income, like a mechanical counter.
	var previous = _counters.get(label, null)
	_counters[label] = value
	if previous == null or not is_inside_tree():
		label.text = str(value)
		return
	if previous == value:
		return
	if label.has_meta("counter"):
		var running = label.get_meta("counter")
		if running.is_valid():
			running.kill()
	var tween = create_tween().set_parallel(true)
	label.set_meta("counter", tween)
	tween.tween_method(
		func(shown): label.text = str(int(round(shown))), float(previous), float(value), .35
	)
	if value > previous:
		label.modulate = Color(1.35, 1.25, 1.0)
		tween.tween_property(label, "modulate", Color.WHITE, .5)


func _refresh():
	if not is_instance_valid(player) or _power_meter == null:
		return
	var mission = player.find_parent("Match")
	if mission != null and mission.settings.mission_id == "supply_line":
		var row = _power_icon.get_parent().get_parent()
		var population_group = _population.get_parent().get_parent().get_parent()
		for item in row.get_children():
			item.visible = item == population_group
		_population.text = str(player.population())
		population_group.tooltip_text = "Surviving escorts and trucks; no base economy."
		size.x = 0
		return
	_count(_materials, player.resource_a)
	_count(_electronics, player.resource_b)
	_refresh_assignments()
	_refresh_refinery_income()
	_population.text = "%d / 100" % player.population()
	var power = player.power_totals()
	var spare = power.x - power.y
	var low = spare < 0
	var near_capacity = not low and spare <= power.x * 0.1
	var color = BattleTheme.SIGNAL_OK
	if low:
		color = BattleTheme.SIGNAL_BAD
	elif near_capacity:
		color = BattleTheme.SIGNAL_WARN
	_power_icon.modulate = color
	_power_title.text = tr("POWER   %d used / %d supply") % [power.y, power.x]
	_power_meter.max_value = maxi(1, power.x)
	_power_meter.value = mini(power.y, power.x)
	# A deficit with no generators still needs a visible warning meter.
	if low and power.x == 0:
		_power_meter.value = 1
	_power_fill.modulate = color
	_power_meter.queue_redraw()
	_power_status.add_theme_color_override("font_color", color)
	if low:
		_power_status.text = tr("BROWNOUT · %d deficit · 25%% speed") % -spare
	elif power.x == 0:
		_power_status.text = tr("No generation · build a power plant")
	elif spare == 0:
		_power_status.text = tr("At capacity · build more power")
	elif near_capacity:
		_power_status.text = tr("%d available · build power soon") % spare
	else:
		# Spare power is supply minus demand, already on the meter: say nothing.
		_power_status.text = tr("Logistics · %d / 100") % floori(player.logistics)
	_power_status.visible = not _power_status.text.is_empty()
	tooltip_text = (
		tr("Power meter: demand / supply. Only completed structures supply or consume power.")
		+ " "
		+ tr(
			(
				"Brownouts stop defense turrets, halve shield recharge and slow production, "
				+ "research and depot repair to 25%."
			)
		)
		+ " "
		+ tr("Logistics · %d / 100") % floori(player.logistics)
		+ ". "
		+ (
			tr("Queued units reserve population. Structures: %d / 40 (includes foundations).")
			% player.structure_count()
		)
	)
