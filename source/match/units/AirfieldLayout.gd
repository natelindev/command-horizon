extends RefCounted

# Runway airfield layout in the structure's local frame (metres; x across,
# -z is the take-off direction). Shared by the airfield's flight logic and its
# model so markings always match where aircraft roll. Plain data: no
# dependencies, safe to preload anywhere.

const RUNWAY_X = -1.6
const RUNWAY_WIDTH = 2.6
const THRESHOLD_Z = 8.0
const RUNWAY_END_Z = -8.0
const TAXIWAY_X = 1.25
const TAXIWAY_WIDTH = 1.4
const STAND_X = 3.0
const STAND_Z = [-5.4, -1.8, 1.8, 5.4]
# Helicopters and drones: the faction building's own pad, and a second pad.
const TOWER_POINT = Vector3(3.0, 0, 10.7)
const PAD_POINTS = [Vector3(3.0, 0, 10.7), Vector3(3.0, 0, -10.2)]
# Landing surface height of each helipad by faction: the tower building's own
# deck, then the ground-level pad.
const PAD_HEIGHTS = {
	"bastion": [0.58, 0.08],
	"helix": [0.38, 0.08],
	"frontier": [0.18, 0.08],
}
# Rolled-out aircraft leave the runway here and taxi back along the taxiway.
const EXIT_Z = -6.5
# Local outline of the whole airfield, also its navigation obstacle.
const OUTLINE = [Vector2(-3.1, -11.6), Vector2(5.4, -11.6), Vector2(5.4, 13.1), Vector2(-3.1, 13.1)]
# Distance from a runway end to the outer approach fix aircraft fly through.
const APPROACH_DISTANCE = 20.0
# Aircraft may manoeuvre this far beyond the playable edge.
const AIRSPACE_MARGIN = 6.0


# Outer approach fixes for landings on either end, for a placed airfield.
static func approach_fixes(transform: Transform3D):
	var threshold = transform * Vector3(RUNWAY_X, 0, THRESHOLD_Z)
	var far_end = transform * Vector3(RUNWAY_X, 0, RUNWAY_END_Z)
	var direction = ((far_end - threshold) * Vector3(1, 0, 1)).normalized()
	return [threshold - direction * APPROACH_DISTANCE, far_end + direction * APPROACH_DISTANCE]


# Whether at least one landing direction has its approach inside the airspace.
static func approach_fits(transform: Transform3D, map_size: Vector2):
	for fix in approach_fixes(transform):
		if (
			fix.x > -AIRSPACE_MARGIN
			and fix.z > -AIRSPACE_MARGIN
			and fix.x < map_size.x + AIRSPACE_MARGIN
			and fix.z < map_size.y + AIRSPACE_MARGIN
		):
			return true
	return false


static func pad_height(faction, index):
	return PAD_HEIGHTS.get(faction, PAD_HEIGHTS.bastion)[index]
