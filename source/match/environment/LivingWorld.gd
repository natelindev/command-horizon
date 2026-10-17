extends Node3D

# Scenic districts are beyond the playable boundary. Small street furniture on
# authored urban sidewalks never adds collision, navigation, selection or vision.
const Actor = preload("res://source/match/ambient/AmbientActor.gd")
const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
var actors = []
var facades = []
var windows: StandardMaterial3D
var river_material: ShaderMaterial
var _game
var _size: Vector2
var _urban = false
var _coastal = false
var _alpine = false
var _desert = false
var _lamps = []
var _overlay: ShaderMaterial
var _materials = {}
var _cloths = []
var _tree_serial = 0


func _ready():
	name = "LivingWorld"
	_game = get_parent().get_parent()
	_size = get_parent().size
	var map_name = Catalog.authored_name(_game.settings.map_path)
	_coastal = map_name == "CoastalFoundry"
	_alpine = map_name in ["AlpineRelay", "SplitSignalMap"]
	_desert = (
		"Desert" in map_name or map_name in ["SupplyLineMap", "AirCorridorMap", "DesertFrontier"]
	)
	if _coastal:
		# Harbor water is north; inhabited expansion belongs on the inland edge.
		transform = Transform3D(Basis(Vector3.UP, PI), Vector3(_size.x, 0, _size.y))
	_urban = (
		map_name
		in ["IndustrialCrossroads", "BrokenFoundryMap", "CommandHorizonMap", "CoastalFoundry"]
	)
	windows = _material(Color("f4ca87"))
	windows.emission_enabled = true
	windows.emission = Color("ffb55e")
	var overlay = _game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	_overlay = overlay.material_override
	_ground_and_river()
	_district()
	_civilian_industry()
	# Tactical buildings retain their interactive geometry and damage state.
	_mountains()
	_population()
	Globals.options.changed.connect(_apply_options)
	_apply_options()


func _apply_options():
	visible = Globals.options.living_world
	_overlay.set_shader_parameter("living_world_visibility", .72 if visible else 0.0)
	set_physics_process(visible)


func _material(color):
	if _materials.has(color):
		return _materials[color]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .87
	_materials[color] = material
	return material


func _box(label, point, dimensions, material):
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	var instance = MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = point
	add_child(instance)
	return instance


func _ground_and_river():
	var ground = _material(
		Color("71818b") if _alpine else (Color("73644c") if _desert else Color("444c39"))
	)
	# Four strips leave the entire existing playable terrain intact.
	_box(
		"NorthLandscape", Vector3(_size.x / 2, -.07, -55), Vector3(_size.x + 200, .04, 110), ground
	)
	if not _coastal:
		_box(
			"SouthLandscape",
			Vector3(_size.x / 2, -.07, _size.y + 55),
			Vector3(_size.x + 200, .04, 110),
			ground
		)
		_box("WestLandscape", Vector3(-55, -.07, _size.y / 2), Vector3(110, .04, _size.y), ground)
		_box(
			"EastLandscape",
			Vector3(_size.x + 55, -.07, _size.y / 2),
			Vector3(110, .04, _size.y),
			ground
		)
	river_material = ShaderMaterial.new()
	river_material.shader = load("res://source/shaders/3d/living_river.gdshader")
	var water = _box(
		"River", Vector3(_size.x / 2, .12, -53), Vector3(_size.x + 160, .08, 12), river_material
	)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quay = _material(Color("6a6d61"))
	for z in [-46.7, -59.3]:
		_box("RiverEmbankment", Vector3(_size.x / 2, .3, z), Vector3(_size.x + 160, .6, .7), quay)
	for x in [12, _size.x - 12]:
		_box("BridgeDeck", Vector3(x, 1, -53), Vector3(5, .55, 15), quay)
		for dx in [-2.5, 2.5]:
			_box("BridgeParapet", Vector3(x + dx, 1.6, -53), Vector3(.22, .7, 15), quay)
		for z in [-49, -57]:
			_box("BridgePier", Vector3(x, .5, z), Vector3(3, 1, 1), quay)


