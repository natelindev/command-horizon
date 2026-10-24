# Battlefield polish verification

The current v19 macOS package passes all **75 registered suites**, strict/deep
code-signature verification and source/ZIP/PCK/executable immutability checks.
The [current package report](../2026-10-24/final-macos-packaged.json) retains every
raw log and known direct-quit test teardown warning. Five additional affected research/save suites also pass against the same PCK.
Four native foreground timing runs of the same production source pass the working
budgets, with no frame over 50 ms among 4,557 unique sampled gameplay frames.
Native menu → skirmish → F5 save → archive load → paused restore → resume → Cmd-Q
also passes in an isolated, locally signed copy containing the exact current PCK.
The original release artifacts and all 56 pre-existing user-data files remain
unchanged. See the [native report](../2026-10-24/native-final-smoke-071518/result.json).
Windows work is explicitly deferred in
[WINDOWS_HANDOFF.md](../2026-10-24/WINDOWS_HANDOFF.md).

## Implemented behavior

- The default skirmish camera starts at size 24 (previously 28). Ground scan
  contrast fades with screen footprint at tactical zoom, preserving close detail.
  Generated faction HUD frames have softer highlights and secondary text has
  stronger contrast.
- Damage bars retain a brief damage chunk before decaying. Material flashes,
  faction selection shapes, heavy shockwaves and sustained burning wreck effects
  have bounded lifetimes/counts and honor reduced-flash presentation.
- Tab cycles a mixed army through its unit classes and back to the full selection.
  P starts a patrol; Shift queues it. Resource rallies dispatch engineers to
  gathering and friendly-unit rallies follow that unit. A lost target retains
  its last known rally point.
- Tanks, heavy tanks and convoy trucks accelerate over roughly a third of a
  second and brake at the final waypoint. Turns, crowd collision and explicit
  Stop keep immediate control; intermediate route corners do not cause braking.
- Bronze, Silver and Gold are earned at 100/300/600 experience. A unit earns
  100 experience for damage equal to an enemy's maximum health, plus 25 for
  the killing blow. Overkill, friendly damage and neutral scenery grant none.
  Only surviving armed mobile units earn experience. Ranks reduce reload time
  by 4/8/12% and increase movement speed by 3/6/9%, with no damage/health bonus.
- Authored walkable plateau tops extend ground-unit vision by 20% (maximum 3 m).
  They extend weapon range by 10% (maximum 1.5 m) only against ground targets
  at least 1.5 m lower. Sloping shoulders, ramps, bridges, water, scenery and
  aircraft do not grant the bonus; terrain obstruction, allied spotting and
  line-of-fire rules remain.
  The selection range ring shows guaranteed range; the tooltip explains the
  conditional high-ground benefit.
- Observable combat smoothly brings in synchronized music percussion. A visible
  enemy HQ collapse has a 2.5-second camera/slow-motion beat; input, pause,
  reduced-motion settings, save/load and scene changes restore normal control.
  The 60-second HQ rebuild grace still decides victory. Final results offer a
  frozen, fully revealed battlefield inspection with a return-to-results action.
- Music yields 3 dB to speech with a 150 ms attack and 600 ms recovery. Aircraft
  cannon, missiles and mobile anti-air use their actual weapon's cue; bomb release
  is quiet and a damaging detonation retains its heavy impact. Existing pooled
  combat voices, local event merging, priority stealing and destruction ducking
  preserve room for major impacts and warnings.
- First Orders gives one practical hint based on current state: keeping gatherers
  working, production costs/power, direct-order authority, attack-move versus
  retreat, recovery of wounded troops, and reinforcement during a hold.
  Required instructions appear first; optional hints follow. Missing armor now
  leads to vehicle-factory production or its engineer/HQ recovery steps. The
  scrolling body reserves room for the minimap and command deck at 720p and 150%
  interface scale. Invalid structure placement has a compact, localized panel
  beside the blueprint; readable text scales with the interface and stays inside
  the viewport without intercepting placement input.
- The audited cross-shaped UI emblems now use wrenches, chevrons, separate bars
  and open target brackets. Repair-site markers and legends match as S in English
  and 修 in Chinese. The Bastion HQ roof uses a rectangular communications panel;
  repair buildings and the repair robot use service gears, regenerated from their
  Blender source scripts. This review concerns decorative symbols, with ordinary
  structural braces, arithmetic and names unchanged.
