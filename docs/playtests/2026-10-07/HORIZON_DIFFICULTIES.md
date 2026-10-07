# Command Horizon: difficulty follow-through and deployment recovery

The finale now names the completed enemy-command objective and the remaining deployment task. If command falls before deployment is secured, the HUD shows the remaining hold time. If deployment has been lost, it says **Command destroyed · retake deployment with infantry**. Completion says **Command destroyed · deployment secured**. A one-time notice explains the infantry requirement; urgent own-HQ rebuilding retains priority. The persistent objective is reconstructed from the existing archive state.

This follows an actual Veteran playthrough that destroyed command but remained unfinished because deployment was lost. The reference commander continued sending replacements into that fight while leaving its surviving strike force at the destroyed HQ. The mission outcome was correct. A test-only, explicitly selected recovery policy now recalls surviving combat units with ordinary attack-move orders, reassigns repair support and buys at most six infantry replacements through the ordinary queue. Human orders remain explicit, and the default reference test is unchanged. Only `CommandHorizon.gd` changes among the 289 shipping scripts; enemy budgets, prices, damage, mission objectives and saves are unchanged.

## Complete playthroughs

All runs use the existing south-route commander, original starting forces, real harvesting, paid infantry/repair/armor production and saved Guard/Service programs. No enemies are removed or weakened and no extra funds are granted. Difficulty indices 0/1/2 correspond to Story/Standard/Veteran. Fixed seed 12701 improves reproducibility but does not establish deterministic navigation scheduling or repeatability.

| Difficulty / modifier | Commander | Outcome | Simulation time |
| --- | --- | --- | --- |
| Story / normal | Existing | Victory | 163.97 s |
| Standard / normal | Existing | Victory | 165.45 s |
| Veteran / normal | Existing | HQ destroyed, deployment lost; unfinished | 407.73 s |
| Veteran / Lean | Existing | Victory | 347.93 s |
| Veteran / Reinforced | Existing | HQ destroyed, deployment lost; unfinished | 407.23 s |
| Veteran / normal | Explicit deployment recovery | Victory | 263.85 s |
| Veteran / Reinforced | Explicit deployment recovery | Victory | 183.33 s |

Every run reaches secured deployment and all four responses. The two unfinished runs retain complete live-world archives; their test deadline is not a mission defeat. The recovery runs recall at 205.23 / 156.23 seconds. These are viable-route observations with different commander decisions, not a statistically controlled speed or difficulty comparison.

## Earned-state recovery and player feedback

The original normal-Veteran archive at 407.73 seconds restores exact positions, HP, funds and a frozen simulation clock. Issuing the explicit recall wins after another **25.72 seconds**, buying three infantry. Aircraft can return before the slower ground force; victory does not require every recalled unit to arrive. No claim is made that recall is the only winning continuation; there is no matched no-new-orders replay.

The final normal-clock Metal replay wins after **20.63 seconds**, buying two infantry. At **1280×720, 150% UI scale**, engine-injected Enter focuses the deployment locator and a mouse click selects the surviving infantry while paused. The new persistent objective fits inside the existing command panel, the deployment panel clears the minimap, and the result remains readable. Both screenshots were inspected: [paused recovery](horizon-difficulties/verified-preview-paused.png), [actual victory](horizon-difficulties/verified-preview-result.png). This is rendered engine input, not physical-device acceptance.

The focused feedback regression exercises early command destruction, lost deployment, the transition notice, urgent own-HQ recovery, paused disk reconstruction and completed-state wording. The preceding shipping code fails four focused assertions; the corrected code passes. The full shared `CommandHorizonRules.gd` suite also passes, including actual objective capture/contest, turret firing after restore, all nine difficulty/modifier budgets, finite responses, occupied-entry denial, alternate-route traversal and progress migration.

## Evidence and qualifications

Sixteen Godot processes are indexed in `horizon-difficulties/run-index.json`, with logs, source snapshots, shipping hashes, outcome JSON, two unresolved archives, reviewed screenshots and a SHA-256 inventory. The first feedback fixture omitted the historical capture flag from its artificial secured-deployment state; its six failures include two invalid-archive failures and it is rejected. Correcting that fixture yields the four valid preceding-code failures. The first rendered fixture compared the camera's elevated position to a ground target; its one failed assertion is rejected. The accepted fixture checks the center-ray ground intersection. Its other controls and gameplay are rerun, not inferred from the rejected result.

The final lint pass prompted an equivalent-text refactor to keep the objective function within the return-count limit; all feedback states are rerun on that exact final source. Complete-match and rendered source revisions are retained separately. Format/lint pass. Known navigation-readback warnings and shutdown ObjectDB/resource/shader/RID diagnostics remain; no runtime script errors occurred in these runs.

Example fresh Veteran recovery run:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tests/playtest/HorizonDifficultyMatches.gd -- --difficulty=2 --retake-deployment
```

This extends the finale's demonstrated playable routes to all three difficulties and both Veteran modifiers. It does not establish novice balance, repeated success, every difficulty/modifier/route combination, or acceptance of the other five campaign missions. Broader gameplay, final environment/platform acceptance and deferred performance remain open; the overall goal remains active.
