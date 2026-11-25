extends Node

# Subtle continuous motion for authored map landmarks: spinning anemometers
# and waterwheels, pulsing tower beacons, bobbing vessels and distant chimney puffs.
var _rotors = []
var _wheels = []
var _beacons = []
var _vessels = []
var _vents = []
var _elapsed = 0.0
var _vent_cursor = 0
var _vent_timer = 0.0


func register(body: Node3D, landmark: Dictionary):
	var asset: String = landmark.get("asset", "")
	if landmark.has("level"):
		_vessels.append(
			{
				"node": body,
				"base_y": body.position.y,
				"base_rot": body.rotation,
				"phase": fposmod(landmark.position.x * 0.37 + landmark.position.y * 0.19, TAU),
			}
		)
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var label := str(mesh.name)
		if "Anemometer" in label or "Fan" in label or "Dish" in label or "Radar" in label:
			_rotors.append(mesh)
		elif "Wheel" in label:
			_wheels.append(mesh)
		elif "Beacon" in label:
			var mat = mesh.get_active_material(0)
			if mat != null:
				var copy = mat.duplicate()
				copy.emission_enabled = true
				copy.emission = Color("ff5c38")
				mesh.material_override = copy
				_beacons.append(copy)
	if (
		"Chimney" in asset
		or "Sawmill" in asset
		or "PotashPlant" in asset
		or "BlastFurnace" in asset
		or "Smelter" in asset
	):
		_vents.append(body.position + Vector3(0, landmark.get("sight_height", 6.0) * 0.85, 0))


func _process(delta: float):
	if get_tree().paused:
		return
	_elapsed += delta
	for rotor in _rotors:
		if is_instance_valid(rotor):
			rotor.rotation.y = fmod(rotor.rotation.y + delta * 2.1, TAU)
	for wheel in _wheels:
		if is_instance_valid(wheel):
			wheel.rotation.x = fmod(wheel.rotation.x + delta * 0.9, TAU)
	for index in _beacons.size():
		var mat = _beacons[index]
		var pulse = 0.5 + 0.5 * sin(_elapsed * 3.0 + index * 1.4)
		mat.emission_energy_multiplier = 0.25 + pulse * 1.35
	for vessel in _vessels:
		var node = vessel.node
		if is_instance_valid(node):
			var t = _elapsed * 1.15 + vessel.phase
			node.position.y = vessel.base_y + sin(t) * 0.045
			node.rotation.z = vessel.base_rot.z + sin(t * 0.72) * 0.012
			node.rotation.x = vessel.base_rot.x + cos(t * 0.58) * 0.008
	if not _vents.is_empty() and DisplayServer.get_name() != "headless":
		_vent_timer += delta
		if _vent_timer >= 0.9:
			_vent_timer = 0.0
			var game = get_parent().get_parent()
			if game != null and "combat_effects" in game and game.combat_effects != null:
				var point: Vector3 = _vents[_vent_cursor % _vents.size()]
				_vent_cursor += 1
				if game.combat_effects._camera_sees(point):
					game.combat_effects.construction_puff(
						"smoke",
						point,
						Vector3(0.18, 0.85, 0.12),
						Color(0.76, 0.78, 0.80, 0.20),
						0.75
					)
