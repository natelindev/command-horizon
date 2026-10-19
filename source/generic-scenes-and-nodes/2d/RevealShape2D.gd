extends Node2D

# A fog-of-war reveal: a circle, or a triangle list (relative to this node's
# position) covering only what terrain leaves visible.
var color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var radius = 15.0:
	set(value):
		radius = value
		queue_redraw()
var triangles = PackedVector2Array():
	set(value):
		triangles = value
		queue_redraw()


func _draw():
	if triangles.size() < 3:
		draw_circle(Vector2.ZERO, radius, color)
		return
	var indices = PackedInt32Array()
	indices.resize(triangles.size())
	for index in indices.size():
		indices[index] = index
	var colors = PackedColorArray()
	colors.resize(triangles.size())
	colors.fill(color)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, triangles, colors)
