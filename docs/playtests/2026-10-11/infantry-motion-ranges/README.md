# Infantry motion and engagement ranges

All five infantry classes across Bastion, Helix, and Frontier use a shared articulated human body, rounded cloth limbs, visible faces, bent weapon grips, independently phased distance-driven strides, planted stance feet, upper-body breathing/recoil, and class equipment attached to the chest. Ownership colors remain on shoulder, chest, and helmet patches. Heroes retain their equipment and aura.

The firing line now has higher avoidance priority than arriving units, so the rear ranks yield around stationary shooters instead of pushing them toward the enemy. A movement order releases that priority. Attack-move acquisition runs at 0.1 s intervals to reduce overshoot at the firing boundary.

## Range changes (metres)

| Weapon / role | Before | After |
| --- | ---: | ---: |
| Assault infantry | 3.5 | 5.5 |
| Rifle infantry | 4.5 | 7 |
| Rocket infantry | 6.5 | 10 |
| Sniper infantry | 9 | 13 |
| Bastion / Helix / Frontier hero | 6 / 9 / 5 | 9 / 13 / 8 |
| Tank / helicopter | 6 | 9 |
| Heavy tank (Bastion, Frontier) | 8 | 12 |
| Helix heavy tank | 10 | 14 |
| Bastion / Frontier autocannon | 5.5 ground / 4.5 air | 8 ground / 6.5 air |
| Helix walker | 8 precision / 5.5 interception | 12 precision / 8 interception |
| Ground / air turret | 8 | 12 |

Sight ranges and English/Chinese weapon descriptions were updated with these changes. Visibility and line-of-fire restrictions still apply.

## Verification

12 regression suites passed: InfantryMotionRegression, InfantryHeroesRegression, UnitMotionRegression, CombatRegression, WeaponModeRegression, FrontierCombatRegression, PreparationRegression, AttackMoveArrivalRegression, AttackCrowdedArrivalRegression, CrowdBoundaryRegression, NavigationRegression, and LocalizationRegression. Logs are alongside this file.

The new regression exercises all 15 infantry class/faction rigs and 33 armed role/faction range boundaries. It checks knee articulation, foot height and sole orientation, stopping, chest movement, muzzle alignment, ownership colors, and gameplay-transform isolation. Six eight-soldier tests cover attack-target and attack-move orders in all three factions. Final nearest firing distances were 6.29–6.70 m, with 6–8 soldiers firing after five simulated seconds. Before raising stationary-shooter avoidance priority, the same extended-range squads compressed to approximately 5.2–5.4 m. Priority release on movement is also checked.

All source GDScript passes `gdformat --check` and `gdlint`; changed test scripts pass lint. Existing regression harnesses may print resource/RID cleanup warnings at exit; assertions and exit codes passed. Full-match balance, every campaign encounter, and maximum-population performance were not audited.

## Visual review

Actual Godot Metal renders were inspected for all three factions at idle and mid-stride. `infantry-motion.mp4` is a three-second in-place gait preview at 30 fps. The production animation is driven by real movement distance and blends to a planted stance when stopped.

Reproduce:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/headless/InfantryMotionRegression.gd --fixed-fps 60
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --script tests/rendered/InfantryMotionPreview.gd
```
