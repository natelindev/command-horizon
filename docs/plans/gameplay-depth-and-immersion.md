# Tactical Gameplay Depth, Faction Asymmetry, and Map Events Plan

## Status and design intent

Reviewed implementation plan, 2026-10-25. The gameplay decisions below were confirmed in a direction-by-direction discussion with the user. They supersede conflicting proposals in earlier drafts. **Numerical values not explicitly chosen during that discussion are initial playtest defaults**, including costs, radii, caps, and most cooldowns; they are not claims of completed balance validation. All reviewed gameplay features are implemented, and automated integration checks plus rendered visual review are complete. Human matchup and pacing evaluation remains outstanding; evidence and limits are recorded in [the verification report](../playtests/2026-10-25/gameplay-depth/verification.md).

The intended result is more meaningful battlefield decisions: establish fire superiority, breach a defended position, commit to a faction's economic strengths, experience automatic battlefield events with small optional rewards, and recognize a damaged vehicle at a glance. Each mechanic needs readable counterplay and controls that fit the bottom HUD.

### Established directions and constraints

- Infantry suppression and grenade breaching of occupied civilian buildings.
- Bastion completed-unit production streaks and instantly deployed barricades; Helix local power overdrive and a dedicated unarmed EW/recon Kite; Frontier mines, area clearance, and permanent salvage armor.
- Map-specific automatic environmental events with small optional rewards, and expensive, infrequent commander call-ins.
- Faction damage identities: Bastion diesel smoke/hull fires, Helix cyan plasma/repulsor wobble, Frontier radiator steam/loose plates/backfire.
- No artificial camera shake or impulse displacement in Skirmish. Campaign impulses are restricted to explicitly scripted cinematic moments.
- No directional armor. Super-units and Behemoths remain Campaign boss content.
- Operation menus stay inside the bottom HUD, without floating windows or scrolling. Preserve selection, pause state, keyboard navigation, and research/production access.

### Confirmed decision record

| Direction | Confirmed behavior |
| --- | --- |
| Suppression | Tactical restraint with player control retained. Ordinary gunfire requires hits; heavy sustained fire can suppress on near misses. Heroes are immune. Pinned infantry receive fixed direct-fire damage reduction and can crawl out with ordinary move orders. Fast recovery: about 2 s delay, 7 s total from full suppression. |
| Garrison breach | Q explicitly targets an occupied hostile building. Deal 52.5 damage to all occupants and eject all survivors. Survivors can immediately move, fire, and use abilities; only re-garrisoning is blocked for 3 s. No stun. |
| Vehicle damage | Audiovisual only, visibly different by faction, clear but restrained. No performance penalty or Skirmish camera movement. |
| Map events | Fixed times with advance notice; automatic environmental performances and small optional benefits, initially on authored theme maps. Alpine grants one global radar snapshot rather than repeated pulses. |
| Commander powers | Barrage clears an area/weakens defenses; EMP strips shields, slows vehicles, and disables turrets for about 6 s; airdrop carries two Outriders and a repair crate. Offensive powers require current vision and affect enemies only. |
| Bastion production | Basic faction trait on Barracks/Vehicle Factory. Bonuses follow consecutive completed units of the same role; switching role resets the streak. |
| Bastion barricades | Instant worker deployment with cooldown. Blocks both sides, can be crushed by tanks. |
| Helix Overdrive | Extra power demand buys faster shield recovery locally around the generator, for the owner's units; overlapping fields do not stack. |
| Helix Kite | Dedicated unarmed electronic-warfare scout. Remove Helix suicide/dive attacks. Chaff stops guidance temporarily without deleting missiles. |
| Frontier mines | Workers and Outriders lay mines. Hostile infantry/combat vehicles trigger them; workers do not. All mobile units can detect them. Combat units ignore mines during normal movement/target acquisition and may still drive over known mines. |
| Mine clearance | Workers receive an area order and automatically clear successive mines. Combat units require a separate manual attack per mine, use existing weapons, and clear it with one successful hit; no automatic next target. |
| Scrap armor | Keep current healing and timed damage/speed buffs, and add permanent percentage damage reduction. Permanent plates and protection have two tiers, independent of the 60 s buffs. |

### Pre-implementation findings

| Area | Baseline behavior and implication |
| --- | --- |
| Grenades | Ordinary Infantry has Q: 35 damage, 3.5 m radius, 10 m range, 12 s cooldown. `UnitAbilities.gd` damages immediately; `CombatEffects.gd` animates the later impact. Breaching needs simulation-owned impact timing first. |
| Garrisons | The actual file is `source/match/ambient/NeutralBuilding.gd`. Occupants are hidden at the building position; leaving preserves ownership. Existing exits project radial points onto navigation and need clearance checks for mass eviction. |
| Damage effects | `BastionVisuals.gd` calls generic `CombatEffects.damage_smoke()`: smoke below 30% HP, fire below 20%. Replace that profile rather than adding overlapping emission loops. |
| Camera | Ordinary combat forwards impulses through `CombatEffects._shake_camera()` to `IsometricCamera3D.add_trauma()`. Neither currently enforces the cinematic-only restriction. |
| Frontier salvage | Scavenging already repairs 35% maximum HP and grants up to two temporary Scrap Hardened stacks: +15% damage/+10% speed per stack for 60 s. Eligible roles are Tank, AntiAirVehicle, AdvancedTank. The new permanent armor rank must be separate from these temporary stacks; it is not a technology tier. |
| Helix shields | Plasma Shields research already grants regeneration at 6 HP/s after 5 s without damage. Overdrive should modify that calculation. |
| Kite drone | The Kite uses shared `Drone.gd`: a scout/loitering munition that dives to attack. The Helix role must now be separated from that shared dive behavior while retaining the other factions' drones. |
| Power/production | Power is player-wide; shortages reduce production to 35%. Queues include physical departure and blocked exits, which assembly bonuses must preserve. |
| Tech buildings | All factions use the CommandLab role: Command lab / Signal lab / Relay workshop. Frontier Scrap Yard/Depot is not the current lab. |
| Maps | Emberworks and Railspire Junction are current industrial Skirmish maps. Industrial Crossroads is legacy; Broken Foundry is Campaign content. |
| Mercenaries | Dust Rangers, Iron Wardens, and Breach Lancers have camp-exclusive contracts. Delivering them through a call-in would deliberately change that rule. |

