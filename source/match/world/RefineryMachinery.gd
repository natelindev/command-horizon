extends Node3D

# A nodding pump and travelling piston make active extraction readable from above.
const Kit = preload("res://source/match/units/traits/InfantryEquipment.gd")
var phase = 0.0
var beam: Node3D
var piston: Node3D
var indicator: StandardMaterial3D


func _ready():
	var steel = Kit._material(Color("49545b"), .65)
	var brass = Kit._material(Color("dba557"), .5)
	indicator = Kit._material(Color("51635b"), .25)
	indicator.emission_enabled = true
	Kit._box(self, "PumpBase", Vector3(0, .15, 0), Vector3(1.3, .3, 2.5), steel)
	Kit._box(self, "Support", Vector3(0, 1.4, 0), Vector3(.32, 2.5, .45), steel)
	beam = Node3D.new()
	beam.name = "WalkingBeam"
	beam.position.y = 2.6
	add_child(beam)
	Kit._box(beam, "Beam", Vector3.ZERO, Vector3(.4, .35, 2.8), brass)
	Kit._box(beam, "Horsehead", Vector3(0, -.2, -1.35), Vector3(.6, .8, .4), brass)
	Kit._box(beam, "Counterweight", Vector3(0, -.35, 1.1), Vector3(.85, .8, .45), steel)
	piston = Kit._box(self, "Piston", Vector3(0, 1.3, -1.35), Vector3(.12, 2.0, .12), steel)
	Kit._box(self, "RunningLight", Vector3(0, .38, .85), Vector3(.9, .12, .4), indicator)


func advance(delta, active):
	if active:
		phase = fmod(phase + delta * 2.4, TAU)
		beam.rotation.x = sin(phase) * .28
		piston.position.y = 1.3 + sin(phase) * .38
	indicator.albedo_color = Color("87e6b0") if active else Color("51635b")
	indicator.emission = indicator.albedo_color * (1.0 + .4 * sin(phase) if active else 0.0)
