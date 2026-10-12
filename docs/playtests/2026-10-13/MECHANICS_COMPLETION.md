# Mechanics and campaign completion — 13 October 2026

The requested mechanics work and subsequent map/campaign extensions are implemented. Existing models, textures, faction appearances and visual style are retained. New sites reuse the existing building geometry; story animation moves the existing camera. Original map paths and layouts remain available for archived battles.

## Completed mechanics

- Group movement packs reachable, separate destinations, including 100 mixed armor units at map boundaries. Mixed attack-move includes unarmed support. Explicit single-unit orders retain their destination.
- Automatic fire prefers effective counters and avoids spending extra shots on targets already covered by lethal allied projectiles. Manual targets and authored priorities remain authoritative.
- Resume retires the previous action immediately. Assigned guards can return observed fire into their area without pursuing outside it. Fresh presets use Best counter; existing program meanings and canonical hashes remain compatible.
- AI protects urgent paid defense before optional construction and selects builders at safe delivery boundaries. Cargo is preserved for emergency HQ rebuilding. Recovery chooses reachable services.
- Unstarted production departures can choose a new clear exit. Foundry's finite tank assembly leaves its production corridor open.
- Starting buildings face the bottom of the default battlefield view (+Z), including production doors. Saved orientations are retained. HQ delivery now finds body-clear approaches and ordinary outside waypoints around idle engineers, with unchanged contact range, collision and speed.

The three previously retained mechanics failures are resolved: the archived engineer delivers instead of being repeatedly diverted; Split Signal's preset guard strategy completes four response waves; Broken Foundry releases all six paid tanks. Original losing/failing evidence is retained in the [12 October report](../2026-10-12/MECHANICS.md). Current outcomes and logs are in [integration](integration/) and [reference playthroughs](continuation-reference/REPORT.md).

## Larger maps and capturable facilities

Three expanded maps are available in match setup; Expanded Desert Frontier is the fresh default. Existing saved setup indices continue to resolve to their original maps. The new maps are 192×144 or 192×156, each with eight resource fields totaling 6,600 materials and 4,320 electronics, plus six useful points of interest.

Infantry capture facilities within five meters over ten seconds. Opposing ground combatants suspend capture/services; armor, aircraft and engineers cannot take ownership. Each map has two of each facility:

| Facility | Benefit | Shared game rules |
| --- | --- | --- |
| Oil refinery | 2 materials / 1 electronics every 10 seconds | Finite stock: 600 M / 300 E; contest/recapture stops income |
| Mercenary camp | Paid Infantry, Rocket Infantry or Sniper recruitment | 25% premium, ordinary faction production time, three-contract queue, shared population cap, clear exits and refunds |
| Repair shop | Services two nearby ground machines | Existing repair rates, under-fire penalty and ownership/contestation checks |

The Sites overview provides camera View, displayed costs, recruitment and cancellation controls. Minimap markers identify public facilities and current owners. AI assigns one infantry detachment while retaining an opening screen, avoids observed danger, and recruits only after protecting priority production funds. Owned repair shops participate in direct recovery, programs and AI recovery. Ownership, capture progress, finite stock, timers, recruitment payments and active recovery references survive strict save/load.

[Map geometry/economy evidence](expanded-maps/REPORT.md), [facility UI evidence](point-of-interest-ui/REPORT.md), [HQ delivery evidence](HQ_DELIVERY.md), [the sequential Alpine route fix](FIELD_APPROACH.md).

## Campaign and narration

All six operations now form a continuous story through voiced openings, gameplay milestones and endings. Briefings animate the existing camera and offer immediate mouse/keyboard skip. They preserve prior camera, input, HUD, pause and reduced-motion preferences. Seen cues persist in saves; legacy saves resume their existing battle without replaying an opening. Critical combat warnings interrupt narration, and unit chatter returns afterward. Ending text remains readable in the bounded, scrollable debrief at 720p/150%.

Air Corridor and Command Horizon have operating enemy bases with resource-gathering workers, power and ordinary paid production. Raiding workers, power or producers changes reinforcement output. Bounded reinforcement groups preserve the authored encounter rhythm. Broken Foundry retains its finite paid production.

Command Horizon includes a siege commander using the existing advanced tank model and ordinary combat stats. Its observed target is locked to a ground point with a four-second warning; moving out of the three-meter area avoids the barrage. Barrages use normal damage rules, have a cooldown, and stop immediately when the commander dies. New finale saves preserve the encounter; older saves keep their original completion requirement.

The 52 shipped English/Mandarin voiceovers use the official Hugging Face [Kokoro English model](https://huggingface.co/hexgrad/Kokoro-82M) and [Kokoro Mandarin model](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh), replacing the operating-system voice draft. Clips play offline; model weights and synthesis dependencies stay outside the game. Pinned revisions, voices, text/file/model hashes and durations are in [the generation manifest](../../../assets/audio/campaign/generation-manifest.json). All three export presets now include the narration JSON catalog and manifest. An isolated exported-pack probe loads all 26 narration pairs, 52 playable streams and three expanded maps without source files. Sample transcription and non-silence/clipping checks also pass; these checks do not claim human listening approval.

[Story and speech evidence](campaign-story/README.md), [enemy base/boss evidence](CAMPAIGN_OPPOSITION.md).

## Verification and limits

**53 distinct headless suites pass with zero final assertion failures and no script errors.** Final integration results are recorded in [integration/summary.json](integration/summary.json), with raw logs and test/source hashes. The headless sweep covers movement, orders, targeting, recovery, economy, AI budgets/coordination, faction rules, programs, canonical archives and all campaign missions. Added suites cover sites, expanded maps, narrative state, paid enemy production, the boss warning/death/save path and bottom-facing starts. The final full-map matrix passes all 72 field returns and paid exits. A clear deposit route keeps its original destination; settled bodies can trigger a preventive detour, preserving both distant Alpine harvesting and delivery through frozen starting rosters. All 54 HQ fixtures and six paused waypoint archives pass.

Fresh ordinary standard-match references reach Victory for Bastion (412.63 s), Helix (541.97 s) and Frontier (386.68 s). Their strategy, faction stats and match timeout were unchanged during the final route fix. The earlier Helix non-outcome and all failed traces remain retained.

Rendered engine-input checks cover direct orders, all three starting factions, expanded map previews, the boss warning, bilingual briefings/debriefs and bilingual facility controls. The accepted UI captures use a real 1280×720 window at 150% scale. Accelerated startup captures that raced macOS window transitions are retained as harness diagnostics and excluded from acceptance.

Engine shutdown ObjectDB/resource/shader leak diagnostics remain in raw logs. The passing behavioral results do not constitute a leak-free export/release, universal balance, novice usability, subjective voice approval or device/performance acceptance. No unit damage, HP, movement speed or original combat price was adjusted for a scripted victory. Ordinary paid reference playthroughs are specific outcome evidence, not general win-rate claims.
