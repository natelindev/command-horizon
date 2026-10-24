extends Sprite3D

const Cache = preload("res://source/utils/RuntimeCache.gd")

## Shared, billboarded chevron textures. Depth testing and parent visibility
## keep ranks behind terrain and hidden with the owning unit in fog.
const COLORS = ["", "bd8958", "d9e3e8", "f5d879"]
var _unit


func _init(unit):
	name = "VeteranBadge"
	_unit = unit
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.014
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaded = false
	no_depth_test = false
	refresh()


func refresh():
	var textures = Cache.bucket("veteran_badge_textures")
	var rank = _unit.veterancy_rank
	visible = rank > 0
	if rank == 0:
		return
	if not textures.has(rank):
		var paths = ""
		for index in rank:
			var y = 5 + index * 9
			paths += (
				(
					'<path d="M4 %d L16 %d L28 %d" fill="none" stroke="#10171c" '
					+ 'stroke-width="7" stroke-linejoin="round"/>'
				)
				% [y + 7, y, y + 7]
			)
			paths += (
				(
					'<path d="M4 %d L16 %d L28 %d" fill="none" stroke="#%s" '
					+ 'stroke-width="3" stroke-linejoin="round"/>'
				)
				% [y + 7, y, y + 7, COLORS[rank]]
			)
		var bitmap = Image.new()
		bitmap.load_svg_from_string(
			'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="36">%s</svg>' % paths
		)
		textures[rank] = ImageTexture.create_from_image(bitmap)
	texture = textures[rank]
	var bar = _unit.get_node_or_null("HealthBar")
	position.y = bar.position.y + 0.45 if bar != null else 2.2
