extends GridContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudKey = preload("res://source/match/hud/HudKey.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

const GRID_HOTKEYS = [
	[KEY_Q, KEY_W, KEY_E, KEY_R], [KEY_A, KEY_S, KEY_D, KEY_F], [KEY_Z, KEY_X, KEY_C, KEY_V]
]
const GRID_LABELS = [["Q", "W", "E", "R"], ["A", "S", "D", "F"], ["Z", "X", "C", "V"]]
const GLYPHS = {
	"Move": "move",
	"Stop": "stop",
	"Hold": "hold",
	"Return": "return",
	"Atk Move": "attack_move",
	"Target": "attack",
	"Reverse": "reverse",
}

var _slots = []
var _selection = []
var _direct_orders = null


func _ready():
	_slots.clear()
	columns = 4
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	for r in range(3):
		var row_slots = []
		for c in range(4):
			var btn = HudKey.new()
			btn.name = "Slot_%s" % GRID_LABELS[r][c]
			btn.custom_minimum_size = Vector2(62, 48)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_child(btn)
			row_slots.append(btn)
		_slots.append(row_slots)


func _unhandled_input(event):
	var globals = get_node_or_null("/root/Globals")
	if globals != null and is_instance_valid(globals.settings_dialog):
		return
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key = event.keycode
	for r in range(3):
		for c in range(4):
			if key == GRID_HOTKEYS[r][c]:
				var btn = _slots[r][c]
				if btn.visible and not btn.disabled:
					btn.emit_signal("pressed")
					get_viewport().set_input_as_handled()
					return


func update_layout(selected_units: Array, direct_orders = null):
	_selection = selected_units.filter(
		func(u):
			return (
				is_instance_valid(u) and not u.is_queued_for_deletion() and ("hp" in u and u.hp > 0)
			)
	)
	_direct_orders = direct_orders
	_clear_slots()
	if _selection.is_empty():
		return

	# Q: Move
	_setup_slot(
		0,
		0,
		"Move",
		"Q",
		_on_move,
		direct_orders != null and not direct_orders.eligible("move").is_empty()
	)
	# W: Stop
	_setup_slot(0, 1, "Stop", "W", _on_stop, true)
	# E: Hold
	_setup_slot(0, 2, "Hold", "E", _on_hold, true)
	# R: Return Cargo
	var has_cargo = _selection.any(func(u): return "type" in u and u.type == "Worker")
	_setup_slot(0, 3, "Return", "R", _on_return_cargo, has_cargo)

	# A: Attack Move
	var has_attack = _selection.any(func(u): return "attack_range" in u and u.attack_range != null)
	_setup_slot(
		1,
		0,
		"Atk Move",
		"A",
		_on_attack_move,
		(
			has_attack
			and direct_orders != null
			and not direct_orders.eligible("attack_move").is_empty()
		)
	)
	# S: Stance Toggle
	var current_stance = _selection[0].stance_name() if "stance_name" in _selection[0] else "Stance"
	_setup_slot(1, 1, current_stance, "S", _on_cycle_stance, true)
	# D: Attack Target
	_setup_slot(
		1,
		2,
		"Target",
		"D",
		_on_attack_target,
		has_attack and direct_orders != null and not direct_orders.eligible("attack").is_empty()
	)
	# F: Reverse Move
	var is_armored = _selection.any(
		func(u): return "type" in u and u.type in ["Tank", "AdvancedTank"]
	)
	_setup_slot(1, 3, "Reverse", "F", _on_reverse_move, is_armored)


func _clear_slots():
	# Rows without any assigned command are hidden rather than shown as empty key boxes.
	for r in range(3):
		for c in range(4):
			var btn = _slots[r][c]
			btn.badge = GRID_LABELS[r][c]
			btn.caption = ""
			btn.glyph = null
			btn.tooltip_text = ""
			btn.disabled = true
			btn.visible = false
			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn.callable)


func _setup_slot(r: int, c: int, label: String, key: String, callable: Callable, enabled: bool):
	var btn = _slots[r][c]
	btn.badge = key
	btn.caption = label
	btn.glyph = BattleTheme.icon(GLYPHS.get(label, "stance"))
	btn.tooltip_text = "%s [%s]" % [label, key]
	btn.accessibility_name = btn.tooltip_text
	btn.disabled = not enabled
	btn.pressed.connect(callable)
	for slot in _slots[r]:
		slot.visible = true


func _on_move():
	if _direct_orders != null:
		_direct_orders.arm("move")


func _on_stop():
	for unit in _selection:
		if unit.is_in_group("controlled_units"):
			if unit.manual_orders != null:
				unit.manual_orders.cancel()
			unit.action = WaitingForTargets.new()


func _on_hold():
	for unit in _selection:
		if unit.is_in_group("controlled_units"):
			if "stance" in unit:
				unit.stance = unit.Stance.HOLD_POSITION
			if unit.manual_orders != null:
				unit.manual_orders.cancel()
			unit.action = WaitingForTargets.new()


func _on_return_cargo():
	if _direct_orders != null:
		var state = _direct_orders.cargo_return_state()
		if not state.orders.is_empty():
			for item in state.orders:
				if is_instance_valid(item.unit):
					item.unit.issue_manual_order(item.action)


func _on_attack_move():
	if _direct_orders != null:
		_direct_orders.arm("attack_move")


func _on_cycle_stance():
	var new_stance_name = "Aggressive"
	for unit in _selection:
		if unit.is_in_group("controlled_units") and unit.has_method("cycle_stance"):
			unit.cycle_stance()
			new_stance_name = unit.stance_name()
	_slots[1][1].caption = new_stance_name
	_slots[1][1].tooltip_text = "%s [S]" % new_stance_name


func _on_attack_target():
	if _direct_orders != null:
		_direct_orders.arm("attack")


func _on_reverse_move():
	# Reverse move backtracks the unit's position while retaining target facing
	for unit in _selection:
		if unit.is_in_group("controlled_units") and unit.type in ["Tank", "AdvancedTank"]:
			var back_dir = -unit.global_transform.basis.z * Vector3(1, 0, 1)
			var reverse_target = unit.global_position + back_dir * 12.0
			unit.issue_manual_order(Orders.point_order("move", reverse_target))