Existing paths below are integration points; proposed new components are marked **new**.

## Shared implementation contracts

1. **Simulation owns outcomes.** Suppression, grenade impacts, event rewards, call-in impacts, mines, and cooldowns work with effects disabled and in headless runs. Visuals/audio consume state.
2. **Use simulation time.** Pause freezes gameplay timers. Delayed actions retain owner and frozen offensive facts if their source dies; no wall-clock gameplay timers.
3. **Respect observation.** Enemy status, damage sounds, and traps must not leak through fog. Public event markers and committed hostile-strike warnings deliberately reveal only their location.
4. **Compose modifiers once.** Integrate movement, reload, damage, shield recharge, and power at existing query points. Never repeatedly mutate base stats or reset reload progress when statuses change.
5. **Save each playable slice.** Update `MatchSnapshot.gd`, `SnapshotSchema.gd`, and `MatchRestore.gd` together. Persist timers, ownership, stable IDs, pending effects, reservations, and reward consumption; rebuild decoration from state.
6. **Current-version saves only.** If `MatchSnapshot.VERSION` changes, convert archives in `docs/playtests/` and `tests/fixtures/` while preserving unit/resource IDs. Do not introduce runtime migration code.
7. **AI is part of delivery.** Use the same costs, observation, unlocks, targeting, and cooldowns as humans; extend existing Skirmish production/sites/defense/recovery helpers.
8. **Bound presentation cost.** Reuse effect/audio pools and spatial queries. Avoid whole-world scans per unit/projectile. Quality settings may reduce decoration, never essential warnings.
9. **Follow asset/UI workflows.** Use icons, tooltips, filled states, shapes, and concise text. No decorative colored selection borders. Preserve keyboard focus. Edit localization TSVs and rebuild the catalog; edit HUD/model generators rather than generated PNGs/GLBs.

## Stage 1 — Infantry suppression and garrison breaching

### 1.1 Suppression: purpose and eligibility

Suppression provides tactical restraint while preserving player control. Heavy sustained fire can cover an advance or withdrawal without making ordinary rifle fire an area-lockdown tool.

- Apply to non-hero infantry, including ordinary, specialist, and mercenary infantry through the roster classification. Heroes are immune. Workers, walkers, vehicles, and aircraft are ineligible.
- Ordinary gunfire needs a confirmed hostile hit, including a shield-absorbed hit. Heavy sustained fire also contributes through near misses; start with autocannon and AA gun/flak profiles, not unguided rockets or guided missiles.
- Initial near-miss distance is 1.5 m from the projectile's swept path, with terrain/obstacle occlusion. Near-miss buildup is capped at 20 points/s per victim.
- A projectile/victim pair cannot accumulate a near-miss contribution and then a full duplicate hit contribution. Retain per-projectile contribution bookkeeping through save/restore; upgrade to the hit total if it later connects.
- Friendly fire, repair, scripted HP changes, and damage-over-time do not contribute.
- Sheltered garrison occupants do not gain ordinary projectile suppression; existing suppression decays normally. Breach does not itself add suppression or stun.

### 1.2 Initial numerical rules

| Parameter/state | Initial tuning |
| --- | --- |
| Meter | 0–100 per eligible infantry unit |
| Rifle / assault hit | +6 / +8 |
| Autocannon hit | +16 |
| AA hit against infantry | +8 × current ground-damage factor; baseline 33% AA adds about 2.64 |
| Heavy-fire near miss | Half that weapon's eligible hit contribution, subject to the 1.5 m/occlusion checks and 20 points/s cap |
| Other weapons | No suppression contribution initially; retain ordinary damage |
| Recovery | After 2 s without a qualifying hit/near miss, decay at 20 points/s |
| Suppressed | Enter at 50: movement ×0.70, reload duration ×1.20 |
| Pinned | Enter at 90: movement ×0.40, reload duration ×1.20, prone/low crawl, direct-fire damage ×0.80 |
| Hysteresis | Pinned exits below 80; Suppressed exits below 45 |

Pinned replaces the Suppressed movement modifier. Compose with sprint/veterancy without applying both suppression bands. Move, attack, and ability orders continue; no extra retreat button or cancelled grenade. No additional accuracy penalty.

The selected protection is **fixed direct-fire damage reduction**, not a smaller physical hit profile or random evasion. Apply the initial 20% reduction to direct non-explosive weapon damage; explosive warheads and splash receive no reduction. Keep projectile hit bodies, aiming facts, navigation, and selection footprints unchanged. Pose changes remain presentation.

Full recovery from 100 takes about 7 s: 2 s delay plus 5 s decay. Any qualifying suppression contribution restarts the recovery delay.

### 1.3 Feedback, implementation, AI, and acceptance

- Suppressed infantry crouch; Pinned infantry use prone/low crawl with aligned weapons and smooth transitions.
- Compact overhead shapes appear only while affected and observed. Shape/text distinguish states without relying on amber/red. Reduced-flash mode uses a steady pinned icon.
- Selected-unit HUD shows one meter/state badge; group selection shows affected counts.
- AI can withdraw injured suppressed infantry toward known safe recovery, with a decision cooldown to prevent oscillation.
- Use a small **new** suppression trait, suggested `units/traits/InfantrySuppression.gd`. `InfantryMotion.gd` reads state rather than owning it. Integrate contributions with `WeaponCatalog.gd` and swept projectile/hit paths; movement/reload/damage modifiers use existing central queries.
- Save meter, hysteresis band, recovery delay, and any live projectile contribution bookkeeping.

