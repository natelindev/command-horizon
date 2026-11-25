extends VBoxContainer

const Behavior = preload("res://source/match/orders/UnitBehavior.gd")
var selection = []
var hud
var _status: Label
var _buttons = {}


func _ready():
	name = "BehaviorPanel"
	add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.tooltip_text = "Standing behavior · Applies between explicit orders until changed."
	# The selected toggle already shows the behavior. Keep its detail in tooltips.
	_status.hide()
	add_child(_status)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	var descriptions = [
		"Fire at nearby enemies automatically.",
		"Return fire and assist nearby allies without a long pursuit.",
		"Choose a friendly unit to follow.",
		"Choose a position. Move there and defend without pursuing enemies.",
		"Stop firing. Only an explicit attack order may open fire."
	]
	for index in Behavior.CHOICES.size():
		var button = Button.new()
		button.name = Behavior.TITLES[index].replace(" ", "")
		button.text = Behavior.TITLES[index]
		button.add_theme_font_size_override("font_size", 12)
		button.toggle_mode = true
		_buttons[Behavior.CHOICES[index]] = button
		button.tooltip_text = descriptions[index]
		button.custom_minimum_size = Vector2(64, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose.bind(Behavior.CHOICES[index]))
		grid.add_child(button)
	refresh()


func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func _choose(behavior):
	if behavior in ["follow", "guard"]:
		hud.direct_orders.arm(behavior)
		return
	hud.direct_orders.cancel()
	for unit in selection:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			Behavior.set_stance(unit, behavior)
	refresh()


func refresh():
	var units = selection.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	if units.is_empty():
		return
	var first = Behavior.current(units[0])
	var same = units.all(func(unit): return Behavior.current(unit) == first)
	var title = tr(Behavior.TITLES[Behavior.CHOICES.find(first)]) if same else tr("Mixed")
	_status.text = tr("Behavior · %s") % title
	for choice in _buttons:
		_buttons[choice].set_pressed_no_signal(same and choice == first)
