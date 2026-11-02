# Headless continuation

The user currently permits **headless launches only**; normal/graphical launches are prohibited again. Preserve the original3Dstyle. The refreshed [candidate5 headless qualification](candidate5/README.md) now passes all162workflow rows, including140packaged scripts, the strict source texture contract and14actual network/replay checks. Its frozen inputs include all subsequent command/local-CPU changes, with zero completion source drift. During the preceding authorized interval, [native passenger/full briefing review](../graphical-resume/README.md), the corrected canonical renderer fixture and [actual OpenGL cleanup](../graphical-resume/opengl/README.md) passed. The [latest actual-release timing](../tactical-formations/fact-reuse-release/README.md) still fails the strict maximum-frame gate. Those rendered results predate the renewed restriction; future rendered checks wait for permission. Earlier candidates and failures retain their original input scope and evidence.

## Current command and package follow-up

[Command-local geometry/origin/heading reuse and canonical action lookup](../command-cpu/README.md) preserve exact200-unit endpoints and order serialization in both backends. All10focused native/fallback checks pass. A proposed Movement cache failed a rename case and was removed; the original component resolution, stop/cancel and post-feedback checks remain. Component call reductions are recorded, without claiming an overall command speedup from variable headless samples.

The complete [candidate5 report](candidate5/report.json) includes these final sources:140/140packaged suites,811archives/389checksums,1,152briefing cases,14/14actual network/replay checks, sourceRichTextures, ordinary/solver startup, clocks and six dummy lifetimes all pass. [Artifact provenance](candidate5/artifact-verification.json) verifies original report bytes, five retained recordings, signed package entries, zero source drift and preservation of candidate4. macOS ARM64 was executed; other-platform execution and fresh graphical/strict-frame qualification remain outside this result.

## Briefing layout matrix

The [source run](briefing-layout-matrix-source.log) passes all **1,152 paragraphs** with zero failures: 16 missions, English/Chinese, four paragraphs, three interface scales (100%, 125%, 150%) and three caption sizes (18, 22, 26).

The fixture asserts that each requested scale and caption size actually applied at physical 1280×720. Logical viewports are 1280×720, 1024×576 and 853×480. Captions, mission titles and Continue controls fit their dialogue panels; objective text remains within the viewport, exposes every line and stays above the dialogue. The minimum measured gap between objectives and dialogue is 16 logical pixels.

[Per-paragraph geometry](briefing-layout-matrix-source.json) and [source/artifact checksums](briefing-layout-matrix-source-manifest.json) are retained. This extends the earlier compact-layout regression without replacing its original failure and clean 128-case evidence. The matrix writes to a writable output directory and can run against an exported pack; it rejects use with a graphical display.

```sh
Godot --headless --path . --fixed-fps 60 \
  --script res://tests/rendered/CampaignBriefingCatalogPreview.gd -- \
  --layout-only --layout-matrix --output-dir=/absolute/writable/directory
```

The actual pack run and remaining headless release checks are tracked separately in the [release review](../release-readiness-review.md). No screenshot or rendered frame timing was produced by this matrix.

## Ability tray CPU

The tray now builds one temporary index of group cooldowns per refresh and reads controlled units in a single pass. A click resolves its recipients again, so removed units are rejected and newly eligible units can participate. The [measured 200-unit case](../ability-tray-refresh/README.md), with 33 retained groups, reduces median caller-thread CPU from 2.703 to 1.554 ms for signature gathering and from 4.001 to 2.766 ms for the complete tray refresh.

Native and fallback regressions pass live cooldown/membership changes, fresh click recipients, paused process frames and actual v22 snapshot restore. The index does not survive a refresh or alter the refresh cadence. These function measurements do not establish the rendered frame budget.

## Formation planning and shared ground movement

