extends GridContainer

const Bindings = preload("res://source/input/KeyBindings.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudKey = preload("res://source/match/hud/HudKey.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

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

## The command deck routes Stop through its own handler (order feedback, rally, refunds).
var stop_override = Callable()
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


# Battle shortcuts are dispatched by the HUD through KeyBindings. The card
# must not add Q/W/E/A/D/F aliases: those collide with camera controls and
# player remappings, including when this card sits on a hidden tab.
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

	# Configured direct-order keys are the only keyboard shortcuts shown here.
	_setup_slot(
		0,
		0,
		"Move",
		Bindings.label("move_order"),
		_on_move,
		direct_orders != null and not direct_orders.eligible("move").is_empty()
	)
	_setup_slot(0, 1, "Stop", "", _on_stop, true)
	_setup_slot(0, 2, "Hold", "", _on_hold, true)
	# Return Cargo. The command deck carries its own Return cargo key beside direct
	# orders, with queueing and delivery feedback, so the card leaves R blank there.
	var has_cargo = _selection.any(func(u): return "type" in u and u.type == "Worker")
	if direct_orders == null:
		_setup_slot(0, 3, "Return", "", _on_return_cargo, has_cargo)

	var has_attack = _selection.any(func(u): return "attack_range" in u and u.attack_range != null)
	var is_armored = _selection.any(
		func(u): return "type" in u and u.type in ["Tank", "AdvancedTank"]
	)
	# Combat commands only for selections that can fight; engineers keep one row.
	if not has_attack and not is_armored:
		return
	_setup_slot(
		1,
		0,
		"Atk Move",
		Bindings.label("attack_move"),
		_on_attack_move,
		(
			has_attack
			and direct_orders != null
			and not direct_orders.eligible("attack_move").is_empty()
		)
	)
	_setup_slot(
		1,
		2,
		"Target",
		Bindings.label("attack_target"),
		_on_attack_target,
		has_attack and direct_orders != null and not direct_orders.eligible("attack").is_empty()
	)
	_setup_slot(1, 3, "Reverse", "", _on_reverse_move, is_armored)


func _clear_slots():
	# Rows without any assigned command are hidden. In a shown row, an unassigned slot
	# keeps its place in the grid but stays blank and out of the focus order.
	for r in range(3):
		for c in range(4):
			var btn = _slots[r][c]
			_set_blank(btn, true)
			btn.badge = ""
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
	btn.tooltip_text = label if key.is_empty() else "%s [%s]" % [label, key]
	btn.accessibility_name = btn.tooltip_text
	btn.disabled = not enabled
	_set_blank(btn, false)
	btn.pressed.connect(callable)
	for slot in _slots[r]:
		slot.visible = true


func _set_blank(btn, blank):
	btn.modulate.a = 0.0 if blank else 1.0
	btn.focus_mode = Control.FOCUS_NONE if blank else Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if blank else Control.MOUSE_FILTER_STOP


## The slot that issues a direct order kind (move, attack, attack_move), if any.
func order_slot(kind):
	var cell = {"move": Vector2i(0, 0), "attack": Vector2i(1, 2), "attack_move": Vector2i(1, 0)}
	return _slots[cell[kind].x][cell[kind].y] if cell.has(kind) else null


func _on_move():
	if _direct_orders != null:
		_direct_orders.arm("move")


func _on_stop():
	if stop_override.is_valid():
		stop_override.call()
		return
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
	# Step back along the current facing through the ordinary manual queue.
	for unit in _selection:
		if unit.is_in_group("controlled_units") and unit.type in ["Tank", "AdvancedTank"]:
			var back_dir = unit.global_transform.basis.z * Vector3(1, 0, 1)
			var reverse_target = unit.global_position + back_dir * 12.0
			unit.manual_orders.submit(
				Orders.point_order("move", reverse_target), Bindings.held("shift_selecting")
			)
