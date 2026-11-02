# Actual-release timing after local fact reuse

This run completed while actual launches were authorized, **before the user renewed the headless-only restriction**. Further graphical verification is deferred. Normal-play art and graphics defaults remain unchanged; this diagnostic deliberately selects Low at1280×720 and wide overview70.

The [actual release-template run](low-native.log) retains all200 Tanks selected and visible through240/240 foreground frames. Full native state/crowd/visibility/presentation bindings are asserted. All200 immediate move intents activate within100ms; the largest batch is96. No pipeline counter changes occur during measurement. The fixture requests foreground once after production prewarm/180frames and requires stable focus before admission; it does not steal focus during measurement.

| Measurement | Milliseconds |
| --- | ---: |
| Hungarian assignment |1.404|
| Projected plan |6.647|
| Complete terrain-click dispatch |11.823|
| Frame median |13.984|
| Frame p95 |16.887|
| Maximum / first frame |32.736|
| Second frame |24.773|
| Maximum after first two samples |17.829|

**The strict16.6ms maximum-frame gate fails.** Both the command-inclusive first frame and subsequent frames exceed it. The diagnostic tail is retained to locate work, without excluding any frame from qualification. The earlier description of17.829ms as the longest frame after frame0 was imprecise: frame1 is24.773ms.

Actual main-thread/process CPU averages12.467/15.911ms per rendered frame. Callback spans average4.089ms process CPU/frame and2.886ms physics CPU/tick; frame signals, deferred callbacks and engine work are outside those callback spans. Initial post-dispatch QA costs700µs. All QA remains inside wall-frame measurement. GPU timestamps are unavailable. This profiled run and the earlier unprofiled run differ in fixture admission and workload timing, so no controlled whole-frame speedup is attributed to individual changes.

The [manifest](manifest.json) pins the actual executable, pack and signed helper. The [overlay manifest](overlay-manifest.json) pins all source/test bytes: candidate4 assets/native code plus six runtime changes (tracks/wheels, invocation-local dust facts, minimap/ownership queries and selection map queries) and four fixture updates. Those deltas have focused native/fallback equivalence coverage; the previous complete139-suite report remains tied to its earlier frozen inputs. [Runner preparation](prepare.py.txt), the [exact measured fixture](TacticalFormationsRegression.gd.txt), [per-run metadata](low-native-result.json), [capture](low-native.png) and [artifact hashes](verification.json) are retained.
