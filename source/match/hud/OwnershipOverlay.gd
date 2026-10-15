extends Control

const Ownership = preload("res://source/match/hud/Ownership.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
var game
var _pointer = null


func _ready():
	name = "OwnershipOverlay"
	game = find_parent("Match")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _notification(what):
	if what == NOTIFICATION_DISABLED:
		_pointer = null


func _process(_delta):
	queue_redraw()


func _input(event):
	if event is InputEventMouseMotion:
		_pointer = event.position


func _hovered_unit(camera):
	if _pointer == null or get_viewport().gui_get_hovered_control() != null:
		return null
	var origin = camera.project_ray_origin(_pointer)
	var query = PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(_pointer) * 1000, 7
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider")


func _draw():
	# Selection uses the player-colored ground outline; keep this layer for hover cards.
	var card = hover_card()
	if card.is_empty():
		return
	var font = get_theme_default_font()
	var background = StyleBoxFlat.new()
	background.bg_color = Color("17202bf2")
	background.set_corner_radius_all(4)
	draw_style_box(background, card.rect)
	for index in card.lines.size():
		draw_string(
			font,
			card.rect.position + Vector2(8, font.get_ascent(15) + 4 + index * 20),
			card.lines[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15,
			Color("eef1f1")
		)


func hover_card():
	var camera = get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(game) or game.restoring:
		return {}
	var target = _hovered_unit(camera)
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return {}
	var lines = []
	var position_3d = target.global_position + Vector3.UP
	if target.is_in_group("resource_units"):
		if not _resource_known(target):
			return {}
		lines = _resource_lines(target)
	elif target.is_in_group("units"):
		if not Globals.options.ownership_symbols or not Ownership.known_now(target, game):
			return {}
		lines = [Ownership.caption(target, game)]
		var health = target.get_node_or_null("HealthBar")
		position_3d = (
			health.global_position if health != null else target.global_position + Vector3.UP * 2
		)
	if lines.is_empty() or camera.is_position_behind(position_3d):
		return {}
	var font = get_theme_default_font()
	lines = lines.map(func(line): return tr(line))
	var width = 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	var point = camera.unproject_position(position_3d) + Vector2(0, -12)
	var rect = caption_rect(point, Vector2(width + 16, lines.size() * 20 + 8))
	return {"unit": target, "lines": lines, "rect": rect} if rect.has_area() else {}


func _resource_known(resource):
	if not resource.is_visible_in_tree():
		return false
	if game.settings.visibility == game.settings.Visibility.FULL:
		return true
	return game.visible_players.any(func(side): return game.battlefield.is_observed(side, resource))


func _resource_lines(resource):
	if resource.is_in_group("salvage_wrecks"):
		var seconds = ceili(resource.salvage_left)
		var human = game._get_human_player()
		return [
			"Wreck · " + Factions.title(resource.wreck_faction, resource.wreck_role),
			"%d M · expires in %d:%02d" % [resource.resource_a, seconds / 60, seconds % 60],
			(
				"Right-click with engineers to recover materials."
				if human != null and human.faction == "frontier"
				else "Only Frontier engineers can salvage wrecks."
			)
		]
	var materials = "resource_a" in resource
	return [
		(
			"Materials · %d M" % resource.resource_a
			if materials
			else "Electronics · %d E" % resource.resource_b
		),
		"%d work slots · right-click with engineers." % Harvest.WORK_SLOTS
	]


func caption_rect(point, dimensions):
	var occupied = []
	for node_name in ["UnitMenus", "Minimap", "Resources"]:
		var control = game.find_child(node_name)
		if control is Control and control.is_visible_in_tree():
			occupied.append(control.get_global_rect().grow(6))
	if "hud" in game and is_instance_valid(game.hud):
		for control in game.hud.get_children():
			if control is Control and control.is_visible_in_tree():
				occupied.append(control.get_global_rect().grow(6))
	if game.subtitles != null and game.subtitles._card.is_visible_in_tree():
		occupied.append(game.subtitles._card.get_global_rect().grow(6))
	var viewport = get_viewport_rect().grow(-4)
	for y in [point.y - dimensions.y - 10, point.y + 12]:
		for x in [point.x - dimensions.x / 2, point.x - dimensions.x, point.x]:
			var rect = Rect2(
				Vector2(clampf(x, 4, maxf(4, viewport.end.x - dimensions.x)), y), dimensions
			)
			if (
				viewport.encloses(rect)
				and not occupied.any(func(block): return block.intersects(rect))
			):
				return rect
	return Rect2()
