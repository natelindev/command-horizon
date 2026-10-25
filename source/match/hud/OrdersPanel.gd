extends VBoxContainer

var selection = []
var _status
var _eject


func _ready():
	add_theme_constant_override("separation", 3)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
	var row = HBoxContainer.new()
	add_child(row)
	_eject = Button.new()
	_eject.text = "Leave building"
	_eject.pressed.connect(_leave_building)
	row.add_child(_eject)
	refresh()


func refresh():
	var units = selection.filter(
		func(unit): return is_instance_valid(unit) and unit.manual_orders != null
	)
	if units.is_empty():
		return
	_eject.visible = units.all(func(unit): return unit.has_meta("garrison_host"))
	var first = units[0].manual_orders
	var same = units.all(func(unit): return unit.manual_orders.status == first.status)
	_status.text = first.status if same else "Mixed orders"
	# Idle units only repeat the queue hint, which the order keys' tooltips carry.
	if (
		_status.text
		in [
			"Shift + right-click to queue orders.",
			"Hold the queue key and right-click to queue orders."
		]
	):
		_status.text = ""
	if units.all(func(unit): return unit.has_meta("garrison_host")):
		_status.text = tr("Garrisoned · Move to leave")
		var host = units[0].get_meta("garrison_host")
		if units.all(func(unit): return unit.get_meta("garrison_host") == host):
			_status.text = tr("Garrison %d / %d") % [host.occupants.size(), host.CAPACITY]
	# Current-order details live in tooltips. Stop is already on the command card.
	_status.hide()
	_eject.tooltip_text = _status.text


func _leave_building():
	for unit in selection:
		if is_instance_valid(unit) and unit.has_meta("garrison_host"):
			unit.manual_orders.cancel()
			unit.action = null
	refresh()
