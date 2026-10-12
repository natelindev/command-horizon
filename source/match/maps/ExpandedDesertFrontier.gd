extends "res://source/match/maps/DesertFrontier.gd"

const Layout = preload("res://source/match/maps/ExpandedMapLayout.gd")
const EXPANSION = 1.5
const EXTRA_FIELDS = [
	Vector2(34, 104),
	Vector2(158, 40),
	Vector2(52, 58),
	Vector2(140, 86),
]
const POI_SITES = [
	{"kind": "refinery", "position": Vector2(66, 20), "name": "North Refinery"},
	{"kind": "refinery", "position": Vector2(126, 124), "name": "South Refinery"},
	{"kind": "mercenary", "position": Vector2(44, 82), "name": "West Mercenary Camp"},
	{"kind": "mercenary", "position": Vector2(148, 62), "name": "East Mercenary Camp"},
	{"kind": "repair", "position": Vector2(84, 68), "name": "West Repair Shop"},
	{"kind": "repair", "position": Vector2(108, 76), "name": "East Repair Shop"},
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
