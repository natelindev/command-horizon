extends "res://tests/rendered/ImpactEffectsPreview.gd"

var _shielded
var _cannon
var _helicopter


func _init():
	_output = "res://art/contact-polish/"


func _prepare_gallery():
	var human = game._get_human_player()
	var helix = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	_shielded = _spawn("Tank", helix, ORIGIN + Vector3(-3.5, 0, -3))
	_cannon = _spawn("Tank", human, ORIGIN + Vector3(3.5, 0, -3))
	_helicopter = _spawn("Helicopter", human, ORIGIN + Vector3(0, 2.4, 3))
	for unit in [_shielded, _cannon, _helicopter]:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.show()
		for path in ["Highlight", "Selection", "TeamFootprint", "HealthBar"]:
			var decoration = unit.get_node_or_null(path)
			if decoration != null:
				decoration.hide()
	_cannon.rotation.y = -PI * .5
	_helicopter.position.y = 2.4
	for unit in [_shielded, _cannon, _helicopter]:
		unit.reset_physics_interpolation()
	game.fog_of_war.reveal()


func _gallery_labels():
	return [["SHIELD CONTACT", -3.5, -1.0], ["CANNON GAS", 3.5, -1.0], ["ROTOR WASH", 0.0, 5.0]]


func _emit_gallery():
	var effects = game.combat_effects
	# Spawn initialization is deferred; pose the frozen models after it settles.
	_helicopter.position.y = 2.4
	for unit in [_shielded, _cannon, _helicopter]:
		unit.get_node("Geometry").global_transform = unit.global_transform
		unit.reset_physics_interpolation()
	_check(effects._can_show(_helicopter), "Rotor gallery is not observed")
	_check(_helicopter.global_position.y < 5.0, "Rotor gallery is above its ground-effect height")
	var center = _shielded.global_position + Vector3.UP * .65
	effects.shield_impact(_shielded, center + Vector3(0, .2, .65))
	var target = _cannon.global_position + Vector3.RIGHT * 5.0 + Vector3.UP * .65
	var origin = game.projectile_system.muzzle_of(_cannon, target)
	effects.shot(_cannon, origin, target, .16, false, null, false, {"kind": "shell"})
	effects.rotor_downwash(_helicopter)


func _gallery_frame(frame):
	_helicopter.get_node("BastionVisuals")._advance_rotors(1.0 / 60.0)
	if frame > 0 and frame % 27 == 0:
		game.combat_effects.rotor_downwash(_helicopter)