func _district():
	var pavement = _material(Color("555c59"))
	var asphalt = _material(Color("293336"))
	var count = maxi(3, int(_size.x / 16))
	for index in count:
		var x = 5.0 + index * 16.0
		var height = (5.0 + float(index % 3) * 2.0) if _urban else (3.4 + float(index % 2) * 1.2)
		_house(Vector3(x, 0, -8), Vector3(6.5, height, 6), index)
		if _urban or index % 2 == 0:
			_house(Vector3(x + 5, 0, -72), Vector3(8, height + (4 if _urban else 0), 8), index + 2)
		_box("NeighborhoodPaving", Vector3(x, .08, -8), Vector3(10, .12, 9), pavement)
		_lamp(Vector3(x + 5, 0, -3.5))
		_tree(Vector3(x - 4, 0, -4), 1.0 + float(index % 2) * .3)
		_tree(Vector3(x + 4, 0, -64), 1.4)
	_box("RiversideStreet", Vector3(_size.x / 2, .05, -66), Vector3(_size.x + 20, .1, 5), asphalt)
	_box("FrontageWalk", Vector3(_size.x / 2, .11, -3), Vector3(_size.x + 12, .12, 1.6), pavement)
	# Known sidewalks between existing industrial blocks, away from combat lanes.
	if _game.settings.map_path.ends_with("IndustrialCrossroads.tscn"):
		for z in [16.5, 27.5, 46.5, 57.5, 76.5, 87.5]:
			for x in [43, 67, 91]:
				_lamp(Vector3(x, 0, z))
				_box("Bench", Vector3(x + 1, .45, z), Vector3(1.4, .16, .45), pavement)
				for dx in [.5, 1.5]:
					_box(
						"BenchLeg",
						Vector3(x + dx, .23, z),
						Vector3(.08, .4, .35),
						_material(Color("344046"))
					)
				_box("BenchBack", Vector3(x + 1, .77, z + .17), Vector3(1.4, .4, .07), pavement)
		for point in [
			Vector3(47, 0, 32), Vector3(71, 0, 62), Vector3(47, 0, 62), Vector3(71, 0, 32)
		]:
			_tree(point, .65)


func _civilian_industry():
	# Retired Bastion models become unowned, non-interactive municipal buildings.
	# Their whole footprint stays beyond the tactical boundary, alongside town.
	var roles = [
		["CommandCenter", "CivicAdministration"],
		["Barracks", "UtilitySheds"],
		["VehicleFactory", "FreightWarehouse"],
		["AircraftFactory", "CargoHangar"],
		["PowerPlant", "MunicipalSubstation"],
		["CommandLab", "CommunicationsOffice"],
		["RepairDepot", "PublicWorksGarage"]
	]
	var neutral_trim = _material(Color("698895"))
	var neutral_wall = _material(Color("888779"))
	var neutral_roof = _material(Color("596565"))
	var pavement = _material(Color("515954"))
	for index in roles.size():
		var point = Vector3(8 + index * (_size.x - 16) / 6.0, 0, -23)
		var model = load("res://assets/models/bastion/demo/%s.glb" % roles[index][0]).instantiate()
		model.name = roles[index][1]
		model.position = point
		model.scale = Vector3.ONE * 1.15
		add_child(model)
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material = mesh.get_active_material(surface)
				if material == null:
					continue
				if material.resource_name.begins_with("TeamColor"):
					mesh.set_surface_override_material(surface, neutral_trim)
				elif material.resource_name == "Bastion_Armor":
					mesh.set_surface_override_material(surface, neutral_wall)
				elif material.resource_name == "Bastion_Panels":
					mesh.set_surface_override_material(surface, neutral_roof)
		_box("MunicipalYard", point + Vector3(0, .03, 0), Vector3(8, .05, 8), pavement)
		_box("YardAccess", point + Vector3(0, .04, 5), Vector3(2.5, .06, 6), pavement)
	_box(
		"MunicipalStreet",
		Vector3(_size.x / 2, .05, -16),
		Vector3(_size.x + 12, .08, 3),
		_material(Color("293336"))
	)


