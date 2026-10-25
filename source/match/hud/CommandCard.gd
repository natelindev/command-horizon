extends GridContainer

const Bindings = preload("res://source/input/KeyBindings.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudKey = preload("res://source/match/hud/HudKey.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

const GRID_LABELS = [["Q", "W", "E", "R"], ["A", "S", "D", "F"], ["Z", "X", "C", "V"]]
const GLYPHS = {
	"Move": "move",
	"Patrol": "move",
	"Stop": "stop",
	"Hold": "hold",
	"Return": "return",
	"Atk Move": "attack_move",
	"Target": "attack",
	"Force": "attack",
	"Reverse": "reverse",
}
const ABILITY_GLYPHS = {
	"field_barricade": "plan",
	"scrap_mine": "attack",
	"sweep_mines": "recover",
	"dismantle_barrier": "stop",
	"power_overdrive": "tech",
	"drone_chaff": "hide",
	"frag_grenade": "attack",
	"combat_sprint": "move",
	"smoke_screen": "hide",
	"siege_anchor": "hold",
	"guided_salvo": "attack_move",
}

## The command deck routes Stop through its own handler (order feedback, rally, refunds).
var stop_override = Callable()
var abilities_only = false
var _slots = []
var _selection = []
var _direct_orders = null
var _ability_slots = []
var _ability_refresh = 0.0


func _ready():
	_slots.clear()
	columns = 4
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 4)
	for r in range(3):
		var row_slots = []
		for c in range(4):
			var btn = HudKey.new()
			btn.name = "Slot_%s" % GRID_LABELS[r][c]
			btn.custom_minimum_size = Vector2(62, 52 if abilities_only else 40)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_child(btn)
			row_slots.append(btn)
		_slots.append(row_slots)


# Ordinary orders follow KeyBindings; selected unit abilities own their QWER
# keys. All keyboard dispatch stays in DirectOrders, even on a hidden HUD tab.
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
	if abilities_only:
		_setup_abilities()
		for row in _slots:
			for button in row:
				button.visible = button.modulate.a > 0.0
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return

	# Ordinary orders show the player's configured keys.
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
	_slots[0][2].tooltip_text = tr(
		"Hold position · Stop moving and fire at enemies in range. Cancels current and queued orders."
	)
	_slots[0][2].accessibility_name = tr("Hold position")
	_slots[0][2].accessibility_description = _slots[0][2].tooltip_text
	if direct_orders != null:
		_setup_slot(
			0,
			3,
			"Patrol",
			Bindings.label("patrol_order"),
			_on_patrol,
			not direct_orders.eligible("patrol").is_empty()
		)
	# The command deck carries its own Return cargo key beside this grid, with
	# queueing and delivery feedback. Standalone cards keep their Return slot.
	var has_cargo = _selection.any(func(u): return "type" in u and u.type == "Worker")
	if direct_orders == null:
		_setup_slot(0, 3, "Return", "", _on_return_cargo, has_cargo)
	_setup_abilities()

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
	_setup_slot(
		1,
		1,
		"Force",
		Bindings.label("force_attack"),
		_on_force_attack,
		(
			has_attack
			and direct_orders != null
			and not direct_orders.eligible("force_attack").is_empty()
		)
	)


func _clear_slots():
	_ability_slots.clear()
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
			btn.set_pressed_no_signal(false)
			if r == 2:
				btn.toggle_mode = false
				btn.remove_theme_stylebox_override("disabled")
			var cooldown = btn.get_node_or_null("AbilityCooldown")
			if cooldown != null:
				cooldown.hide()
			btn.visible = false
			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn.callable)


func _setup_abilities():
	var assigned = []
	for unit in _selection:
		if (
			not unit.is_in_group("controlled_units")
			or not "abilities" in unit
			or unit.abilities == null
			or not unit.abilities.unit_available()
		):
			continue
		for ability in unit.abilities.abilities:
			var column = ["Q", "W", "E", "R"].find(ability.key)
			if column < 0 or column in assigned:
				continue
			assigned.append(column)
			_setup_slot(
				2,
				column,
				ability.name,
				ability.key,
				_activate_ability.bind(ability.id),
				ability.is_ready()
			)
			var button = _slots[2][column]
			button.glyph = BattleTheme.icon(ABILITY_GLYPHS.get(ability.id, "stance"))
			button.toggle_mode = true
			var cooldown = button.get_node_or_null("AbilityCooldown")
			if cooldown == null:
				cooldown = Label.new()
				cooldown.name = "AbilityCooldown"
				cooldown.add_theme_font_size_override("font_size", 11)
				cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				button.add_child(cooldown)
				cooldown.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				cooldown.offset_left = 16
				cooldown.offset_right = -4
			_ability_slots.append({"button": button, "id": ability.id, "cooldown": cooldown})
	_refresh_abilities()


