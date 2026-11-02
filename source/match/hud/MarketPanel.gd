extends VBoxContainer

const Choice = preload("res://source/match/hud/ResearchButton.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
var player
var _buttons = {}
var _contracts
var _aircraft = {}
var _refresh_left = 0.0


func _ready():
	add_theme_constant_override("separation", 6)
	_contracts = load("res://source/match/economy/FrontierAirContracts.gd").get_for(player)
	var exchanges = HBoxContainer.new()
	exchanges.add_theme_constant_override("separation", 6)
	add_child(exchanges)
	for direction in ["buy_electronics", "buy_materials"]:
		var button = Choice.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): player.market_exchange(direction))
		exchanges.add_child(button)
		_buttons[direction] = button
	var aircraft = HBoxContainer.new()
	aircraft.add_theme_constant_override("separation", 6)
	add_child(aircraft)
	for role in Factions.air_contract_roles(player.faction):
		var button = Choice.new()
		button.name = "Contract" + role
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _contracts.hire(role))
		aircraft.add_child(button)
		_aircraft[role] = button
	player.changed.connect(refresh)
	refresh()


func _process(delta):
	if not is_visible_in_tree():
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = .2
		refresh()


func refresh():
	for direction in _buttons:
		var quote = player.market_quote(direction)
		var button = _buttons[direction]
		var buying = direction == "buy_electronics"
		var title = tr("Buy Electronics") if buying else tr("Buy Materials")
		var cost = {"resource_a": quote.x if buying else 0, "resource_b": 0 if buying else quote.y}
		var icon = load(
			"res://assets/ui/economy/%s.svg" % ("electronics" if buying else "materials")
		)
		button.show_role(icon, title, cost)
		button.show_state(tr("Receive %d E") % quote.y if buying else tr("Receive %d M") % quote.x)
		button.tooltip_text = (
			title
			+ "\n"
			+ tr("Trade resources at the current Black Market rate.")
			+ "\n"
			+ tr("%d M / %d E") % [cost.resource_a, cost.resource_b]
		)
		button.accessibility_name = title
		button.accessibility_description = button.tooltip_text
		button.disabled = (
			get_tree().paused
			or not player.has_completed_structure("CommandLab")
			or (player.resource_a < quote.x if buying else player.resource_b < quote.y)
		)
	for role in _aircraft:
		var button = _aircraft[role]
		var cost = Factions.cost(player, role)
		var title = tr(Factions.title(player.faction, role))
		var reason = _contracts.disabled_reason(role)
		button.show_role(Factions.portrait(player.faction, role), title, cost)
		button.show_state(
			(
				tr("Next contract · %d s") % ceili(_contracts.cooldown_left)
				if _contracts.cooldown_left > 0.0
				else tr("90 s sortie")
			)
		)
		button.disabled = reason != ""
		button.tooltip_text = (
			title
			+ "\n"
			+ tr(
				(
					"Hire a loaded mercenary aircraft for one controllable sortie. "
					+ "It departs when its ammunition or 90-second fuel supply runs out. "
					+ "No rearming; 20-second contract cooldown."
				)
			)
			+ "\n"
			+ tr("%d M / %d E") % [cost.resource_a, cost.resource_b]
		)
		if reason != "":
			button.tooltip_text += "\n" + tr(reason)
		button.accessibility_name = title
		button.accessibility_description = button.tooltip_text
