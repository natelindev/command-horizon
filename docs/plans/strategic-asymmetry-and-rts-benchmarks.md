# Strategic Faction Asymmetry and RTS Benchmark Evolution Plan

## Status and Design Intent

Design and implementation roadmap, 2026-11-01. This plan establishes the strategic evolution of **Godot Open RTS**, bridging the architectural gap between an open-source engine prototype and genre-defining RTS masterworks: **StarCraft II**, **Command & Conquer: Red Alert 2**, and **Age of Empires II**.

Current implementation, 2026-11-02: faction components, dedicated rosters, exclusive research, strategic AI, macro economy, tactical controls, command hubs, building collapse, scenario editing and authoritative multiplayer/replay have requirement-specific implementation and verification evidence. The complete combat voice bank, runtime faction mixes and briefing publication are audited. The frozen macOS `qualified-run-5` passes all 162 headless workflow rows: 140/140 packaged scripts, strict source texture validation, 811 archived saves/389 recorded checksums, 1,152 layouts/zero failures, six dummy lifetime instances, startup/clock checks and 14/14 actual multiplayer/replay checks. The [current report](../playtests/2026-11-02/headless-continuation/candidate5/report.json) includes the final command and six CPU query changes; [artifact verification](../playtests/2026-11-02/headless-continuation/candidate5/artifact-verification.json) confirms matching package hashes and zero source drift. ARM64 executed on macOS; the universal x86-64 slice was structurally checked only, without Windows/Linux execution claims. Candidate 4's pass and all failed workflows remain preserved. Normal and graphical launches remain prohibited under the renewed headless-only restriction. MI12 and final release acceptance remain open. The original 3D style remains the target; [static inspection](../playtests/2026-11-02/original-style-audit.md) found no global pixel-art conversion or saved benchmark graphics leakage. The [completion audit](benchmark-completion-audit.md) records each requirement and its evidence.

The core objective is to replace the historical 1:1 mirrored roster and uniform tech tree with three radically asymmetric operational playstyles:
- **Bastion Directorate (The Fortified Juggernaut):** High-armor, slow, entrenchment-based siege warfare inspired by Terran mech and Soviet armor.
- **Helix Systems (The Cybernetic Directed-Energy Swarm):** Shield-reliant, hover-skimming, beam-chaining precision army inspired by Protoss high-tech and Allied prism technology.
- **Free Frontier Coalition (The Scavenger Swarm & Guerrilla Raiders):** Fast, batch-produced, salvage-cannibalizing raiders inspired by Zerg mass-production, Yuri weirdness, and scrap mechanics.

---

## Architectural Principles Learned from Benchmark Titles

| Benchmark | Core System Mechanism | Application to Godot Open RTS |
| :--- | :--- | :--- |
| **StarCraft II** | **Macro Asymmetry & Distinct Production Engines** | Bastion uses dedicated worker construction; Helix uses "fire-and-forget" nanite projection; Frontier uses batch/pair unit production and frontline wreck cannibalization. |
| **StarCraft II** | **Shield vs. Hull Health Dynamics** | Helix units receive rapidly regenerating Plasma Shields (8 HP/s out of combat), forcing distinct hit-and-run kiting counterplay compared to Bastion's permanent hull attrition. |
| **Red Alert 2** | **Signature Gimmicks & Non-Generic Units** | Differentiate unit roles: Bastion gets deployable Siege Colossus artillery; Helix gets beam-refracting Prism Skimmers; Frontier gets mobile garrison flatbed trucks. |
| **Red Alert 2** | **Power Grid Interactivity** | Power is not just a static capacity check: Helix Flux Overdrive allows temporary localized shield/production supercharging at high power cost. |
| **Age of Empires II** | **Exclusionary Tech Trees** | Remove universal `weapons_1/2/3` and `armor_1/2/3`; give each faction mutually exclusive doctrines and specialized upgrade paths. |
| **AoE2 & SC2** | **Tactical Micro & Formations** | Expand unit navigation beyond single-point clustering to support line, flank, and spread postures against explosive splash weapons. |

---

## Multi-Stage Implementation Plan

The full-objective requirement/evidence ledger is maintained in [the completion audit](benchmark-completion-audit.md).