func _house(point, dimensions, index):
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/living_facade.gdshader")
	material.set_shader_parameter(
		"masonry", [Color("89816a"), Color("727d79"), Color("8f6f59"), Color("6e757a")][index % 4]
	)
	var floors = maxi(2, int(dimensions.y / 2))
	material.set_shader_parameter("floors", Vector2(4, floors))
	material.set_shader_parameter("building_size", dimensions)
	facades.append(material)
	_box("Residence", point + Vector3(0, dimensions.y / 2, 0), dimensions, material)
	var roof = _material(Color("35454a"))
	_box(
		"RoofCornice",
		point + Vector3(0, dimensions.y + .1, 0),
		Vector3(dimensions.x + .5, .3, dimensions.z + .5),
		roof
	)
	_box("RoofPlant", point + Vector3(1, dimensions.y + .6, 1), Vector3(1.8, .9, 1.7), roof)
	_box(
		"ShopAwning",
		point + Vector3(0, 2.2, dimensions.z / 2 + .6),
		Vector3(dimensions.x * .8, .18, 1.5),
		_material(Color("69796c") if index % 2 else Color("af8a52"))
	)
	_box("Door", point + Vector3(0, 1, dimensions.z / 2 + .03), Vector3(.9, 2, .08), roof)
	var stone = _material(Color("b1aa92"))
	var glass_trim = _material(Color("344c50"))
	var front = dimensions.z / 2 + .055
	for floor_index in floors:
		for column in 4:
			var x = -dimensions.x / 2 + (column + .47) * dimensions.x / 4
			var y = (floor_index + .52) * dimensions.y / floors
			var window_width = dimensions.x / 8
			var window_height = dimensions.y / floors * .48
			_box(
				"WindowSill",
				point + Vector3(x, y - window_height / 2, front),
				Vector3(window_width + .16, .095, .22),
				stone
			)
			_box(
				"WindowMullion",
				point + Vector3(x, y, front),
				Vector3(.04, window_height, .075),
				glass_trim
			)
			_box(
				"WindowLintel",
				point + Vector3(x, y + window_height / 2, front),
				Vector3(window_width + .12, .08, .15),
				stone
			)
	_box("EntranceStep", point + Vector3(0, .12, front + .3), Vector3(1.25, .24, .65), stone)
	for side in [-1, 1]:
		_box(
			"CanopyBracket",
			point + Vector3(side * dimensions.x * .32, 1.99, front + .35),
			Vector3(.06, .34, .55),
			roof
		)
		_box(
			"RainwaterPipe",
			point + Vector3(side * (dimensions.x / 2 - .28), dimensions.y / 2, front),
			Vector3(.085, dimensions.y, .09),
			roof
		)
	if not _alpine:
		for z in [-dimensions.z / 2, dimensions.z / 2]:
			_box(
				"RoofParapet",
				point + Vector3(0, dimensions.y + .34, z),
				Vector3(dimensions.x + .1, .3, .15),
				stone
			)
		for slot in 5:
			_box(
				"RoofPlantLouver",
				point + Vector3(1, dimensions.y + .3 + slot * .11, 1.86),
				Vector3(1.45, .035, .04),
				glass_trim
			)
	if dimensions.y > 4 and index % 2 == 0:
		var balcony = point + Vector3(-dimensions.x * .22, 2.7, front + .35)
		_box("BalconySlab", balcony, Vector3(1.8, .13, .8), stone)
		for x in [-.8, 0, .8]:
			_box("BalconyRailing", balcony + Vector3(x, .4, .35), Vector3(.045, .75, .04), roof)
		_box("BalconyRail", balcony + Vector3(0, .76, .35), Vector3(1.72, .045, .05), roof)
		var cloth = _box(
			"BalconyCloth",
			balcony + Vector3(.38, .6, .37),
			Vector3(.5, .45, .02),
			_material(Color("a19a7a"))
		)
		_cloths.append(cloth)
	if _alpine:
		_pitched_roof(point, dimensions)
	var trim = _material(Color("c0b69b"))
	for floor_index in range(1, int(dimensions.y / 2)):
		_box(
			"StoneCourse",
			point + Vector3(0, floor_index * 2, 0),
			Vector3(dimensions.x + .12, .1, dimensions.z + .12),
			trim
		)
	for x in [-dimensions.x / 2 + .12, dimensions.x / 2 - .12]:
		_box(
			"CornerPier",
			point + Vector3(x, dimensions.y / 2, dimensions.z / 2 + .03),
			Vector3(.20, dimensions.y, .16),
			trim
		)


