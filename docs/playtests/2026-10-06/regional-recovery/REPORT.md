# Regional sustained gameplay — 2026-10-06

Four complete paid Standard-start matches extend the retained armor-preservation commander to Alpine Relay and Industrial Crossroads. **All four lose.** Three activate programs within the 3–5 minute hypothesis; only one launches a ground assault. The runs do not establish a viable cross-map strategy or justify changing faction statistics.

`RegionalRecoveryMatches.gd` inherits the previous paid depot-before-lab, two-opening-tank, conventional recovery, worker safety, retrofit and screened-air policies. It changes only map selection and records public relay transitions plus the shipping own-force battle record. All construction, production, research, fitting and losses use ordinary costs, timers and combat against Normal AI. The reference commander does not assign infantry to capture relays. No shipping gameplay, costs, maps or AI were changed this turn.

## Complete outcomes

Times are simulation seconds. Depot completion is the first ten-second observation showing a completed depot. All trials use seed 4110; asynchronous navigation/scheduling mean these are identifiers rather than deterministic paired comparisons.

| Reference → opponent | Map | Defeat at | Depot observed | Basic unlock | First program | First assault | Armor returns | Paid retrofits installed |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Frontier → Bastion | Alpine | 1378.8 | 166.2 | 269.7 | 281.2 | 790.2 | 1 | 2 |
| Frontier → Helix | Industrial | 692.0 | 156.2 | 193.7 | 209.2 | — | 2 | 2 |
| Bastion → Frontier | Alpine | 1351.6 | 166.2 | 260.2 | 278.2 | — | 0 | 2 |
| Helix → Frontier | Industrial | 423.4 | 146.2 | 177.2 | — | — | 0 | 0 |

The trials record three completed conventional armor recoveries, ten completed infantry recoveries and six paid retrofits. Four additional fitting attempts cancel under threat. AI task/order monitoring reports no violations across **7,692 samples**; peak simultaneous tasks are two in each match. All four processes exit 0 with one resolved match and zero unresolved checks, without script/parse errors. Defeat is a valid recorded outcome, not a gameplay-acceptance pass.

The AI owns both relays by 28.2–31.7 seconds in each trial, and the reference never takes them away. This is a disclosed limitation of the fixed commander and an uncontrolled vision advantage, not proof that relay ownership caused the losses. Only the Bastion trial records an outer-field cargo return, at 404.2 seconds. The two Alpine durations fit the 20–30 minute hypothesis; the two Industrial durations remain shorter. One trial per pairing cannot establish pacing or balance.

## Findings that change the next work

- Helix loses its barracks at 170.9 seconds, then tanks at 184.1 and 220.7. Basic unlock occurs at 177.2, but there is no retrofit or first program. Completed support alone does not preserve this opening under the observed attack.
- Frontier on Industrial preserves and fits two tanks, yet records no assault. Between the first and last reserved-infantry observations at 299.2 and 433.2 seconds, 269 half-second decisions hold an affordable infantry replacement behind the optional 45 M / 20 E airfield reserve. The 420.7-second army sample contains five infantry and three tanks. The earlier [reservation experiments](SUSTAIN_PRESSURE.md) already show why removing one spending conflict is insufficient evidence of a stronger opening.
- Repeated production-building losses consume the Alpine defenses. Frontier loses three vehicle factories and eight barracks; Bastion loses four vehicle factories. The strong repair totals do not establish sustainable defense or expansion.
- Frontier's Alpine archive captures a guard program blocked at 1148.7 seconds. Its assigned anchor `(17.5, 26)` lies near a vehicle factory centered at `(19.68, 24.47)`. The navigation endpoint is offset from the assignment. In an unchanged live-AI restore, explicit Resume reaches “Watching assigned area” after about four seconds, then movement continues under crowd pressure. [blocked-probe.log](regional-recovery/blocked-probe.log) does not prove a permanent route failure or its root cause. Investigate the exact guard/structure clearance and crowd behavior before changing arrival rules.

## Earned recovery continuation

`RegionalRecoveryContinuation.gd` restores the first real conventional-tank recovery from each Frontier trial. It does not restore the reference commander, issue replacement orders, disable enemy AI, add resources or fit a chip. The archived ordinary recovery action remains authoritative. Both tanks rise from **32/68 HP** to at least 80%: Alpine in **11.1 s**, Industrial in **13.0 s**. Paused inspection preserves action, health and funds.

The headless [continuation-final.log](regional-recovery/continuation-final.log) and normal-clock Metal [rendered-final.log](regional-recovery/rendered-final.log) pass. The rendered fixture routes Space through the engine's input handling and records paused withdrawal/recovery views at 1280×720 with 150% interface scale. This is engine-routed input, not a physical native-input claim. Initial fixture preloading compiled an action before autoload identifiers were available; the final fixture loads it after initialization. Initial failure logs remain retained.

**Visual acceptance remains open.** The Industrial recovered captures show clipped command/program controls at the right edge. A focused rerun in [width.log](regional-recovery/width.log) reports a 470-pixel content width inside the matching scroll clip and passes all command-button bounds, while its PNG still shows clipping. This geometry/render mismatch must be isolated; the passing bounds are not accepted as proof of a visually correct panel. No speculative layout change was made. Physical UI review remains limited by the previous turn's computer-use binding to Godot Project Manager.

Review: [Alpine withdrawal](regional-recovery/width-0-withdrawal.png), [Alpine recovery](regional-recovery/width-0-recovered.png), [Industrial withdrawal](regional-recovery/width-2-withdrawal.png), [Industrial recovery with unresolved clipping](regional-recovery/width-2-recovered.png).

## Evidence and reproduction

[summary.json](regional-recovery/summary.json) contains the compact outcome table. `case0/2/4/6.json` and matching logs retain full production decisions, losses, service observations, worker/retrofit authority, program milestones, relay transitions and coordination checks. Earned archives and the blocked snapshot are preserved. `run-source-sha256.txt` fingerprints 629 gameplay/scenario files; their hashes remained unchanged through the complete cohort. This is a gameplay-source fingerprint, not a full asset/binary release manifest.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/RegionalRecoveryMatches.gd -- --case=0 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/regional-case0.json --archive=res://tmp/regional-stall0.json --archive-prefix=res://tmp/regional-earned0
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/RegionalRecoveryContinuation.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/RegionalRecoveryPreview.gd -- --captures=/tmp/regional-review
```

Use new output/archive/capture paths. Cases 0/4 select Alpine; 2/6 select Industrial. Odd cases retain Advanced starts but were not exercised here. Existing navigation readback and shutdown ObjectDB/resource diagnostics remain. Broader strategy, novice, visual/platform and release acceptance stay open; performance optimization remains deferred.
