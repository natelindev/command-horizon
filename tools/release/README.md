# Desktop release builds

Run `python -X utf8 tools/release/build.py` on the target desktop platform to
download the pinned Godot engine and export templates, build the Windows native
extension when applicable, export the game, and validate the packaged resources.
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

The project is imported before native regression scripts run so a fresh checkout
has its global script classes and imported resources available. Both build modes
run the same startup smoke check and full packaged regression list. A failed
check stops the build before creating the distributable archive.

Exports are written to `build/<platform>/`; validated archives are written to
`build/release-assets/`. Build output is decoded as UTF-8, including on Windows.
