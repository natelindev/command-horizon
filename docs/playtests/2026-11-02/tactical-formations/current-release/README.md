# Resumed actual-release frame qualification

Actual game launches were explicitly reauthorized before these runs. Each uses the official macOS release template from frozen candidate4 runtime inputs, an empty bootstrap, the registered `TacticalFormationsMainLoop` fixture and a private review profile. The [manifest](manifest.json) records exact executable/PCK/native-helper hashes and the two fixture/profile configuration changes from the ordinary distribution. The editor is not used to execute the release measurements.

The workload keeps all200 Tanks selected and visible for240 actual rendered frames, at1280×720, normal overview70 and30Hz offline simulation, with VSync/frame caps disabled. Normal production effects and180 rendered frames warm before the terrain-click command. Frame0 includes synchronous command dispatch; every subsequent deferred activation and the QA observer remains in wall time. No frame time is subtracted, percentile substituted for maximum or workload reduced. Metal GPU timestamps are unavailable.

| Run | Command / p50 / p95 / maximum (ms) | Coverage and result |
| --- | --- | --- |
| [Low, full native](low-native.log) |11.892 /17.270 /20.700 /41.709|Actual release;200selected/visible;240/240foreground; activation200within100ms; zero timed pipeline changes. **Strict frame gate fails.** |
| [Low, default](low-default.log) |13.903 /25.245 /34.542 /45.355|Only79/240foreground frames and one pipeline change; **diagnostic**, not qualifying comparison. |
| [High, full native](high-native.log) |11.218 /23.557 /30.078 /51.299|Only15/240foreground frames and one pipeline change; **diagnostic**, not qualifying comparison. |

No other Godot/compiler process was present before each launch. All200 immediate intents are admitted and all activate within100ms, at most96per tick. The focused native Low run reaches200 moving bodies and retains200visible/selected throughout. Its longest frame is105; frame0 is39.803ms. Both the command-inclusive first frame and later frames exceed16.6ms. This does not close MI12.

The separate [native Low CPU/sampler diagnostic](low-native-cpu-sample.log) reports18.363ms main-thread CPU/frame,6.547ms process-callback CPU/frame and3.465ms physics-callback CPU/tick. The two-second1ms native sampler adds substantial overhead and loses focus; its109.545ms maximum is not an isolated comparison. [Raw stack samples](low-native-cpu-sample.txt) retain stripped engine addresses and native helper calls. Callback spans exclude SceneTree frame signals, deferred callbacks and engine work; residual CPU is not attributed solely to rendering.

The [editor script-profiler run](low-native-editor-script-profile.log) is diagnostic. Its refreshed measurement block begins after the second `BEGIN PROFILING`, separating startup from the sampled frame. It identifies articulated pose finishing, tracks/dust, selected-unit indicators, minimap synchronization and transient command geometry as review targets. Its debugger/profiler overhead and missing focus preclude release qualification.

[Per-run metadata](low-native-result.json), all other result JSON, rendered captures, the exact frozen fixture, runner and [artifact hashes](verification.json) are retained. Earlier performance attempts remain unchanged. No speedup is claimed between these configurations.
