extends Node

var hud
var _markers = []


func _ready():
	var game = hud.get_parent()
	for relay in game.map.relays:
		relay._label.hide()
		var label = Label.new()
		label.text = "◆  " + tr(relay.label_title)
		label.add_theme_font_override("font", preload("res://assets/fonts/NotoSansSC.ttf"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		add_child(label)
		var marker = ColorRect.new()
		marker.size = Vector2(6, 6)
		marker.position = Vector2(relay.position.x, relay.position.z) * 2 - Vector2(3, 3)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.z_index = 2
		game.find_child("MinimapViewport").add_child(marker)
		_markers.append({"relay": relay, "label": label, "minimap": marker})


func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for marker in _markers:
			marker.label.text = "◆  " + tr(marker.relay.label_title)


func _process(_delta):
	var camera = get_viewport().get_camera_3d()
	for marker in _markers:
		var relay = marker.relay
		# Keep the locator on the capture ground, so a ground order at its center lands in range.
		var point = relay.global_position
		marker.label.position = camera.unproject_position(point) - marker.label.size * 0.5
		marker.label.visible = (
			not camera.is_position_behind(point)
			and get_viewport().get_visible_rect().encloses(marker.label.get_rect())
		)
		marker.minimap.color = (
			relay.captured_by.color if relay.captured_by != null else Color("dae3e3")
		)
