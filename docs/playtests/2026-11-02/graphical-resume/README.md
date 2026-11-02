# Passenger HUD and complete briefing renderer review

The corrected [English Frontier passenger console](passengers/frontier-en-1280x720-ui150-native.png) and [Chinese console](passengers/frontier-zh_CN-1280x720-ui150-native.png) both render at actual **1280×720**, with **150% interface scale**. Four direct passenger cards, portraits, names/costs, status and unload controls fit inside the bottom console. Chinese controls use their imported translations. [The actual renderer run](passenger-render.log) exits 0; [native state evidence](passengers/native-state.json) records live CopperfinUnitState, crowd and CopperfinPresentationBatch bindings. Every mounted root and Geometry is hidden, only the carrier is selected, and all 64 native passenger pose rows per capture are entirely zero. Both images were visually reviewed; no mounted infantry body appears on the vehicle.

All **16 missions × English/Chinese** have new [full-size briefing captures](briefings-final/) at actual **1280×720**, 150% interface scale and subtitle size 26. The logical canvas remains **853.333×480**. The [final actual-renderer log](briefing-final-render.log) exits 0 with **128 paragraphs and zero failures**. The unchanged base fixture checks every paragraph's title, caption lines, objective wrapping, panel/viewport bounds and Continue control; each saved image selects that mission/locale's largest caption. [All measured geometry](briefings-final/layouts.json) and [eight review sheets](final-review-sheets/) are retained. All 32 final images were visually reviewed: mission/title, objectives, captions and Continue controls fit without overlap or clipping. The log retains one nonfatal macOS IMK mach-port diagnostic; no Godot/script/layout error occurred.

These runs use the official Godot 4.7.2 editor, Metal 4.0 Forward+, Apple M1 Pro, and the current source tree. **No PCK was used.** [Before-run provenance](provenance-before.json), [691 source/input hashes](source-files-before.json) and [complete verification/artifact hashes](verification.json) record the exact inputs and commands. None of those source/input hashes changed during review. The ARM64 helper is SHA256 **b4ad2c825feeb8347267c4ec4b802e5ec2921d8e4c6c69c3507b26f852cadc27**. Only documentation fixtures and artifacts were added; runtime, canonical fixtures, native code and assets stayed frozen. All owned graphics processes exited. Concurrent package checks make these visual results unsuitable for performance qualification; strict MI12 remains open.

## Retained fixture corrections and failures

The [docs-only passenger fixture](PassengerNativePreview.gd) extends the existing HudConsolePreview and adds native-binding, hidden-body and zero-palette assertions before delegating to its existing raster/layout/localization capture. The pre-existing English image was actually3456×2168; its [original bytes](historical-hud/frontier-720p-passengers.png) and the [original Chinese image](historical-hud/frontier-720p-zh-passengers.png) are preserved before the standard art output paths were refreshed.

The canonical briefing fixture initially used `CONTENT_SCALE_MODE_VIEWPORT`, producing [32 images at853×480](briefings/) and [125 raster/root failures](briefing-render.log). The [docs-only corrected fixture](BriefingRasterPreview.gd) uses production canvas scaling and settles the physical window before each mission. Its first canvas run produced [32 correct-size images](briefings-canvas/) but [128 guard failures](briefing-canvas-render.log), because the canonical guard truncated853.333 to853. The [pre-correction derived fixture](briefing-canvas-rounding-before.gd.txt) is retained. The final derived guard compares actual logical size to untruncated physical size divided by interface scale, preserving every physical-raster and text-bound assertion. After the frozen package run completed, the [canonical fixture correction](canonical/README.md) received its own clean1,152-case headless matrix and32-capture/128-paragraph renderer check. Its original bytes, final patch, transient renderer pause and final results are retained separately.

## Final briefing captures

| Operation | English | 中文 |
| --- | --- | --- |
| Supply Line | [EN](briefings-final/supply_line-en.png) | [中文](briefings-final/supply_line-zh_CN.png) |
| First Orders | [EN](briefings-final/first_orders-en.png) | [中文](briefings-final/first_orders-zh_CN.png) |
| Split Signal | [EN](briefings-final/split_signal-en.png) | [中文](briefings-final/split_signal-zh_CN.png) |
| Bastion: Cinder Ford | [EN](briefings-final/bastion_cinder_ford-en.png) | [中文](briefings-final/bastion_cinder_ford-zh_CN.png) |
| Broken Foundry | [EN](briefings-final/broken_foundry-en.png) | [中文](briefings-final/broken_foundry-zh_CN.png) |
| Command Horizon | [EN](briefings-final/command_horizon-en.png) | [中文](briefings-final/command_horizon-zh_CN.png) |
| Quiet Streets | [EN](briefings-final/helix_quiet_streets-en.png) | [中文](briefings-final/helix_quiet_streets-zh_CN.png) |
| The Gate | [EN](briefings-final/helix_the_gate-en.png) | [中文](briefings-final/helix_the_gate-zh_CN.png) |
| Helix: Cinder Ford | [EN](briefings-final/helix_cinder_ford-en.png) | [中文](briefings-final/helix_cinder_ford-zh_CN.png) |
| Pruning | [EN](briefings-final/helix_pruning-en.png) | [中文](briefings-final/helix_pruning-zh_CN.png) |
| Severance | [EN](briefings-final/helix_severance-en.png) | [中文](briefings-final/helix_severance-zh_CN.png) |
| Drainage | [EN](briefings-final/frontier_drainage-en.png) | [中文](briefings-final/frontier_drainage-zh_CN.png) |
| Frontier: Cinder Ford | [EN](briefings-final/frontier_cinder_ford-en.png) | [中文](briefings-final/frontier_cinder_ford-zh_CN.png) |
| Salvage | [EN](briefings-final/frontier_salvage-en.png) | [中文](briefings-final/frontier_salvage-zh_CN.png) |
| Wren | [EN](briefings-final/frontier_wren-en.png) | [中文](briefings-final/frontier_wren-zh_CN.png) |
| The Coalition | [EN](briefings-final/frontier_the_coalition-en.png) | [中文](briefings-final/frontier_the_coalition-zh_CN.png) |