- Unit-attached information text now appears only with the existing F1 diagnostic
  overlay. Weapon modes, signatures, charge/lock/deployment, action captions,
  garrison status and commander names start hidden in every match and refresh
  when diagnostics is enabled, including while paused. Health bars, rank
  chevrons, selection indicators, weapon effects, HUD controls and fixed
  map-site/objective labels remain visible under their normal gameplay rules.
- Research upgrades and Coordination use one prepaid queue, with ordered jobs,
  cancellation/refunds and prerequisite handling in both research interfaces.
  Save/load preserves the queue and its reserved resources.
- Actual elimination produces a short announcement and a persistent commander
  status. Losing an HQ still allows the existing 60-second rebuild period.
- First-use hit-flash, ground-scar and shockwave rendering is prepared under the
  loading screen without advancing simulation or changing gameplay/cosmetic state.
  Cancelled restoration disposes of its provisional match.

## Save contract

Snapshot version 19 records veterancy, patrol state and prepaid queued research.
The initial v17→v18 conversion added zero experience while preserving existing
values and IDs. The later v18→v19 conversion adds an empty research queue per
player, again preserving all prior values and IDs. All 810 supported saves in
`docs/playtests/` and `tests/fixtures/` pass `ArchivedSnapshotRegression.gd`, which
also checks their 389 recorded checksums.

The 2026-10-24 cleanup removed all 927 identified obsolete snapshots: eight v9
Air Corridor archives, 818 temporary backups and 98 local battle/test saves,
including three incompatible macOS checkpoint slots, plus three v13 Windows
checkpoint slots. All were older than v18 and had verified storage checksums.
The 810 current fixtures remain; campaign progress
and preferences are untouched. The archive regression no longer exempts old
versions. See [cleanup manifest](obsolete-saves-cleanup.json) for the paths,
versions and hashes. All 389 recorded snapshot hashes in `SHA256SUMS` files
were refreshed for the converted archives and are now checked by the regression.
The later queue conversion's 810 temporary v18 copies were removed after all
current archives passed validation. The isolated native prewarm UI's owned v18
quicksave was also removed; its byte-identical historical text evidence remains.
See the [queue conversion](../2026-10-24/research-queue-archive-conversion.json)
and [owned-slot cleanup](../2026-10-24/combat-prewarm-ui/owned-save-cleanup.json).
There is no runtime migration code.

## Automated and rendered checks

All checks below use Godot 4.7.2 stable official (`ed1daf0bf`).
The focused source-tree/rendered checks below were supplemented by the earlier macOS
exported-package baseline: all 73 then-registered suites passed, including
PlacementFeedbackRegression and UnitInfoTextRegression. That baseline package then
incorporated two locale-dependent fixture corrections. Those two suites passed
again under English and Chinese; 71 unchanged results were carried forward for that baseline. Exactly two
of 5,594 packed resources changed, both compiled test fixtures. Native startup/quit
and code-signature checks pass on the refreshed package; this was selective
revalidation, not a second full-suite run.

- StrategicPolishRegression: normalized damage/kill experience, no overkill or
  friendly-fire rewards, noncompounding bonuses, rank decrease/reset, saved ranks,
  Fighter/Bomber cruise and per-store reload bonuses, automatic targeting,
  high-ground fog radii, ramp/air exclusions and smooth-shoulder exclusions.
- MicroControlsRegression, DirectOrdersRegression, KeyBindingsRegression,
  SelectionRosterRegression, RallyRetargetRegression and RallyControlsRegression:
  subgroups, patrol/queues/Skip, binding focus, contextual rallies and lost targets.
- GroundVehicleMotionRegression and MixedArmyMovementRegression: acceleration,
  final braking, intermediate-velocity save/load, reverse/queued orders and Stop;
  all 20 mixed units advance and retreat without stranding. Traversal changes
  from 26.7/22.7 seconds to 27.8/23.7 seconds in that fixture.
- Navigation, GroundCrowdRecovery, ExitClearance, CrowdedDestination,
  AttackMoveArrival and FrontierCrowd regressions passed.
- CombatRegression, TerrainSightRegression, SaveRestoreRegression,
  OpeningGuidanceRegression, RichTexturesRegression, LocalizationRegression,
  WeaponModeRegression and FixedWingFlightRegression passed. The terrain-sight
  fixture reports zero disagreements in each of seven 420-point fog comparisons.
