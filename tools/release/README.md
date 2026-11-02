# Desktop release builds

Run `python -X utf8 tools/release/build.py` on the target desktop platform to
download the pinned Godot engine and export templates, build native support,
export the game, and validate the packaged resources. macOS builds a universal
ARM64/x86-64 helper; Linux builds for its host; Windows uses the pinned toolchain.
`RTS_RELEASE_PLATFORM` can explicitly select `windows`, `linux`, or `macos`;
otherwise the script uses the host platform.

To reuse local tools without downloading Godot or its templates, first install
the matching Godot 4.7.2 export templates, then pass the executable paths. For
example, in PowerShell:

```powershell
python -X utf8 tools/release/build.py `
  --godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' `
  --zig 'C:\Tools\Zig\zig.exe'
```

`--zig` applies to Windows builds. Omitting it retains the pinned toolchain
download and SHA-256 verification in `tools/build_native.py`.

The project is copied into a private staging directory before import. Source,
assets, imported resources and freshly built native support do not share mutable
files with the workspace. Derived `.godot/exported` resources are discarded;
asset imports are retained. This prevents stale converted resources from
surviving script-only default changes. The native solver's actual release-template startup
check uses a registered fixture main loop because release templates ignore
`--script`. The ordinary application separately reaches its real menu, observes
120 frames and exits through production cleanup; engine `--quit-after` bypasses
that path.

For an authorized headless-only continuation, use:

```sh
python3 tools/release/build.py --headless-only --native-backend \
  --godot /path/to/Godot \
  --source-root /path/to/immutable-project \
  --verification-output /path/to/new-verification-directory
```

`--headless-only` runs all standalone tests, archive validation, actual-template
headless startup, the dummy resource-lifetime check, the 1,152-case briefing
layout matrix and real multiplayer/replay checks. It blocks graphical engine
and Xvfb commands. The native-backend flag selects the supported native kernels,
unit state and crowd for checks without changing shipping defaults. Omitting it
uses the ordinary platform defaults.

The packaged standalone manifest currently contains 140 checks, including live
ownership and hidden-passenger minimap behavior. Before export, a separate
headless `RichTexturesRegression` source gate validates authoring texture-import
settings, ground layers, weathering and decal save/restore. Exported `.import`
files omit those authoring parameters, so this source check stays strict and
does not run against the package. Both full and headless workflows retain it;
its failures are recorded while independent verification continues.

The network workflow includes exact terminal-state receipts, concurrent result
teardown and a real host disconnect while its guest awaits confirmation. These
are real peer processes; shutdown services only terminal control packets for a
bounded interval, and ordinary in-progress exits do not wait for receipts.

Headless success is reported as `headless_checks_passed`. Graphical resource
lifetime, visual review and strict performance remain deferred. Review packages
go under `build/headless-review/<platform>/<run>/`, outside `release-assets`;
they are not fully qualified releases. The default full CI path retains its
actual OpenGL resource gate, using Xvfb/Mesa on Linux when required.

Every check retains a numbered log capped at 16 MiB and updates an atomic
`report.json` with its arguments, working directory, status and duration.
Timeouts stop the owned process family and preserve output. Archive, CPU-clock,
startup and standalone failures are collected while independent checks continue;
any failure prevents a successful package result. The report also identifies the
frozen source, engine, compiled native, signed executable/helper, exported pack
and final archive hashes. Headless review uses a
fresh private user profile. Failed runs retain that entire profile, including
diagnostics written directly under `user://`; successful runs retain test
artifacts and replays before cleanup.

Normal full-mode exports are written to `build/<platform>/`; checked archives
are written to `build/release-assets/`. Detailed verification logs stay outside
the package in `build/verification/` or the requested new directory. Build output
is decoded as UTF-8, including on Windows. Independent product/performance
acceptance remains separate from the builder's packaging checks.
