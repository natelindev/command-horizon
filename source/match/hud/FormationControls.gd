extends VBoxContainer

const Bindings = preload("res://source/input/KeyBindings.gd")
const Planner = preload("res://source/match/orders/FormationPlanner.gd")
const Cohesion = preload("res://source/match/orders/CohesionGroup.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const CHOICES = {
	"line": ["Line", "Heavy armor leads two or three broad firing ranks.", "attack"],
	"box":
	["Box", "Armor escorts the perimeter; engineers, artillery and recon shelter inside.", "hold"],
	"flank":
	[
		"Flank",
		"Split into two wings with a clear six-metre center corridor. Reforms immediately to evade artillery.",
		"move"
	],
	"staggered":
	[
		"Staggered",
		"Spread into a hexagonal lattice with 2.5 metres of clear space between hulls.",
		"stance"
	],
}
var selection = []
var hud = null
var buttons = {}
var cohesion_button: Button


func _ready():
	name = "FormationControls"
	add_theme_constant_override("separation", 10)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for posture in Planner.POSTURES:
		var button = Button.new()
		button.name = posture.capitalize()
		button.text = Bindings.hint(tr(CHOICES[posture][0]), "formation_" + posture)
		button.tooltip_text = tr(CHOICES[posture][1])
		button.accessibility_description = button.tooltip_text
		button.icon = BattleTheme.icon(CHOICES[posture][2])
		button.add_theme_constant_override("icon_max_width", 18)
		button.custom_minimum_size = Vector2(106, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(choose.bind(posture))
		row.add_child(button)
		buttons[posture] = button
	cohesion_button = Button.new()
	cohesion_button.name = "Cohesion"
	cohesion_button.text = Bindings.hint(tr("Match march speed"), "cohesion_mode")
	cohesion_button.tooltip_text = tr(
		"March at the slowest surviving group member's current speed. Includes suppression and temporary speed effects. Off by default."
	)
	cohesion_button.accessibility_description = cohesion_button.tooltip_text
	cohesion_button.custom_minimum_size.y = 36
	cohesion_button.toggle_mode = true
	cohesion_button.pressed.connect(toggle_cohesion)
	add_child(cohesion_button)
	refresh()


func members() -> Array:
	return selection.filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and unit.hp > 0
				and unit.manual_orders != null
				and unit.movement_speed > 0
			)
	)


func choose(posture: String):
	if posture not in Planner.POSTURES:
		return
	var units = members()
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(hud.get_parent(), {"kind": "formation", "units": units.map(gate.id_for), "value": posture}):
		return
	for unit in units:
		unit.manual_orders.formation = posture
	# Posture changes also reform the army now, making Flank an actual dodge.
	if units.size() > 1:
		var movement = load("res://source/match/utils/UnitMovementUtils.gd")
		var pivot = movement.calculate_aabb_crowd_pivot_yless(units)
		var heading = -units[0].global_basis.z
		var controller = hud.get_parent()._get_human_player().get_node("UnitActionsController")
		controller._try_navigating_selected_units_towards_position(pivot)
		controller._on_terrain_target_heading_set(pivot, heading)
	refresh()


func toggle_cohesion():
	var units = members()
	var enable = not units.all(func(unit): return unit.manual_orders.cohesion_enabled)
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(hud.get_parent(), {"kind": "cohesion", "units": units.map(gate.id_for), "value": enable}):
		return
	var group = Cohesion.new(units)
	for unit in units:
		unit.manual_orders.configure_cohesion(enable, group)
	refresh()


func refresh():
	var units = members()
	for posture in buttons:
		buttons[posture].set_pressed_no_signal(
			(
				not units.is_empty()
				and units.all(func(unit): return unit.manual_orders.formation == posture)
			)
		)
	cohesion_button.set_pressed_no_signal(
		not units.is_empty() and units.all(func(unit): return unit.manual_orders.cohesion_enabled)
	)


func handle_input(event) -> bool:
	if members().size() < 2:
		return false
	for posture in Planner.POSTURES:
		if Bindings.pressed(event, "formation_" + posture):
			choose(posture)
			return true
	if Bindings.pressed(event, "cohesion_mode"):
		toggle_cohesion()
		return true
	return false