func _refresh_abilities():
	for slot in _ability_slots:
		var abilities = []
		var issues = []
		for unit in _selection:
			if (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and "abilities" in unit
				and unit.abilities != null
			):
				var ability = unit.abilities.get_ability(slot.id)
				if ability != null and unit.abilities.unit_available():
					abilities.append(ability)
					issues.append(unit.abilities.availability_issue(slot.id))
		var ready = issues.any(func(issue): return issue.is_empty())
		var active = abilities.any(func(ability): return ability.is_active)
		var remaining = INF
		for ability in abilities:
			remaining = minf(remaining, ability.cooldown_left)
		if slot.id == "field_barricade":
			remaining = INF
			for unit in _selection:
				if unit.type == "Worker" and unit.player.faction == "bastion":
					remaining = minf(remaining, unit._match.engineering.cooldown_left(unit))
		slot.button.disabled = not ready
		slot.cooldown.visible = not ready and is_finite(remaining) and remaining > 0.0
		slot.cooldown.text = "%.1fs" % remaining if is_finite(remaining) else ""
		var armed = is_instance_valid(_direct_orders) and _direct_orders.ability_id == slot.id
		slot.button.set_pressed_no_signal(active or armed)
		if active:
			# Keep the active face visible during a toggle's cooldown too.
			slot.button.add_theme_stylebox_override(
				"disabled", slot.button.get_theme_stylebox("pressed")
			)
		else:
			slot.button.remove_theme_stylebox_override("disabled")
		if abilities.is_empty():
			continue
		var ability = abilities[0]
		slot.button.tooltip_text = (
			tr("%s [%s]\n%s\nRange: %.1f m · Radius: %.1f m · Cooldown: %.1f s")
			% [
				tr(ability.name),
				ability.key,
				tr(ability.description),
				ability.range,
				ability.radius,
				ability.cooldown
			]
		)
		if active:
			var status = tr("Active")
			if slot.id == "power_overdrive":
				for member in _selection:
					if member._match.helix_support.overdrive_status(member) == "suspended":
						status = tr("Suspended: low power")
						break
			slot.button.tooltip_text += "\n" + status
		if ability.range > 1000:
			slot.button.tooltip_text = (
				"%s [%s]\n%s" % [tr(ability.name), ability.key, tr(ability.description)]
			)
		if slot.id == "field_barricade" and remaining > 0 and is_finite(remaining):
			slot.button.tooltip_text += "\n" + tr("Deployment cooldown · %.1f s") % remaining
		if not ready and not issues.is_empty():
			slot.button.tooltip_text += "\n" + tr(issues[0])
		slot.button.accessibility_name = tr(ability.name) + " [" + ability.key + "]"
		slot.button.accessibility_description = slot.button.tooltip_text


func _process(delta):
	_ability_refresh += delta
	if _ability_refresh >= .1:
		_ability_refresh = 0.0
		_refresh_abilities()


func _activate_ability(id):
	if is_instance_valid(_direct_orders):
		_direct_orders.activate_ability(id)
	else:
		for unit in _selection:
			if (
				is_instance_valid(unit)
				and unit.is_in_group("controlled_units")
				and "abilities" in unit
				and unit.abilities != null
			):
				var ability = unit.abilities.get_ability(id)
				if ability != null and ability.target_type in ["instant", "toggle"]:
					ability.trigger()
	_refresh_abilities()


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
	var cell = {
		"move": Vector2i(0, 0),
		"attack": Vector2i(1, 2),
		"force_attack": Vector2i(1, 1),
		"attack_move": Vector2i(1, 0),
		"patrol": Vector2i(0, 3)
	}
	return _slots[cell[kind].x][cell[kind].y] if cell.has(kind) else null


func _on_patrol():
	if _direct_orders != null:
		_direct_orders.arm("patrol")


func _on_force_attack():
	if _direct_orders != null:
		_direct_orders.arm("force_attack")


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
