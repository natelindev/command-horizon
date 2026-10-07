# Free Frontier gameplay integration — 2026-10-04

Free Frontier Coalition is selectable in skirmish with all seventeen models/icons, differentiated mobile units, paid retrofits, finite wreck salvage, Maneuver Burst and doctrine. The first six-mission campaign keeps its authored factions. This is initial functional acceptance; balance and novice/full-match acceptance remain open.

## Implemented rules

- Mobile units have 85% base health. Infantry/Drone move 20% faster; other mobile units move 10% faster. Lookout Drone gains 2 m sight. Structure rules remain shared.
- Ironback uses an 8 m heavy cannon: 18 base damage, 2.2 s interval, no preparation charge; armor multipliers are 0.35/0.9/1.3/0.8 for infantry/light/heavy/structure. Its hull receives a 1.2 visual normalization adjustment to compensate for cannon overhang. Jackal has autocannon plus 4.5 m AA on one reload.
- Conventional chips cost 2 E / 3 s at HQ/workshops and when fitted in production. UI, AI budgeting, cancellation/refunds and archive recovery use the same canonical values. Unit material/electronics prices are in `FrontierCatalog.gd`.
- In a skirmish involving Frontier, destroyed ground machines (engineers, tanks, repair/combat rigs, heavy tanks) leave floor(20% of original material price) in a 180 s wreck. No kill bounty. Only Frontier engineers can collect observed wrecks and deliver material through ordinary cargo/HQ rules. Infantry, aircraft and structures give no salvage. At most 128 wrecks survive; overflow retires the oldest. Wrecks do not obstruct rebuilding/navigation.
- Coordination enables up to six ready chipped ground combatants to gain +35% speed for 6 s, with a 25 s cohort cooldown. Rapid redeployment doctrine raises the bonus to +50%. Activation preserves manual/program orders and cannot permanently stack speed.
- Snapshot version 8 validates/restores third-faction identities, finite wreck material/lifetime, cargo, paid retrofit timers, movement windows and cooldown cohorts. Versions 1–7 retain their supported original semantics. Old numeric opponent `2` migrates explicitly to Random; new preferences store stable IDs.

## Verification

All following final runs finish successfully. No final log contains a script error. Existing navigation-readback and shutdown-only renderer/ObjectDB/resource warnings remain visible in retained logs.

| Check | Evidence |
| --- | --- |
| Actual 2 E/3 s retrofit, exact cancellation/missing-service refund, disk restore and fitted factory debit/time | [Gameplay](frontier-gameplay/gameplay.txt) |
| Maneuver eligibility, real travel, unchanged orders, exact paused archive, paid doctrine integration and expiration | [Gameplay](frontier-gameplay/gameplay.txt), [all-three-faction technology](frontier-gameplay/technology.txt) |
| Death-to-save boundary, no duplicate wreck on load, partial cargo round trip and exact HQ delivery | [Gameplay](frontier-gameplay/gameplay.txt) |
| Hidden/revealed wrecks, expiration while carrying, excluded deaths, 128 cap, rebuilding over wrecks, forged yield rejection | [Salvage adverse cases](frontier-gameplay/salvage-edges.txt) |
| Actual heavy cannon hits: 23.4 damage against armor / 6.3 against infantry; actual AA hit and range limit | [Combat](frontier-gameplay/combat.txt) |
| Nine faction pairings: paid production, construction, mobile AA, pause/results/restart; all-three-faction AI economy/attacks | [Shared skirmish](frontier-gameplay/skirmish.txt) |
| Frontier Standard home/outer economics, formation routes/retreat, moving archives, map-specific relay/air/placement boundaries | [Desert](frontier-gameplay/map-desert.txt), [Alpine](frontier-gameplay/map-alpine.txt), [Industrial](frontier-gameplay/map-industrial.txt), [Coastal](frontier-gameplay/map-coastal.txt) |
| Seven arena cases for every faction; Frontier all-role manual takeover; wrong/stale/faulting scripts fail | [Arena](frontier-gameplay/arena.txt) |
| All-three-faction arena research, actual researched hit/service rate and retained result context | [Arena research](frontier-gameplay/arena-research.txt) |
| Existing program progression/authority/service, ordinary fields, exact snapshot and original faction abilities | [Programs](frontier-gameplay/programs.txt), [fields](frontier-gameplay/resource-fields.txt), [snapshot](frontier-gameplay/snapshot.txt), [signatures](frontier-gameplay/signatures.txt) |
| All seventeen actual asset imports and editor import | [Assets](frontier-gameplay/assets.txt), [editor](frontier-gameplay/editor-import.txt) |
| Native Metal 1280×720 battle controls: Start, funded retrofit/HQ target, ability, paid doctrine/cancel, paused queued wreck target then resumed harvest | [Native controls](frontier-gameplay/native-controls.txt) |

AI observations after six simulated minutes: Bastion 8 structures / 10 produced / 4 attacks; Helix 8 / 13 / 4; Frontier 8 / 14 / 4. These prove activity in the fixture, not competitive balance or complete-match victory quality.

[Setup](../../../art/frontier/v1/controls-setup.png) · [Retrofit target](../../../art/frontier/v1/controls-retrofit-target.png) · [Paid retrofit](../../../art/frontier/v1/controls-retrofit-paid.png) · [Maneuver](../../../art/frontier/v1/controls-maneuver.png) · [Doctrine](../../../art/frontier/v1/controls-doctrine.png) · [Salvage](../../../art/frontier/v1/controls-salvage.png). Captures were visually reviewed for 720p layout and correct faction content.

## Verification corrections and limits

Several initial test failures were fixture/harness errors: the advanced-start tank already had a chip; Helix-only mode expectations accidentally included Frontier; the three-faction technology suite outgrew its prior two-faction watchdog; unrestricted headless process frames did not represent fixed simulation seconds. Final simulation regressions use `--fixed-fps 60` where frame-count timing is required. Native checks distinguish queued orders during pause from active actions after resume, and check doctrine titles on their label rather than the generic Research button.

The default native fixture selects setup options through the OptionButton signal contract, then uses viewport keyboard events for buttons and mouse events for HQ/wreck targeting. Programmatic native-popup focus was unreliable. A separate OS-level attempt could bind only the Godot project manager, despite the live test window; no user app was restarted. Consequently OS-pointer selection of the new dropdown option is not claimed. `-- --manual-menu` keeps an optional test window waiting for those three selections. Setup resolution, stable-ID persistence/Random migration, rendered content and actual launched Frontier match are covered.

An independent review identified a paused-load wreck visibility gap: wrecks initialized before saved observers and stayed hidden until resuming. The targeted regression failed before the fix and passed afterward; the full gameplay suite also passes. It checks both world and minimap visibility before resuming. The final gameplay log is retained.

Changed GDScript formatting/lint and documentation whitespace checks pass. Numerical balance and working names remain provisional. Repeated full matches against mixed strategies, novice acceptance, wheel animation, final audio/environment/platform exports and performance remain open. Performance work remains explicitly deferred.

## Reproduce

Use the repository Godot 4.6 binary. For the headless suites above:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/FrontierGameplayRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/FrontierFactionMaps.gd -- --region=coastal
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script res://tests/rendered/FrontierFactionPreview.gd
```

Substitute the named regression scripts and `desert`, `alpine`, `industrial` or `coastal` region as appropriate. Native fixtures preserve/restore options in memory and use a PID-specific preference file; normal setup preferences are not overwritten.
