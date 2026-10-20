extends VBoxContainer

var selection = []
var _precision
var _interception
var _row
var _status


func _ready():
	add_theme_constant_override("separation", 6)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)
	_precision = _button("Precision", "precision")
	_interception = _button("Interception", "interception")
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	add_child(_status)
	refresh()


func _button(title, mode):
	var button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 32
	button.tooltip_text = (
		(
			"Ground targets · anti-armor lance · 12 m\n30 vs heavy armor · 0.75 s charge · weak vs infantry"
			if mode == "precision"
			else "Air targets only · 8 m"
		)
		+ "\nTwo seconds without firing to switch. Movement and orders continue."
	)
	button.pressed.connect(func(): _choose(mode))
	button.add_theme_font_size_override("font_size", 13)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(button)
	return button


func _units():
	return selection.filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and unit.is_in_group("controlled_units")
				and unit.type == "CombatRobot"
				and unit.can_switch_weapon()
			)
	)


func _choose(mode):
	for unit in _units():
		unit.request_weapon_mode(mode)
	refresh()


func refresh():
	var units = _units()
	var switching = units.filter(func(unit): return unit.weapon_switch_left > 0).size()
	for entry in [[_precision, "precision"], [_interception, "interception"]]:
		var count = units.filter(func(unit): return unit.weapon_mode == entry[1]).size()
		entry[0].text = "%s · %d" % [entry[1].capitalize(), count]
		entry[0].disabled = units.all(
			func(unit): return unit.weapon_mode == entry[1] or unit.weapon_switch_left > 0
		)
	_status.text = (
		"%d switching" % switching
		if switching > 0
		else "%d Lancer%s" % [units.size(), "" if units.size() == 1 else "s"]
	)
