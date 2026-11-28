extends Node3D

## Optional Forward+ lighting. Only four nearby, observed facilities can contribute.
const MAX_LIGHTS = 4
const MAX_LIGHTS_ULTRA = 8
const ULTRA_SHADOWED_LIGHTS = 3
const ROLES = ["CommandCenter", "VehicleFactory", "AircraftFactory", "CommandLab", "PowerPlant"]
const COLORS = {"bastion": Color("ffd6a0"), "helix": Color("8fe7ed"), "frontier": Color("d4e7a4")}
var daylight = 1.0
var lights = []
var _elapsed = 0.0
var _game


func _ready():
	name = "BaseAreaLighting"
	_game = get_parent()
	Globals.options.changed.connect(refresh)
	refresh()


func enabled():
	return (
		Globals.options.area_lighting
		and DisplayServer.get_name() != "headless"
		and RenderingServer.get_current_rendering_method() == "forward_plus"
	)


func _process(delta):
	# Revoke a light immediately when its facility leaves sight or is destroyed.
	for light in lights:
		var reference = light.get_meta("facility", null)
		var unit = reference.get_ref() if reference != null else null
		if (
			not is_instance_valid(unit)
			or unit.is_queued_for_deletion()
			or not unit.visible
			or not _game.combat_audio._observed(unit)
		):
			light.hide()
	_elapsed += delta
	if _elapsed >= .4:
		_elapsed = 0.0
		refresh()


func refresh():
	if not enabled() or _game.restoring:
		for light in lights:
			light.hide()
		return
	var camera = _game.get_node("IsometricCamera3D")
	var candidates = []
	for unit in _game.get_units():
		if (
			unit.type in ROLES
			and unit.is_constructed()
			and unit.visible
			and _game.combat_audio._observed(unit)
			and _game.combat_effects._camera_sees(unit.global_position)
		):
			candidates.append(unit)
	candidates.sort_custom(
		func(a, b):
			return (
				camera.global_position.distance_squared_to(a.global_position)
				< camera.global_position.distance_squared_to(b.global_position)
			)
	)
	var ultra_lights: bool = Globals.options.graphics_extreme_shadows
	var max_count: int = MAX_LIGHTS_ULTRA if ultra_lights else MAX_LIGHTS
	while lights.size() < mini(max_count, candidates.size()):
		var light = AreaLight3D.new()
		light.shadow_enabled = false
		add_child(light)
		lights.append(light)
	for index in lights.size():
		var light = lights[index]
		light.visible = index < mini(max_count, candidates.size())
		if not light.visible:
			continue
		var unit = candidates[index]
		light.set_meta("facility", weakref(unit))
		light.global_position = unit.global_position + Vector3.UP * 2.8
		# Rectangular work lights point down onto the apron, clear of the roof.
		light.global_position += unit.global_basis.z * (unit.radius + .5)
		light.rotation_degrees = Vector3(-90, 0, 0)
		light.light_color = COLORS.get(unit.player.faction, COLORS.bastion)
		light.light_energy = (
			lerpf(2.0, .24, daylight) if ultra_lights else lerpf(1.4, .18, daylight)
		)
		light.area_size = Vector2(clampf(unit.radius * 1.4, 2, 6), 1.0)
		light.area_range = 10.5 if ultra_lights else 8.0
		light.shadow_enabled = (
			ultra_lights and Globals.options.graphics_shadows and index < ULTRA_SHADOWED_LIGHTS
		)
		if light.shadow_enabled:
			light.shadow_bias = 0.04
			light.shadow_blur = 1.4
