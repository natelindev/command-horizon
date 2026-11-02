extends VBoxContainer

## Direct passenger controls stay in the host's bottom console. Infantry never
## become world-visible or replace the selected carrier while using these cards.
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
var host = null
var cards = []
var unload_all: Button
var _elapsed = 0.0
var _grid: GridContainer


func _ready():
	add_theme_constant_override("separation", 8)
	var header = HBoxContainer.new()
	add_child(header)
	var title = Label.new()
	title.text = tr("Infantry mounts")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	unload_all = Button.new()
	unload_all.text = tr("Unload all")
	unload_all.pressed.connect(_unload_all)
	header.add_child(unload_all)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	refresh()


func _process(delta):
	_elapsed += delta
	if _elapsed >= .1:
		_elapsed = 0.0
		refresh()


func _add_card(slot: int):
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 124
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", BattleTheme.socket(6, 4))
	_grid.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 1)
	row.add_child(details)
	var title = Label.new()
	title.add_theme_font_size_override("font_size", 12)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(title)
	var price = Label.new()
	price.add_theme_font_size_override("font_size", 10)
	price.add_theme_color_override("font_color", BattleTheme.MUTED)
	details.add_child(price)
	var status = Label.new()
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", BattleTheme.MUTED)
	details.add_child(status)
	var unload = Button.new()
	unload.text = tr("Unload")
	unload.custom_minimum_size.y = 25
	unload.add_theme_font_size_override("font_size", 12)
	unload.pressed.connect(_unload_slot.bind(slot))
	column.add_child(unload)
	cards.append(
		{
			"panel": panel,
			"portrait": portrait,
			"title": title,
			"status": status,
			"price": price,
			"unload": unload
		}
	)


func refresh():
	if not is_instance_valid(host) or host.garrison_mount == null:
		return
	var mount = host.garrison_mount
	while cards.size() < mount.capacity:
		_add_card(cards.size())
	_grid.columns = 3 if mount.capacity > 4 else mount.capacity
	unload_all.disabled = mount.occupants.is_empty()
	for index in cards.size():
		var card = cards[index]
		card.panel.visible = index < mount.capacity
		var units = mount.occupants.filter(
			func(unit):
				return is_instance_valid(unit) and unit.get_meta("garrison_slot", -1) == index
		)
		var passenger = units[0] if not units.is_empty() else null
		card.unload.disabled = passenger == null or passenger in mount.pending_evacuations
		card.portrait.texture = (
			Factions.portrait(passenger.player.faction, passenger.type)
			if passenger != null
			else null
		)
		card.title.text = (
			tr(Factions.title(passenger.player.faction, passenger.type))
			if passenger != null
			else tr("Empty mount")
		)
		var state = tr("Ready")
		if passenger == null:
			state = "—"
		elif passenger in mount.pending_evacuations:
			state = tr("Evacuating")
		elif is_instance_valid(passenger.aim_target):
			state = tr("Firing")
		card.status.text = state
		if passenger != null:
			var price = Factions.cost(passenger.player, passenger.type)
			card.price.text = "%dM / %dE" % [price.resource_a, price.resource_b]
			card.panel.tooltip_text = (
				"%s\n%s\n%dM / %dE"
				% [
					card.title.text,
					tr(Factions.description(passenger.player.faction, passenger.type)),
					price.resource_a,
					price.resource_b
				]
			)
		else:
			card.price.text = ""
			card.panel.tooltip_text = tr(
				"Infantry can fire from the carrier while remaining protected inside."
			)
		card.unload.accessibility_name = tr("Unload") + " · " + card.title.text
		card.unload.accessibility_description = tr(
			"Keep the carrier selected and unload this infantry unit nearby."
		)


func _unload_slot(slot: int):
	if _network_unload(slot):
		return
	if not is_instance_valid(host) or host.garrison_mount == null:
		return
	for passenger in host.garrison_mount.occupants.duplicate():
		if passenger.get_meta("garrison_slot", -1) == slot:
			passenger.manual_orders.cancel()
			passenger.action = null
			break
	refresh()


func _unload_all():
	if _network_unload(-1):
		return
	if not is_instance_valid(host) or host.garrison_mount == null:
		return
	for passenger in host.garrison_mount.occupants.duplicate():
		passenger.manual_orders.cancel()
		passenger.action = null
	refresh()


func _network_unload(slot: int) -> bool:
	var gate = load("res://source/match/network/NetworkGate.gd")
	if not is_instance_valid(host):
		return false
	var passengers = host.garrison_mount.occupants.filter(func(unit): return slot < 0 or unit.get_meta("garrison_slot", -1) == slot)
	if passengers.is_empty():
		return false
	return gate.intercept(host, {"kind": "order", "units": passengers.map(gate.id_for), "order": "stop", "point": gate.Protocol.quantize(host.global_position)})
