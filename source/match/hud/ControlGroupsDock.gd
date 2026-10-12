extends HBoxContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var _buttons = {}
var _handler = null
var _last_counts = {}


func _ready():
	add_theme_constant_override("separation", 6)
	_handler = get_tree().root.find_child("UnitGroupSelectionHandler", true, false)
	for i in range(1, 10):
		var btn = Button.new()
		btn.name = "Group%d" % i
		btn.text = "%d" % i
		btn.custom_minimum_size = Vector2(36, 30)
		btn.theme_type_variation = "BattleQuietButton"
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = "Control Group %d\nClick to select, double-click to center camera." % i
		btn.pressed.connect(_on_group_pressed.bind(i))
		btn.hide()
		add_child(btn)
		_buttons[i] = btn
		_last_counts[i] = 0


func _process(_delta):
	for i in range(1, 10):
		var group_name = "unit_group_%d" % i
		var units = get_tree().get_nodes_in_group(group_name).filter(
			func(u): return is_instance_valid(u) and not u.is_queued_for_deletion() and u.hp > 0
		)
		var count = units.size()
		if count != _last_counts[i]:
			_last_counts[i] = count
			var btn = _buttons[i]
			if count > 0:
				btn.text = "%d [%d]" % [i, count]
				btn.show()
			else:
				btn.hide()


func _on_group_pressed(group_id: int):
	if _handler != null and is_instance_valid(_handler):
		_handler.access_group(group_id)
	else:
		_handler = get_tree().root.find_child("UnitGroupSelectionHandler", true, false)
		if _handler != null:
			_handler.access_group(group_id)
