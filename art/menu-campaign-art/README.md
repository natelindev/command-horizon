# Menu and campaign artwork

Generated with the built-in `image_gen` tool. The exact sixteen prompts and
commander reference paths are recorded in [prompts.json](prompts.json).
Existing paintings and SVGs are retained; new assets use separate paths.

## Runtime assets

- `assets/ui/art/bastion-foundry-dawn.png`
- `assets/ui/art/helix-relay-night.png`
- `assets/ui/art/frontier-convoy-sunset.png`
- `assets/ui/campaign/portraits/{aegis,nyx,rook,voss,kerrigan,elias,cantor,arden,ren,ilan,wren,hask,jory}.png`

The environments join the existing hangar and river-city paintings in a five-image
gallery. Front-end backdrops choose on creation or redisplay. Both battle pause
menus choose when opened and keep the picture still. Skirmish and Campaign
restore the prior tactical pause state on closing. The gallery excludes the
previous image and uses a private
random generator so it does not affect gameplay randomness.

All 160 conversation lines and 64 authored briefing paragraphs use the painted
cast portraits. Hero selection/production art, the mission board, command-hub
header and archive transmissions share those portraits. Aegis, Nyx and Rook retain
their existing painted briefing identities. Generic radio narrators retain their
existing text presentation.

## Review

Run from the repository root with a Godot 4.7.2 executable:

```sh
Godot --path . --script tests/rendered/MenuCampaignArtPreview.gd
Godot --path . --script tests/rendered/HudConsolePreview.gd -- --console-only
Godot --headless --path . --script tests/headless/MenuArtworkRegression.gd
Godot --headless --path . --script tests/rendered/CampaignBriefingCatalogPreview.gd -- --layout-only --layout-matrix
```

The focused rendered preview writes `review/`: five main-menu backgrounds,
the complete cast, faction mission boards, briefings, archive transmissions,
live campaign dialogue and pause menus. English and Chinese samples include
150% interface scale at 1280×720. The HUD preview writes `art/hud-console/`.

All nine verification runs passed. The full briefing matrix covered 1,152
paragraph/layout cases with portraits enabled. See [verification.json](verification.json)
for exact results and asset hashes. `MenuArtRegression` also emitted shutdown
ObjectDB/resource warnings after reporting zero failures; the other final runs
were clean. A packaged export was not reviewed in this pass.
