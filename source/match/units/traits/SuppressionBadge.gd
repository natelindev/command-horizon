extends Label3D

var unit


func _init(owner_unit):
	name = "SuppressionBadge"
	unit = owner_unit
	position = Vector3(0.45, 2.15, 0)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	font_size = 32
	pixel_size = 0.014
	outline_size = 7
	modulate = Color("f0dbb7")
	no_depth_test = false
	unit.suppression.changed.connect(refresh)
	refresh()


func refresh():
	visible = unit.suppression.band > 0 and not unit.has_meta("garrison_host")
	# Distinct steady shapes remain readable without colors or flashing.
	text = "▼" if unit.suppression.band == 1 else "▼\n━"
