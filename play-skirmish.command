#!/bin/zsh
set -eu
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
for godot_bin in \
  "$project_dir/tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot" \
  "$HOME/.cache/godot/4.6/Godot.app/Contents/MacOS/Godot" \
  "/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$godot_bin" ]]; then
    exec "$godot_bin" --path "$project_dir" res://source/main-menu/Play.tscn
  fi
done
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$project_dir" res://source/main-menu/Play.tscn
fi
print "Godot 4.6 is required. Open project.godot in Godot and choose SKIRMISH."
exit 1