**Acceptance:** hero immunity; ordinary misses versus heavy near misses; swept-path/occlusion checks; bounded buildup and no double contribution; shield hits; direct-fire reduction versus explosive damage; ordinary retreat orders; exact recovery; sprint/veterancy composition; fog; pause/save/restore. Rendered checks verify readable poses without introducing extra physical evasion.

### 1.4 Grenade breach sequence

Keep infantry Q, the existing 10 m throw range, and 12 s cooldown. Explicitly click an observed hostile occupied neutral building to breach; terrain targeting retains ordinary area damage. Measure range to the building footprint and require a valid throwing line, not through another structure or cliff.

1. Validate target/range/cooldown and begin cooldown on an accepted throw.
2. Create a simulation-owned pending grenade with an initial 0.6 s flight/fuse. Freeze owner, landing point, and building ID. The visual arc follows that timer.
3. At impact, re-evaluate hostile surviving occupants. Apply 52.5 damage per occupant (35 × 1.5) through normal shield/HP handling. Exterior enemies receive ordinary 35 damage inside the blast; each victim is damaged once.
4. Eject all survivors into individually reserved, reachable, non-overlapping positions.
5. Survivors can **immediately move, fire, and use abilities**. Apply only a 3 s prohibition on entering any garrison to the ejected units, starting on physical exit. Do not close the building to other units.
6. End the old garrison action so it cannot automatically re-enter. Preserve later valid orders. Ownership remains with the defender until normal capture.

There is no breach stun, movement lock, firing lock, or ability lock after evacuation. The first version damages occupants, not structural HP. Empty/friendly buildings do not breach. Occupants leaving or ownership changing before impact changes who can be affected; building destruction must not cause duplicate collapse damage/evacuation. Thrower death does not cancel the grenade.

If no legal exit exists, hold the survivor in pending evacuation without garrison firing and retry clearance. Never teleport across disconnected terrain or kill a unit to satisfy eviction. Save pending evacuations and reserve exits for the whole batch before moving units; the 3 s re-entry timer starts only once physically outside.

**Counterplay:** screen the building, kill the short-range thrower before release, or evacuate during the visible throw. Survivors can immediately fight back or retreat. Show the impact and re-entry cooldown clearly.

**Acceptance:** full/partial garrison; survivors/deaths; shields/allies; thrower death; ownership change/destruction; blocked exits; queued orders; immediate movement/fire/abilities after exit; affected-unit-only 3 s re-entry prohibition. Save in flight, pending evacuation, and during re-entry cooldown. Extend existing ability/garrison tests and add `GarrisonBreachRegression.gd`.

## Stage 2 — Vehicle damage identity and camera discipline

### 2.1 Faction damage states

These are presentation states, with no new combat/stat penalties. Start with mobile ground machines, including workers and repair vehicles; aircraft and buildings retain separate existing damage/death behavior.

| HP state | Bastion | Helix | Frontier |
| --- | --- | --- | --- |
| Healthy: ≥50% | Normal exhaust | Stable propulsion | Normal machinery |
| Damaged: <50% | Intermittent black diesel smoke | Cyan plasma leaks from heat/power sockets | White radiator steam; subtle plate vibration |
| Critical: <25% | Hull fires, spark trails, grinding engine | Short arcs; restrained repulsor wobble on hover models | Backfire/soot, loose plates, chassis vibration |
| Destroyed | Existing death/wreck behavior takes over | Same lifecycle rule | Same lifecycle rule |

- Recover from Critical above 28%, and Damaged above 53%; retain the band in saves if necessary for hysteresis. Stop emissions at death/despawn.
- All motion is local to presentation geometry. Navigation, collision, gameplay aiming, and camera remain stable. Helix walkers use arcs/joint motion rather than hover wobble.
- Use engine/radiator/repulsor sockets and generated plate groups through `art/<faction>/build_*.py`, preserving weathering.
- Preserve silhouette, team markings, selection, and telegraphs at tactical zoom. Prefer intermittent puffs and restrained loops to continuous fireballs.
- Distance/observation-gate audio. Start with a cap of four nearby damage loops, prioritizing selected/closest units; rate-limit backfires.
- Reuse the `BastionVisuals` update hook and bounded `CombatEffects` pools. Shared faction profiles define sockets, thresholds, emissions, and sounds.

**Acceptance:** all factions at 100%, 49%, 24%, repaired, dead; stationary/moving/selected/hidden cases. Compare dense-army frame time, particles, and audio voices against the same battle without damage decoration.

### 2.2 Enforce cinematic-only camera impulses

A `mission_id != ""` check alone would still permit ordinary Campaign combat shake. Require an explicit scripted cinematic request as well as Campaign mode.

- Remove ordinary firing/impact/death/call-in authority to shake the camera.
- Guard the camera entry point, not just callers. Skirmish rejects requests and clears stale/restored trauma and shake offsets.
- Campaign cinematic scripts may request bounded impulses; normal combat does not.
- Honor reduced-motion/flash preferences and reset offsets when the cinematic ends.
- Preserve inertial panning, zoom anchoring, dragging, bounds, and deliberate cinematic movement.

**Acceptance:** extend `CameraFeelRegression.gd` for direct Skirmish requests, explosions, stale trauma, pause, and mode transitions. Verify ordinary Campaign combat stays stable and an explicit cinematic request works. This existing policy violation is a suitable first small implementation slice.

## Stage 3 — Map-specific battlefield events

### 3.1 Purpose, lifecycle, and placement

Events primarily make the map feel alive through automatic environmental performances, with small optional rewards. They are not a mandatory strategic objective and do not require long capture channels, dedicated worker transport, or repeated radar control.