The latest user instruction permits headless implementation and verification only; normal and graphical launches are prohibited until later permission. The exact frozen macOS `qualified-run-5` passes its complete 140-script headless package workflow plus the strict source texture gate and all 14 actual multiplayer/replay checks, with final command and CPU query changes included. Before the renewed restriction, [passenger/32-briefing captures](../playtests/2026-11-02/graphical-resume/README.md) and [six actual OpenGL lifetime instances](../playtests/2026-11-02/graphical-resume/opengl/README.md) passed. The [earlier actual-release native Low measurement](../playtests/2026-11-02/tactical-formations/fact-reuse-release/low-native-result.json) retains 200 selected/visible units, 240 focused frames and zero timed pipeline changes: command 11.823 ms, frame median 13.984 ms, p95 16.887 ms and maximum 32.736 ms. It predates the final command changes and fails MI12's strict 16.6 ms maximum-frame requirement; further graphical qualification is deferred pending permission. Candidate 4 and candidate 3's terminal-receipt failure remain retained, and final integrated release acceptance remains open.

### Stage 1 — Core Component Traits Architecture
Status: **Implemented and verified**, including hidden mounted infantry and current-version save/restore.

Decouple faction traits from global multiplier tables into modular, extensible unit components in `source/match/units/traits/`:
- **`ShieldComponent.gd`**: Manages regenerating energy shields that absorb damage before health is impacted. Emits shield break and recharge events, renders floating cyan shield bars above unit health bars, and links with `VehicleDamageProfile.gd`.
- **`GarrisonMount.gd`**: Enables designated vehicles (e.g., Frontier Battle Rigs) to embark infantry units who can fire their individual weapons while the vehicle is in motion.
- **`AutonomousAssembly.gd`**: Modifies building placement so Helix workers spawn a self-assembling nanite beacon and immediately disengage to return to harvesting.
- **`BattlefieldSalvage.gd`**: Expands wreck interaction beyond material transport, allowing Frontier engineers to consume wrecks on-site to spawn light buggies or attach permanent scrap armor.

### Stage 2 — Roster Decoupling & Signature Units
Status: **Implemented and verified** across all three factions.

Break the 1:1 unit mirror in `source/match/FactionCatalog.gd` and create dedicated unit scenes:
- **Bastion Siege Colossus (`SiegeColossus.tscn`)**: Replaces the generic Advanced Tank. Deploys heavy stabilizers over 2.0s; fires high-arcing kinetic shells with heavy area splash damage. Cannot fire on the move.
- **Helix Prism Skimmer (`PrismSkimmer.tscn`)**: Replaces the generic hover tank. Fires continuous coherent laser beams that chain to up to 2 adjacent enemy targets, or refract through allied Helix turrets.
- **Frontier Battle Rig (`BattleRig.tscn`)**: Replaces the heavy tank with an armored flatbed mounting 4 garrison firing ports and dual forward autocannons.
- **Dedicated Anti-Air Divergence**:
  - Bastion: Flak halftrack firing bursting area-of-effect flak clouds.
  - Helix: Guided ion interceptor causing engine stall / thrust disablement.
  - Frontier: High-speed buggy firing unguided rocket swarms.

### Stage 3 — Exclusionary Technology & Doctrinal Trees
Status: **Implemented and verified**, including payments, queues, exclusions and saved research.

Refactor `source/match/research/TechnologyCatalog.gd` to abolish universal mirrored upgrades:
- **Hard Tech Exclusions**:
  - Bastion: Exclusive access to heavy composite plating, bunker reinforcements, and automated repair cranes; no directed-energy weapons or airborne cloaking.
  - Helix: Exclusive access to shield harmonic modulators, beam refraction grids, and instant hover thrusters; no heavy ballistic armor.
  - Frontier: Exclusive access to high-octane nitrous boosters, concealed IED density, and scrap cannibalization; no dedicated aerospace production facilities.
- **Branching Faction Doctrines**:
  - Command Lab provides mutually exclusive operational upgrades (e.g., Bastion *Iron Fortress* vs *Blitz Breakthrough*; Helix *Phase Shift Array* vs *Continuous Laser Amplification*).

### Stage 4 — Asymmetric Skirmish AI Archetypes
Status: **Implemented and verified** with faction-specific composition, research and tactical behavior.

