# Game polish acceptance — 2026-10-19

Implemented the six approved areas while preserving the existing uncommitted
command-reliability and neutral-site work. Local implementation and automated
review are complete. Fresh Windows measurements and observation of unfamiliar
players remain outstanding; neither is implied by these local results.

## Delivered behavior

1. **HUD:** no empty selection deck; populated panels fit their content within a
   128–246 logical-pixel budget. The skirmish objective is compact. Campaign
   notices retain stable control positions. Existing faction textures are unchanged.
2. **Commands:** contextual cursors share the actual right-click resolver. Accepted,
   queued and rejected orders show grouped destination feedback with text, shapes
   and existing UI audio. Rejections explain queue capacity or invalid targeting.
   The persistent Attack behavior is labeled Auto-engage. Zoom eases around the
   pointer and respects map bounds and direct camera jumps.
3. **World:** each structure has a static terrain-fitting foundation with faction
   paving and worn approaches. Infantry specialists have stronger equipment
   silhouettes. The decoration adds no collision or per-frame script and follows
   the owning unit's visibility.
4. **Combat:** shell impacts are compact and directional; ordinary missile hits
   produce less debris. Destruction keeps the larger burst and briefly lowers
   weapon audio by 3.5 dB. Infantry, heavy weapons and destruction have distinct
   audio priorities. Damage and weapon timing are unchanged.
5. **Performance:** cached ambient route lookup and reduced walker pose overhead;
   matched Mac combat mean frame time improves 4.3–5.5%. Native release stress and
   command-response probes pass. See the [performance report](../../performance/GAME_POLISH.md).
6. **Opening missions:** First Orders follows actual resource, construction and
   relay state; Supply Line has a repair-support shortcut and damaged-truck advice.
   Both missions offer practical next-step debrief text. New text and command
   rejection messages have Chinese translations. Exiting during a cinematic also
   now releases its pause without restoring controls that have left the tree.

## Verification

Focused headless checks pass for game polish, opening guidance, command and
behavior reliability, navigation, combat, combat effects, combat audio, animation,
graphics, settings, HUD layout, research feedback, campaign controls, campaign
progression, cinematic cleanup, Supply Line, battle debrief, neutral objectives,
ambient route equivalence and save/navigation timing. The new tests cover full
queues, grouped feedback while paused, Guard/rally markers, Chinese rejection text, cursor context,
zoom anchoring, bounds, construction guidance, contested capture, and state-read
invariance. Existing command tests exercise actual viewport mouse input.

Rendered checks were run with a real renderer:

- `HudConsolePreview.gd`: 66 captures, all three factions, English/Chinese,
  720p/1080p, zero layout assertions. Reviewed empty and selected states,
  production controls and large-interface layouts.
- `GamePolishPreview.gd`: 22 captures covering bases, accepted/queued/rejected
  commands, First Orders gathering/building/Guard/capture/contested/debrief states,
  and Supply Line repair guidance in both languages.
- `CombatPreview.gd`: 18 captures across normal, muted and reduced-flash settings;
  reviewed projectile hits, crowded combat and destruction aftermath.
- `CombatAudioPreview.gd`: zero failures for real projectile/hit/destruction audio,
  left/right spatial energy, pause/settings freeze and resume, live fog loss,
  24-voice saturation and speech ducking. The measured mix stays bounded. This is
  automated audio verification, not a claim of human subjective listening.

Visual review caught untranslated queue rejection/count text and a campaign
cinematic teardown error; both were fixed and their scenarios rechecked.

Artifacts are local and regenerable:

- [Empty Bastion HUD](../../../art/hud-console/bastion-720p-closed.png)
- [Chinese queue rejection](../../../art/game-polish/command-rejected-zh_CN.png)
- [First Orders guidance](../../../art/game-polish/first-orders-gather-en.png)
- [Chinese debrief](../../../art/game-polish/first-orders-debrief-zh_CN.png)
- [Muted combat](../../../art/game-polish/combat/normal-muted/combat-240.png)
- [Measured audio mix](../../../art/audio/combat-runtime.wav)

Machine-readable results are in [verification.json](verification.json). Detailed
local logs and the macOS export are in `tmp/polish-2026-10-19/`. Changed GDScript
passes formatting/lint; the source diff passes whitespace checks.

## Known limits of the broader checks

- `SaveSnapshotRegression` and `SaveRestoreEdges` still exercise retired Lua
  configuration/runtime assumptions. Their failures are not claimed as passing;
  the save/navigation timing test does pass.
- The local editor cache still lists the retired native extension in
  `.godot/extension_list.cfg`, so local `NoLuaRuntimeRegression` fails. The exported
  package excludes the extension and passes the same absence check from an
  isolated working directory. The user's local cache was not deleted.
- `AmbientLifeRegression` reports 92 authored scenery-clearance assertions on
  Command Horizon / Broken Foundry. Replaying those maps with the original route
  lookup produces the same 92 assertions. The new cached lookup matches original
  positions at route corners, nearby samples and wrapped distances.
- Some fixtures retain Godot shutdown ObjectDB/resource/RID warnings. Assertions
  and script errors were checked separately; no full repository suite pass is claimed.
- Early release runs showed extra movement wall time that the final instrumented
  repeats did not reproduce. Cold-start behavior needs further measurement.

## New-player observation protocol

No unfamiliar player participated in this pass. The following protocol is ready
for the next observation session; the guidance changes above are based on game
state and direct review rather than invented participant findings.

Recruit three players who have not played this project, with at least one who is
new to RTS controls. Run Supply Line and then First Orders, observing the first
ten minutes of each without coaching. Use the player's normal language and input
setup. Record each attempted action and any hesitation lasting more than ten
seconds; do not explain a control until the player asks for help, and record that
intervention separately.

| Moment | Record |
| --- | --- |
| First movement | Time to select and issue a successful order; confusion about camera or selection |
| Convoy checkpoint | Whether Advance/Hold and separate escort orders are understood |
| Damaged truck | Whether repair support is found and a repair order succeeds |
| Resource shortage | Whether the player identifies the missing resource and begins gathering |
| Lab construction | Whether a foundation is resumed rather than duplicated |
| Guard lesson | Whether Auto-engage behavior and directed orders are distinguished |
| Relay | Whether infantry capture, contesting and the hold timer are understood |
| Rejected/queued order | Whether feedback is noticed and the player can recover |
| Debrief | Ask the player to describe one action they would change next time |

Record observations verbatim before proposing changes. Prioritize repeated
misunderstandings, then update instruction timing or labels and replay the affected
scenario. A successful automated run does not establish tutorial comprehension.
