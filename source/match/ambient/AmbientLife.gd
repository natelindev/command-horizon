extends Node3D

const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
const Actor = preload("res://source/match/ambient/AmbientActor.gd")
var actors = []
var _game


func _ready():
	_game = get_parent().get_parent()
	for entry in Catalog.entries(_game.settings.map_path):
		var actor = Actor.new()
		actor.setup(entry)
		add_child(actor)
		actors.append(actor)
	if not _game.is_node_ready():
		await _game.ready
	refresh_visibility()


func _physics_process(delta):
	if not is_instance_valid(_game) or not _game.is_node_ready():
		return
	for actor in actors:
		actor.advance(delta, _game)


func refresh_visibility():
	for actor in actors:
		actor.refresh_visibility(_game)


func capture():
	return actors.map(func(actor): return actor.capture())


func restore(saved):
	var by_id = {}
	for entry in saved:
		by_id[entry.id] = entry
	for actor in actors:
		actor.restore(by_id[actor.entry.id])
	refresh_visibility()
