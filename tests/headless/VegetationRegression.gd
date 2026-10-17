extends SceneTree

const Vegetation = preload("res://source/match/maps/Vegetation.gd")
var errors = []


func _initialize():
	for biome in Vegetation.TREES:
		for index in 4:
			var model = Vegetation.tree(biome, index, 7.0)
			_check(
				absf(Vegetation.bounds(model).size.y - 7.0) < .01,
				"Tree is undersized: " + model.scene_file_path
			)
			_check(
				model.scene_file_path.begins_with(Vegetation.ROOT),
				"Tree does not reuse a shipped asset"
			)
			_check(
				model.find_children("*", "CollisionObject3D", true, false).is_empty(),
				"Scenic vegetation introduced collision"
			)
			model.free()
	for index in 3:
		var shrub = Vegetation.bush(index)
		_check(not shrub.scene_file_path.contains("DryScrub"), "Flat scrub placeholder returned")
		var height = Vegetation.bounds(shrub).size.y
		_check(height >= 1.59 and height <= 1.91, "Shrub remains miniature")
		shrub.free()
	for message in errors:
		push_error(message)
	print("Vegetation: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(value, message):
	if not value:
		errors.append(message)
