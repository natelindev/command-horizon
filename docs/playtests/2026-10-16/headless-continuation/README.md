# Headless continuation — verification report

The user explicitly required continuing until the headless work is complete and
prohibited game/editor windows and rendered previews. Every Godot invocation in
this continuation uses `--headless`. No fresh GPU or rendered acceptance is claimed.

## Gameplay and integration

- All three faction campaign menus, 16 operations, hero presence/survival, tiered
  abilities, cooldowns, save/load identity and expanded progress persistence.
- Actual convoy travel after disk restoration, convoy loss, objective sequencing,
  hero proximity requirements, malformed hero/objective save rejection.
- Full Command Horizon battle through the final Spire approach; finale rules require
  the siege commander defeated, deployment guarded and Aegis at the controls.
- All eleven new operations complete in live headless battles with normal harvesting,
  paid reinforcements, hero abilities, capture, destruction and escort objectives.
- All 32 resource deposits and every objective/extraction point are reachable on each
  new campaign map.
- Helix and Frontier: six 600-second difficulty simulations, supplementing the
  prior Bastion runs. Easy/Normal/Hard first attacks occur at about 181/122/76s.
- Nine active-opponent matches (three factions × three opponent difficulties),
  360 simulated seconds each. All commanders build and attack without overspending.
  This is behavior/pacing evidence, not a claim of competitive balance from nine games.
- Additional BastionDesert and BigArena facilities, caches and landmarks pass
  opposed-start path-distance, collision, sight, clearance and archive checks.
- Movement, Lua, animation and combat checks after CPU optimization. The old desert
  crowd fixture's fixed deposit count was updated to include authored salvage;
  restored counts are still compared against the actual pre-save population.

## CPU measurements

Same debug Godot 4.6 executable, headless real time, 200 mobile units, 80 structures,
200 Lua VMs. Other agent-owned simulation/audio jobs were suspended for these runs
and resumed in a `finally` block. Logs retain engine metrics and OS peak memory.

| Run | Movement wall seconds | Combat wall seconds |
| --- | ---: | ---: |
| Before | 13.75 | 15.77 |
| Typed math/spatial loops | 13.29 | 15.41 |
| Render-frame visual posing | 12.89 | 13.55 |
| Flat-terrain projection index | 10.60 | 12.22 |
| Final integrated code, including contact recovery | 10.67 | 12.36 |

Each phase advances about ten simulated seconds. The render-frame run also includes
three seconds of native sampling and is diagnostic. The final maximum-load debug run
still exceeds real time; these are CPU throughput measurements, not rendered FPS.
The final run peaks at 426.8 MiB RSS and keeps all 200 Lua VMs active.
All 200 units moved and travelled. The terrain index matched 13,500 native projection
queries over three maps and before/after navigation rebakes. Muzzle alignment remains
synchronous at firing, and animation gameplay-invariance tests pass.

## Regression findings

- The original crowded-destination fixture completed its Move, then aggressive idle
  acquisition started a separate enemy pursuit. Hold Fire now isolates the archived
  movement command; arrival, treatment, distance and no-teleport assertions remain.
- The captured worker approach also failed with original CPU/navigation code and
  original map decorations. Two offset rows of workers needed two turns around the
  crowd, while contact recovery searched only one turn. A bounded 48-point fallback
  now finds a clear two-turn route after the cheaper approaches fail. Three replays
  leave the blocked face within four seconds and collect at 7.17 seconds, preserving
  finite stock, unit clearance, movement speed and disk-restored detours.
- The older isolated-factory navigation fixture placed its destination inside an
  authored settlement. Its route was moved to open ground and now checks the
  destination's native navmesh projection before exercising factory avoidance.
- The map population fixture now compares restored resources with the actual pre-save
  population, including new authored caches.

## Campaign audio and dialogue

All 160 English recordings across 13 distinct characters are installed as 96 conversations
for the 16 campaign slots. The final independent audit decodes the shipped Ogg files,
transcribes them, measures their mix and checks speaker identity. It reports **160/160
passing**, zero word error after the documented spelling/homophone/number normalization,
zero failed identities, maximum cross-speaker similarity 0.4204, and integrated loudness
from −16.42 to −15.99 LUFS. Total recorded dialogue is 8.33 minutes. Hashes in
`art/audio/campaign-audio-verification.json` identify the exact audited assets.

The generator now performs speech QC after Ogg encoding, retaining the accepted bytes.
This closes a discrepancy between pre-codec acceptance and the actual shipped recording.
The 12 audio unit tests include normalization and rejection of missing/wrong words.
Human listening remains separate from these automated measurements.

