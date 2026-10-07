# Paid research economy audit — 2026-10-05

The original shared AI labor policy omitted research from its entire resource demand. At population 100 with all planned buildings completed, unit and building demand are zero. Six materials gatherers therefore remain assigned to materials even when eligible Coordination lacks electronics. Repeated research decisions cannot change this state. Depleted Harvest actions retain their resource kind while waiting for a new assignment, so depletion does not trigger the idle-worker fallback. This is a demonstrated policy omission in a staged legal state, not a claim about how frequently Standard matches reach that state.

The original routine production policy also protected no research savings. A separate uncapped Bastion fixture ran actual six-worker harvesting and paid production at the normal 90-frame/1.5-second decision cadence for 240 simulated seconds. Population rose from 15 to 21, but Coordination never started; final stock was 0 M / 4 E. This establishes a sustained delay, not a permanent uncapped deadlock. Full Standard-match outcomes and frequency belong to the independent match cohort.

## Real-harvest isolation

`PaidResearchEconomyProbe.gd.txt` stages the army/buildings and freezes combat to isolate the economy. Resources begin at 0 M / 0 E; map deposits, work slots, movement, collection, delivery, research prices and timers remain real. No resource replenishment or free research is used. All three original-policy capped cases run 120 simulated seconds with six materials gatherers: Bastion ends 172 M / 0 E, Helix 184 M / 0 E, Frontier 184 M / 0 E, with no Coordination. Manually assigning one worker to the existing electronics field then allows the unchanged AI to buy and complete Coordination in 120.02/112.52/117.02 seconds respectively. This control demonstrates that the resource field, return route and paid research APIs function.

## Maintained regression

`tests/headless/ResearchEconomyRegression.gd` replaces the manual recovery with autonomous labor and retains the real population cap, finite stock, six workers, completed base and 0/0 opening balance. The test checks research demand, actual electronics funding, real timed completion and conservation of total finite stock against delivered resources, carried cargo and the exact 20 M / 20 E payment. It then independently checks exact-price routine production, urgent observed-air counters, repair support, first aircraft, emergency workers, construction protection, healthy-army eligibility, the active shared slot, and sticky program unlock after lab destruction, an unfinished replacement and completed reconstruction. Budget contracts explicitly stage exact price-sized balances; only the income case claims earned resources and timed completion.

| Faction | Original after 180 s | Updated Coordination start | Updated completion |
| --- | --- | --- | --- |
| Bastion | 272 M / 0 E, no research | 64.48 s | 94.50 s |
| Helix | 316 M / 0 E, no research | 56.98 s | 87.00 s |
| Frontier | 280 M / 0 E, no research | 55.48 s | 85.50 s |

The isolated original policy returns exit 1 with 18 expected assertions. The updated policy returns exit 0 with 0 failures. Both use the same maintained scenario; only whitespace formatting followed execution. Logs are `research-economy-before.log` and `research-economy-after.log`. No script errors occur in these maintained runs. They include the existing runtime navigation-mesh warning and dummy-renderer RID cleanup error; the exploratory probe also has an ObjectDB cleanup warning.

The smallest production design, implemented by the parent agent, adds a shared candidate method on SkirmishAI. It returns only an eligible unpaid research ID/cost, including an explicitly completed-lab requirement because the basic-program unlock remains sticky after loss. Production demand adds that cost through the existing AI object, with no circular preload. Routine priority 6 production protects it; construction and priority 0–5 jobs keep precedence. Active paid research contributes no second reserve. Prices, fog, emergency rules and geometry are unchanged.

## Older labor fixture: original traffic deadline plus paid progression

The previous SkirmishLaborRegression funded Tank + Helicopter and called `_train` directly while Coordination was eligible and unpaid. Its assumption that routine armor spends ahead of research is incompatible with the new intentional priority. Its prior source is retained as `SkirmishLaborRegression-before.gd.txt`.

The first adaptation added the 20 E research purchase to the same 6000-frame earning threshold. It retained the original actors and 200 M / 0 E balance. This result remains archived as `skirmish-labor-research-first.log` and `SkirmishLaborRegression-research-first.gd.txt`: Bastion earned 48 E versus 46 required. Helix earned 52 E versus 54 required, with two workers each carrying 1 E and three waiting for work slots. Four assertions failed as a consequence (funding, both queues, combined payment, completion). The original mixed-unit-only requirement of 34 E had been exceeded. This was an expanded purchase contract, and must not be represented as the old traffic requirement failing.

The final adaptation uses two explicit stages. The original Tank + Helicopter earning threshold, original 6000-frame/100-second deadline, handoff/archive flow, actors, starting balance and original electronics conservation assertion remain. At that threshold the normal `_train` call must buy the urgent first Helicopter, preserve the routine Tank's savings for unpaid Coordination, pay exactly the first wing's cost and leave the production index unchanged.

A separate progression stage earns the additional research cost with actual harvesting and invokes `_harvest`, `_research` and `_train` every 90 frames. Its independent bound is 3600 frames/60 seconds. Producers remain frozen until Coordination has been purchased and both original unit jobs are queued, so they cannot finish early or add duplicate orders. Conservation across player stock, all finite deposits, carried cargo and the exact combined purchase cost is checked. The original 1800-frame unit-completion window and final materials rebalance then run normally.

| Faction | Original budget earned | Original budget elapsed | Coordination bought in extra stage | Both jobs queued in extra stage |
| --- | --- | --- | --- | --- |
| Bastion | 28 E / 26 required | 67.42 s | 18.00 s | 33.00 s |
| Helix | 36 E / 34 required | 75.57 s | 16.50 s | 34.50 s |

The final two-stage run returns exit 0 with 0 failures, including both finished units, exact spending/conservation and final material delivery. See `skirmish-labor-research-stages.log` and `SkirmishLaborRegression-stages.gd.txt`. No prices, original traffic deadline, resource grant or actor removal was used to make the result pass. The additional bound describes a separate additional purchase, not an extension of the old traffic deadline.

## Exploratory setup corrections

Initial exploratory attempts had fixture errors: a compile-time preload pulled autoload-dependent production code in too early; subsequent attempts referenced a nonexistent `_enemy` member and accessed `production_queue` on workers. These were corrected to runtime loading, player-group lookup and guarded property access. The first noisy log is retained compressed, and subsequent failed/successful logs and source are retained. These are probe setup errors, not shipping gameplay failures.

Formatting, lint and whitespace checks pass for the maintained test and the adapted labor file. No production changes were made by the audit agent.
