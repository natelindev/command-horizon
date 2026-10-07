# Independent resource reserves — 2026-10-06

The skirmish AI now allows a purchase that consumes only a resource's surplus even while another resource is below its savings target. Materials-only infantry no longer wait for electronics they do not consume. Construction, higher-priority production and research still protect the currencies that a proposed purchase would spend.

## Retained late-game evidence

Restoring the [earned 1228.25-second Industrial archive](relay-commitment/final6-earned-case6-10-technology.json) reveals a Frontier AI with **72 materials / 14 electronics**, an unpaid AircraftFactory reserve of **45 / 20**, an idle barracks requesting infantry at **5 / 0**, and a routine fitted-tank request at **20 / 6**. The old `_train` check rejects the infantry because 14 electronics is below the factory's 20-electronics reserve, although the proposed purchase leaves that stockpile unchanged and leaves more than 45 materials.

This is the opponent AI's purchasing defect. The reference army's separate late seven/eight-unit recovery stall is not claimed fixed. The initial archive diagnostic, failed tests and isolated original-code control remain in [the evidence folder](resource-reserves/).

The only shipping change is the reserve check in `SkirmishAI._train`: apply a currency's reserve when the job consumes that currency. Actual queue affordability, prices, refunds, priority ordering, worker exceptions, research selection, finite income and production timing retain their existing authority.

## Focused verification

The initial regression produces fourteen expected assertions on the old code. After adding independent higher-priority counter-unit coverage, the finalized fixture against an isolated original-code project produces **twenty expected assertions**. Its shipping source differs from the working project only in `SkirmishAI.gd`.

The [final regression](resource-reserves/final-regression.log) passes:

- The untouched live archive buys infantry for exactly 5 materials, survives a paused disk save/reload without changing funds or queue time, and actually spawns it eight seconds after resuming. Electronics remain 14. Existing unit actions and combat stay live; further player decisions are disabled for the focused observation. No units or income are granted to the archive.
- All three factions purchase infantry from exact surplus materials with electronics at zero, one below the reserve, or exactly funded. Cancellation refunds the precise faction price.
- One-material-short purchases preserve construction savings. Electronics-consuming armor remains blocked below the electronics reserve, and rejected purchases do not advance the production sequence.
- An unfunded observed-air counter protects its material/electronics savings while allowing surplus-material infantry; one-material-short infantry remains blocked. Once funded, both the counter and infantry enter real queues at their exact combined price. These are controlled fixtures with selected producers and assigned budgets, separate from the earned live case.

Nine headless suites have passing final runs: ResourceReserve, SkirmishBudget, ResearchEconomy, FrontierProductionAI, SkirmishComposition, SkirmishLabor, TechnologyAI, SkirmishCoordination and ReferenceEconomy. ResearchEconomy funds and completes Coordination through actual finite harvesting for all three factions while checking conservation and priority contracts. Live coordination retains combat, relay, repair-support and regroup behavior. Final runs exit zero without script/parse errors; formatting and lint pass. Existing navigation-readback and shutdown resource/RID diagnostics remain.

The initial FrontierProductionAI fixture fails against **both** original and changed shipping code: its exact tank price competes with unpaid Coordination research, and its early failure leaves a live match that causes cascading duplicate-human script errors. The fixture now explicitly stages Coordination unlocked for the isolated procurement contract, asserts no research candidate, and cleans up after failures. The corrected fixture passes against both original and changed code, including actual timed tank delivery, paid chip fitting and conventional fallback after lab loss. Live research coverage remains in ResearchEconomy; no shipping research exception was added. The original logs and failed batch result remain classified rather than overwritten.

## Complete paid matches

Two current-code Standard/Normal trials retain the cautious relay commander, paid construction/research/production/repair and seed 4110:

| Trial | Result / time | First program | First main assault | Longest sampled stationary travel, own / AI |
| --- | --- | --- | --- | --- |
| Frontier → Bastion, Alpine | Victory / 749.4 s | 353.7 s | 371.7 s | 2.5 / 1.5 s |
| Helix → Frontier, Industrial | Defeat / 610.7 s | 199.7 s | None | 2.0 / 1.0 s |

Both [Alpine](resource-reserves/match0.json) and [Industrial](resource-reserves/match6.json) reach real outcomes, exit zero and have no script/parse errors. There are zero AI coordination violations across 2,720 samples. In Alpine at 139.52 seconds, the AI pays **6 materials / 0 electronics** for infantry while saving **50 / 30** for its lab: funds change **65 / 24 → 59 / 24**. That is a normal paid purchase the old electronics-shortfall condition would reject. Industrial records no matching building-reserve-shortfall purchase in this one run.

These are follow-through observations, not a controlled win-rate comparison. Both factions' progression and combat remain live, the reference policy is unchanged, and asynchronous simulation can vary. Industrial still loses without a main assault and records ten own barracks losses; sustained home defense remains a concern.

## Limits and reproduction

This fixes a demonstrated cross-resource budget blockage, not overall late-game pacing or recovery strategy. The cautious reference policy still has its own purchasing and army-readiness decisions. Home defense, strategic progression and broader novice/content/platform acceptance remain open. Performance remains deferred.

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/headless/ResourceReserveRegression.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/ResourceReserveMatches.gd -- --case=0 --repeats=1 --research=combined --strategy=screened-air --output=res://tmp/resource-reserve-new.json
```

The match wrapper observes actual paid infantry orders under an electronics building-reserve shortfall. It changes no commander decisions. Source snapshots, [classified runs](resource-reserves/run-results.json), [source fingerprints](resource-reserves/source-fingerprint.json) and [artifact hashes](resource-reserves/SHA256.json) accompany this report.
