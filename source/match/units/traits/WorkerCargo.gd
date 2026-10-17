extends Node3D

# Cargo follows the animated chassis and derives entirely from carried resources,
# so mining, delivery and restored games share the same presentation.
const MATERIALS = preload("res://assets/models/resources/materials_0.glb")
const ELECTRONICS = preload("res://assets/models/resources/electronics_0.glb")
const ANCHORS = {
	"bastion": Vector3(0, .58, .12),
	"helix": Vector3(0, .56, .10),
	"frontier": Vector3(0, .62, .12),
}
var _worker
var _materials
var _electronics


func _init(worker):
	name = "CarriedResources"
	_worker = worker


func _ready():
	position = ANCHORS[_worker.player.faction]
	_materials = _pile(MATERIALS)
	_electronics = _pile(ELECTRONICS)
	refresh()


func _pile(scene):
	var pile = Node3D.new()
	var model = scene.instantiate()
	var bounds = load("res://source/match/FactionCatalog.gd")._bounds(model, Transform3D.IDENTITY)
	var factor = .38 / maxf(bounds.size.x, bounds.size.z)
	model.scale = Vector3.ONE * factor
	model.position = (
		-Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	)
	pile.add_child(model)
	add_child(pile)
	return pile


func refresh():
	visible = _worker.resource_a + _worker.resource_b > 0
	_materials.visible = _worker.resource_a > 0
	_electronics.visible = _worker.resource_b > 0
	var mixed = _materials.visible and _electronics.visible
	_materials.position.x = -.16 if mixed else 0.0
	_electronics.position.x = .16 if mixed else 0.0
	for entry in [[_materials, _worker.resource_a], [_electronics, _worker.resource_b]]:
		var fill = clampf(float(entry[1]) / maxf(1, _worker.resources_max), 0, 1)
		entry[0].scale = Vector3.ONE * lerpf(.65, 1.0, fill)