- ArchivedSnapshotRegression: 810 current archives checked, zero failures;
  every retained archive must pass the current schema.
- Combat presentation and material tests passed, including 344 models and 7,323
  material surfaces. New effects honor reduced-flash settings and count caps.
  Pixel/color caching and hit-material reuse preserve the images while avoiding
  redundant uploads/allocations; regression checks cover subpixel damage, color
  thresholds, mesh replacement, fog visibility and disposal.
- MusicRegression, CombatAudioRegression and EndgamePresentationRegression pass
  with clean shutdown. Checks cover synchronized layer changes, actual projectile
  presentation, speech ducking/recovery, pause/mute/scene changes, cinematic
  cancellation/save/load/restart, fog disclosure and frozen result inspection.
- Initial native rendered reviews passed: faction HUDs (126 captures), four
  terrain maps (36), combat presentation (8), strategy/onboarding (8), and endgame (6).
- The 2026-10-24 onboarding follow-up passed the actual menu/control flow with
  11 captures, then separately verified six English/Chinese lesson views at exact
  1280×720 and 150% interface scale. Required instructions remain above the fold;
  missing-tank recovery selects a completed vehicle factory. Placement feedback
  passed a focused regression and three native captures at 1080p/100% English
  and 720p/150% English/Chinese. Earlier flow images retain the old tiny placement
  label; the later placement captures document its replacement.
- Native CoreAudio review recorded 15 bus WAVs across the three factions with
  zero clipped samples. Unprompted speech recognition matched the base warning
  in all three mixed excerpts and three isolated Voice controls, with zero word
  errors. This is one moderate battle mix per faction, not subjective listening
  or maximum-population audio acceptance. See [audio/onboarding evidence](AUDIO_ONBOARDING.md).
- Localization was regenerated from TSV sources (2,266 entries after the queue and
  commander-status follow-up). Changed GDScript
  files pass formatting/lint checks and the repository diff passes whitespace checks.
- The final neutral-symbol review inspected all 45 UI SVGs and passed 14 native
  UI captures at exact 1280×720/150%: orders and research for all three factions in
  English/Chinese, plus both map legends. Runtime 16 px command glyphs and 40 px
  cursors remain legible. LocalizationRegression, 12 required weathering captures,
  RichTexturesRegression and nine close/front/rear model views all pass without
  diagnostics. The [retained audit record](../2026-10-24/symbol-review/README.md)
  contains summaries, logs and hashes; capture PNGs remain local.
- UnitInfoTextRegression passes hidden-state changes, real F1 input while paused,
  current-state refresh, newly spawned units, repeated toggles, inherited unit
  visibility and the default-off state in a new match. Six native English/Chinese
  captures at exact 1280×720/150% reproduce the reported repeated Precision text
  near Water Stop Camp: ordinary play, diagnostics enabled, and ordinary play
  restored. All were visually reviewed. WeaponModeRegression and
  PreparationRegression also pass. The latter now tests the restored caption
  under diagnostics and waits for the actual shared-reload deadline before
  requiring an immediate Interception shot; weapon behavior is unchanged.
  See the [retained review, captures and logs](../2026-10-24/unit-info-review/README.md).

