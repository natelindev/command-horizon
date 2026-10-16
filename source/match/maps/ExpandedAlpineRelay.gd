extends "res://source/match/maps/AlpineRelay.gd"

const Layout = preload("res://source/match/maps/ExpandedMapLayout.gd")
const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const EXPANSION = 1.5
const EXTRA_FIELDS = [
	Vector2(32, 112),
	Vector2(160, 44),
	Vector2(70, 20),
	Vector2(122, 136),
]
var points_of_interest = []


func overview():
	return Layout.overview(
		super.overview(), EXPANSION, EXTRA_FIELDS, Sites.definitions(scene_file_path)
	)


func _ready():
	super._ready()
	Layout.expand(self, FIELDS, EXPANSION)
	Layout.add_fields(self, EXTRA_FIELDS)
	Layout.roads(self, overview().roads)
