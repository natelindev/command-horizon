# Program recovery support — 2026-10-06

Program status now explains when a damaged unit reaches an unserviced safe point. First-program guidance recommends Guard area for combat units, Scout route for drones, and Service area for repair robots, with the matching recovery support. A safe point alone does not heal a unit.

## Original failure and change

The original all-faction fixture fails eighteen assertions: six programmable unit roles reach their safe points at low health without explaining the missing service. Health correctly stays unchanged. `program-recovery/before.log` and the four `before/` source snapshots retain that baseline.

The shared `RecoveryAdvice` helper inspects owned, eligible facilities and available nearby repair robots. Preset retreat status names the faction's matching service facility and, for ground machinery, the mobile alternative. Lua and compiled visual programs retain their custom status and add the same explanation when a damaged unit requests its unserviced safe point. Nearby support is described as waiting for healing; this does not promise an available service slot.

The first-program step chooses the preset appropriate to the selected unit's role and explains safe-point support. Existing priority, costs, orders, thresholds, Lua memory and program eligibility remain unchanged. Advice does not spend funds, assign points, heal units or take control.

## Earned pressure continuation

`ProgramPressureProbe.gd` restores two paid-retrofit snapshots from the earlier Normal-AI runs, assigns the already-fitted tank to Guard at (20, 0, 40), and places its safe point near its HQ. Enemy strategic AI and existing unit actions remain active. The previous external human reference commander is not reconstructed. No extra units, resources, structures or health are granted.

| Continuation | Two-minute observation |
| --- | --- |
| Frontier | Tank remains alive at 68/68 HP and watches its assigned area. No unsupported retreat occurs. |
| Helix | Tank reaches the unsupported safe point at 41 seconds with 13.15/64 HP and remains at that health through the last sample at 119 seconds. |

The Helix unsupported state is retained as `pressure-helix-unsupported.json`. It contains 83 M / 12 E and five engineers. `EarnedServiceRecoveryRegression.gd` restores that state and pays 25 M / 10 E through the normal structure-placement path to build a Service cradle near the existing safe point. The tank's program action and safe point stay intact. Real construction and healing return the tank to Guard with enemy AI still active: the initial headless run reaches 52.74 HP in 48.1 seconds; the final harness verification reaches 52.06 HP in 47.3 seconds. These are observed runs, not deterministic timing claims.

## Regression verification

The final feedback regression passes all three factions and six roles: Tank, AdvancedTank, CombatRobot, RepairRobot, Drone and Helicopter. It checks unsupported status and unchanged health, actual facility healing and return, paused disk restoration, role-specific first-program advice, and unfinished-facility exclusion. Additional Lua and visual fixtures verify mobile healing, support departure, manual Stop authority and paused read-only advice.

PresetRecovery, AuthoredRecovery, RecoveryOrders and BattlePlan shared regressions also pass. Final source formatting and lint cover all nine changed/new scripts. Passing logs contain no script/parse errors. Existing navigation-readback warnings and renderer/ObjectDB shutdown diagnostics remain separate from test results.

## Native verification

The native continuation uses the same earned Helix archive at 1280×720 and 150% UI scale. It captures the unsupported program explanation, paid foundation, healing and return to Guard, with native Space input at each review checkpoint. The initial harness directly paused the tree without updating HUD pause ownership; the resulting input guard correctly refused to resume, and that attempt timed out. `native.log` and its two images retain the failed harness attempt. The corrected harness uses the existing HUD pause API; final evidence is in `native-verified.log` and four `native-verified-*.png` images. It passes with zero failures and returns to Guard at 52.06 HP after 52.9 simulation seconds. All four checkpoints keep their panels within the viewport and their status text readable.

## Limits and next work

This closes an actionable recovery-feedback gap and demonstrates a paid repair under continued enemy pressure. It does not establish a winning opening, full-match survival, novice comprehension or balance across factions. Native review covers the earned Helix guard; the other roles and authored programs are covered by automated live simulation. Broader strategy/content acceptance remains open, and performance work stays deferred.
