extends "res://source/match/maps/AlpineRelay.gd"

const Layout = preload("res://source/match/maps/ExpandedMapLayout.gd")
const EXPANSION = 1.5
const EXTRA_FIELDS = [
	Vector2(32, 112),
	Vector2(160, 44),
	Vector2(70, 20),
	Vector2(122, 136),
]
const POI_SITES = [
	{"kind": "refinery", "position": Vector2(50, 45), "name": "West Refinery"},
	{"kind": "refinery", "position": Vector2(142, 111), "name": "East Refinery"},
	{"kind": "mercenary", "position": Vector2(56, 114), "name": "South Mercenary Camp"},
	{"kind": "mercenary", "position": Vector2(136, 42), "name": "North Mercenary Camp"},
	{"kind": "repair", "position": Vector2(72, 78), "name": "West Repair Shop"},
	{"kind": "repair", "position": Vector2(120, 78), "name": "East Repair Shop"},
]
var points_of_interest = []


func overview():
	return Layout.overview(super.overview(), EXPANSION, EXTRA_FIELDS, POI_SITES)


func _ready():
	super._ready()
	Layout.expand(self, FIELDS, EXPANSION)
	Layout.add_fields(self, EXTRA_FIELDS)
	Layout.roads(self, overview().roads)
	load("res://source/match/world/PointOfInterestCatalog.gd").populate(self)
