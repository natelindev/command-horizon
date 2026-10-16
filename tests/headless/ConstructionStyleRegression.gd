extends "res://tests/headless/StructureActivityRegression.gd"

# Every faction builds with its own construction style, the effect follows paid
# progress, halts when builders leave, and leaves nothing behind on completion,
# cancellation or destruction.

const MAX_SITE_DRAWS = 14

var construction_visual
var _shaders = {}


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	construction_visual = load("res://source/match/effects/ConstructionVisual.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	for faction in factions.IDS:
		await _fixture(faction)
		for role in ["PowerPlant", "VehicleFactory", "AntiGroundTurret"]:
			await _style(faction, role)
		await _activity(faction)
		await _completion(faction)
		await _cancel_and_destroy(faction)
		await _reduced_flashes(faction, options)
		await _memory(faction)
		game.queue_free()
		await _frames(5)
	options.reduced_flashes = reduced
	_check(
		_shaders.values().size() == 3 and not _shaders.values().has(null),
		"Factions do not each use a construction shader"
	)
	_check(
		(
			_shaders.bastion != _shaders.helix
			and _shaders.helix != _shaders.frontier
			and _shaders.bastion != _shaders.frontier
		),
		"Factions share a construction shader"
	)
	for message in errors:
		push_error(message)
	print("Construction styles: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _site(role = "PowerPlant", point = Vector3(40, 0, 12)):
	var site = _spawn(role, point, true)
	await _frames(2)
	return site


func _style(faction, role):
	var site = await _site(role)
	var visual = site.get_node_or_null("ConstructionVisual")
	_check(visual != null, faction + ": foundation lacks a construction visual")
	if visual == null:
		return
	_check(visual.style == faction, faction + ": construction uses %s style" % visual.style)
	_check(
		visual.rig.get_script() == construction_visual.STYLES[faction].rig,
		faction + ": construction uses another faction's rig"
	)
	var shader = construction_visual.STYLES[faction].shader
	_shaders[faction] = shader
	for mesh in site.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			_check(
				material is ShaderMaterial and material.shader == shader,
				"%s %s: surface is not assembled by the faction shader" % [faction, role]
			)
			if material is ShaderMaterial:
				_check(
					(material.next_pass != null) == (faction == "helix"),
					faction + ": hologram pass belongs to Helix only"
				)
	var draws = visual.find_children("*", "GeometryInstance3D", true, false)
	_check(
		not draws.is_empty() and draws.size() <= MAX_SITE_DRAWS,
		"%s %s: rig uses %d draw nodes" % [faction, role, draws.size()]
	)
	_check(
		not visual.find_children("*", "MultiMeshInstance3D", true, false).is_empty(),
		faction + ": static rig parts are not batched"
	)
	_check(
		(
			visual.find_children("*", "GPUParticles3D", true, false).is_empty()
			and visual.find_children("*", "Light3D", true, false).is_empty()
		),
		faction + ": sites must use pooled particles and no per-site lights"
	)
	var shown = _shown(visual)
	site.construct(.5)
	_check(
		visual._materials.all(
			func(material): return is_equal_approx(material.get_shader_parameter("progress"), .5)
		),
		faction + ": assembly does not follow paid progress"
	)
	_check(is_equal_approx(visual.rig.progress, .5), faction + ": rig ignores progress")
	_check(_shown(visual) != shown, faction + ": rig does not change with progress")
	site.queue_free()
	await _frames(3)


func _shown(visual):
	# Revealed scaffold pieces and the placement of moving machinery.
	var pose = []
	for node in visual.find_children("*", "MultiMeshInstance3D", true, false):
		pose.append(node.multimesh.visible_instance_count)
	for node in visual.rig.find_children("*", "Node3D", true, false):
		pose.append(node.transform)
	return pose


func _activity(faction):
	var site = await _site()
	var visual = site.get_node("ConstructionVisual")
	for frame in 60:
		site.construct(.002)
		visual._process(1.0 / 60.0)
	_check(visual.is_worked() and visual.rig.activity > .9, faction + ": worked site looks idle")
	var work = visual.rig.work
	_check(work > 0, faction + ": machinery does not run while building")
	for frame in 120:
		visual._process(1.0 / 60.0)
	_check(
		not visual.is_worked() and visual.rig.activity == 0.0,
		faction + ": abandoned site keeps working"
	)
	work = visual.rig.work
	visual._process(.5)
	_check(visual.rig.work == work, faction + ": machinery moves without builders")
	site.queue_free()
	await _frames(3)


func _completion(faction):
	var site = await _site("VehicleFactory")
	var meshes = site.get_node("Geometry").find_children("*", "MeshInstance3D", true, false)
	var visual = weakref(site.get_node("ConstructionVisual"))
	var rig = weakref(site.get_node("ConstructionVisual").rig)
	site.construct(.4)
	site.construct(.6)
	await _frames(2)
	_check(site.is_constructed(), faction + ": site did not complete")
	_check(
		visual.get_ref() == null and rig.get_ref() == null,
		faction + ": completion leaves the construction effect"
	)
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			_check(
				not _is_construction(mesh.get_active_material(surface)),
				faction + ": completion keeps an assembly material"
			)
	_check(
		site.find_children("*", "MultiMeshInstance3D", true, false).is_empty(),
		faction + ": completed building keeps scaffold"
	)
	site.queue_free()
	await _frames(3)


func _is_construction(material):
	if not material is ShaderMaterial:
		return false
	for style in construction_visual.STYLES.values():
		if material.shader == style.shader:
			return true
	return material.shader == construction_visual.HOLOGRAM_SHADER


func _cancel_and_destroy(faction):
	var site = await _site()
	site.construct(.3)
	var visual = weakref(site.get_node("ConstructionVisual"))
	var rig = weakref(site.get_node("ConstructionVisual").rig)
	_check(site.cancel_construction(), faction + ": cancellation failed")
	await _frames(3)
	_check(
		visual.get_ref() == null and rig.get_ref() == null,
		faction + ": cancelled site leaves its effect"
	)
	site = await _site()
	site.construct(.6)
	visual = weakref(site.get_node("ConstructionVisual"))
	rig = weakref(site.get_node("ConstructionVisual").rig)
	site.hp = 0
	await _frames(3)
	_check(
		visual.get_ref() == null and rig.get_ref() == null,
		faction + ": destroyed site leaves its effect"
	)


func _reduced_flashes(faction, options):
	var site = await _site()
	var visual = site.get_node("ConstructionVisual")
	options.reduced_flashes = true
	visual.refresh()
	_check(
		(
			visual.rig.steady
			and visual._materials.all(
				func(material): return material.get_shader_parameter("steady")
			)
		),
		faction + ": reduced flashes still flicker"
	)
	options.reduced_flashes = false
	visual.refresh()
	_check(not visual.rig.steady, faction + ": flicker setting does not recover")
	site.queue_free()
	await _frames(3)


func _memory(faction):
	var site = await _site()
	site.construct(.3)
	var handler = game.find_child("UnitVisibilityHandler", true, false)
	_check(handler != null, "Missing unit visibility handler")
	if handler == null:
		site.queue_free()
		return
	handler._create_dummy_structure(site)
	var dummy = handler._structure_to_dummy_mapping[site]
	site.construct(.4)
	var remembered = []
	for mesh in dummy.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.get_surface_override_material_count():
			var material = mesh.get_surface_override_material(surface)
			if _is_construction(material):
				remembered.append(material.get_shader_parameter("progress"))
	_check(not remembered.is_empty(), faction + ": fog memory lost the construction site")
	_check(
		remembered.all(func(progress): return is_equal_approx(progress, .3)),
		faction + ": fog memory follows hidden construction progress"
	)
	handler._try_removing_dummy_structure(site)
	site.queue_free()
	await _frames(3)