- Initial schedule: events at 5:00 and 11:00, warnings 45 s earlier. Advanced starts use the same clock; no endless recurrence.
- Lifecycle: `scheduled → announced → active → claimed/expired`. Each occurrence has a stable ID, authored location(s), and finite reward budget.
- Add **new** `world/BattlefieldEvents.gd` and map definitions. Explicitly extend authored layout expansion; arbitrary new keys are not currently transformed with symmetric features.
- Environmental transports/trains/flotsam animate automatically and never obstruct navigation. They are decorative, not combat targets.
- Use authored reachable locations, with seeded choice only among validated candidates. Review route exposure/access from all starts.
- Keep rewards clear of exits, bridges, deposits, and capture interactions. Try authored alternatives if obstructed; cancel publicly if none remain valid.
- Announce/ping once at warning and activation. Reveal the event marker through fog, not nearby armies. Allow click-to-focus; never move the camera automatically.
- Display concise event state/time in the bottom-HUD objective/map area.
- Add a saved Events on/off setting. Default on only for completed theme maps; Campaign requires mission-specific opt-in.

### 3.2 Event variants and initial rewards

| Event | Target maps | Automatic performance and optional interaction | Reward/window |
| --- | --- | --- | --- |
| Desert supply drop | Desert Frontier, Redrock Divide | Cargo aircraft drops supplies; ground unit collects through one interaction | Total 10 Materials + 5 Electronics; 180 s |
| Industrial freight | Emberworks, Railspire Junction | Authored freight train arrives/unloads at depot; ground unit collects | 5 Electronics; 180 s |
| Coastal flotsam | Coastal Foundry, Sunken Exchange | Cargo drifts ashore onto reachable land; ground unit collects without worker hauling | Total 10 Materials + 5 Electronics; 180 s |
| Alpine relay | Alpine Relay, Glacier Narrows | Antenna powers up; first ground-unit interaction uses the terminal | One global radar snapshot; terminal available for 60 s |

- Any living owned mobile ground unit, including a worker, can receive the explicit interaction order. Approach and collect once within reach; no sustained holding, channel, or cargo-return requirement.
- Commit collection atomically. Stable entity ordering resolves simultaneous claims; a reward cannot be collected twice. A unit dying before it reaches the reward does not claim it.
- Resource rewards credit the collecting player's stock directly, with no additional Frontier salvage multiplier.
- The alpine reward belongs to the first collecting player and its allies: show one snapshot of enemy mobile-unit positions as minimap blips for 3 s. No repeated pulses, continuous tracking, targeting vision, terrain exploration, or mine detection. No resource reward.
- Expired unclaimed rewards disappear. The event's environmental performance does not depend on someone collecting the reward.
- For multi-start layouts, author fair access and retain the total reward budget per occurrence, splitting resource rewards if needed. Do not multiply rewards automatically by player count. Railspire Junction and Sunken Exchange need dedicated multi-start verification.

### 3.3 Scope, AI, persistence, and acceptance

- Initially author only the listed theme maps. Other maps remain event-free; do not infer behavior from names or terrain appearance.
- Industrial gameplay power surges and coastal visibility-changing fog remain out of this delivery. Do not add random grid outages.
- AI may collect a nearby safe reward but should not divert its army or create a worker logistics operation for these small benefits.
- Save lifecycle, warning-delivered flag, remaining timers, unclaimed reward entities, claimant/consumption ledger, and snapshot expiry. Use separate stable event IDs; preserve existing ordered site/relay/garrison IDs.

**Acceptance:** both schedules; unobtrusive automatic performance; no route blocking; one-action collection; worker and combat-unit eligibility; small exact payouts; simultaneous claims; death before collection; expiry; one global snapshot without attack vision or mine detection; save in every state. Reload cannot replay warnings, duplicate cargo, or pay/scan twice.

## Stage 4 — Commander off-map call-ins

### 4.1 Access, payment, and HUD

- Gate on a completed CommandLab: Command lab / Signal lab / Relay workshop. Do not implicitly add Coordination or a new Frontier structure requirement.
- One power/charge per player; extra labs grant no extra charges or recharge. Proposed initial readiness: 60 s after first lab completion.
- Activation requires a surviving completed lab and adequate power. Cooldown continues during lab loss/low power; rebuilding never refreshes it. Committed effects survive lab destruction.
- Initial prices after review: barrage/EMP cost 50 Materials + 30 Electronics; airdrop costs 45 Materials + 15 Electronics. Cooldowns: barrage 150 s, EMP 150 s, airdrop 120 s, starting on accepted activation. Tune each separately after prototype playtests.
- A persistent Commander icon opens a bottom-HUD submenu. Show price, recharge, and disabled reason. Choose a rebindable opener after auditing `KeyBindings.gd`; contextual Q activates the power only in that submenu.
- Target mode preserves selection. Escape/right-click cancels without payment. Confirmation atomically revalidates lab, power, target, resources, cooldown, and population reservation, then spends once.
- Barrage/EMP require currently observed ground; airdrop requires explored legal land. Losing sight after commitment does not cancel a strike.
- No payment merely for opening target mode. Invalid actions explain why. Accepted call-ins are commitments, with no refund for enemy interception.

### 4.2 Bastion — Heavy Artillery Barrage

**Purpose:** dislodge stationary forces and soften a defended structure before an assault.

- Fixed 6 m target circle; public red-smoke/shape warning for 3.5 s before first impact.
- Six shells arrive at 0.6 s intervals over 3 s. Generate/save the impact pattern on activation; no retargeting or rerolling on load.
- Initial per-shell damage: 80, blast radius 2.5 m, linear falloff to 25% at the edge. Explicit profile: infantry ×0.75, light/heavy machines ×1.0, structures ×1.25. No unit research/veterancy damage scaling.
- Structures are hit when their circular or polygonal footprint intersects the blast. Keep center-based damage falloff with its 25% floor; do not count a structure twice. The normal six-shell pattern centered on a 500-HP headquarters deals 189 damage, leaving 311 HP. Ordinary mobile blast reach and weapon acquisition ranges are unchanged.
- Damage hostile ground units/structures only; allies and neutral unowned objects are immune, matching existing hostile-only abilities. Exclude airborne aircraft.
- Occupants follow normal building-collapse rules; barrage does not apply grenade breach.
- Smoke, whistles, debris, and sound provide impact without camera shake. Shells are not AA-interceptable initially.

