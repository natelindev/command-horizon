extends RefCounted

## Shared cosmetic values, owned by the runtime cache rather than static script
## storage. Each visual retains this typed reference outside its frame loop.
var frustum_frame: int = -1
var frustum: Array = []
var headless: bool = DisplayServer.get_name() == "headless"
var budget_frame: int = -1
var pixels_per_metre: float = INF
var crowded: bool = false
