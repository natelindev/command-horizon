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
	MatchSignals.unit_weapon_hit.connect(_nearby_combat)
	Globals.options.changed.connect(refresh_visibility)
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
		if by_id.has(actor.entry.id):
			actor.restore(by_id[actor.entry.id])
	refresh_visibility()


func _nearby_combat(target, _source):
	for actor in actors:
		if actor.hp > 0 and actor.global_position.distance_to(target.global_position) < 12:
			actor.panic_left = 7.0