Extend `source/match/players/skirmish-ai/` so AI commanders embody their faction's strategic doctrine:
- **Bastion AI**: Methodical advance, establishes fortified defensive outposts at expansions, rolls forward with heavy siege lines and dedicated repair support.
- **Helix AI**: Mobile harassment, utilizes hover units to cross shallow water/cliffs, engages in hit-and-run tactics, disengages when shields collapse.
- **Frontier AI**: Rapid map saturation, swarms resource deposits with inexpensive raiders, sets up ambush minefields along transit corridors, rapidly replaces lost units via batch production.

### Stage 5 — Interface, HUD & Feedback Polish
Status: **Implemented and verified** in English/Chinese, including the passenger console and direct power tray.

- Integrate shield bars into `HealthBar.gd` and the bottom console selection panel.
- Update `AbilityTray.gd` with signature faction active powers (Bastion Anchor, Helix Phase Shift, Frontier Overdrive).
- Display garrisoned squad members and their fire status within the bottom HUD vehicle cards.
- Update localization catalogs (`art/localization/factions.tsv`, `tactical-environment.tsv`) and compile via `build_catalog.py`.

### Stage 6 — Long-Term Engine Platform Gates (Multiplayer & Tooling)
Status: **Implemented with authoritative synchronization; current macOS ARM64 headless package verified**. Real host/guest/spectator sessions, reconnect, binary playback and exported scenario tooling pass. The frozen candidate 5's complete multiplayer/replay runner passes 14/14, including simultaneous terminal-result closure and a host disconnect while receipt confirmation is pending; candidate 4 and candidate 3's 11/12 failure are preserved. Commands use quantized typed intents and a 60 Hz authority boundary. Authoritative state playback is exact; command-only floating-point re-simulation still diverges and is explicitly documented in the [platform report](../playtests/2026-11-02/network-platform.md). The universal x86-64 slice is structurally checked only; this is not Windows/Linux execution verification.

- **Deterministic Simulation Foundation**: Isolate simulation math from float non-determinism in preparation for lockstep multiplayer.
- **Deterministic Input Replay Engine**: Implement binary command-logging (`.rtsreplay`) for match playback, spectator casting, and desync detection.
- **In-Engine Scenario & Map Editor**: Expose an in-game level builder utilizing the modular environment kits.

---

## Agent Progress

- **Exploration & Benchmarking Completed**: Conducted deep comparative analysis of `godot-open-rts` against StarCraft II, Red Alert 2, and Age of Empires II. Identified root structural issues: 1:1 mirrored rosters, uniform tech trees, absence of distinct macro engines, and lack of networking/replay infrastructure.
- **Living Game Design Updated**: Added Section 141 ("Strategic Faction Asymmetry & RTS Benchmark Evolution") to `docs/GAME_DESIGN.md` defining the architectural vision and faction identities.
- **Implementation Plan Formulated**: Created `docs/plans/strategic-asymmetry-and-rts-benchmarks.md` establishing a 6-stage roadmap for engine traits, roster decoupling, tech exclusions, AI doctrines, and long-term benchmark platform goals.


### 2026-11-02 — First implementation: operational traits

- Read the faction, macro economy, tactical navigation, narrative/presentation and benchmark roadmap specifications, plus their README, living-design and remaining-work references. Started with the roadmap's core trait stage; the later economic, formation and narrative stages remain queued.
- **Helix assembly:** added `AutonomousAssembly.gd`. An engineer must reach the paid foundation to deploy its beacon, then returns to harvesting or its queued orders. Assembly continues without workers, retains authored faction build times, pauses with the match, and resumes from saved progress. Human, Skirmish and simple-AI construction dispatch skip active beacons. Bastion/Frontier construction remains tethered.
- **Shields:** extracted authoritative charge, interception, EMP drain, break/recharge events and recharge timing into `ShieldComponent.gd`. Recharge now follows the specified 8 HP/s after five seconds without damage, retaining existing Overdrive multipliers. Cyan world shield tracks share the existing health-bar visibility settings; the bottom HUD retains its shield gauge. Existing role capacities and the Plasma Shields research gate remain until the roster/technology stage can rebalance hull and shield durability together.
- **Frontier salvage:** added `BattlefieldSalvage.gd`, retaining direct vehicle scavenging, permanent scrap armor and temporary buffs. Worker wreck orders reuse this trait; Scrap Cannibalization now grants exactly +50% wreck material yield and heals nearby friendly ground vehicles by 25 HP. On-site buggy creation remains open because it still needs a player command and valid spawn rules.
- **Mobile garrisons:** `GarrisonMount.gd` supplies four firing slots on the current Frontier AdvancedTank as the gameplay foundation for the later Battle Rig scene. Embarked infantry are hidden while retaining their individual weapons as the host moves; unloading and carrier loss restore their visibility. Unload, host loss and passenger save/restore use the existing order flow. Bespoke flatbed geometry, dual autocannons and passenger cards remain in the roster/presentation stages.
- **Persistence:** shield and salvage state retain their existing fields; autonomous assembly derives activation from paid construction progress. Mobile garrisons use an optional validated snapshot field, retaining the current snapshot version and existing archive validity.
- **Verification:** 24 targeted headless suites pass, including script/native mobile garrisons, visibility refresh, 26,772 native-state comparisons and all 811 archived fixtures. Six bilingual 720p/150% trait captures pass. The all-faction HUD matrix retains four existing 8 px research-deck height failures reproduced on the original HEAD; details and remaining scope are in [the implementation report](../playtests/2026-11-02/faction-traits/README.md).