**Counterplay/acceptance:** disperse, move artillery, pressure the lab before the next cast. A representative full-health headquarters must survive one barrage. Validate allied immunity, frozen pattern, per-impact restore, and no duplicate area damage.

### 4.3 Helix — Orbital EMP Surge

**Purpose:** open a temporary assault window against shields and static defense.

- Fixed 8 m ground circle with a 2.5 s public holographic/audio warning, then one pulse against enemies still inside.
- Strip shields from enemy ground combat units to zero; restart the normal 5 s recharge delay. Deal no HP damage.
- Ground vehicles/walkers move at ×0.60 for 6 s. Infantry movement, aircraft flight, factories, economy, and grid power are unaffected.
- Ground/AA defense turrets cannot acquire/fire for 6 s. Preserve orders/reload progress; projectiles already flying continue.
- Repeated EMPs use the strongest slow and later expiry, not multiplied modifiers or added durations. Coordinated casts still require a lockout balance check.
- Overdrive can accelerate subsequent recharge only after the ordinary delay.

**Counterplay/acceptance:** leave the warned area, spread defenses, screen with infantry, exploit the downtime after the attack. Show temporary turret disablement distinctly from damage. Test expiry, overlapping casts, shield recharge, orders, and save/load during all durations.

### 4.4 Frontier — Smuggler Airdrop

**Purpose:** pay a premium to reinforce a forward location with interception risk.

Confirmed payload: **two existing Outriders and one repair crate**. Use existing faction vehicles; do not add mercenary units or change camp-exclusive contracts.

- Reserve two population slots at payment, including queued/reserved units in the 100-unit cap. Transfer reservations to landed units; release on failure. Production must see those reservations.
- Show a 4 s landing-zone warning, then a 3 s descent with a targetable cargo carrier. The map-edge approach is cosmetic; gameplay interception begins over the landing zone, avoiding a full transport-flight subsystem initially.
- Carrier baseline: 120 HP, light-machine air target, no weapons/shields. Valid enemy AA can attack it. Check real missile travel time against the descent window.
- Destruction before touchdown loses all cargo, with no refund/salvage reward. Landing atomically removes the air target and creates the payload.
- Require room for both units at activation; reserve actual spawn positions at landing. Try reachable clearance within 6 m; hold up to 5 s if blocked. Carrier remains vulnerable while holding. Failure releases population reservations.
- Spawn ordinary Outriders with completed research but no free veterancy, temporary salvage stacks, or permanent scrap armor ranks. Do not replace current selection/control groups.
- Repair crate: 60 s lifetime, 30 HP, destroyable by enemies. One damaged allied ground machine channels for 2 s to consume it and repair 35% maximum HP; no resources/buffs. Undamaged units do not consume it automatically.

**Counterplay/acceptance:** scout warnings, position AA, shoot the carrier, contest landing. Test population racing with production, blocked landing, carrier killed exactly at touchdown, allied repair consumption, and saves throughout descent/holding/landing.

### 4.5 Implementation, AI, and common verification

Use **new** player-level commander state plus match-owned pending-effect records. Reuse damage/projectiles/observation/alerts/targeting where appropriate; do not fake a free-firing unit to bypass payment or ownership.

Save initial charge/cooldown, activation IDs, frozen pattern, pending impacts, EMP expiry, carrier/cargo, reservations, and crate consumption. Validate finite timers and bounded counts. Define owner elimination explicitly: cancel undelivered reinforcement cargo and release reservations; already committed offensive impacts finish with their frozen ownership.

AI casts on observed worthwhile targets and evaluates known AA risk for drops. It uses normal payment/unlock rules.

**Acceptance:** atomic spend/rejection, cancellation before commitment, lab loss/rebuild, power deficit, owner elimination, fog, pause, source removal, and restore in every effect state. Add `CommanderCallInsRegression.gd` and rendered telegraph captures.

## Stage 5 — Faction macro mechanics

### 5.1 Bastion Assembly Line

**Decision:** commit a producer to repeated units for efficiency, or switch composition to counter an opponent.

- Basic Bastion faction trait, available as soon as each Barracks/Vehicle Factory is complete, without research or a lab requirement. Applies independently per producer, excluding heroes. No aircraft, HQ workers, research, or mercenary contracts.
- Count consecutive **completed units of the same role**, not prepaid queue length. First unit: no bonus; second: +8% assembly rate; third: +16%; fourth onward: +24%.
- Formula: assembly rate = base × power factor × (1 + bonus). A 24% rate gain gives about 19.35% less assembly time, not 24% less duration.
- Lock the active job's bonus when assembly starts. Queue additions/removals cannot retroactively change it.
- Starting another role resets the streak even if cancelled. Cancelling the active job resets it; cancelling waiting jobs does not.
- Empty queue keeps the streak for 5 s, then resets. Game pause freezes that grace. Power slowdown, missing prerequisites, and blocked exits retain the streak.
- Accelerate assembly only; retain existing departure speed and correct time accounting across phase transitions.
- Queue tooltip shows streak/next bonus. AI may specialize factories but must still switch to needed counters.

**Save/acceptance:** persist last role, completed streak, idle grace, active bonus. Test switches, refunds/cancellation, independent factories, low power, blocked exits, large time steps, and mid-departure load. Enqueue/cancel loops must never manufacture progress.

### 5.2 Bastion Field Barricades

**Decision:** instantly shape a defended approach with a worker-deployed obstacle and a deployment cooldown.

