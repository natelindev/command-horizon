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
	var carriers = units.filter(
		func(unit): return unit.garrison_mount != null and not unit.occupants.is_empty()
	)
	_eject.visible = (
		not carriers.is_empty() or units.all(func(unit): return unit.has_meta("garrison_host"))
	)
	_eject.text = tr("Unload infantry") if not carriers.is_empty() else tr("Leave building")
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
			var capacity = (
				host.garrison_capacity() if host.has_method("garrison_capacity") else host.CAPACITY
			)
			_status.text = tr("Garrison %d / %d") % [host.occupants.size(), capacity]
	# Current-order details live in tooltips. Stop is already on the command card.
	_status.hide()
	_eject.tooltip_text = _status.text
	if not carriers.is_empty():
		var count = 0
		var capacity = 0
		for carrier in carriers:
			count += carrier.occupants.size()
			capacity += carrier.garrison_capacity()
		_eject.tooltip_text = (
			tr("Unload infantry") + "\n" + tr("Garrison %d / %d") % [count, capacity]
		)
	_eject.accessibility_name = _eject.text
	_eject.accessibility_description = _eject.tooltip_text


func _leave_building():
	var gate = load("res://source/match/network/NetworkGate.gd")
	var units = selection.filter(func(unit): return is_instance_valid(unit))
	if (
		not units.is_empty()
		and gate.intercept(
			units[0],
			{
				"kind": "order",
				"units": units.map(gate.id_for),
				"order": "unload",
				"point": gate.Protocol.quantize(units[0].position)
			}
		)
	):
		return
	for unit in selection:
		if is_instance_valid(unit) and unit.has_meta("garrison_host"):
			unit.manual_orders.cancel()
			unit.action = null
		elif is_instance_valid(unit) and "garrison_mount" in unit and unit.garrison_mount != null:
			for passenger in unit.occupants.duplicate():
				passenger.manual_orders.cancel()
				passenger.action = null
	refresh()
