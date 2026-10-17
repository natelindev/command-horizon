extends NavigationObstacle3D

@export var domain = Constants.Match.Navigation.Domain.TERRAIN
@export var path_height_offset = 0.0
@export var sight_height = 3.0

var _synchronized = false

@onready var _match = find_parent("Match")
@onready var _unit = get_parent()


func _ready():
	if affect_navigation_mesh and not _unit.is_in_group("resource_units"):
		add_to_group("sight_blockers")
		var collider = _unit.get_node_or_null("CollisionShape3D")
		if collider != null and "height" in collider.shape:
			sight_height = collider.shape.height

	# Use the same footprint for path planning and circular local avoidance.
	# This includes deposits: their old 0.2 m bake footprint admitted gaps that
	# their 0.6 m avoidance radius could not pass, stranding loaded engineers.
	if affect_navigation_mesh:
		var footprint = PackedVector3Array()
		for index in range(16):
			var angle = index * TAU / 16.0
			footprint.append(Vector3(cos(angle), 0, sin(angle)) * radius)
		vertices = footprint
	if _match.navigation == null:
		await _match.ready
	await _match.navigation.wait_until_synchronized(domain)
	set_navigation_map(_match.navigation.get_navigation_map_rid_by_domain(domain))
	_align_unit_position_to_navigation()
	_affect_navigation_if_needed()
	_synchronized = true


func _exit_tree():
	if affect_navigation_mesh:
		remove_from_group(Constants.Match.Navigation.DOMAIN_TO_GROUP_MAPPING[domain])
		MatchSignals.schedule_navigation_rebake.emit(domain)


func _align_unit_position_to_navigation():
	var aligned = (
		NavigationServer3D.map_get_closest_point(get_navigation_map(), _unit.global_position)
		- Vector3(0, path_height_offset, 0)
	)
	# Reload baking already contains these footprints. Snapping onto their edges
	# moves static objectives out of their own holes; only align elevation.
	if _match.restoring:
		aligned.x = _unit.global_position.x
		aligned.z = _unit.global_position.z
	_unit.global_position = aligned
	_unit.reset_physics_interpolation()


func _affect_navigation_if_needed():
	if affect_navigation_mesh:
		add_to_group(Constants.Match.Navigation.DOMAIN_TO_GROUP_MAPPING[domain])
		MatchSignals.schedule_navigation_rebake.emit(domain)