func _pitched_roof(point, dimensions):
	var width = dimensions.x / 2 + .4
	var depth = dimensions.z / 2 + .4
	var eave = dimensions.y
	var ridge = eave + 1.8
	var vertices = [
		Vector3(-width, eave, -depth),
		Vector3(width, eave, -depth),
		Vector3(-width, eave, depth),
		Vector3(width, eave, depth),
		Vector3(0, ridge, -depth),
		Vector3(0, ridge, depth)
	]
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 4, 2, 2, 4, 5, 1, 3, 4, 3, 5, 4, 0, 1, 4, 2, 5, 3]:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	surface.set_material(_material(Color("b8c9d0")))
	var roof = MeshInstance3D.new()
	roof.name = "SnowRoof"
	roof.mesh = surface.commit()
	roof.position = point
	add_child(roof)


func _tree(point, size_factor):
	var biome = (
		"alpine" if _alpine else ("desert" if _desert else ("coastal" if _coastal else "urban"))
	)
	var model = load("res://source/match/maps/Vegetation.gd").tree(
		biome, _tree_serial, 7.5 * maxf(1.0, size_factor)
	)
	_tree_serial += 1
	model.position = point
	model.rotation.y = point.x * .73
	add_child(model)


func _lamp(point):
	var metal = _material(Color("344046"))
	_box("StreetLamp", point + Vector3(0, 1.8, 0), Vector3(.10, 3.6, .10), metal)
	_box("LampArm", point + Vector3(.35, 3.6, 0), Vector3(.8, .12, .12), metal)
	_box("Lantern", point + Vector3(.7, 3.5, 0), Vector3(.45, .12, .3), windows)
	# Emissive lanterns are cheap; a bounded set of local lights serves the streets.
	if _lamps.size() < 10:
		var light = OmniLight3D.new()
		light.position = point + Vector3(.7, 3.2, 0)
		light.light_color = Color("ffcd8c")
		light.omni_range = 6
		light.shadow_enabled = false
		add_child(light)
		_lamps.append(light)


func _mountains():
	var desert = "Desert" in _game.settings.map_path or "Supply" in _game.settings.map_path
	for index in 9:
		var asset = (
			"desert/CanyonMesa%d" % (index % 3 + 1)
			if desert
			else "alpine/AlpineMassif" + ("A" if index % 2 else "B")
		)
		var mountain = load("res://assets/models/environment/%s.glb" % asset).instantiate()
		mountain.name = "DistantRidge"
		mountain.position = Vector3(-45 + index * 28, -1, -91 - float(index % 3) * 8)
		mountain.scale = Vector3(1.7, 1.2, 1.4)
		mountain.rotation.y = index * 1.17
		add_child(mountain)


func _population():
	var entries = []
	Catalog._add(
		entries,
		"resident",
		[[1, -3], [int(_size.x) - 1, -3], [int(_size.x) - 1, -5], [1, -5]],
		12 if _urban else 6
	)
	Catalog._add(
		entries,
		"car",
		[[-3, -65], [int(_size.x) + 3, -65], [int(_size.x) + 3, -67], [-3, -67]],
		5 if _urban else 2
	)
	Catalog._add(
		entries,
		"gull",
		[[8, -49], [int(_size.x) - 8, -49], [int(_size.x) - 8, -56], [8, -56]],
		5,
		6
	)
	Catalog._add(entries, "fox", [[3, -34], [22, -34], [22, -39], [3, -39]], 3)
	for entry in entries:
		var actor = Actor.new()
		actor.setup(entry, false)
		add_child(actor)
		actors.append(actor)


func _physics_process(_delta):
	if not _game.is_node_ready():
		return
	for cloth in _cloths:
		cloth.rotation.x = sin(_game.simulation_time * 1.6 + cloth.position.x) * .09
	# Scenic routes are outside tactical space and derive from the saved clock.
	for actor in actors:
		var speed = {"resident": .8, "car": 2.6, "gull": 3.4, "fox": 1.1}[actor.entry.kind]
		actor.travel = fposmod(
			actor.entry.start + _game.simulation_time * speed, actor.entry.length
		)
		actor.phase = fposmod(actor.entry.start + _game.simulation_time * 5, TAU)
		actor.apply_pose(true)
		actor.visible = true


func set_atmosphere(daylight, wetness):
	for material in facades:
		material.set_shader_parameter("night", 1.0 - daylight)
		material.set_shader_parameter("wetness", wetness)
	windows.emission_energy_multiplier = lerpf(2.5, .15, daylight)
	for light in _lamps:
		light.light_energy = (1.0 - daylight) * 1.4 if visible else 0.0
	river_material.set_shader_parameter("wetness", wetness)
