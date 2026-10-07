extends RefCounted

const Factions = preload("res://source/match/FactionCatalog.gd")
const LEGEND = "● Your forces   ▲ Opponent   ◆ Resources"


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
	return "own" if unit.player == observer else "opponent"


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
	var owner = "Your forces" if kind(unit, game) == "own" else "Opponent"
	if game._get_human_player() == null:
		owner = "Side %d" % (unit.player.get_index() + 1)
	elif game.get_node("Players").get_child_count() > 2:
		owner += " %d" % (unit.player.get_index() + 1)
	return "%s · %s" % [owner, Factions.NAMES.get(unit.player.faction, unit.player.faction)]


static func paint(canvas, point, shape, radius, tint):
	# Neutral backing keeps the silhouette readable against both snow and dark roads.
	if shape == "own":
		canvas.draw_circle(point, radius + 1.2, Color("17202bea"), true, -1.0, true)
		canvas.draw_circle(point, radius, tint, true, -1.0, true)
	else:
		var corners = (
			PackedVector2Array([Vector2(0, -1.15), Vector2(1, .8), Vector2(-1, .8)])
			if shape == "opponent"
			else PackedVector2Array([Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)])
		)
		var outer = PackedVector2Array()
		var inner = PackedVector2Array()
		for corner in corners:
			outer.append(point + corner * (radius + 1.2))
			inner.append(point + corner * radius)
		canvas.draw_colored_polygon(outer, Color("17202bea"))
		canvas.draw_colored_polygon(inner, tint)
