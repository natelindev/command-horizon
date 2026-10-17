extends VBoxContainer

var selection = []
var _status
var _skip
var _eject
var _clear


func _ready():
	add_theme_constant_override("separation", 3)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
	var row = HBoxContainer.new()
	add_child(row)
	_skip = Button.new()
	_skip.text = "Skip order"
	_skip.pressed.connect(func(): _each(func(orders): orders.skip()))
	row.add_child(_skip)
	_clear = Button.new()
	_clear.text = "Clear waiting"
	_clear.pressed.connect(func(): _each(func(orders): orders.clear_waiting()))
	row.add_child(_clear)
	_eject = Button.new()
	_eject.text = "Leave building"
	_eject.pressed.connect(_leave_building)
	row.add_child(_eject)
	refresh()


func _each(callback):
	for unit in selection:
		if is_instance_valid(unit) and unit.manual_orders != null:
			callback.call(unit.manual_orders)
	refresh()


func refresh():
	var units = selection.filter(
		func(unit): return is_instance_valid(unit) and unit.manual_orders != null
	)
	if units.is_empty():
		return
	_eject.visible = units.any(func(unit): return unit.has_meta("garrison_host"))
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
	_status.visible = not _status.text.is_empty()
	_status.tooltip_text = (
		"Solid route: active order. Dashed route: waiting orders. "
		+ "Gathering yields after the next delivery. Follow continues until target loss or Skip."
	)
	_skip.disabled = units.all(func(unit): return not unit.manual_orders._engaged)
	_clear.disabled = units.all(func(unit): return unit.manual_orders.pending.is_empty())
	# Queue controls appear while there is an order to skip or a queue to clear.
	_skip.visible = not _skip.disabled
	_clear.visible = not _clear.disabled


func _leave_building():
	for unit in selection:
		if is_instance_valid(unit) and unit.has_meta("garrison_host"):
			unit.manual_orders.cancel()
			unit.action = null
	refresh()
