# Campaign opposition and siege encounter

The campaign now combines authored response events with working enemy production.
No faction models, terrain shaders, palettes, or unit art were replaced.

## Functioning bases

- Air Corridor has an eastern headquarters, generator, barracks, three engineers,
  and local materials/electronics deposits. Economy and production activate when
  the first evacuation launches; the player can raid this base instead of only
  waiting for response events.
- Command Horizon's existing base has four engineers and local deposits. It
  harvests actual cargo and spends faction prices through ordinary infantry/tank
  production queues. Power, prerequisites, cancellation, departure clearance,
  and the shared population limit remain authoritative.
- Broken Foundry retains its two ordinary paid factories and finite announced
  production batches. These are complementary mission mechanics, rather than an
  invisible income refill or units appearing without payment.
- New replenishment is bounded to 2/3/4 active plus queued units by difficulty,
  with a 60-second opening delay and 65/50/40-second subsequent purchase cadence.
  Scripted, warned response events keep their existing timing and budgets.
- Killing engineers stops delivered income; killing producers cancels their
  unfinished queues. Production can spend previously banked funds, like the
  player's base. Generators affect the same ordinary production power factor.

## Finale siege commander

One existing Helix artillery defender is the siege commander. It retains normal
catalog HP, armor and weapon damage, and remains attackable throughout the fight.
Victory requires destroying both headquarters and commander while holding an
infantry guard at deployment.

The commander chooses only observed enemy ground units within 22 m. It marks the
chosen ground point with the existing circle effect for four seconds, then deals
one normal weapon hit to eligible ground units remaining within 3 m. The attack
does not follow a moving target. A fourteen-second cooldown separates barrages;
killing the commander cancels an unresolved warning. The HUD shows the warning,
observed commander HP, and defeated state. Long notices move the objective panel
alongside command controls when the alternative would cover the minimap.

## Verification

- `CampaignOppositionRegression`: 0 failures. Real delivery of both resources,
  no production without funds, ordinary faction-price debit, paused timer,
  completed paid output with an attack-move order, four-second warning, dodging
  the locked location, stationary damage, and death cancelling a pending barrage.
- `AirCorridorRegression`: 0 failures. Complete escorted victory at 217 simulated
  seconds, capture/restore, difficulty response budgets, occupied-entry denial,
  and unescorted-flight loss remained meaningful. The static defender fixture
  accounts for the three new engineers.
- `CommandHorizonRegression`: 0 failures. Complete normal south-route victory at
  251 simulated seconds; deployment was guarded, both command and commander were
  destroyed, and all four authored response events occurred. The reference
  commander can focus the siege commander after headquarters falls.
- `CampaignOppositionPreview`: native Metal rendered at 1280 × 720; warning ring,
  identifiable commander and objective status reviewed. Objective/minimap overlap
  detected in the first rendering and corrected before delivery.
- Changed scripts pass `gdformat` and `gdlint`.

Run with the local Godot 4.6 binary and `--headless --fixed-fps 60 --path . --script
res://tests/headless/CampaignOppositionRegression.gd` (or the corresponding
AirCorridor/CommandHorizon script). The preview uses the native renderer.

Raw logs retain existing Godot exit cleanup/resource warnings. These controlled
regressions establish mechanics and scripted outcomes; they do not establish
novice acceptance or all-difficulty balance. Save integration is maintained by
the central snapshot schema, with optional opposition state for older archives.