Local captures are under `art/hud-console/`, `art/terrain-layers/`,
`art/combat-presentation/`, `art/strategic-polish/` and
`art/endgame-presentation/`; the neutral-symbol review uses `art/symbol-review/`
and `art/weathering/`. Unit-caption captures also remain under
`art/unit-info-review/`. Final coordinating logs use `tmp/polish-*.log`.
The earlier sustained-combat particle-shader/RID shutdown warning is fixed.
The follow-up [native combat log](../2026-10-24/lifecycle-review/native-combat.log)
has 10 captures, including active harvesting sparks and resource-depletion
particles, zero failures and no exit diagnostics. The
[menu preview](../2026-10-24/lifecycle-review/native-menus.log),
[window-close harness with active audio](../2026-10-24/lifecycle-review/native-window-close.log),
[cache lifecycle](../2026-10-24/lifecycle-review/cache-release-rebuild.log) and
[Set lifecycle](../2026-10-24/lifecycle-review/set-release-rebuild.log) checks also
exit cleanly. Normal-app Cmd-Q on the prior exported build also passed: exit 0
with no ObjectDB, resource or RID teardown diagnostics. Its
[verbose log](../2026-10-24/lifecycle-review/normal-app-quit.log) contains two
RGB8-to-RGBA8 texture-format conversion warnings during startup; the shutdown
itself is clean. The full-suite baseline export, including all symbol,
unit-caption and CPU changes, passed all 73 registered packaged suites and strict
deep code-signature verification. Its native main menu → Alpine Relay skirmish → Cmd-Q check exited 0
with no script errors or ObjectDB/resource/RID leaks. Seven Metal texture-format
conversion warnings remain in the verbose startup/game log and are explicitly
recorded. Source, ZIP and PCK hashes stayed unchanged through that verification.
The [preserved full-suite record](../2026-10-24/macos-full-suite-baseline.json)
retains its 79 text logs. The later fixture-only refresh passed four focused
English/Chinese runs, strict signature verification and native main-menu → Cmd-Q
with a clean exit; its verbose startup log retains two Metal format conversions.
The engine binaries are identical after removing signatures from temporary
comparison copies. The [preserved fixture-refresh report](../2026-10-24/macos-package-v19/previous-final-macos-packaged.json)
and [historical artifact remapping](../2026-10-24/macos-package-v19/previous-release-preservation.json)
records exact package identities, packed-resource equivalence, 71 carried-forward
results and two revalidated suites. All package test logs are retained in the repository.

The restored fog-memory material error is resolved: live and restored memories
detach surface-material overrides before mesh deletion. Three headless
FixedWingSaveRegression repeats, SaveRestoreEdges, ConstructionStyleRegression
and the complete native Metal landing scenario pass the affected material and
rendering checks. The native landing harness retains its known direct-quit
audio teardown warnings; this is separate from the material fix. The
[material-lifetime evidence](../2026-10-24/material-memory-lifetime.json)
records the original failure, controls, fix and verification scope.

