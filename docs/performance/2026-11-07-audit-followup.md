# Performance audit follow-up — 2026-11-07

Canonical state hashing now takes **10.21 ms instead of 63.96 ms** on the
200-mobile fixture, an **84% reduction**. Healthy 200-unit command refreshes
take about **25–30% less CPU time**, and the ability tray also costs less.
These are subsystem diagnostics, not proof of a 60/120 FPS gameplay target.

## Implementation

- The native C ABI extension serializes the existing sorted, tagged JSON format
  directly into an owned buffer and uses Godot's SHA-256 implementation. Hashes
  remain identical, including String/StringName keys, Unicode, integer types,
  IEEE-754 bits and root-only camera exclusion. Save/network versions are unchanged.
- Builders and readers prepare the stateless native helper on the main thread
  before detached worker jobs. Scratch memory belongs to each invocation. Depth,
  item, string and native allocation limits are bounded. Unsupported inputs use
  the portable encoder, which now sorts while encoding rather than deep-copying
  and canonicalizing the entire snapshot first. Invalid inputs return no checksum.
- The hash helper is independent of experimental simulation/render backends.
  A compatible installed native library enables it on standard-precision hosts;
  missing/older binaries and `--disable-native-kernels` retain the script path.
- Command buttons ask whether any unit can execute, stopping at the first valid
  recipient. A refresh shares those answers; actual order execution still builds
  a fresh full recipient list. Cargo/recovery scans reject empty carriers and
  healthy units before evaluating movement modifiers. Ability-tray scans validate
  each unit once and retain only the first issue string. Health totals update on
  dirty signals and selection changes, including maximum health and paused play.
- Campaign load diagnostics now run two complete tours, record node/resource
  counts and cache sizes after teardown, and use the normal audio-draining exit.

## Measurements

Godot 4.7.2 official editor/debug, Apple M1 Pro, macOS arm64. Baseline commit:
`9e20f97d094ed277b127c524ec01ead2bef05e19`. Network/HUD timing comparisons were serial, headless, without
fixed FPS. Campaign load durations are retained for diagnosis only; correctness
checks overlapped part of that retention run. Native runs used `--enable-native-kernels`; the portable
comparison used `--disable-native-kernels`. No workload, graphical quality,
physics cadence or gameplay behavior was reduced.

NetworkCaptureBenchmark: 200 mobiles, 212 total units, 12 samples. Both versions
produced 17,107-byte final deltas and 619,829-byte full encoded baselines.

| Stage | Before median (ms) | After median (ms) |
| --- | ---: | ---: |
| Main-thread capture | 9.48 | 10.09 |
| Schema validation | 25.58 | 25.05 |
| Delta | 0.65 | 0.65 |
| State hash | 63.96 | 10.21 |
| Packet encoding | 5.20 | 5.30 |
| Combined pipeline, reported p50 | 105.30 | 51.47 |

Combined reported p95 fell from 106.80 to 53.05 ms. The worker's elapsed median
fell from 252.21 to 210.72 ms; it includes additional encode/decode, replica-digest
and replay work plus scheduling. Main-thread capture is effectively unchanged.
The portable hash measured 58.43 ms, versus the original 63.96 ms.

HudSelectionProfile: 200 selected Tanks, 40 samples per state, caller-thread CPU
medians. The table uses the first final run; a second run is retained in the data.

| Wounded / Coordination | Buttons before → after (ms) | Tray before → after (ms) |
| --- | ---: | ---: |
| 0 / locked | 2.271 → 1.610 | 0.961 → 0.696 |
| 0 / unlocked | 2.536 → 1.870 | 1.342 → 1.113 |
| 100 / locked | 2.651 → 2.345 | 0.913 → 0.696 |
| 100 / unlocked | 2.867 → 2.609 | 1.327 → 1.119 |
| 200 / locked | 2.960 → 2.968 | 0.917 → 0.699 |
| 200 / unlocked | 3.252 → 3.278 | 1.322 → 1.174 |

The Move presence query costs about 0.006 ms instead of constructing the full
recipient list at about 0.52 ms. Healthy recovery checks fell from about 0.55 ms
to about 0.07 ms. Fully wounded armies still require per-unit mobility and reachable
service decisions; their button refresh is approximately unchanged. Do not sum
the separately profiled recovery/card/health subcalls into the button total.

Across 32 campaign loads, teardown returned to 14 nodes every time. The first
tour grew from 128.28 to 175.78 MiB after free, while the second ended at
177.75 MiB. Cached-resource count ended at 842 in both tours; the occlusion
surface cache grew from 383 to 673 entries (its existing cap is 1,024).
Both the original and enhanced load diagnostic exited without ObjectDB/resource
leak warnings on this run. This supports cache warm-up/retention, not the audit's
claim that 47.5 MiB necessarily represents leaked match nodes. No blanket cache
purge or speculative signal disconnection was added.

## Verification and limits

- Native/script/legacy hash parity on captured matches, reordered and typed keys,
  randomized nested data, Unicode/control characters, signed zero, precise numeric
  types, camera changes, immutable input, malformed/cyclic/oversized values and
  concurrent detached workers. Script fallback also passes.
- Command-card refresh, direct orders, ability tray, unit abilities, recovery
  reachability, selection batching/health/resource deposits, authoritative frames, network foundation
  and runtime shutdown regressions pass. Tests cover same-tick mobility, weapon,
  ownership, completion, death, resource and cooldown changes, plus keyboard focus.
- Real localhost host/guest/spectator session and replay verification: 4/4 passed.
- Native library builds for macOS arm64 and x86-64; runtime validation used arm64.
  Release Python checks: 26 passed. Changed production scripts pass formatting
  and lint; the editor import and whitespace checks pass.
- Rendered HudConsolePreview captured all three factions in English and Chinese;
  the bottom console and ability-tray captures were inspected. Its two Helix
  shield-shimmer assertions also fail against the unmodified baseline revision.
  Those pre-existing rendering failures remain outside this optimization.

Windows execution and whole-match rendered FPS remain unverified. The audit's
crowd-contact spikes, high-quality GPU load and main-thread snapshot cost remain
separate bottlenecks. Native hashing is substantially faster but does not meet
the audit's speculative sub-millisecond estimate.

## Reproduce

Build with `python3 tools/build_native.py` (`--universal` for both Mac slices).
Set `GODOT` to the local Godot 4.7.2 executable, then run:

```sh
"$GODOT" --headless --path . --script tests/headless/HudSelectionProfile.gd -- --enable-native-kernels
"$GODOT" --headless --path . --script tests/headless/NetworkCaptureBenchmark.gd -- --enable-native-kernels
"$GODOT" --headless --path . --script tests/headless/StateHashRegression.gd -- --enable-native-kernels
"$GODOT" --headless --path . --script tests/headless/StateHashRegression.gd -- --disable-native-kernels
"$GODOT" --headless --path . --script tests/headless/CampaignLoadBenchmark.gd -- --enable-native-kernels
"$GODOT" --path . --script tests/rendered/HudConsolePreview.gd -- --console-only
```

Retained samples and campaign records:
[audit-followup-results.json](2026-11-07-audit-followup-results.json).
Local full logs are in `tmp/performance-audit-followup/`.
