@tool
extends StyleBox

## Nine-slice style for the industrial HUD kit.
##
## Kit textures are authored at DENSITY x logical resolution and drawn at
## 1 / DENSITY scale, so bevels and bolts stay crisp at interface scales above
## 1.0 and on HiDPI displays. Slices are given in logical units.

const DENSITY = 2.0

@export var texture: Texture2D
@export var slice_left := 12.0
@export var slice_top := 12.0
@export var slice_right := 12.0
@export var slice_bottom := 12.0
## Extends drawing beyond the control rect (logical units), e.g. focus brackets.
@export var expand := 0.0
## RenderingServer.NinePatchAxisMode for the centre column: stretch, tile (bars) or
## tile-fit (rails).
@export var horizontal_mode := RenderingServer.NINE_PATCH_STRETCH
@export var draw_center := true
@export var modulate := Color.WHITE


func _draw(to_canvas_item: RID, rect: Rect2):
	if texture == null:
		return
	rect = rect.grow(expand)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	# Never let the corner slices overlap on a control smaller than the corners.
	var horizontal = minf(1.0, rect.size.x / maxf(0.001, slice_left + slice_right))
	var vertical = minf(1.0, rect.size.y / maxf(0.001, slice_top + slice_bottom))
	var top_left = Vector2(slice_left * horizontal, slice_top * vertical) * DENSITY
	var bottom_right = Vector2(slice_right * horizontal, slice_bottom * vertical) * DENSITY
	var server = RenderingServer
	server.canvas_item_add_set_transform(
		to_canvas_item, Transform2D(0.0, Vector2.ONE / DENSITY, 0.0, rect.position)
	)
	server.canvas_item_add_nine_patch(
		to_canvas_item,
		Rect2(Vector2.ZERO, rect.size * DENSITY),
		Rect2(),
		texture.get_rid(),
		top_left,
		bottom_right,
		horizontal_mode,
		RenderingServer.NINE_PATCH_STRETCH,
		draw_center,
		modulate
	)
	server.canvas_item_add_set_transform(to_canvas_item, Transform2D())


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(expand)