Some older direct-quit headless harnesses still report ObjectDB/resource warnings.
The exported startup smoke using `--quit-after 120` retained four Ogg-related
objects, including two menu-music resources, at forced shutdown; the
[engine's frame-limit exit](https://github.com/godotengine/godot/blob/ed1daf0bf/main/main.cpp#L4777-L4782)
bypasses the application's audio-drain path. That log is not warning-free.
The initial packaged NavigationRegression run reached only 11 of 12 crowded
tanks. The final macOS package and subsequent source runs reach 12 of 12, but the
intermittent failure's cause remains unresolved and is retained as an open
finding; a passing repeat is not evidence of a specific fix. The
[bounded navigation audit](../2026-10-24/navigation-intermittent-audit.json)
records 42 passing crowd checks in the retained rerun corpus and at least 13
simulation seconds of margin in instrumented runs. The original active tank was
5.84 m short, so the deadline and arrival tolerance were not relaxed. Failure-only
snapshot capture is retained for a future deterministic reproduction.

The current v19 release measurements use full-resolution 1920×1080 rendering
and independently verified native foreground ownership. Ordinary 70-unit combat
p95 is 14.95 / 16.53 ms (16.7 target); 200-mobile/80-structure combat p95 is
28.57 / 30.70 ms (33.3 target). Both fresh-game-cache and repeat-process runs
pass. Across all four runs, including ordinary warm-up, 4,557 unique frames have
a 40.50 ms maximum and none over 50 ms. Production effect preparation preserves
paused snapshot/cosmetic state and node/process-mode state. Its helper-only cost
is 1,653.54 / 154.03 ms for ordinary play and 1,702.39 / 564.21 ms for stress;
these exclude fixture preparation and are not full loading times. The
[current performance summary](../2026-10-24/macos-current-v19-performance.json)
retains all accepted runs, the rejected early stress baseline, hash-method
correction and exact source/artifact provenance. OS/driver caches were not reset.

Earlier baseline results and the one-second first-use stalls that motivated
loading-time preparation remain historical evidence in [PERFORMANCE.md](PERFORMANCE.md).
The latest movement/query optimizations are included in these final Mac runs;
their individual performance contribution is not isolated. The clean historical
Windows foreground result remains 36.80 ms stress combat p95, above 33.3 ms.
Windows work is explicitly deferred, including the reported four-player FFA case;
the [handoff](../2026-10-24/WINDOWS_HANDOFF.md) records the remaining work.
Two runs per workload on one Mac do not establish physical input latency,
long-match performance or all-platform acceptance.

The final native app check exercises the main menu, loading into a skirmish,
F1 both running and paused, F5 save, archive loading, paused restoration, resumed
time advancement and Cmd-Q. The current PCK is unchanged; only an isolated
user-directory override and local signature distinguish the test copy. Its game
log has no errors or warnings, and the original user files and release artifacts
retain their hashes. The F1 diagnostic overlay's top performance lines overlap
the HUD rail; this existing diagnostic-layout limitation is retained in the
[native report](../2026-10-24/native-final-smoke-071518/result.json).

## Live-match follow-up — 2026-10-24

Technology upgrades now share a prepaid FIFO queue with Coordination. Both the
selected lab and Tech panel show ordered jobs and cancellation controls. Removing
a prerequisite refunds its dependent queued jobs; independent jobs remain.
Lab loss pauses paid research until rebuilding. Snapshot v19 preserves active and
queued work without another charge. All 810 supported archives validate after
conversion, with unchanged prior values/IDs and 389 refreshed checksums; the
810 obsolete temporary conversion copies were removed after verification.
Focused payment/refund, ordering, lab recovery, pause, disk and malformed-state
checks pass. The initial UI review found a freed-button audio callback; deferred
row deletion fixes it and the affected six-case regression passes. A further
[native rendered UI matrix](../2026-10-24/research-queue-ui/result.json) passes
six faction/language cases and 18 captures at 720p/150%, using actual Viewport GUI
keyboard events. It covers queue purchases, focus/scroll, prerequisite cancellation,
exact refunds, pause ownership and translated controls/accessibility.

Actual player elimination now updates a persistent commander list and a brief
announcement. HQ destruction alone leaves the player in battle through the
existing rebuild grace. Tests cover rebuilding, actual expiry/empty-army defeat,
single notification, paused/restored status and keyboard access to eight players.
[Native all-faction English/Chinese review](../2026-10-24/commander-elimination/summary.json)
passes 12 cases/30 captures at 720p/150%, including large resource balances.
The current v19 package passes all 75 registered suites plus five additional
affected research/save suites, with unchanged source and artifact hashes.

The actual restore-cancellation test reproduced a provisional battle remaining
attached after a scene replacement during prewarming. The restorer now frees that
specific cancelled battle and retains the replacement scene's pause state. The
[before/after test](../2026-10-24/restore-prewarm-cancellation/result.json) fails
against the original restorer and passes the fix without Godot script errors or
regression failures. The raw native launch logs retain a macOS sandbox-extension
notice, classified separately in the report.

The user clarified that four-player FFA felt slow because of low frame rate,
then explicitly deferred Windows work. The two-player benchmarks do not validate
that scenario. [WINDOWS_HANDOFF.md](../2026-10-24/WINDOWS_HANDOFF.md) retains the
recovered setup, preserved player data, unfinished fixture and remaining work.

## Participant acceptance protocol

Recruit five people who have not played this build. Observe each independently;
do not explain a control until they ask or remain stuck for 60 seconds. Record
build revision, resolution, interface scale, prior RTS experience and input device.

1. Start First Orders without instructions. Ask the participant to establish
   production while keeping income running. Record time to their first useful
   command and every resource/power/production misunderstanding.
2. Ask them to send mixed troops to the objective, then retreat from a threatened
   position. Observe whether they distinguish Move, Attack move and Hold position.
3. Ask them to select one unit class without losing track of the rest of the army,
   then set and interrupt a patrol. Observe discoverability of Tab/P and whether
   direct orders behave as expected.
4. Damage a veteran and ask how they would preserve it. Observe whether they
   understand the health chunk, rank, recovery action and available repair service.
5. Ask them to capture/hold the relay, reinforce, and inspect the final battlefield.
   Record objective comprehension, alert overload, perceived audiovisual impact
   and any loss of camera/control confidence.

After each session, ask which three moments felt unclear or unresponsive. Count
unassisted task completions, wrong-command incidents, requests for help and
time-to-recovery; retain quotes without treating five participants as a balance
study. Fix recurring friction, then repeat the affected task with new participants.

Five novice sessions, subjective listening and physical input-to-photon latency
remain unverified. Windows platform work is explicitly deferred at the user’s request, with final acceptance still pending. Scripted UI review and speech recognition are
documented separately and do not substitute for participant acceptance.
