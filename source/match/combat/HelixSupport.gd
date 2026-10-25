extends Node

## Gameplay support queries share the battlefield spatial index. Ability state
## owns persistence; visuals never determine coverage or recharge.
const Players = preload("res://source/match/Players.gd")
const OVERDRIVE_DEMAND = 3
const OVERDRIVE_RADIUS = 12.0
const CHAFF_RADIUS = 10.0
var _rings = {}
var _cores = {}
var _visual_left = 0.0
@onready var game = get_parent()


func ability_issue(unit, id: String) -> String:
	if id == "power_overdrive":
		var ability = unit.abilities.get_ability(id)
		if ability != null and ability.is_active:
			return ""
		if (
			unit.player.technology == null
			or "plasma_shields" not in unit.player.technology.completed
		):
			return "Requires Plasma Shields research."
		var power = unit.player.power_totals()
		if power.x < power.y + OVERDRIVE_DEMAND:
			return "Requires 3 spare power."
	elif id == "drone_chaff" and not unit.player.has_completed_structure("CommandLab"):
		return "Requires a completed Signal lab."
	return ""


func toggle_overdrive(ability, unit) -> bool:
	if unit.player.faction != "helix" or unit.type != "PowerPlant":
		return false
	if not ability_issue(unit, "power_overdrive").is_empty():
		return false
	ability.is_active = not ability.is_active
	unit.player.emit_changed()
	return true


func activate_chaff(ability, unit) -> bool:
	if unit.player.faction != "helix" or unit.type != "Drone":
		return false
	if not ability_issue(unit, "drone_chaff").is_empty():
		return false
	ability.is_active = true
	ability.active_left = ability.duration
	return true


static func requested(unit) -> bool:
	if not is_instance_valid(unit) or unit.hp == null or unit.hp <= 0:
		return false
	if unit.player.faction != "helix" or unit.type != "PowerPlant" or unit.abilities == null:
		return false
	var ability = unit.abilities.get_ability("power_overdrive")
	return ability != null and ability.is_active and unit.is_constructed()


func operating(unit) -> bool:
	if not requested(unit):
		return false
	var power = unit.player.power_totals()
	return power.x >= power.y


func overdrive_status(unit) -> String:
	if not requested(unit):
		return "off"
	return "operating" if operating(unit) else "suspended"


func shield_factor(unit) -> float:
	if unit.player.faction != "helix" or unit.shields_max <= 0:
		return 1.0
	var power = unit.player.power_totals()
	if power.x < power.y:
		return 1.0
	for generator in game.battlefield.nearby_units(unit.global_position_yless, OVERDRIVE_RADIUS):
		if generator.player == unit.player and requested(generator):
			if (
				generator.global_position_yless.distance_to(unit.global_position_yless)
				<= OVERDRIVE_RADIUS
			):
				return 1.5
	return 1.0


func missile_jammed(shooter_player, target) -> bool:
	if not is_instance_valid(target) or not "player" in target or target.player == null:
		return false
	if Players.allied(shooter_player, target.player):
		return false
	var point = target.global_position * Vector3(1, 0, 1)
	for drone in game.battlefield.nearby_units(point, CHAFF_RADIUS):
		if drone.type != "Drone" or drone.player.faction != "helix" or drone.abilities == null:
			continue
		if Players.allied(drone.player, target.player) and drone.abilities.is_active("drone_chaff"):
			if drone.global_position_yless.distance_to(point) <= CHAFF_RADIUS:
				return true
	return false


func affected_count(generator) -> int:
	if not operating(generator):
		return 0
	var count = 0
	for unit in game.battlefield.nearby_units(generator.global_position_yless, OVERDRIVE_RADIUS):
		if unit.player == generator.player and unit.shields_max > 0:
			count += 1
	return count


func _process(delta):
	if DisplayServer.get_name() == "headless":
		return
	_visual_left -= delta
	if _visual_left > 0:
		return
	_visual_left = 0.1
	var wanted = {}
	var generators = {}
	for unit in game.get_units():
		if unit.player.faction != "helix" or unit.hp <= 0 or not unit.visible:
			continue
		var radius = 0.0
		if unit.type == "PowerPlant":
			generators[unit] = true
			_refresh_generator_visuals(unit)
			if unit.is_in_group("selected_units"):
				radius = OVERDRIVE_RADIUS
		elif (
			unit.type == "Drone"
			and unit.abilities != null
			and unit.abilities.is_active("drone_chaff")
		):
			radius = CHAFF_RADIUS
		if radius == 0.0:
			continue
		wanted[unit] = true
		if not _rings.has(unit):
			var ring = load("res://source/match/effects/TacticalRangeRing.gd").create(radius)
			if ring != null:
				game.add_child(ring)
				_rings[unit] = ring
		if _rings.has(unit):
			_rings[unit].position = (
				game.map.ground_point(Vector2(unit.position.x, unit.position.z)) + Vector3.UP * .08
			)
	for unit in _rings.keys():
		if not wanted.has(unit):
			_rings[unit].queue_free()
			_rings.erase(unit)
	for unit in _cores.keys():
		if not generators.has(unit):
			_restore_generator_visuals(unit)


func _refresh_generator_visuals(unit):
	var status = overdrive_status(unit)
	if status == "off":
		_restore_generator_visuals(unit)
		return
	if not _cores.has(unit):
		var surfaces = []
		# Exported generator meshes merge the cores into the authored optics surface.
		for mesh in unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original = mesh.get_active_material(surface)
				if (
					not original is StandardMaterial3D
					or not original.resource_name.begins_with("Helix_Optics")
				):
					continue
				var material = original.duplicate()
				(
					surfaces
					. append(
						{
							"mesh": mesh,
							"surface": surface,
							"override": mesh.get_surface_override_material(surface),
							"material": material,
							"albedo": original.albedo_color,
							"energy": original.emission_energy_multiplier,
						}
					)
				)
				mesh.set_surface_override_material(surface, material)
		_cores[unit] = {"status": "", "surfaces": surfaces}
	var cores = _cores[unit]
	if cores.status == status:
		return
	cores.status = status
	for core in cores.surfaces:
		var material = core.material
		material.emission_enabled = true
		if status == "operating":
			material.albedo_color = core.albedo.lerp(Color(.25, .9, .95), .16)
			material.emission_energy_multiplier = maxf(1.8, core.energy * 1.6)
		else:
			material.albedo_color = core.albedo.darkened(.55)
			material.emission_energy_multiplier = .08


func _restore_generator_visuals(unit):
	if not _cores.has(unit):
		return
	for core in _cores[unit].surfaces:
		if is_instance_valid(core.mesh):
			core.mesh.set_surface_override_material(core.surface, core.override)
	_cores.erase(unit)


func _exit_tree():
	for ring in _rings.values():
		if is_instance_valid(ring):
			ring.queue_free()
	for unit in _cores.keys():
		_restore_generator_visuals(unit)
