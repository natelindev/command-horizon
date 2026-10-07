# Relay commitment and home reserve — 2026-10-06

An optional cautious reference commander now reserves two healthy infantry near home, reassesses observed opposition during relay expeditions, and protects an outmatched scout's withdrawal until it returns or yields to recovery/manual control. Controlled checks and one live Alpine withdrawal establish those behaviors. The match comparison does **not** establish a stronger opening: three final trials lose and the fourth fails the 30-minute completion check.

This changes test/reference code only. Shipping AI, unit values, map rules and player controls remain unchanged.

## Commitment and authority

`CautiousRelayPolicy.gd` extends the existing expedition policy. It selects at most two conventional infantry while leaving at least two healthy eligible infantry within 18 m of the home defense point. It therefore waits for additional infantry rather than diverting one of the two starting defenders. Observed threats within 30 m of HQ, or threats to owned economy assets identified by the shared defense planner, suspend expeditions until twenty simulation seconds of quiet. A missing HQ also suspends dispatch.

At dispatch and during travel, observed enemies within 12 m of the objective or expedition members are reassessed. The infantry mission declines or withdraws from a targetable non-infantry opponent or an equal/larger infantry group. Hidden units do not enter this decision. This is a conservative scouting rule, not a combined-arms strength model.

An opposition recall issues ordinary Move toward home and retains the withdrawing units in the commander's protected set. Assault, regroup and recurring home orders cannot reclaim them during that return. Arrival within 6 m releases them. Recovery handoff, explicit order replacement, death and a sixty-second return limit also release them; replacement orders remain intact. Existing mission cooldowns and recovery priority remain in force. Reference-policy bookkeeping is not a shipping save feature; archives preserve the actual issued unit orders.

## Current-code comparison

All four final trials use paid Standard starts, Normal AI, seed 4110, combined research, screened-air production, two opening tanks, early depot and conventional recovery/retrofit. Control is the existing expedition policy, not the earlier no-expedition baseline. Each row is one observation; asynchronous navigation and setup remain nondeterministic.

| Pairing / map | Expedition | Result / time | First relay | Captures | Relay-seconds | Forces lost |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Frontier → Bastion / Alpine | Existing | Defeat / 989.0 s | 19.7 s | 8 | 263.5 | 32 |
| Frontier → Bastion / Alpine | Cautious | Defeat / 1152.1 s | 50.2 s | 10 | 481.5 | 48 |
| Helix → Frontier / Industrial | Existing | Defeat / 759.5 s | 73.7 s | 4 | 96.0 | 31 |
| Helix → Frontier / Industrial | Cautious | **Unresolved / 1800.7 s** | 55.2 s | 4 | 172.0 | 35 |

[Comparison data](relay-commitment/comparison.json) links the [Alpine control](relay-commitment/control0.json), [Alpine cautious](relay-commitment/final0.json), [Industrial control](relay-commitment/control6.json) and [Industrial cautious](relay-commitment/final6.json) records. Relay-seconds integrate the number of owned relays over sampled ownership transitions.

The cautious Alpine expedition recalls two infantry at 276.7 s for observed opposition. Both complete their protected return, at 286.2 and 289.2 s. It nevertheless loses more forces and never launches the main assault. All four final trials activate programs; only the Industrial trials launch an assault. The cautious Industrial army later remains in recovery: its last ten minute-spaced samples contain seven or eight healthy ground combatants, below the nine-unit assault threshold, with no visible home threats. This is incomplete outcome/pacing acceptance, not a draw or victory.

The same Industrial run records two engineers stationary near HQ for approximately 272 s: a Move around `(13.68, 53.10)` toward `(9.52, 48.14)` and an electronics harvester around `(13.60, 54.38)` bound for the southern expansion. Their supplied paths still have intermediate waypoints. This evidence identifies a traffic investigation; it does not prove its cause or a fix. Earned archives at [300.7 s](relay-commitment/final6-earned-case6-10-worker_alternative.json), [404.2 s](relay-commitment/final6-earned-case6-10-infantry_recovery.json) and [416.7 s](relay-commitment/final6-earned-case6-10-infantry_ready.json) cover the episode. A [1228.3 s technology archive](relay-commitment/final6-earned-case6-10-technology.json) provides a later recovery/economy state.

There are no coordination violations in 9,402 final-trial samples. The three defeated trials exit zero; the unresolved Industrial trial correctly exits one with its match-completion assertion. All four have no script/parse errors. A separate earlier cautious Industrial trial, before protected-return bookkeeping, loses at 558.1 s; its source snapshot, record and log are retained but excluded from the final table. That variability reinforces the limits of single-run comparisons.

## Verification

- [CautiousRelayRegression](relay-commitment/final-regression.log): six faction/map cases complete actual travel, travel/partial-capture disk restoration and capture. Three faction risk cases verify hidden/visible contacts, paused decisions, actual survival and return under tank fire, nearby reserve requirements and quiet-home gating. Zero failures.
- [CautiousRelayAuthorityRegression](relay-commitment/formatted-authority.log): all factions preserve withdrawal through assault, then release correctly for recovery, manual replacement, arrival and timeout; missing HQ prevents dispatch. Zero failures.
- [RelayExpeditionRegression](relay-commitment/shared-regression.log): the unchanged existing policy still passes all six capture/archive cases and its priority bounds after introducing overridable selection/risk hooks. Zero failures.
- [Rendered earned-state review](relay-commitment/final-render.log): six 1280×720 / 150% captures restore the two cautious matches' first earned captures, open the overview and locate the relay while preserving pause, orders and funds. Zero failures. [Alpine overview](relay-commitment/final-render-case0-overview.png) and [Industrial field](relay-commitment/final-render-case6-field.png) are representative. Input uses engine GUI events, not physical native input.

The final cautious regression run against the existing policy produces [110 expected assertion failures](relay-commitment/original-regression.log), including repeated per-update withdrawal assertions. This is a policy-capability comparison, not 110 distinct shipping bugs. Controlled cases spawn an extra infantry to establish the reserve fixture and inject the threat encounter; the complete matches above earn their units normally. The authority-only recovery case verifies ownership handoff, not healing.

The first threat fixture placed the scout inside the relay's solid pole, blocking its own sight; moving both units to clear ground fixes the fixture. Its failed logs remain. Two rejected intermediate runs also exposed test-only nil/constructor errors and cascading scene cleanup diagnostics; compressed logs and earlier fixture sources are retained. Final accepted suites contain no script/parse errors. Formatting/lint pass. Existing navigation-readback and shutdown resource/RID diagnostics remain.

The cautious policy remains opt-in. Next work is to reproduce the archived engineer congestion and investigate the late recovery/production deadlock, then repeat broader strategy acceptance. Novice, environment/content and platform acceptance remain open; performance stays deferred. [Artifact hashes](relay-commitment/SHA256.json), source snapshots and run metadata accompany this report.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/CautiousRelayRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/CautiousRelayMatches.gd -- --case=6 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/cautious-new.json --archive-prefix=res://tmp/cautious-earned-new
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --script tests/rendered/CautiousRelayPreview.gd -- --captures=docs/playtests/2026-10-06/relay-commitment/review-new
```

Use fresh output and capture paths to preserve prior evidence.
