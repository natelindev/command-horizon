extends Node3D

# A nodding pump, spinning exhaust turbine, pulsing flare stack and travelling
# piston make active extraction unmistakably alive from above.
const Kit = preload("res://source/match/units/traits/InfantryEquipment.gd")
var phase = 0.0
var beam: Node3D
var piston: Node3D
var turbine: Node3D
var flare: Node3D
var indicator: StandardMaterial3D
var flare_material: StandardMaterial3D
var _puff_timer = 0.0


func _ready():
	var steel = Kit._material(Color("49545b"), .65)
	var brass = Kit._material(Color("dba557"), .5)
	indicator = Kit._material(Color("51635b"), .25)
	indicator.emission_enabled = true
	flare_material = Kit._material(Color("ff993b"), .1)
	flare_material.emission_enabled = true
	flare_material.emission = Color("ff7a22")
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
	turbine = Node3D.new()
	turbine.name = "ExhaustTurbine"
	turbine.position = Vector3(.75, .75, .65)
	add_child(turbine)
	Kit._box(turbine, "BladeA", Vector3.ZERO, Vector3(.75, .04, .14), brass)
	Kit._box(turbine, "BladeB", Vector3.ZERO, Vector3(.14, .04, .75), brass)
	flare = Kit._box(
		self, "FlareGlow", Vector3(-1.45, 8.6, 5.9), Vector3(.28, .42, .28), flare_material
	)
	flare.visible = false


func advance(delta, active):
	if active:
		phase = fmod(phase + delta * 2.4, TAU)
		beam.rotation.x = sin(phase) * .28
		piston.position.y = 1.3 + sin(phase) * .38
		turbine.rotation.y = fmod(turbine.rotation.y + delta * 4.5, TAU)
		flare.visible = true
		var flicker = 0.8 + 0.3 * sin(phase * 3.1)
		flare.scale = Vector3(flicker, 0.85 + 0.35 * cos(phase * 2.7), flicker)
		flare_material.emission_energy_multiplier = 1.2 + 0.8 * sin(phase * 3.7)
		if DisplayServer.get_name() != "headless":
			_puff_timer += delta
			if _puff_timer >= 1.6:
				_puff_timer = 0.0
				var site = get_parent()
				if (
					site != null
					and "_match" in site
					and site._match != null
					and site._match.combat_effects != null
				):
					var effects = site._match.combat_effects
					if effects._camera_sees(site.global_position):
						effects.construction_puff(
							"smoke",
							site.global_position + Vector3(-1.45, 4.4, -.55),
							Vector3(0.08, 0.75, 0.06),
							Color(0.84, 0.84, 0.82, 0.22),
							0.55
						)
	else:
		flare.visible = false
	indicator.albedo_color = Color("87e6b0") if active else Color("51635b")
	indicator.emission = indicator.albedo_color * (1.2 + .5 * sin(phase) if active else 0.0)