- Worker build-submenu option. Initial segment: 10 Materials, instant deployment, 15 s per-worker cooldown, 80 HP, about 2.5 m long/0.8 m tall, no power/population. Cap 12 active/reserved segments per player.
- The worker must reach legal placement range; instant deployment does not mean remote map-wide construction. Validate position, materials, cap, and cooldown atomically on deployment. Invalid/cancelled targeting spends nothing; an accepted segment and its cooldown are committed together.
- Rotate using existing placement controls. Require observed reachable ground. Reject overlap with units/structures, deposits, capture access, bridge exits, or closure of critical routes. Preserve required unit clearance, not just a point path; never trap a unit by spawning on it.
- Use low physical obstacles and existing projectile/LOS behavior, with no extra proximity-armor aura.
- Block both sides. Tanks/advanced tanks crush them through existing light-barricade behavior. Hostile owned barricades are normally targetable, requiring adaptation of neutral `DestructibleObstacle.force_attack_only()`.
- Owner workers can explicitly dismantle a segment with `R` in 2 s without refund; normal worker repair is supported. Right-click repairs a damaged owned segment and ignores a healthy one, preserving current orders. No timed construction phase or post-deployment cancellation refund.
- Register/remove dynamic footprints through the existing navigation rebake workflow; coalesce nearby changes.

**AI/save/acceptance:** defend known routes without blocking own production/harvesting. Persist deployed segments and worker cooldowns. Test instantaneous occupancy validation, simultaneous deployment/cap/payment, cliffs/bridges, crush, repair, friendly blockage, targetability, dismantling/destruction cleanup, and load mid-cooldown. Preserve authored neutral-obstacle IDs.

### 5.3 Helix Power Grid Overdrive

**Decision:** sacrifice electrical capacity to recover shields faster near a generator.

- Requires Plasma Shields research. Completed Flux generators gain a toggle and selected-state 12 m coverage radius.
- Each requested Overdrive adds **3 power demand**. While operating, recharge is 9 rather than 6 HP/s for the owner's eligible units within range. A generator supplies 12 power, so one Overdrive consumes a quarter of its output.
- Preserve the 5 s no-damage delay. No shield-capacity increase, hull healing, or instant refill. Multiple fields do not stack; allied players do not receive free coverage initially.
- Enable only when projected supply covers demand. If a later loss causes shortage, suspend all Overdrive bonuses but retain their requested demand; show “Suspended: low power.”
- Keep requests until toggled off or power returns. This avoids automatic power on/off oscillation and makes the production tradeoff explicit.
- Update local coverage at a bounded interval (initially 0.25 s). Losing range/generator removes the modifier on the next update.
- HUD shows toggle, demand, and affected count. Coils brighten while operating; suspended state remains visually distinct.

**AI/acceptance:** enable for damaged shields with spare power; disable during shortage to restore production. Test overlap, boundary movement, research, recharge delay, no toggle refill, generator loss, EMP, power suspension, and save/restore. Extend power/faction regressions.

### 5.4 Helix Kite — dedicated EW/recon drone

**Decision:** convert the Helix Kite to an unarmed electronic-warfare scout. It no longer performs suicide/dive attacks; other factions retain their current drones.

- Keep existing base cost, flight, and sight parameters initially. Remove Helix attack acquisition, attack/dive orders, warhead behavior, and offensive command-card entries; retain move/scout/support control.
- Add E Chaff, gated by a completed Signal lab. Initial values: 8 s active, 30 s cooldown, 10 m radius following the drone. Movement continues; death ends the field.
- Affect hostile `kind == missile` rounds targeting an allied unit inside coverage. Bullets, shells, rails, bombs, and unguided rockets are unchanged.
- During coverage, stop guidance updates but preserve velocity/motor/gravity/lifetime. Missiles can still hit or proximity-detonate; chaff does not delete projectiles or damage.
- Resume guidance outside coverage/after expiry if the original target remains valid. Overlapping fields add no strength.
- Use shared spatial coverage queries independent of rendering. Show restrained chaff/broken-lock cues; distinguish guided missiles from rockets in tooltips.
- Update faction description, HUD availability, AI scouting/escort behavior, and saved-action validation together. A converted archived Helix drone keeps its identity but loses any obsolete attack/dive action. Do not remove other factions' valid dive actions.

**Counterplay/acceptance:** use guns/unguided fire, kill the drone, or wait out the field. Verify Helix cannot acquire/execute a dive even through restored or AI-issued orders; other factions still can. Test existing/new missiles, moving targets/emitter, overlap, drone death, pause/save mid-field, and unchanged other weapons.

### 5.5 Frontier Concealed Scrap Mines and clearance

**Decision:** workers and Outriders lay traps; all units can detect them, but combat units require deliberate manual clearance. Workers provide fast automated area clearance.

#### Deployment and detonation

- Both Scrapper workers and Outriders deploy after a completed Relay workshop.
- Initial values: 8 Materials, 3 s deployment, 2 s arming, 1.5 m trigger radius, 2.5 m blast radius, 45 damage with linear falloff to 25%.
- Armor factors: infantry ×0.75, light machines ×1.0, heavy armor ×0.60. No added stun or suppression.
- Trigger on hostile grounded combat units, including infantry; exclude workers, aircraft, neutral traffic, and allies. Blast affects hostile ground units, not structures; no chain detonation.
- Minimum allied-mine spacing 3 m; cap 12 live/reserved mines per player. Reject exits, deposit interaction areas, event spawn reservations, and impassable ground. Mines do not block navigation.
- Swept crossing of the trigger radius starts a visible 0.35 s fuse at the mine position. Unless cleared first, it detonates against units still within the blast.
- Destruction or disarming clears the mine without explosion or resource refund.

#### Detection and combat-unit behavior

- Visible/attackable during deployment/arming; then concealed until detected. Owners/allies retain markers.
- All living non-garrisoned mobile units can detect enemy mines within range and terrain LOS, including aircraft. Initial ordinary detection distance: 6 m; workers: 12 m. Share detection with allies. Radar snapshots do not detect mines.
- Combat units do **not** auto-acquire, auto-clear, or automatically route around mines, even when detected. Existing move/attack-move orders continue and may cross them. AI follows the same rule; avoiding/clearing requires an explicit tactical order.
- A player can manually order a weapon-capable combat unit to attack one detected mine using its existing weapon/range/cadence. **One successful hit clears that mine.** Do not require multiple hits, a special short-range weapon, or a slow infantry disarm action.
- After that mine is cleared, do not automatically target another mine. Each requires a distinct explicit command. Normal non-mine combat targeting can resume.
- Physical splash can clear mines without granting knowledge of hidden positions; no automatic mine selection or chain explosion.

