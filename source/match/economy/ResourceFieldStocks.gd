extends RefCounted

## Equal reserves for every faction; stronger expansions reward leaving home.
const HOME_MATERIALS = 600
const EXPANSION_MATERIALS = 900
const RICH_MATERIALS = 1200
const STOCKS = {
	"home": [HOME_MATERIALS, 720],
	"expansion": [EXPANSION_MATERIALS, 1200],
	"rich": [RICH_MATERIALS, 1800]
}