### 2026-11-02 — Macro economy verified

- Completed faction harvesting profiles, forward refineries, exact-field macro abilities, Logistics, active power, neutral economic sites, saturation and timed contested deliveries. ME01–ME20 evidence is consolidated in [the macro report](../playtests/2026-11-02/macro-economy.md).
- Actual native optimal harvesting now exhausts home materials in 7–9 minutes across 30 faction/map cohorts. Fresh legacy homes retain node order/IDs, use safe short HQ arcs, and pass 308-deposit all-start Standard/Advanced navigation plus exact archived resource restoration. Campaign supplies and archived resource positions/amounts remain untouched.
- Corrected field balancing and the coastal Helix phase landing lane from measured behavior; the original 565-second coastal outlier now finishes in 454 seconds without a timing or supply override. Native supply-event renders show the authored locomotive and exact 50 M / 25 E hover reward. Bastion structure resistance/free perimeter maintenance and shield-hit audio have separate gameplay evidence. Combat voice and full narrated briefing generation continue independently; those narrative rows remain open until their complete audio audits pass.

- 2026-11-02: Published 80 role-specific critical-hull/kill recordings (872 total clips), preserving all prior recordings. Encoded cast/speech audits and native/fallback priority regressions pass. Three actual faction runtime mixes preserve nine exact speech transcripts with all stems, −3 dB ducking and no clipping. The OpenGL collapse cleanup defect is fixed by retaining per-instance scene templates; repeated headless/OpenGL teardown and collapse previews pass. Thirteen of sixteen complete narrated briefings are encoded; their final publication and the explicit instrument/style acceptance remain active.

- 2026-11-02: Required faction orchestration is now implemented with pinned CC0 recorded horn/trombone, continuously sliding sampled guitar and diatonic blues harp, plus original Helix arpeggio/sub synthesis. Three synchronized stems retain exact stereo sample counts; encoded headroom/loop/pitch/spectrum checks pass. The final full-native runtime mix verifies all nine live stream paths, nine exact speech transcripts and unclipped buses; subjective listening approval is explicitly unclaimed. Fifteen complete45–60s mission narrations are encoded; the final Coalition narration remains active.

- 2026-11-02: Published and independently audited all 16 voiced mission briefings (64 English paragraphs with bilingual captions), preserving all prior campaign/battle recordings. Actual encoded mission lengths are 45.1200–45.1627 seconds. Native and fallback complete-catalog regressions both pass all 16 operations, 64 paragraph IDs and per-mission real disk resume. The final narration asset queue is complete; strict 200-unit performance acceptance remains tracked independently.

- 2026-11-02: Mounted infantry remain hidden in ordinary/native rendering, visibility refreshes, saves and replicated state, with visibility restored on valid unloading or carrier loss. Command-card refresh retains controls/focus while reducing measured caller CPU. All owned graphical processes have exited. Further launches are headless only; complete graphical/performance/release verification is deferred until the user approves it.

- 2026-11-02 (headless continuation, intermediate snapshot): The expanded briefing layout matrix passes all 1,152 paragraphs across supported interface and caption scales. Refresh-local signature aggregation and command-local formation facts reduce measured caller CPU; shared per-frame ground travel fixes compound nudge/walking overruns while preserving vertical settling, phase relocation, hidden passenger handoffs and snapshot v22. Native/fallback focused checks and 750 native/script movement parity cases pass. The immutable 139-script package sweep is intermediate: normal-startup shutdown and control-group recall corrections must enter a refreshed final snapshot. No final headless or new graphical performance pass is claimed.