#### Worker area clearance

- Available to workers of every faction, not just Frontier. Explicitly designate a 12 m-radius area; the worker searches it, approaches known mines, and clears them sequentially.
- Initial disarm time: 1 s per mine within 3 m reach. Workers do not trigger mines, enabling safe approach.
- Use current observations/shared detections and actual traversal to discover remaining mines; never query concealed enemy mine positions as an omniscient target list.
- Finish once the reachable search area has been inspected and discovered mines cleared. Report unreachable portions instead of looping indefinitely. A new player order cancels/queues according to ordinary order semantics.
- Do not automatically interrupt harvesting/building merely because a worker sees a mine. The fast large-area behavior belongs to the explicit clearance order.

**Save/acceptance:** persist ownership/IDs, deployment/arming/fuse state, worker search area/progress/active target, and placement reservations; derive detection from restored observers. Test all-unit detection, terrain/elevation LOS, fast swept crossings, combat ignoring known mines, manual one-hit clearance without next-mine acquisition, worker multi-mine search/clearance/cancellation, hidden splash, worker death, alliance/owner elimination, and save mid-search/disarm/fuse. On elimination, remove remaining untriggered mines; committed fuses finish with frozen ownership.

### 5.6 Frontier permanent Scrap Armor and existing timed buffs

**Decision:** retain current salvage healing and timed offensive/mobility buffs, and add permanent percentage protection plus permanent two-tier plate visuals.

- Keep current mechanics: each scavenge repairs 35% maximum HP, adds one temporary stack up to two, and refreshes 60 s. Each temporary stack still gives +15% damage and +10% speed.
- Add an independent permanent scrap armor rank, 0–2. Each successful scavenge raises it by one until capped; waiting for the temporary buff to expire does not reset it.
- Initial permanent damage reduction: 5% per rank, capped at 10%, applied once in the normal incoming-damage calculation. It is not extra maximum HP or flat damage subtraction; compose it multiplicatively with other damage factors.
- First permanent rank reveals a small plate set; second reveals the full additional set. Both appearance and protection persist for the unit's remaining life, even after temporary buffs expire. Later scavenges do not add more geometry or permanent ranks.
- Limit to currently eligible Outrider, Ripsaw AA truck, and Ironback. Do not silently add Jackal scavenging. Newly produced/airdropped vehicles begin at rank zero.
- Generate plate groups through Frontier build scripts. Preserve joints, weapons, team markings, and selection. Damage-state rattling may animate the plates without changing protection.
- Store permanent rank separately from `scrap_hardened_tiers`/`scrap_hardened_left`. Derive visible plates from permanent rank; HUD distinguishes permanent protection from temporary damage/speed stacks.
- During required archive conversion, initialize permanent rank from any recorded active salvage stacks (capped at two); otherwise zero. Do not invent historical scavenges that old saves never recorded.

**Acceptance:** separate 0/1/2 permanent ranks and temporary stacks; single-hit reduction with other modifiers; repeat salvage at cap; timed buff expiry retaining plates/protection; repair, death/wreck, and restore before/after expiry. Inspect tactical-zoom readability and run prescribed model/weathering verification.

## Stage 6 — Delivery sequence and verification

Stage numbers group design topics. Implement in dependency order with playable, verified slices:

| Slice | Deliverable | Gate |
| --- | --- | --- |
| A | Cinematic-only camera impulses | Existing camera feel preserved; no Skirmish combat displacement |
| B | Suppression, posture, HUD, AI | Hero immunity, heavy near misses, direct-fire reduction, retreat and recovery |
| C | Simulation-timed grenades and breach | No timing mismatch, duplicate damage, trapped teleport, or lost orders |
| D | Faction damage and permanent salvage armor/plates | Readable factions; permanent versus timed state; repair/death cleanup |
| E | Bastion assembly/barricades | Queue/refund/departure and navigation invariants |
| F | Helix Overdrive and support-only Kite | Power/shields, guidance interruption, no Helix dive, other drones preserved |
| G | Frontier mines and area clearance | All-unit detection; no automatic combat avoidance/clearance; worker sweep |
| H | Automatic events plus Desert Frontier supply drop | Atmosphere, fair access, small one-time rewards, lifecycle saves |
| I | Industrial/coastal/alpine performances | Fair routes/rewards, one radar snapshot, multi-start playtests |
| J | Commander framework and barrage | Atomic payment, warnings, target legality, impact persistence |
| K | EMP and airdrop | Expiry, AA counterplay, population/landing races |
| L | Combined balance/accessibility/performance | Representative faction matchups and archive checks |

### Automated checks

- Add focused `SuppressionRegression.gd`, `GarrisonBreachRegression.gd`, `VehicleDamageVisualsRegression.gd`, `BattlefieldEventsRegression.gd`, and `CommanderCallInsRegression.gd` as features land.
- Add macro-specific tests for assembly, barricades, Overdrive/chaff, and mines rather than one monolithic dependency-heavy regression.
- Extend existing camera, abilities, garrison combat/exit, authored garrison, projectiles, power, technology, production, and AI regressions where behavior changes.
- Run relevant `SaveRestoreRegression.gd`, `SaveRestoreCombat.gd`, snapshot, and save-edge checks for each persisted feature. Save at transition boundaries. Reject invalid IDs, non-finite/negative timers, excessive counts, and impossible reservations.
- Use runtime `load()` in `--script` tests for source scripts that reference autoloads, per `AGENTS.md`.

### Rendered and playtest checks

