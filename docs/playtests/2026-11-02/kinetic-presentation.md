# Kinetic presentation verification — 2026-11-02

Completed structures leave a persistent ruin when destroyed. Critical sparks and foundation fires precede a 1.5-second gravity-shaped collapse; settling emits rolling dust and scatters concrete fragments. Charred faction geometry remains on the map, with smoke for 30 seconds. The ruin blocks navigation and gives nearby infantry 20% directional protection against small arms. Engineers salvage it with a two-second channel; heavy vehicles can clear it without earning scrap. Construction cancellation produces no ruin.

Ruin identity, source faction/role, health, collapse age and salvage amount survive current-version saves. Reloading a settled ruin does not repeat its failure burst. A saved collection channel resumes without paying early or paying twice.

Bastion cannons now drive a separate analytic suspension spring in `ChassisMotion`, recovering after 0.4 seconds. Recoil follows the turret's firing direction and never writes the simulation transform. Heavy shells emit a quarter-second muzzle refraction ring and heat shimmer; compatibility rendering uses a translucent ring, verified in a separate OpenGL capture pass. Both share the existing six-shockwave budget and reduced-flashes control. Ground displacement dust and bounded barrel-heat sleeves remain active.

Scorch marks fade linearly over 180 seconds, including when ground wear rendering is disabled. Their remaining lifetime persists in saves; pause freezes the clock. Existing small-arms infantry falls retain varied directional poses, while direct explosive hits add an outward slide and airborne impulse.

## Verification

Godot 4.7.2 on Apple M1 Pro, Metal Forward+. Native runs use `--enable-native-kernels --native-unit-state --native-crowd-runtime`.

| Check | Result |
| --- | --- |
| StructureCollapseRegression | All three factions; intermediate fall, paused clock, damaged ruin save/restore, cover direction and actual damage facts, navigation obstacle, partial salvage channel, exact payout and vehicle clearing; 0 failures |
| StructureCollapsePreview | Ten 1280×720 captures at 150% interface scale: three destruction stages per faction plus a real cannon projectile; 0 failures, camera transform unchanged |
| UnitAnimationRegression | Script and full native checks include 0.4s barrel/chassis recovery, root/health/weapon-charge invariance and outward explosive infantry impulses; 0 failures |
| ScorchLifetimeRegression |180s lifetime, midpoint save/restore, invalid timer rejection, pause, expiration with tracks preserved and disabled-render aging; 0 failures |
| BattleAftermathRegression | Existing bounded effects and aftermath contracts; 0 failures |
| MobileGarrisonRegression | Full native binding assertions, hidden passengers, moving fire, unload/death/save behavior; 0 failures after presentation integration |

Reviewed [collapse/cannon captures](../../../art/structure-collapse/). Logs are retained in [kinetic-presentation/](kinetic-presentation/). The strict 200-unit audiovisual performance gate is tracked separately and remains open. The OpenGL compatibility preview passes all feature assertions but Godot reports six texture cleanup leaks at shutdown (about2MiB total); the Metal pass exits cleanly.
