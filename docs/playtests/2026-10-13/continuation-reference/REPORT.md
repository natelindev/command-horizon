# Final paid reference playthrough — 13 October 2026

All three factions reached Victory in fresh processes using the final settled/frozen-body movement guard, with **0 test assertions and exit 0**. These runs use the existing standard-start paid reference policy on the original Desert Frontier map, against Easy AI. They establish end-to-end progression and match completion for this reference; they do not establish general balance, human difficulty or campaign acceptance.

| Faction | Outcome | Simulated seconds | Harvested M / E | Units produced | Enemy attacks | Surviving army | Failures / exit |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| bastion | Victory | 412.6333 | 392 / 152 | 41 | 1 | 10 | 0 / 0 |
| helix | Victory | 541.9667 | 492 / 232 | 46 | 2 | 12 | 0 / 0 |
| frontier | Victory | 386.6833 | 339 / 172 | 31 | 1 | 11 | 0 / 0 |

The starting economy is 60 materials / 12 electronics, four engineers and two infantry. The reference performs actual harvesting, paid construction, paid production, program activation and normal assault orders. It retains its existing strategy, unit costs, combat values, AI difficulty and 1,200-second limit. The only permanent harness change in this verification is symmetric faction selection: `--bastion`, `--helix` and `--frontier` select those factions; no flags still runs all three. Production is the match-wide counter, covering both players.

The final guard preserves ordinary deposit routes unless a route crosses settled or frozen units; structure approach planning remains preventive. [The source manifest](fresh-source.json) records the movement, labor, production, rules and reference scripts at fresh-process launch. Those recorded files were unchanged when all three runs completed. The exact result values and log hashes are in [summary.json](summary.json).

The earlier cached cohort remains in [skirmish-loop.log.txt](skirmish-loop.log.txt), including its Helix non-outcome at 1,200.75 seconds and exit 1. That process loaded the earlier movement implementation before resource approach planning was refined. Its Bastion and Frontier victories are also retained. The fresh cohort above provides acceptance of the current source; the earlier failure trace has not been overwritten.

Fresh runs used failure-only diagnostic instrumentation extending the normal reference harness. It invokes the original assertions and captures an active match snapshot only after an assertion fails; it does not alter strategy, simulation or pass criteria. No fresh assertion failed, so no failure snapshot was generated. The exact instrumentation is preserved in [TraceSkirmishLoop.gd.txt](TraceSkirmishLoop.gd.txt).

The real Sites controls were also rerun after localized capture statuses/world labels and service-catalog filtering: **0 failures / exit 0**, in English and Chinese at **1280 × 720 / 150% interface scale**. The [rendered facility report](../point-of-interest-ui/REPORT.md) includes the six current screenshots and verifies engine-routed mouse/keyboard controls, real infantry capture, paid recruitment/cancellation/refund, camera movement, modal input isolation and pause restoration. The rerun log is retained here as [point-of-interest-preview.log.txt](point-of-interest-preview.log.txt).

Fresh logs retain existing shutdown ObjectDB/resource/Shader RID cleanup warnings. There were no runtime script errors. Formatting/lint for the two reference UI/test harnesses and `git diff --check` passed.

Reproduce the standard reference on the local Godot 4.6 executable:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/SkirmishLoop.gd
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/headless/SkirmishLoop.gd -- --helix
```

The fresh launch commands substituted `res://tmp/continuation-reference/TraceSkirmishLoop.gd` and selected one faction per process; reconstruct that optional file from the preserved instrumentation if failure snapshots are required.