Thirteen portraits load as textures. Portrait/name display remains visible with captions
off; English/Chinese text follows the subtitle option without interrupting speech. The
layout regression checks every character's longest line across three factions, two
languages, two scales and both caption states, including a 26-point font at 1280×720.
Dialogue saves preserve active speaker, audio position and queued scenes; legacy
single-narrator and history-only saves still load. Briefing duration sums the actual
recordings rather than multiplying the first line's length.

The final installed-content run passes all 14 suites: CampaignStory, CampaignDialogue,
CampaignStoryMissions, CampaignPortraitLayout, HeroCampaign, HeroCampaignRoutes,
HeroCampaignMenu, CampaignControls, ChineseUI, Localization, MenuConsole,
BattleHudProduction, Speech and CombatAudio. The all-mission check covers the 16 current
slots plus legacy Air Corridor. Subsequent Music/CampaignStory/CampaignDialogue/CombatAudio
checks also pass after removing redundant volume updates for settled music tracks.

## Campaign loading and memory

All 16 missions reached navigation readiness in one sequential headless run with a warm
filesystem. Individual loads were 214–4165 ms; the newly shared HeroTheater operations
loaded in roughly 277–314 ms. First Supply Line was about 3000 ms, Split Signal 4165 ms,
Command Horizon 3160 ms, Broken Foundry 1572 ms and First Orders 214 ms.

OS peak RSS was 355.1 MiB. Peak Godot static memory was 153.33 MiB; static memory after
closing successive missions rose with resource caches and settled around 95.7 MiB.
This run shows no continuing growth at the end; it is not a long-duration memory-leak proof.
See `campaign-load-results.json` and `campaign-load-final.txt`.

## macOS package

The universal release export includes both arm64 and x86_64 Lua libraries. Runtime checks
run on this arm64 Mac; x86_64, Linux and Windows runtime behavior is not verified here.
The local artifact is `build/Open RTS-headless-verified.zip` (ad-hoc signed, not notarized).

The official release template rejects `--main-pack` and ignores `--script`, so passing
those flags is not a valid regression test. Six tests instead run with the test-capable
Godot 4.6 executable against the **exported PCK**, from an isolated temporary directory
containing only copies of the package's native libraries: CampaignStory,
CampaignDialogue, CampaignPortraitLayout, HeroCampaign, LuaSandbox and LuaProgram.
All six pass without script errors. No source checkout is available as a resource fallback.
The actual release executable also boots its own bundled pack headlessly. Its ad-hoc
signature passes `codesign --verify --deep --strict`; the ZIP checksum is recorded in
`package-artifact.json`.

An initial uncapped menu run crashed after 108.5 seconds in Godot's dummy-audio thread
(`AudioServer::thread_find_bus_index`). The release template had ignored the requested
test script. A separate 180.9-second, 60-FPS headless menu run passed before the follow-up
change. Inspection found MusicDirector resending settled volume values on every frame;
these redundant audio-thread updates are now skipped, while fades and switching retain
their behavior. Music, campaign story/dialogue and combat-audio regressions pass. This
is a targeted reduction of unnecessary mixer updates, not a claim that every possible
Godot audio-thread fault has been fixed. The rebuilt release completed **40 million
uncapped fixed-step frames in 173.1 wall seconds**, beyond the original failure window,
and exited successfully. The six exported-resource checks also pass against this final
package. See `package-final-soak-results.json` and `package-results.json`.

## Evidence and remaining acceptance

`passing-suites.json` indexes passing runs for 59 distinct suites.
`headless-results.json` retains individual attempts, including failed fixtures and
reruns; a historical failure is not silently removed. The corrected cases are Navigation
(`corrections-check`), ContactApproach (`contact-approach-final`), CrowdedDestination
(`crowded-destination-final`), FrontierCrowd (`followup-checks`), CombatJuice
(`motion-checks`), HeroCampaignMenu (`corrections-check` and final runtime), and
CommandHorizonRules (`finale-rules-final`). ExpandedMap's exhaustive three-map/three-faction
run also passes (944 seconds).

CI's `gdformat --check source/` and `gdlint source/` pass, as does `git diff --check`.
Some passing Godot tests print ObjectDB/resource/DummyShader shutdown warnings; these
runs are not claimed to have clean stderr. Audio playback resources retained at engine
shutdown remain visible in verbose logs.

The work that still needs a different verification mode is rendered HUD/menu/portrait
and animation review, GPU/frame-rate profiling, and human play/listening acceptance.
No game/editor window or rendered preview was launched during this continuation.
