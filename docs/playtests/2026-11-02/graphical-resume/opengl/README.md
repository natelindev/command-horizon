# Actual OpenGL scene resource lifetime

The [actual renderer run](renderer.log) passes with **six temporary-template instances freed, zero failures and no resource leaks**. It uses Godot 4.7.2, OpenGL 4.1 Metal compatibility on Apple M1 Pro and the exact final headless-candidate PCK (`072fc45c0040e9eb83c9a5a0634b58ee76f3249b12647c5552bde0465f40f9e5`). Match and Skirmish templates are each instantiated and freed three times. The fixture requires a real OpenGL renderer; the dummy server cannot satisfy this gate.

[Command and exit status](result.json), [input provenance](input.json) and [artifact hashes](verification.json) are retained. The process exits 0 after normal audio cleanup. Five hardware texture-format warnings report BPTC-to-RGBA8 conversion; no Godot error or leaked allocation occurs. All engines exited before the subsequent isolated timing launch. This establishes scene resource lifetime, without claiming frame-performance or native-unit presentation coverage.
