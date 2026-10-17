extends RefCounted

## Shared geometry for the industrial battle console (logical units).
##
## Top: a full-width rail with hanging plates (resources left, mission clock
## centre, system keys and alerts right). The mission column hangs below the
## resources plate. Bottom: the minimap housing (left) and command deck (right)
## sit flush in the corners, joined by a rail that carries the captions.

const TOP_RAIL = 12.0
const TOP_PLATE = 70.0
## Mission briefing and campaign objectives start here.
const COLUMN_TOP = 76.0
const COLUMN_WIDTH = 372.0
## The command deck never rises over the top plates.
const DECK_TOP_LIMIT = 84.0
const BOTTOM_RAIL = 30.0
const CONSOLE_HEIGHT = 246.0
## The empty console keeps the same footprint as the selected-unit deck.
const CLOSED_DECK_HEIGHT = CONSOLE_HEIGHT
## The minimap screen keeps a fixed height; its width follows the map's aspect.
const MINIMAP_SCREEN = 196.0
const MINIMAP_ASPECT_LIMIT = 1.25
const GAP = 8.0


static func deck_width(viewport_width: float) -> float:
	return maxf(680.0, viewport_width - (MINIMAP_SCREEN * MINIMAP_ASPECT_LIMIT + 50.0))


static func info_bay(_viewport_width: float) -> float:
	return 236.0


static func roster_columns(viewport_width: float) -> int:
	return clampi(floori((deck_width(viewport_width) - info_bay(viewport_width) - 64) / 132), 3, 8)
