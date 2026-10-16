extends Node3D

# Cosmetic courtyard activity follows the saved battle clock. It respects fog and
# the living-world preference without adding military targets or save identities.
const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
const Actor = preload("res://source/match/ambient/AmbientActor.gd")
var buildings = []
var actors = []
var _game


func _ready():
	name = "CampaignInteriorLife"
	_game = get_parent().get_parent()
	var entries = []
	for index in range(0, buildings.size(), maxi(1, int(buildings.size() / 6))):
		if entries.size() >= 12:
			break
		var building = buildings[index]
		var point = building.position
		var radius = building.get_meta("clearance_radius") + 1.1
		Catalog._add(
			entries,
			"resident",
			[
				[point.x - radius, point.z - radius],
				[point.x + radius, point.z - radius],
				[point.x + radius, point.z + radius],
				[point.x - radius, point.z + radius]
			],
			2
		)
	for entry in entries:
		if not _clear_path(entry):
			continue
		var actor = Actor.new()
		actor.setup(entry, false)
		add_child(actor)
		actors.append(actor)
	Globals.options.changed.connect(_refresh)


func _physics_process(_delta):
	if not _game.is_node_ready():
		return
	for actor in actors:
		actor.travel = fposmod(actor.entry.start + _game.simulation_time * .8, actor.entry.length)
		actor.phase = fposmod(actor.entry.start + _game.simulation_time * 5, TAU)
		actor.apply_pose(true)
	_refresh()


func _refresh():
	if not _game.is_node_ready():
		return
	for actor in actors:
		actor.refresh_visibility(_game)


func _clear_path(entry):
	for obstacle in get_parent().find_children("*", "NavigationObstacle3D", true, false):
		var center = obstacle.get_parent().global_position
		for point in entry.path:
			if Vector2(point.x - center.x, point.z - center.z).length() < obstacle.radius + .4:
				return false
	return true
