# Early armor preservation — 2026-10-06

This experiment tests the design requirement that conventional tanks need explicit retreat orders and that surviving armor can later receive programmable chips. The previous [sustained recovery audit](SUSTAIN_PRESSURE.md) recorded tanks lost before support completed. All new behavior is opt-in reference-commander policy; shipping units, player automation, statistics, maps and default strategy are unchanged.

## Policy and tradeoff

`ArmorPreservationMatches.gd` extends the existing paid two-tank/retrofit opening. When that opening would place its lab, it instead pays for a depot if none is complete. Placement uses the same builder selection, normal prices, construction and placement validation. The existing economy still waits until it can afford the requested lab before invoking placement: this experiment substitutes the depot at that decision, rather than introducing an earlier independent resource reservation. The lab follows completed support. It retains the existing screened-air rule rather than combining the prior nine-ground experiment.

The new `ArmorRecoveryPolicy.gd` issues conventional tank withdrawal below 60% health during operations, or below 80% during regrouping, when an observed-safe reachable depot is available. It inherits the existing service recovery behavior and its 80% release threshold. Installed programs, active fitting and pending manual queues are excluded. The commander preserves treatment through its phases and excludes held patients from retrofit candidates, preventing chip fitting from interrupting treatment as a tank crosses 60% health.

The common infantry policy now exposes patient/entry-threshold methods for the armor specialization and records patient roles. Its default infantry behavior remains the same. `PaidRetrofitMatches.gd` exposes a candidate-selection method; its default still considers the same owned units.

## Regression evidence

The original infantry-only policy leaves all three wounded conventional tanks outside treatment: three expected failures in the controlled faction fixtures. The armor policy verifies a paid depot foundation and live completion, paused treatment, defense/attack/regroup authority, continued treatment above the fitting threshold, real healing from 50% to at least 80%, exactly one paid chip, and a Running guard program. Installed-program authority and pending manual orders are also checked. Starting units and stockpiles are controlled fixtures; these checks do not establish an earned survival advantage.

The corrected all-faction armor regression passes with zero failures, as do the shared infantry treatment and paid retrofit suites. The five touched scripts pass formatting and lint checks. The retained earned-infantry continuation also passes: all four infantry heal and rejoin the assault in 37 simulation seconds with 289 treatment-authority checks.

Early fixture attempts contained a parse error, an already-complete Advanced-start depot, missing inherited helper initialization and a queue assertion that captured the action before queue submission. Those logs are retained separately; they are not counted as original gameplay failures. Corrected logs must have no script/parse errors as well as passing assertions. Known navigation readback and renderer/resource shutdown diagnostics remain documented in the logs.

## Complete paid observations

Times are simulation seconds. Depot timing is the first roughly ten-second observation showing completion.

| Faction / seed | Outcome | Depot complete | Basic unlock | First program | First assault | Tank returns / entries | Installed retrofits |
|---|---|---:|---:|---:|---:|---:|---:|
| Frontier / 4110 | Victory at 937.4 | 136.2 | 182.2 | 185.7 | 673.2 | 2 / 2 | 2 |
| Helix / 4110 | Defeat at 763.4 | 146.2 | 187.2 | 229.2 | — | 0 / 0 | 1 |
| Helix / 4111 | Victory at 429.2 | 136.3 | 174.8 | 183.3 | 252.3 | 2 / 2 | 2 |

Four conventional tanks complete treatment in the Frontier and second Helix trials, with 101 checks preserving treatment through the actual commander loop. Those four tanks then receive chips; the remaining Helix run installs one chip without a conventional recovery episode. Total: five completed paid retrofits, two victories, one defeat, and no recorded AI coordination violations. The winning trials lose no tanks.

The first Helix trial still loses and never launches an assault. Its empty armor-recovery list means it cannot validate withdrawal under pressure, despite reaching paid retrofit. The results establish that paid support, conventional recovery and chip progression can coexist through full matches; they do not isolate which opening choice caused the victories. The previous baseline already included a Frontier victory.

Next acceptance work should make timely support investment discoverable in the opening without forcing it or hiding programming progress, then return to broader faction/map and novice acceptance. The reference variant remains opt-in. No new native UI behavior is introduced by these scripts.

All complete-match spending uses ordinary Standard-start harvesting, construction, production and chip costs against Normal AI. Navigation/scheduling make seeds trial identifiers rather than deterministic causal pairs. This small sample on Coastal Foundry cannot establish balance or a superior strategy; the depot-first tradeoff can also delay programming and other investment.

## Reproduce

Use fresh archive/output paths:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ArmorPreservationRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ArmorPreservationMatches.gd -- --case=6 --repeats=2 --research=combined --strategy=screened-air --output=res://tmp/armor-preservation.json --archive=res://tmp/armor-stall.json --archive-prefix=res://tmp/armor-earned
```

Add `-- --original-policy` to the regression to exercise the original infantry-only selection. Case 2 is Frontier→Helix; case 6 is Helix→Frontier. Performance and broader gameplay/content acceptance remain open.
