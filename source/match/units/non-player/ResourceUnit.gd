extends Area3D

const ResourceDecayAnimation = preload("res://source/match/utils/ResourceDecayAnimation.tscn")
const ObjectMaterials = preload("res://source/match/ObjectMaterials.gd")

# Absolute stock thresholds keep partially harvested deposits and restored saves visually
# exact without introducing a second, potentially stale resource balance into the archive.
const PILE_THRESHOLDS = [60, 150, 300]
const PILE_POSITIONS = [
	Vector3.ZERO,
	Vector3(-0.27, 0.05, 0.12),
	Vector3(0.25, 0.08, -0.15),
	Vector3(-0.06, 0.32, 0.02),
	Vector3(0.06, 0.58, -0.02),
]
const PILE_SCALES = [1.0, 0.42, 0.42, 0.68, 0.46]

const SALVAGE_MODELS = {
	"materials":
	[
		preload("res://assets/models/resources/materials_0.glb"),
		preload("res://assets/models/resources/materials_1.glb"),
		preload("res://assets/models/resources/materials_2.glb"),
	],
	"electronics":
	[
		preload("res://assets/models/resources/electronics_0.glb"),
		preload("res://assets/models/resources/electronics_1.glb"),
		preload("res://assets/models/resources/electronics_2.glb"),
	],
}

const DEPLETED_MODELS = {
	"materials":
	[
		preload("res://assets/models/resources/materials_depleted_0.glb"),
		preload("res://assets/models/resources/materials_depleted_1.glb"),
		preload("res://assets/models/resources/materials_depleted_2.glb"),
	],
	"electronics":
	[
		preload("res://assets/models/resources/electronics_depleted_0.glb"),
		preload("res://assets/models/resources/electronics_depleted_1.glb"),
		preload("res://assets/models/resources/electronics_depleted_2.glb"),
	],
}

var radius:
	get:
		return find_child("MovementObstacle").radius
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)

var harvest_origin = Vector3.INF

var _salvage_kind = ""
var _salvage_key = 0
var _salvage_stage = -1


func _exit_tree():
	_invalidate_registry()


func _invalidate_registry():
	var game = find_parent("Match")
	if game != null and game.has_method("invalidate_group_registry"):
		game.invalidate_group_registry("resource_units")


func _enter_tree():
	_invalidate_registry()
	var game = find_parent("Match")
	if game != null and game.has_method("invalidate_group_registry"):
		tree_exited.connect(game.invalidate_group_registry.bind("resource_units"), CONNECT_ONE_SHOT)
	tree_exiting.connect(_animate_decay)


func _animate_decay():
	# Scene teardown also emits tree_exiting; only depleted deposits produce particles.
	if (
		("resource_a" in self and get("resource_a") > 0)
		or ("resource_b" in self and get("resource_b") > 0)
	):
		return
	_spawn_decay.call_deferred(get_parent(), global_transform)


static func _spawn_decay(parent, a_transform):
	# A wreck can be consumed in the same frame that the match closes. Delay
	# creation as well as attachment, so a destroyed parent cannot orphan it.
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var game = parent.find_parent("Match")
	if game == null or game.is_queued_for_deletion():
		return
	var decay_animation = ResourceDecayAnimation.instantiate()
	parent.add_child(decay_animation)
	decay_animation.global_transform = a_transform


func _setup_salvage(kind):
	# Position hashing is cosmetic and never consumes simulation randomness.
	_salvage_kind = kind
	_salvage_key = absi(int(round(global_position.x * 31)) + int(round(global_position.z * 73)))
	get_node("Geometry").rotation.y = float(_salvage_key % 16) * TAU / 16.0
	_update_salvage(get("resource_a") if kind == "materials" else get("resource_b"))


func relocate_field(point: Vector3, origin: Vector3):
	global_position = point
	harvest_origin = origin
	if not _salvage_kind.is_empty():
		_salvage_stage = -1
		_setup_salvage(_salvage_kind)
	reset_physics_interpolation()


func _update_salvage(amount):
	# Setters also run before ready and for vehicle wrecks, which have their own art.
	if _salvage_kind.is_empty():
		return
	var stage = 0
	for threshold in PILE_THRESHOLDS:
		if amount > threshold:
			stage += 1
	if stage == _salvage_stage:
		return
	_salvage_stage = stage
	var geometry = get_node("Geometry")
	for original in geometry.get_children():
		geometry.remove_child(original)
		original.queue_free()
	if stage < PILE_THRESHOLDS.size():
		# Open bundles -> loose parts -> scraps: authored geometry, at its real scale.
		geometry.add_child(DEPLETED_MODELS[_salvage_kind][stage].instantiate())
		ObjectMaterials.apply(geometry)
		return
	for index in PILE_POSITIONS.size():
		var pile = SALVAGE_MODELS[_salvage_kind][(_salvage_key + index) % 3].instantiate()
		pile.position = PILE_POSITIONS[index]
		pile.scale = Vector3.ONE * PILE_SCALES[index]
		pile.rotation.y = float((_salvage_key + index * 5) % 16) * TAU / 16.0
		geometry.add_child(pile)
	ObjectMaterials.apply(geometry)


func can_harvest(_worker):
	return not is_queued_for_deletion()


func saturation_info(observer = null) -> Dictionary:
	var deposits = get_tree().get_nodes_in_group("resource_units").filter(
		func(deposit):
			return (
				not deposit.is_queued_for_deletion()
				and not deposit.is_in_group("salvage_wrecks")
				and ("resource_a" in deposit) == ("resource_a" in self)
				and (
					deposit.harvest_origin.is_equal_approx(harvest_origin)
					if harvest_origin.is_finite()
					else (
						deposit.global_position_yless.distance_squared_to(global_position_yless)
						<= 100.0
					)
				)
			)
	)
	var workers = 0
	for assignment in get_tree().get_nodes_in_group("harvest_assignments"):
		if assignment.is_queued_for_deletion():
			continue
		var worker = assignment.get_parent()
		if observer != null and worker.player != observer:
			continue
		if assignment.get_resource_unit() in deposits:
			workers += 1
	var optimal = deposits.size() * 2
	return {"workers": workers, "optimal": optimal, "maximum": deposits.size() * 3}
