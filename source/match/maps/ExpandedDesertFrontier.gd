extends "res://source/match/maps/DesertFrontier.gd"

const Layout = preload("res://source/match/maps/ExpandedMapLayout.gd")
const EXPANSION = 1.5
const EXTRA_FIELDS = [
	Vector2(34, 104),
	Vector2(158, 40),
	Vector2(52, 58),
	Vector2(140, 86),
]


func overview():
	return Layout.overview(
		super.overview(), EXPANSION, EXTRA_FIELDS, Sites.definitions(scene_file_path)
	)


func _ready():
	super._ready()
	Layout.expand(self, FIELDS, EXPANSION)
	Layout.add_fields(self, EXTRA_FIELDS)
	Layout.roads(self, overview().roads)
