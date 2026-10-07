# Skirmish relay navigation — 2026-10-06

Alpine Relay and Industrial Crossroads now expose a **Relays** button beside the battle controls. The overview names North/South objectives, explains infantry capture and optional vision, shows public ownership/capture/contest state, and offers camera locators. Opening it pauses the battle; closing or viewing restores the previous pause state. Selection, actions, queued orders and funds remain intact. Campaigns retain their mission-specific objective controls.

Public screen-space labels and minimap markers now remain visible through unexplored fog, without exposing surrounding troops. Locators sit at the capture ground: a ground order at a label's center lies inside the capture radius. Labels render behind interface panels, ignore pointer input and hide at viewport edges. Map geometry, capture rules, AI, economy and saves are unchanged.

## Evidence

| Check | Result |
| --- | --- |
| Original missing access, three factions × two maps | Six failures in [before.log](relay-overview/before.log) |
| Final all-faction/map regression | [ground-targeting.log](relay-overview/ground-targeting.log), zero failures |
| Actual ten-second capture, opposing armor contest, paused progress | Pass in all six cases |
| Partial capture/contest written to disk, restored and completed | Pass in all six cases |
| Paused/running modal restoration, camera target, selection, manual queue, funds | Pass |
| Public enemy ownership while nearby enemy infantry remains hidden, including camera movement | Pass |
| Absent-map and campaign scope; existing modal/result guards | Pass |
| Alpine navigation, economy, capture, archive and AI | [AlpineRegression.log](relay-overview/AlpineRegression.log), zero failures |
| Industrial routes, economy, capture, archive and AI | [IndustrialRegression.log](relay-overview/IndustrialRegression.log), zero failures |
| Campaign controls and notice stability | [CampaignControls-final.log](relay-overview/CampaignControls-final.log), zero failures |
| Shared repair-support discovery | [SupportDiscoveryRegression.log](relay-overview/SupportDiscoveryRegression.log), zero failures |
| Rendered mouse/Enter event routing, two maps, 720p/150% | [verified-rendered.log](relay-overview/verified-rendered.log), zero failures; 14 captures |
| Formatting/lint, eight changed scripts | [source-checks-final.log](relay-overview/source-checks-final.log), pass |

The rendered fixture alternates mouse and Enter events through Godot's GUI input path; it does not call button signals for the ordinary locator flow. It verifies dialog/button bounds, the command bar and battle-plan/minimap separation. The headless fixture also guards stale activation against existing modals and finished matches. All six final suites exited 0 without script or parse errors.

Review: [unexplored Alpine locator](relay-overview/verified-AlpineRelay-frontier-located-0.png), [contested capture](relay-overview/verified-AlpineRelay-frontier-contested.png), [own/enemy ownership](relay-overview/verified-AlpineRelay-frontier-enemy.png), [Industrial locator](relay-overview/verified-IndustrialCrossroads-frontier-located-0.png), [Industrial overview](relay-overview/verified-IndustrialCrossroads-frontier-neutral.png).

## Investigation and limitations

- The first camera assertions compared a ground-plane ray with relay bases at Y=0.6. [camera-probe.log](relay-overview/camera-probe.log) establishes the mismatch; the test now intersects the relay's actual elevation. This was a fixture correction, not a camera change.
- Initial rendering showed a locator opening onto blank unexplored fog. The final public markers address that discovery. Earlier captures and failing assertions are retained separately from `verified-*` artifacts.
- The campaign controls fixture passed an empty assignment selection, which now hits an existing chip-cost expression that expects a unit. Its corrected fixture supplies an actual tank and uses the normal cancellation method; it also asserts that campaign HUDs do not expose duplicate skirmish relay controls. No assignment gameplay code was changed. The original failure remains in `CampaignControlsRegression.log`.
- Physical native input remains unverified. Computer use bound both the app path and the rediscovered `org.godotengine.godot` application to **Godot Engine - Project Manager**. The waiting native test was stopped through its own process handle after the bounded retry; [native.log](relay-overview/native.log) records that incomplete run. The user's Project Manager was not closed or restarted.
- Existing navigation mesh readback warnings and shutdown ObjectDB/resource/RID diagnostics remain. This work does not establish novice usability, full-match strategy/balance or platform-wide input acceptance. Performance optimization remains deferred.

## Reproduction

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RelayOverviewRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/RelayOverviewPreview.gd -- --captures=/tmp/relay-review
```

Use a fresh capture prefix. `--native` waits for the first four actual button activations; the fourth locator receives keyboard focus. Final source copies and a SHA-256 manifest accompany the evidence in `relay-overview/`.
