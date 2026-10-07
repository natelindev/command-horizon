# Relay-contesting strategy audit — 2026-10-06

The reference commander can now exercise contested regional objectives through a separate, optional infantry expedition policy. Four complete paid matches establish working capture/recapture and a real defense tradeoff; they do **not** establish a stronger strategy or justify changing shipping balance.

## Policy and scope

The established reference repeatedly orders conventional infantry to its home defense point. `RelayContestMatches.gd` adds `RelayExpeditionPolicy.gd` to the regional armor-preservation reference. It sends at most two healthy conventional infantry to the nearest unowned relay, reserves at least one healthy infantry for the main force, and excludes the expedition from main-assault readiness and recurring home orders. Orders use ordinary attack-move; no units, resources, chips, capture progress or upgrades are granted.

One objective may be active at a time, with a sixty-second limit. Public relay ownership guides destination choice; enemy decisions use observed contacts only. Observed home danger, a change to assault/regroup, or an infantry recovery requirement releases the mission. Existing recovery patients retain their orders. Completed captures allow a new mission after five seconds; other endings wait thirty seconds. This deliberately simple strategy counts observed opposition rather than evaluating a full combined-arms matchup. It is test infrastructure, not a new player automation or shipping AI policy.

## Complete matches

All four use Standard starts, Normal AI, recorded seed 4110, combined research, screened-air production, two opening tanks, early depot, conventional recovery and paid retrofit. Control uses `RegionalRecoveryMatches.gd`; Expedition uses the new subclass. Each is one observation. Navigation and asynchronous setup remain nondeterministic even with a fixed random seed.

| Pairing and map | Reference | Result / time | First relay | Relay-seconds owned | Own forces lost |
| --- | --- | --- | --- | --- | --- |
| Frontier → Bastion, Alpine | Control | Victory / 863.1 s | None | 0 | 9 |
| Frontier → Bastion, Alpine | Expedition | Victory / 1081.6 s | 19.7 s | 344.0 | 26 |
| Helix → Frontier, Industrial | Control | Defeat / 639.6 s | None | 0 | 18 |
| Helix → Frontier, Industrial | Expedition | Defeat / 297.9 s | 73.2 s | 70.5 | 15 |

Relay-seconds integrate the count of owned relays across recorded ownership transitions; owning two for one second counts twice. Sampling is approximately every half-second. [comparison.json](relay-contest/comparison.json) retains the underlying metrics and mission episodes; full records are [control Alpine](relay-contest/control0.json), [expedition Alpine](relay-contest/contest0.json), [control Industrial](relay-contest/control6.json) and [expedition Industrial](relay-contest/contest6.json).

The Alpine expedition completes nine captures/recaptures and reaches a peak of two owned relays. It activates programs at 334.2 s and assaults at 631.2 s, versus 311.7 s and 663.2 s in the control. More losses and a later victory do not support promoting it as a better opening. Industrial's first single-infantry attempt recalls for recovery; later two-infantry missions recapture South, North and South again. It never holds both simultaneously and loses before program activation or assault. The control also loses, later, without unlocking programs. Objective success alone did not secure the home economy.

All four runs reach an actual result, exit zero, and report no script/parse errors or coordination violations across 5,764 samples. These observations support exercising map objectives in future trials; they are insufficient for a causal win-rate, faction-strength or balance conclusion. No shipping gameplay values, AI, maps or UI were changed in this slice.

## Verification and retained evidence

`RelayExpeditionRegression.gd` passes six controlled Standard-start faction/map cases. An existing infantry travels from the normal base to the relay; the other remains available at home. Real disk saves during travel and partial capture preserve position, destination and capture progress. The loaded ordinary orders finish capture and grant local vision without running the reference commander after restoration. Funds and chip state remain unchanged. Controlled enemy AI is disabled for these isolated path/capture checks; the four complete matches retain live AI.

Adverse checks cover attack/regroup priority, recovery exclusion, health, the home reserve, owned objectives, paused updates, hidden relay enemies, observed home danger, protected recovery orders, cooldown and timeout. [Final regression log](relay-contest/final-regression.log) reports zero failures. The policy-disabled control deliberately produces six missing-expedition assertions; it is a capability control, not evidence of a shipping defect. An initial fixture mistakenly assumed infantry had a program controller; that nil access was corrected and its rejected cascading-error log retained compressed. The final test accepts the ordinary no-controller infantry state.

Two earned full-match capture archives are restored for [rendered review](relay-contest/render.log), with six 1280×720 / 150% captures. GUI mouse/Enter events open the overview and locate the owned relay, retaining paused time, funds and existing orders. The [Alpine view](relay-contest/render-case0-overview.png) and [Industrial view](relay-contest/render-case6-overview.png) show actual earned ownership. These are engine-input checks, not physical native-input acceptance. Existing navigation-readback and shutdown resource diagnostics remain.

The retained match-run policy and final policy differ only in an equivalent return-path consolidation for the linter. Final source copies, gameplay fingerprint and artifact hashes are retained with this report. Performance remains deferred; sustained home defense, safer objective commitment, broader strategies and novice/content/platform acceptance remain open.

## Reproduction

Use a new output/capture prefix to preserve prior evidence:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RelayExpeditionRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/RelayContestMatches.gd -- --case=0 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/relay-contest-new.json --archive-prefix=res://tmp/relay-earned-new
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/RelayContestPreview.gd -- --captures=docs/playtests/2026-10-06/relay-contest/review-new
```
