# Economic defense camera focus — 2026-10-06

The battle plan's defender-selection action now centers the camera on a threatened owned asset instead of the first selected soldier. This makes a distant economic raid visible while selecting the recommended defenders. It preserves their orders, queues, health, resources and pause state. Production/engineer recommendations retain their existing selection focus.

## Behavior and evidence

A paused all-faction fixture places an owned engineer at a distant visible infantry raid while the recommended defenders remain at home. The original button selects those defenders and centers on their first member, leaving the raid out of view. The existing tactic already knows the economic asset is threatened; the change carries that known position through the advice into camera selection.

The most recently hit owned asset within the existing six-second damage window takes precedence. Without recent damage, the closest threatened asset to a visible legal attacker is used. Hidden attackers never contribute a position: recent unseen fire focuses its owned victim. Expired damage without a visible threat clears this focus. The existing selection action gains a tooltip and accessibility explanation; no new controls or automatic movement orders are added.

The isolated original-code control fails [37 assertions](defense-focus/original-final.log) against the finalized fixture. Changed code passes fourteen focus cases: visible ground danger, hidden incoming damage, newer-hit priority and mobile air defense for all three factions, plus the earned Industrial raid and a paused disk reload. Selection is suppressed while a modal owns the HUD. Actual troop selection and all paused gameplay state remain checked. Structure/engineer production guidance does not acquire a defender focus.

The [253.73-second earned Industrial archive](reinforcement-pacing/control6-earned-case6-10-infantry_ready.json) contains real incoming fire on the HQ and an engineer. Its action focuses the recently hit engineer near `(16.98, 54.96)`, and restoration recalculates the same focus without persisting a stale target. The initial test chose a 68.73-second first-contact archive where no economic asset was threatened; its failed assumption is retained and excluded. Contact with a remote enemy alone still does not trigger economic defense advice.

## Verification

Seven headless suites pass: DefenseFocus, BattlePlan, AirDefenseAdvice, GroundDefenseAdvice, SupportDiscovery, EngineerResponse and HQCountdown. The shared suites retain fog isolation, counter-role/stance advice, paid production and prerequisites, repair support, threatened-engineer selection, and urgent HQ/worker recovery priority. One batch command mistakenly named a nonexistent EngineerSafetyRegression script; Godot exited zero despite load errors. That attempt is rejected and the relevant existing EngineerResponse suite was run successfully.

The [accepted rendered run](defense-focus/accepted-render.log) passes all fourteen focus/authority cases using seven injected mouse clicks and seven injected Enter activations. Every actual button signal is verified. Six captures at 1280×720 and 150% interface scale were visually inspected: visible ground danger for all factions, Frontier air defense, the earned Industrial raid and its disk reload. The threatened asset is visible and the battle plan does not overlap the minimap or selection panel. [Distant Frontier raid](defense-focus/accepted-render-visible-frontier.png) and [earned Industrial keyboard activation](defense-focus/accepted-render-earned-reloaded.png) are representative. These are engine GUI events, not physical native input. Formatting and lint pass.

Intermediate preview evidence is retained: the first staged distant-raid captures had stale fog after paused fixture relocation; the next preview called an incorrect visibility method and produced script errors despite exit zero. The corrected presentation refresh uses normal per-unit visibility and owned fog circles without advancing simulation or revealing the map. A subsequent run missed one mouse target during action-row reflow; the preview now waits for layout and verifies the actual button signal before checking camera and selection behavior.

Final shipping changes are limited to `SkirmishTactics.gd` and `SkirmishPlanPanel.gd`. Existing navigation-readback and shutdown resource/RID/shader diagnostics remain; no gameplay script/parse errors are accepted. Source snapshots, [classified runs](defense-focus/run-results.json), [source fingerprints](defense-focus/source-fingerprint.json) and [artifact hashes](defense-focus/SHA256.json) accompany this report.

## Limits

This improves the player's view of known economic danger. It does not move defenders, guarantee an effective counter-order or establish that the Industrial opening survives long enough to reach programming. The earlier strategic deficits and broader content, novice and platform acceptance remain open. Performance stays deferred.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/DefenseFocusRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/DefenseFocusPreview.gd -- --captures=docs/playtests/2026-10-06/defense-focus/new-review
```

Use a fresh capture prefix to retain previous evidence.
