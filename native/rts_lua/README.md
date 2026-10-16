# RTS Lua native runtime

A narrow Godot GDExtension, built and tested on macOS arm64 with Godot 4.6. It passes plain copied values between Lua and GDScript. It does not bind Godot objects into Lua. Built-in programs remain GDScript; the native runtime and game action adapter are implemented, with custom/visual editors, versioned libraries and the desktop arena now integrated.

## Build

Requires Python 3.12+, a C/C++ compiler, SCons, and the platform SDK. The optional credential bridge also builds Objective-C++ on macOS and links Security, CoreFoundation and LocalAuthentication; Windows links Advapi32. Credential methods are never exposed to Lua. Run from the repository root:

```sh
python3 native/rts_lua/fetch_dependencies.py
uv tool run --from scons==4.11.1 scons -C native/rts_lua platform=macos arch=arm64 target=template_release build_profile=build_profile.json -j 8
```

The fetcher verifies SHA-256 before extraction, applies the recorded Lua fix and refuses to overwrite an unrecognized existing dependency directory. Downloads/object files and native outputs are ignored by Git. The generated `.gdextension` file is registered only after the library exists: Godot 4.6's macOS missing-library path crashed during validation, so a fresh source checkout must not carry an auto-loaded manifest pointing to an absent binary. Run the build before opening Godot to enable Lua. Missing runtime support is reported by `LuaRuntime.available()`/`compile_source()`; ordinary presets do not depend on it.

For the universal macOS export, also build the x86_64 library:

```sh
uv tool run --from scons==4.11.1 scons -C native/rts_lua platform=macos arch=x86_64 target=template_release build_profile=build_profile.json -j 4
```

The v0.11.0 release builds and validates native libraries on Linux x86_64, Windows x86_64 and macOS (both arm64 and x86_64 libraries). Build the library for the export's architecture before making a package. Do not ship a registration file without its matching library. Export filters include `source/native/THIRD_PARTY_LICENSES.txt`; source notices are also in `licenses/`.

[Release CI](https://github.com/natelindev/copperfin/actions/runs/38930052716) verifies exported-game headless startup and six packaged gameplay/Lua regressions on each native runner, using the test-capable Godot executable in an isolated directory. The official release template ignores `--script`, so it cannot run those tests directly. Windows uses Lua's portable allocation alignment fields; registration copies the manifest explicitly rather than indexing into the DLL/import-library output list. All 569 native sanitizer assertions pass. Intel macOS execution and Windows/Linux graphical acceptance remain unverified. See [release evidence](../../docs/playtests/2026-10-16/rendered-continuation/README.md).

## Verification

```sh
python3 native/rts_lua/run_sanitizers.py
# Substitute your Godot executable for godot:
godot --headless --path . --script tests/headless/LuaSandboxRegression.gd
godot --headless --path . --script tests/headless/LLMProviderRegression.gd
godot --headless --path . --fixed-fps 60 --script tests/headless/LuaProgramRegression.gd
godot --path . --fixed-fps 60 --script tests/rendered/LuaPreview.gd
godot --path . --fixed-fps 60 --script tests/headless/ScaleBenchmark.gd -- --lua
```

See [dependency review and API contract](../../docs/LUA_RUNTIME.md) and [verification evidence](../../docs/playtests/2026-10-01/LUA_RUNTIME.md). Re-run native sanitizers, Godot bridge, gameplay/authority regressions and the scale workload after dependency or sandbox changes.
