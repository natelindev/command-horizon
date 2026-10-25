extends RefCounted

const Cache = preload("res://source/utils/RuntimeCache.gd")

const Factions = preload("res://source/match/FactionCatalog.gd")
const LEGEND = "● Your forces   ■ Ally   ▲ Opponent   ◆ Resources"


static func legend(game):
	return (
		LEGEND if game._get_human_player() != null else "● Viewed side   ▲ Other side   ◆ Resources"
	)


static func kind(unit, game):
	if unit.is_in_group("resource_units"):
		return "resource"
	var observer = game._get_human_player()
	if observer == null:
		observer = game.visible_player
	if unit.player == observer:
		return "own"
	return (
		"ally"
		if load("res://source/match/Players.gd").allied(unit.player, observer)
		else "opponent"
	)


static func known_now(unit, game):
	if game.restoring or unit.is_queued_for_deletion() or not unit.is_visible_in_tree():
		return false
	if unit.is_in_group("resource_units"):
		return true
	if unit.hp == null or unit.hp <= 0:
		return false
	if game.settings.visibility == game.settings.Visibility.FULL:
		return true
	for observer in game.visible_players:
		if is_instance_valid(observer) and game.battlefield.is_observed(observer, unit):
			return true
	return false


static func caption(unit, game):
	var owner = {"own": "Your forces", "ally": "Ally", "opponent": "Opponent"}.get(
		kind(unit, game), ""
	)
	if game._get_human_player() == null:
		owner = "Side %d" % (unit.player.get_index() + 1)
	elif game.get_node("Players").get_child_count() > 2:
		owner += " %d" % (unit.player.get_index() + 1)
	return "%s · %s" % [owner, Factions.NAMES.get(unit.player.faction, unit.player.faction)]


# Cache antialiased silhouettes once. Rebuilding circles/polygons for hundreds of
# minimap markers every physics tick otherwise reallocates GPU vertex/index buffers.


static func _symbol(shape):
	var symbols = Cache.bucket("ownership_symbols")
	if not symbols.has(shape):
		var geometry = {
			"own": '<circle cx="0" cy="0" r="1" fill="white"/>',
			"ally": '<rect x="-.8" y="-.8" width="1.6" height="1.6" fill="white"/>',
			"opponent": '<path d="M0,-1.15 L1,.8 L-1,.8 Z" fill="white"/>',
			"resource": '<path d="M0,-1 L1,0 L0,1 L-1,0 Z" fill="white"/>'
		}[shape]
		var image = Image.new()
		(
			image
			. load_svg_from_string(
				(
					'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="-1.25 -1.25 2.5 2.5">'
					+ geometry
					+ "</svg>"
				)
			)
		)
		symbols[shape] = ImageTexture.create_from_image(image)
	return symbols[shape]


static func paint(canvas, point, shape, radius, tint):
	var texture = _symbol(shape)
	for layer in [[radius + 1.2, Color("17202bea")], [radius, tint]]:
		var extent = Vector2.ONE * layer[0] * 1.25
		canvas.draw_texture_rect(texture, Rect2(point - extent, extent * 2), false, layer[1])
