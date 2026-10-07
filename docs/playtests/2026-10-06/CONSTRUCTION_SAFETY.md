# Observed-threat construction experiment

Started 2026-10-06; verification completed 2026-10-07. This is an opt-in reference-commander experiment. Shipping gameplay sources match the preceding defense-focus slice exactly. No player placement restriction, AI balance change or default-policy promotion is made.

## Cause and policy

The original reference `_place` searches four rings around HQ and buys the first collision/navigation-valid site. It does not consider threats. Earlier Industrial records show repeated barracks purchases at `(21, 0, 50)`, including foundations destroyed almost immediately.

`SkirmishLoop` now has a default-true candidate hook, preserving existing callers. `SafeConstructionMatches` derives from the cautious relay reference and filters otherwise-valid sites using currently observed contacts and the existing engineer danger rules: legal attackers within weapon range plus six metres at the destination, and range plus four metres along the straight segment from the builder to that destination. This segment is a conservative heuristic, not a prediction of the eventual navigation path. An exposed builder can therefore defer all construction. Unseen attackers cannot influence the decision. A quiet opening still uses the original eastern site; this policy does not predict future attacks.

The normal handler still validates space, navigation, availability and resources, charges the faction price and issues construction through the selected engineer. If every candidate is rejected, the blueprint is cancelled without spending or changing selection/orders. Telemetry records purchases and changes in deferral reasons, including the actual role when the inherited early-depot policy substitutes a depot for a requested lab.

## Focused verification

The [final regression](construction-safety/final-regression.log) passes for Bastion, Helix and Frontier. Controlled fixtures explicitly grant exact construction funds and stage visibility. The original branch buys at `(21, 0, 50)`; the filter buys at approximately `(9.0503, 0, 54.9497)` and pays exactly once. Checks cover a safe endpoint with an exposed approach, hidden-contact exclusion, all-site deferral without spending/order mutation, blueprint cancellation and paused clock preservation. Disk reload preserves the exact foundation position/progress and saved funds; each real engineer then completes the building.

The [negative control](construction-safety/final-original-regression.log) overrides only the candidate hook to return true and fails 21 assertions across the three factions. Those include downstream noncompletion after the unwanted second purchase replaces the builder's order; they are not 21 independent gameplay defects. There are no script/parse errors. The initial fixture used a constant expected balance for reload after the negative control had already spent on the unwanted purchase; the final fixture compares the actual saved funds instead. Both initial logs and source are retained.

EngineerSafetyPolicyRegression and AirDefenseAdviceRegression pass. Formatting and lint pass. No UI source changed, so this slice does not claim a new rendered-input acceptance run. Known navigation readback and shutdown resource/RID diagnostics remain.

## Same earned funded state

The accepted audit restores `resource-reserves/match6-earned-case6-10-armor_recovery.json`, at 178.233 seconds, independently for both branches. The Helix reference owns 22 materials / 6 electronics and has no barracks. No funds, units or completion progress are granted. Player decision loops are disabled; existing movement, combat, harvesting and paid queues continue. Every half second, the audit tries to replace a missing barracks with the first surviving engineer. Other reference decisions are intentionally omitted, so this is a spending/site-selection isolation, not a complete reconstruction of the original commander.

| Policy | Barracks bought / lost in 120 s | Materials spent | First completion after restore | Site |
| --- | --- | --- | --- | --- |
| Original | 4 / 3 | 80 | 35.5 s | All four at `(21, 0, 50)` |
| Observed-threat filter | 1 / 0 | 20 | 22.0 s | `(11.3212, 0, 43.5328)` |

The original first foundation is destroyed before completing; two later replacements complete and are subsequently destroyed. The filtered barracks remains alive at the observation's end. Final funds are 78/6 versus 150/6. The 72-material balance difference includes different live harvesting outcomes, so only **60 materials of avoided construction spending** is directly accounted for by the purchase totals. Both branches remain unfinished at 120 seconds; after-state archives and purchase/loss timings are retained in [funded audit](construction-safety/funded-audit.json).

An earlier audit used the unfunded 173.733-second reinforcement-pacing archive. Both branches eventually selected the western `(7, 0, 50)` site without rejection, showing no placement benefit. That 240-second audit reached Defeat and then attempted to save finished matches; both writes failed and its acceptance run is rejected. Its observations, failed log and initial source are retained. The accepted audit uses a bounded 120-second observation and successfully writes both live after-states. This earlier neutral observation is not discarded as evidence of policy limits.

## Complete paid Industrial matches

Both current-code Standard / Normal runs use Helix against Frontier, seed 4110, combined research, screened-air production, two opening tanks, early depot and cautious relay behavior. They complete through ordinary paid gameplay with no fixture grants.

| Policy | Outcome | First program | First main assault | Own barracks losses | Total own losses |
| --- | --- | --- | --- | --- | --- |
| Existing cautious reference | Defeat, 520.3 s | 203.2 s | None | 3 | 34 |
| Filtered construction | Defeat, 494.4 s | 357.2 s | None | 1 | 22 |

The filtered run rejects exposed alternatives when rebuilding its barracks and later briefly defers the lab. It reduces observed barracks losses but reaches programming later and still loses. Early periods also diverge before the filter rejects any site, reflecting nondeterministic navigation/physics; these two runs do not establish causal survival or progression improvements. The variant remains opt-in.

There are zero coordination violations across 2,030 samples. Longest sampled stationary travel is 33 seconds for the control and 2.5 seconds for the variant; the control also records three programmed tank goals blocked by a friendly structure. Neither issue is considered solved by changing construction policy. See [comparison](construction-safety/comparison.json) and complete records/logs.

## Open regression found during verification

`ContactApproachRegression` fails four checks on current shipping code: the retained engineer does not finish collecting within the three eight-second replays, and its restored detour does not finish harvesting within ten seconds. The same test and same four failures reproduce in `tmp/defense-focus-baseline`, which predates this construction experiment. The older `tmp/hq-traffic-baseline` passes. These baseline projects differ in more than one shipping file; this brackets a pre-existing regression but does not identify its responsible change.

All current shipping fingerprints match the preceding defense-focus report, and this test does not inherit the modified reference-placement loop. This construction experiment therefore does not introduce the failure. Nevertheless, the shared regression suite is **not fully green**. Investigate and fix the captured contact approach next, while retaining the Industrial HQ-traffic and occupied-arrival gains. Baseline logs and classified exit codes are retained. Existing unconditional `PASS` prints inside this old test do not override its four failed assertions and exit code 1.

## Reproduction and evidence

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/SafeConstructionRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ConstructionArchiveAudit.gd -- --archive=res://docs/playtests/2026-10-06/resource-reserves/match6-earned-case6-10-armor_recovery.json --output-prefix=res://tmp/new-construction-audit
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/SafeConstructionMatches.gd -- --case=6 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/new-safe-construction
```

Use existing output directories and fresh names. The archive audit refuses to overwrite retained evidence. `source-fingerprint.json`, `run-results.json`, source snapshots and `SHA256SUMS` record provenance. Broader home-defense, progression, movement, content, novice and platform acceptance remain open. Overall goal remains active; performance stays deferred.

Follow-up 2026-10-07: the pre-existing contact-approach failure identified above is now isolated and repaired; see [contact recovery verification](../2026-10-07/CONTACT_RECOVERY.md). This addendum does not change the historical construction experiment's source or results.
