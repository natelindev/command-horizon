extends Area3D

signal selected
signal deselected
signal hp_changed

const Rules = preload("res://source/match/combat/CombatRules.gd")
var player = null
var hp = 60.0
var hp_max = 60.0
var signature = null
var type = "Infantry"
var radius = .45
var movement_domain = 1
var sight_range = null
var movement_speed = 0.0
var attack_range = null
var attack_damage = null
var attack_domains = []
var death_age = 0.0
var panic_left = 0.0
var hit_left = 0.0
var interactive = true
var neutral_id = ""
var _match
var _model
var _model_origin = Vector3.ZERO
var _model_scale = Vector3.ONE
var _death_kind = "resident"
var _health
var _charred = false
var _meshes = []
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)


func configure_target(kind, size, health, height = 1.7):
	_death_kind = kind
	radius = size
	hp_max = health
	hp = health
	type = "Infantry" if kind in ["resident", "fox", "gull"] else "Worker"
	movement_domain = 0 if kind == "gull" else 1
	collision_layer = 2 if interactive else 0
	collision_mask = 0
	input_ray_pickable = interactive
	if not interactive:
		return
	add_to_group("neutral_targets")
	var collider = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = size
	shape.height = height
	collider.shape = shape
	collider.position.y = shape.height / 2
	add_child(collider)
	var target = load("res://source/match/units/traits/Targetability.tscn").instantiate()
	target.radius = size
	target.position.y = .05
	add_child(target)
	_health = load("res://source/match/units/traits/HealthBar.tscn").instantiate()
	_health.position.y = shape.height + .45
	_health.size = Vector2(44, 6)
	add_child(_health)
	input_event.connect(_inspect)
	MatchSignals.deselect_all_units.connect(func(): deselected.emit())


func _inspect(_camera, event, _point, _normal, _shape):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit()


func receive_weapon_hit(source):
	if hp <= 0 or not interactive:
		return
	var damage = Rules.damage(source, self)
	if damage <= 0:
		return
	_match.combat_effects.impact(self, source, global_position + Vector3.UP * .5)
	hp = maxf(0, hp - damage)
	hp_changed.emit()
	hit_left = .3
	panic_left = 7.0
	for neighbor in get_tree().get_nodes_in_group("neutral_targets"):
		if neighbor.hp > 0 and neighbor.global_position.distance_to(global_position) < 12:
			neighbor.panic_left = 7.0
	if hp == 0:
		begin_death()


func begin_death():
	collision_layer = 0
	input_ray_pickable = false
	if _health != null:
		_health.hide()
	_apply_scorch()
	_match.combat_audio.destruction(self)
	_match.combat_effects.deaths_emitted += 1
	if visible:
		var effects = _match.combat_effects
		for index in 8:
			var angle = index * TAU / 8
			var drift = Vector3(cos(angle), .7, sin(angle))
			effects._puff(
				"dust",
				global_position + Vector3.UP * .15,
				drift,
				Color(.5, .44, .35, .6),
				radius * 1.4
			)
			if _death_kind in ["car", "tug", "building"]:
				effects._puff(
					"fire", global_position + drift * .4, drift, Color(1, .32, .06, .8), radius
				)


func advance_damage(delta):
	hit_left = maxf(0, hit_left - delta)
	panic_left = maxf(0, panic_left - delta)
	if hp > 0:
		return false
	if death_age >= 30:
		return true
	death_age = minf(30, death_age + delta)
	apply_death_pose()
	if visible and _death_kind in ["car", "tug", "building"] and death_age < 6:
		if int(death_age * 10) != int((death_age - delta) * 10):
			_match.combat_effects._puff(
				"smoke",
				global_position + Vector3.UP * minf(radius * .4, 2.5),
				Vector3.UP * .6,
				Color(.18, .19, .2, .5),
				minf(radius * .65, 3.5)
			)
	return true


func apply_death_pose():
	var t = smoothstep(0, 1.1, death_age)
	_model.position = _model_origin
	_model.scale = _model_scale
	match _death_kind:
		"resident":
			_model.rotation.z = -1.45 * t
			_model.position.y += .18 * t
		"fox":
			_model.rotation.z = 1.55 * t
			_model.position.y += .17 * t
		"gull":
			_model.rotation = Vector3(.4 * t, 0, 1.7 * t)
			_model.position.y -= maxf(0, position.y - .12) * t * t
		"car":
			_model.rotation.z = -.16 * t
			_model.position.y -= .2 * t
			_model.scale.y *= 1 - .22 * t
		"tug":
			_model.rotation.z = .65 * t
			_model.position.y -= 1.5 * t
		"building":
			_model.scale.y *= 1 - .86 * t
			_model.rotation.z = .035 * t
	if _meshes.is_empty():
		_meshes = _model.find_children("*", "MeshInstance3D", true, false)
	for mesh in _meshes:
		mesh.transparency = (
			clampf((death_age - 20) / 10, 0, 1) if _death_kind in ["resident", "fox", "gull"] else 0
		)


func refresh_visibility(game):
	var observed = game.settings.visibility == game.settings.Visibility.FULL
	if not observed:
		for side in game.visible_players:
			if side != null and game.battlefield.is_observed(side, self):
				observed = true
				break
	visible = observed and (interactive or Globals.options.living_world)
	input_ray_pickable = visible and interactive and hp > 0
	collision_layer = 2 if input_ray_pickable else 0


func capture_combat():
	return {"hp": hp, "death_age": death_age, "panic_left": panic_left, "hit_left": hit_left}


func restore_combat(saved):
	hp = saved.hp
	death_age = saved.death_age
	panic_left = saved.panic_left
	hit_left = saved.hit_left
	collision_layer = 2 if hp > 0 else 0
	hp_changed.emit()
	if hp == 0:
		_apply_scorch()
		apply_death_pose()
		_health.hide()


func _apply_scorch():
	if _charred or _death_kind not in ["car", "tug", "building"]:
		return
	_charred = true
	var soot = StandardMaterial3D.new()
	soot.albedo_color = Color(.09, .08, .065, .65)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.roughness = .98
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = soot
