extends RefCounted

## Equal Raw reserves for every faction; stronger expansions reward leaving home.
## High-tech Refined Cores are manufactured via Risk-the-Batch Refining rather than mined.
const HOME_MATERIALS = 650
const EXPANSION_MATERIALS = 950
const RICH_MATERIALS = 1250
const STOCKS = {
	"home": [HOME_MATERIALS, 720],
	"expansion": [EXPANSION_MATERIALS, 1200],
	"rich": [RICH_MATERIALS, 1800]
}
