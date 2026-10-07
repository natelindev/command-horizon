extends "res://source/match/units/traits/ConvoyVisual.gd"


func _ready():
	# Broad passenger cabin, four lift nacelles, tail and rescue markings.
	_box(Vector3(1.2, 0.7, 2.6), Vector3(0, 0.35, 0), Color("adad88"))
	_box(Vector3(1.06, 0.35, 0.55), Vector3(0, 0.44, -1.32), Color("588c9e"))
	_box(Vector3(3.5, 0.14, 0.5), Vector3(0, 0.45, 0.1), Color("586967"))
	_box(Vector3(0.17, 0.85, 0.65), Vector3(0, 0.85, 1.12), Color("627372"))
	_box(Vector3(1.85, 0.1, 0.32), Vector3(0, 0.7, 1.15), Color("9aa58d"))
	for x in [-1.45, 1.45]:
		for z in [-0.7, 0.7]:
			_box(Vector3(0.6, 0.42, 0.8), Vector3(x, 0.28, z), Color("34444b"))
			_box(Vector3(0.38, 0.07, 0.55), Vector3(x, 0.02, z), Color("74d6e0"))
	for x in [-0.61, 0.61]:
		_box(Vector3(0.03, 0.35, 0.22), Vector3(x, 0.45, 0), Color("edc268"))
		_box(Vector3(0.03, 0.1, 0.7), Vector3(x, 0.45, 0), Color("edc268"))