- Run rendered previews without `--headless`. All HUD changes require `tests/rendered/HudConsolePreview.gd` captures for every faction in `art/hud-console/`.
- Capture suppression poses/icons, breach timing/exits, damage bands, plate stacks, chaff/mine detection, event stages, and all call-in warnings. Include normal zoom, dense selection, fog, reduced flashes, and supported window sizes.
- For generated model changes, run `WeatheringPreview.gd` and relevant `RichTexturesRegression.gd` contracts. Ground texture changes use generators and `TerrainLayersPreview.gd`.
- Fixed-seed scenarios: infantry crossing autocannon fire; full-garrison assault; low-power Helix retreat; detected/undetected mines and worker area clearance; repeated Bastion production with blocked exits; automatic events and optional collection; barrage evacuation; EMP assault; airdrop against/without AA.
- Play Bastion–Helix, Bastion–Frontier, Helix–Frontier, and mirrors from both sides. Include advanced starts and multi-start event maps.
- Record casualties, retreat success, event reward share, power uptime, call-in value, and whether the opponent understood the warning/counterplay.
- Compare frame time, projectiles, path rebakes, particles, and audio voices against the same seeded baseline. Establish a concrete regression budget from measurement before increasing effect density.
- Store evidence/tuning in dated `docs/playtests/` folders. Both mechanics and readability must pass; screenshots alone do not establish correctness, and headless tests alone do not establish usability.

## Balance validation priorities

The gameplay choices above are settled for implementation. Validate numerical tuning without silently reverting those choices:

1. **Suppression:** check heavy near-miss buildup/caps, hero immunity, 20% direct-fire reduction, and roughly 7 s recovery. Maintain control and normal retreat commands.
2. **Breach:** test 52.5 damage/full eviction with immediate retaliation and only 3 s re-entry lock. Do not restore the rejected stun.
3. **Helix:** verify the unarmed Kite is useful as reconnaissance/EW with its existing base cost, and that local Overdrive's 3-power tradeoff matters.
4. **Frontier:** tune permanent 5%/10% protection while keeping existing temporary buffs; test permanent plate readability and one-hit manual mine clearance versus automated worker sweeps.
5. **Bastion:** tune instant barricade cost/cooldown/cap, preserve routes, and test completed-unit production streaks against cancellation exploits.
6. **Pacing:** events should remain automatic atmosphere with small optional benefits. Validate 60 s first commander charge, 120–150 s repeat cooldowns, and 6 s turret disable against actual match lengths and team play.
7. **Persistence:** inspect conversions for Helix obsolete dive actions and separately saved permanent armor, preserving all archived unit/resource IDs.

### Implementation status and documentation scope

The decision record describes the delivered mechanics and initial balance defaults. The baseline source findings are retained as pre-implementation context. Delivery and verification progress is recorded below.

## Agent progress

- 2026-10-25: Read the original plan and inspected abilities, garrisons, projectiles, faction catalogs, power/production, map roster, camera, save integration, AI entry points, and existing regression coverage.
- 2026-10-25: Expanded every direction with proposed mechanics/tuning, counterplay, HUD/AI behavior, persistence, integration points, and acceptance criteria. Corrected stale names/paths and identified grenade timing, drone-role, and camera-policy gaps.
- 2026-10-25: Reviewed every direction with the user through Chinese question prompts. Recorded confirmed choices in the decision table and replaced conflicting earlier proposals throughout the mechanics, delivery gates, and acceptance criteria.
- 2026-10-25: Major revisions: heavy-fire near-miss suppression/hero immunity; breach without stun; automatic low-reward events/one radar snapshot; 6 s EMP; instant barricades; support-only Helix Kite; all-unit mine detection/manual one-hit attacks/worker area clearance; permanent two-tier scrap armor.
- 2026-10-25: Started the full implementation requested by the user. Parallel work covers infantry combat, field engineering, presentation/production, and shared commander/HUD integration.
- 2026-10-25: Focused suppression, garrison breach, camera, vehicle-damage, and assembly regressions pass. Generated faction models now include damage sockets and two permanent Frontier plate tiers. Shared persistence, HUD, events, AI, and combined verification remain in progress.

- 2026-10-25: Implemented all reviewed mechanics and shared integrations: suppression/breach, faction vehicle damage and camera discipline, assembly/barricades, Overdrive/EW Kite, mines/clearance/permanent armor, eight authored event maps, all three commander powers, AI, bottom-HUD input and Chinese localization.
- 2026-10-25: Advanced snapshots to version 21 and converted 811 archived saves. Independent audit preserved 29,764 unit ID/owner/role mappings and 13,040 resource ID/kind mappings; all 389 archived checksum records validate. Added full-state round trips for all three factions and blocked-breach queued orders.
- 2026-10-25: Real input and commander regressions pass, including F6/Q/Escape/right-click, pause/selection preservation, prerequisites, physical AA interception, population reservation, map-edge exploration, and turret action continuity through EMP. Dense-army presentation measurements and delivered behavior are recorded in [the verification report](../playtests/2026-10-25/gameplay-depth/verification.md).
- 2026-10-25: Completed all 36 headless suites, the 118-capture English/Chinese HUD matrix, and rendered suppression, vehicle damage, weathering, commander and map-event previews. Final review added explicit Overdrive low-power suspension text/core dimming and refined transport, crate and radar geometry; their relevant regressions and final Helix captures pass. Legacy garrison fixtures now respect the existing 15-second capture channel and isolate firing/exit checks from simultaneous capture crowding. Gameplay capture rules are unchanged. Implementation is complete; numerical tuning still needs representative human matches.
- 2026-10-25: Addressed the user's follow-up review. Healthy owned barricades ignore worker right-clicks; dismantling requires explicit `R`. Barrage now includes building footprints without widening mobile blast reach; a centered default HQ receives 189 damage and survives with 311 HP. Applied the approved initial tuning: Frontier airdrop 45 Materials / 15 Electronics with its 120-HP carrier retained, and Helix Overdrive +3 power with the existing five-second recharge delay retained. AI, HUD and Chinese text match these values. Both bugs have retained failing reproductions; all six relevant regressions and the complete 118-capture HUD rerun pass. Details and logs are in [the verification report](../playtests/2026-10-25/gameplay-depth/verification.md#user-review-fixes-and-initial-balance-adjustment).