- 2026-11-02 (final headless candidate, launch): The final refreshed immutable `qualified-run-3` is running the complete 139-script headless package workflow with all diagnosed corrections included. Focused checks cover startup cleanup and hidden-passenger carrier selection; source/exported native/fallback tests verify restored faction exclusions. Release staging omits stale exported-resource caches. This candidate's full result is pending. Graphical/UI/OpenGL review and strict MI12 qualification remain deferred until later approval.

- 2026-11-02 (headless candidate 3 result): The frozen macOS `qualified-run-3` passed 139/139 standalone scripts, 811 archived saves/389 recorded checksums, six dummy resource-lifetime instances and all 1,152 layout cases without failures. Its complete report remains failed after the final multiplayer runner passed 11/12: the host did not receive the terminal acknowledgment before the guest disconnected. The failure is preserved while terminal-receipt delivery/retention is investigated. Headless qualification, graphical/UI/OpenGL review, strict MI12 and final release acceptance remain open.

- 2026-11-02 (headless candidate 4, launch): The corrected frozen `qualified-run-4` is running the complete 139-script and 14-check multiplayer/replay workflow. Exact terminal receipt confirmation and a bounded terminal-only ENet shutdown drain retain live sender/tick/hash validation, handle host loss and preserve immediate ordinary exits. Focused source/fresh-pack peer checks and native/fallback Foundation checks pass; the complete candidate result is pending. Candidate 3's failed report remains intact. Graphical/UI/OpenGL review, strict MI12 and final release acceptance remain deferred.

- 2026-11-02 (verification authorization): The user has authorized actual game launches. Graphical/UI/OpenGL review and strict MI12 verification are now authorized and pending; final release acceptance remains open. The frozen headless candidate 4 continues its complete 139-script and 14-check workflow, with no complete-pass claim before its actual final report. Earlier graphical restrictions and failed candidate evidence remain chronological records.

- 2026-11-02 (headless verification, current): The frozen macOS `qualified-run-4` completed with `headless_checks_passed`: 139/139 standalone scripts, 811 archived saves/389 recorded checksums, six dummy resource-lifetime instances, 1,152 layout cases/zero failures and 14/14 actual multiplayer/replay checks. The [retained report](../playtests/2026-11-02/headless-continuation/final/report.json) preserves the complete result and earlier failures remain intact. Graphical/UI/OpenGL review and strict MI12 verification are authorized and pending; final release acceptance remains open.

- 2026-11-02 (current headless-only boundary): Normal/graphical launches are again prohibited, while headless implementation remains authorized. The complete candidate 4 pass remains tied to its frozen snapshot before six separately tested CPU query changes. Actual passenger controls, all 32 bilingual briefing captures and six OpenGL lifetime instances passed before the renewed restriction. The fresh actual-release native Low run retains 200 selected/visible bodies across 240 focused frames and zero timed pipeline changes, with command 11.823 ms and median/p95/max frames 13.984/16.887/32.736 ms. The strict 16.6 ms maximum-frame gate fails; MI12 and final release acceptance remain open, with graphical qualification deferred pending permission. The [original-style audit](../playtests/2026-11-02/original-style-audit.md) preserves static rendering/defaults evidence without claiming the cause of an unseen user image.

- 2026-11-02 (current candidate 5 pass): The exact frozen macOS `qualified-run-5` passes all 162 headless workflow rows: 140/140 packaged scripts, strict pre-export source texture validation, 811 archives/389 recorded checksums, 1,152 layouts/zero failures, six dummy lifetime instances, startup/clock checks and 14/14 actual multiplayer/replay checks. The final command and six CPU query changes are included; [artifact verification](../playtests/2026-11-02/headless-continuation/candidate5/artifact-verification.json) confirms zero source drift and matching signed helper/executable/PCK/ZIP hashes. ARM64 executed; the universal x86-64 slice received structural checks only, with no Windows/Linux execution claim. Candidate 4 and all failed workflows remain preserved. Normal/graphical launches remain prohibited, headless work is authorized and original 3D style is retained. The earlier 32.736 ms maximum frame predates final command changes and leaves MI12 and final release acceptance open.
