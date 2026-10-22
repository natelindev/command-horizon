# Infantry portraits

The 15 transparent PNG portraits in `assets/ui/infantry/{bastion,helix,frontier}` use the actual faction models and infantry equipment, including faction heroes.

Rebuild with Godot 4.6 using a graphical renderer:

```sh
godot --path . --script art/infantry/render_portraits.gd
godot --headless --editor --path . --import
```

The rendered visual regression checks every portrait for visible pixels and verifies the Barracks menu:

```sh
godot --path . --fixed-fps 60 --script tests/headless/VisualPolishRegression.gd -- --render
```

Captures are written to `tmp/visual-polish`.

The [infantry redesign](redesign/README.md) records the generated target, production model/motion implementation, and repeatable graphical review commands.
