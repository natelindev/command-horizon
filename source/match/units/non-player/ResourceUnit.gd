extends Area3D

const ResourceDecayAnimation = preload("res://source/match/utils/ResourceDecayAnimation.tscn")

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

var radius:
	get:
		return find_child("MovementObstacle").radius
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)


func _enter_tree():
	tree_exiting.connect(_animate_decay)


func _animate_decay():
	# Scene teardown also emits tree_exiting; only depleted deposits produce particles.
	if (
		("resource_a" in self and get("resource_a") > 0)
		or ("resource_b" in self and get("resource_b") > 0)
	):
		return
	var decay_animation = ResourceDecayAnimation.instantiate()
	decay_animation.global_transform = global_transform
	get_parent().add_child.call_deferred(decay_animation)


func _setup_salvage(kind):
	# Position hashing is cosmetic and never consumes simulation randomness.
	var key = absi(int(round(global_position.x * 31)) + int(round(global_position.z * 73)))
	var variant = key % 3
	var geometry = get_node("Geometry")
	if variant != 0:
		var original = geometry.get_child(0)
		geometry.remove_child(original)
		original.queue_free()
		var model = SALVAGE_MODELS[kind][variant]
		geometry.add_child(model.instantiate())
	geometry.rotation.y = float(key % 16) * TAU / 16.0


func can_harvest(_worker):
	return not is_queued_for_deletion()
