# Exported 200-unit audiovisual qualification

The macOS release pack ran all three factions at High and Low, with a fresh match per quality, actual production combat preparation, normal 30 Hz physics, uncapped real-time rendering and 1280×720 output on Apple M1 Pro / Metal Forward+. All six phases pass the workload and quality guards: 200 visible live combatants, 100 selected bodies, real weapons/audio and all 240 sampled frames in the foreground. The six captured images were visually reviewed for HUD-safe army placement and effect presentation. Full-visibility observer mode intentionally shows both commanders’ resource bars.

[Complete measurements](performance.json) and [clean runtime log](runtime.log) include process/thread CPU, render submission, actual simulation progress, draw calls and unchanged particle capacities. No shader/pipeline compilation occurred during any timed phase. GPU timing is unavailable on this Metal backend; its zero readings are not measured GPU cost. Observer time is included throughout.

| Faction / quality | Median ms | p95 ms | Maximum ms | Main-thread CPU ms/frame | Shots |
| --- | ---: | ---: | ---: | ---: | ---: |
| bastion / high | 20.276 | 28.886 | 35.787 | 16.060 | 429 |
| bastion / low | 7.974 | 26.858 | 37.931 | 13.292 | 333 |
| helix / high | 21.065 | 34.917 | 41.603 | 16.911 | 637 |
| helix / low | 9.005 | 25.838 | 44.521 | 14.138 | 501 |
| frontier / high | 19.849 | 26.093 | 33.137 | 15.585 | 502 |
| frontier / low | 8.003 | 24.025 | 31.458 | 12.688 | 384 |

The independent [unprofiled run](unprofiled-performance.json) also passes all six workload/focus/real-time guards and has zero pipeline compilation. These artifacts qualify the audiovisual/quality verification requirement. They do not satisfy the separate ≤16.6 ms formation maximum-frame requirement, which remains open. The original cold-effect stalls remain preserved as diagnostic histories; the production-prepared captures contain no frame above 100 ms.

Reproduce with the release build of `tests/rendered/BenchmarkBattlePerformance.gd`, `--av-output=/absolute/output`, `--profile-runtime` and these flags:

```text
--enable-native-kernels --native-unit-state --native-crowd-runtime
--native-presentation --native-pose-rigs --native-infantry-poses
--native-visibility-runtime --native-combat-queries --native-battlefield-index
--indexed-player-rosters --native-nearest-surface --native-exploration
```

Do not pass `--fixed-fps`, headless, diagnostic cold-effects or tracing options for qualified timings. The synthesis/ASR workers were paused for both captures; no other renderer ran. Actual networking verification had reached its idle host-expiry stage for the first run and was stopped before the CPU-profiled run. No timing samples were discarded or observer overhead subtracted. Native backends remain opt-in; this artifact does not promote the platform defaults.