The planner now reuses member facts within each synchronous command, preserving assigned destinations and all navigation checks. The [headless diagnostic and regressions](../tactical-formations/README.md#headless-cpu-and-ground-travel-follow-up) measure median caller CPU of 46.145 → 40.981 ms for a boundary-heavy 200-unit plan. This workload differs from the earlier release benchmark. An empty mass-contact index also returns before searching empty cells.

Verification exposed a separate movement bug: an allied nudge and the affected unit's own walking callback could spend two independent movement allowances in the same tick. Native and scripted reproductions moved 0.163334 m against a 0.103333 m limit. They now share one transient planar allowance per physics frame. Ground settling retains its vertical step, and phase relocation and actual garrison embark/unload reset the allowance. Both backends pass the original mixed-army route with its strict speed bounds, same-tick compound movement, vertical settling and hidden passenger handoffs; native/script parity passes 750 cases. Snapshot v22 remains unchanged.

## CPU-clock fixture correction

The first immutable package attempt passed import and all 811 archives/389 checksums, then stopped at the CPU-clock fixture. That fixture included an invalid absolute ordering comparison between separately sampled process and caller-thread clocks. The sampler and native implementation are unchanged.

The [corrected source run](cpu-clock-corrected-source.log) records process/thread samples of 842602/845843 μs followed by 913110/916334 μs: absolute process time is lower, while each clock advances correctly during the workload by 70508/70491 μs. Sleeping consumes 40 μs of caller CPU over 46914 μs of wall time. The fixture now compares each clock with its own prior value and retains the workload, monotonicity and sleep-accounting checks. The [earlier raw run with the original assertion](cpu-clock-original-assertion-source.log) and [source/log checksums](cpu-clock-source-manifest.json) are retained as well.

The original failed package attempt and its user profile remain intact under `build/verification/macos/headless-20261102-resume/qualified-run/`. The intermediate immutable `qualified-run-2` completed all 139 standalone scripts: 135 passed, with four failures covering deployment diagnostics and exported faction exclusions. Its forced-exit startup also failed. Archive validation, dummy resource lifetime, all 1,152 exported-pack layouts and the actual multiplayer/replay runner's 12 checks passed. The attempt remains marked failed, with its original source snapshot, logs and user profile retained.

A separate `qualified-run-3` completed all 139 standalone scripts successfully after incorporating those corrections. Archive validation (811/389), ordinary and solver startup, dummy resource lifetime and all 1,152 packaged briefing layouts also passed. The final multiplayer/replay runner passed 11/12: the host missed the terminal acknowledgment when the guest immediately closed, despite both peers recording the same terminal tick and hash. The complete workflow remains marked failed and its evidence is retained. Terminal receipt delivery and shutdown ordering are being corrected before another coherent candidate; graphical resource lifetime, visual review and strict performance remain deferred.

The receipt correction is frozen in `qualified-run-4`. Its [complete report](final/report.json) passes all **139 standalone scripts**, all **14 actual network/replay checks**, all **811 archives/389 checksums**, ordinary and numerical-solver release-template startup, six dummy-renderer resource-lifetime instances and all **1,152 packaged briefing layouts**. All160workflow rows pass. The [artifact verification](final/artifact-verification.json) independently checks retained report bytes and executable, pack, helper and ZIP provenance. The frozen source, tests, tools, assets and native headers matched the workspace at qualification. Subsequent canonical fixture and local CPU changes have their own focused evidence; a new coherent headless candidate is required for those later inputs. Actual graphical review and strict frame timing retain their separate scopes.

## Ordinary startup and shutdown

The actual release-template startup was being stopped by `--quit-after 120`, bypassing the game's audio drain. A [verbose forced-exit run](startup-diagnosis/forced-exit-verbose.log) identifies the four retained objects as menu Ogg stream/playback resources. A [comparison using the existing cleanup path](startup-diagnosis/graceful-exit-verbose.log) exits cleanly after the ordinary menu and 120 process frames. Both use byte-identical exported executable, pack and native helper, with fresh private profiles; [forced](startup-diagnosis/forced-exit.json) and [graceful](startup-diagnosis/graceful-exit.json) metadata retain their hashes. The external [diagnostic observer](startup-diagnosis/GracefulExit.gd) only waits for the menu and calls `Globals.quit_game()`.

The release template does not support selecting a test script or main loop through its CLI, as recorded in its [actual help output](startup-diagnosis/actual-template-help.log). The final candidate therefore adds an explicitly requested headless startup smoke path after normal menu readiness. It waits 120 frames, asserts the same ordinary menu remains ready and uses normal cleanup. The builder requires its completion marker and still rejects fatal output, leaks, nonzero exits and timeouts. [Twenty tooling contracts](python-release-contracts.log) pass, including isolation of the derived export cache from imported assets.

## Deployment diagnostics

The [intermediate pack failure](unit-info-intermediate-pack-failure.log) exposed a stale diagnostic fixture expecting the retired Helix artillery deployment behavior. Removing its obsolete tracked stabilizers had also removed the deployment caption entirely. The F1-only caption now reports the actual Bastion siege deployment state independently of geometry, and the fixture uses its canonical faction scene and owner.

Unit info passes in [native](unit-info-native.log) and [scripted](unit-info-fallback.log) runs. The existing exact charge-geometry contracts also pass in [native](charge-geometry-native.log) and [scripted](charge-geometry-fallback.log) runs. [Source/log checksums](unit-info-source-manifest.json) identify these focused checks; no new graphical review is claimed.

## Hidden passenger selection

[Current passenger evidence](../tactical-formations/README.md) covers control-group recall and direct selection resolving mounted infantry to their live same-owner vehicle, deduplicating shared cargo and preserving ordinary group members and passenger orders. Actual replica mounting also normalizes an existing passenger selection while preserving unrelated selections and emitting no remote commands. Occupants stay hidden through these updates and become selectable normally after unloading. The original five-failure group and four-failure replica reproductions are retained alongside passing native/scripted checks.

The real Select All handler also reproduced an Array/Set interface error. Its caller now supplies the established Set type. Native/scripted checks cover empty armies, worker/building exclusion, ordinary combat units and mounted-carrier deduplication. Stationary bunker selection behavior retains its passing regression.

## Faction exclusions in exported resources

The intermediate package's non-Bastion refinery portrait failures exposed missing faction exclusion lists, including Frontier aerospace restrictions. Source loading preserved the authored lists, while a clean minimal exported project lost them. Explicit `PackedStringArray()` defaults preserve those values in the converted resource. A second probe confirmed that an existing derived export cache could still reuse the old resource after the script-only correction; release staging now excludes `.godot/exported` while retaining independent imported assets.

The [export investigation](../roster-export/README.md) retains the original failures, minimal before/after reproduction, stale-cache failures and clean fresh-pack checks. Native and scripted HUD production, faction asymmetry and Frontier air-contract tests all pass against the corrected pack. The native HUD checks require actual worker state/crowd bindings in all three factions. Every legal production portrait/name/cost assertion remains in place; the fixture now also checks excluded structures and units and the actual build menu. No roster data, portrait assets or save schema were changed.

## Terminal receipt and concurrent result shutdown

The [failed complete attempt](attempt3/report.json) retains the original 139/139 standalone pass and 11/12 network result. A guest could queue its exact terminal acknowledgment and immediately close ENet before the host consumed it. Merely retaining an already accepted receipt did not ensure delivery.

The host now confirms the exact validated terminal tick/hash. Completed-match shutdown services only bounded final receipts, with a one-second deadline and 128-packet cap; the host keeps servicing its queued confirmation until peers leave or the deadline expires. Ordinary in-progress shutdown bypasses this drain. Connection identity/status checks after polling prevent access to a host ENet has already cleared. Invalid senders, ticks, hashes, fields and unvalidated frames cannot acquire confirmation.

The ordinary outcome fixture waits for an exact guest acknowledgment so both result states exist, then closes the host without waiting for disconnect; the guest closes immediately after its own result. A separate actual host-drop case withholds confirmation while a guest receipt is pending and requires bounded, error-free teardown without a false confirmation. The full runner now includes 14 checks.

[Final focused checks](terminal-receipt/final-focused-checks.json) retain passing native/scripted Foundation coverage, ten source peer checks and twelve fresh-pack peer checks, with [exact source/PCK provenance](terminal-receipt/final-focused-provenance.json). Earlier probes, the readiness failure and real 30-second host-loss/expiry checks remain separately preserved. Independent review found and verified the post-poll transport guard. The subsequent complete candidate-4 workflow passes all 14 actual network/replay checks; normal host drain takes 2 ms and the guest confirms its receipt before a 1 ms drain.
