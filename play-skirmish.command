#!/bin/zsh
set -eu
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
# Linked worktrees share the main checkout's ignored tooling installation.
tooling_dir="$project_dir/tmp/tooling"
git_common_dir="$(git -C "$project_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [[ -n "$git_common_dir" ]]; then
  tooling_dir="${git_common_dir:h}/tmp/tooling"
fi
native_flags=()
if [[ -f "$project_dir/native/bin/copperfin.gdextension" ]]; then
  native_flags=(
    --
    --native-unit-state
    --native-crowd-runtime
    --native-nearest-surface
    --native-visibility-runtime
    --native-exploration
    --native-combat-queries
    --native-battlefield-index
    --native-infantry-poses
    --native-presentation
    --indexed-player-rosters
  )
fi
for godot_bin in \
  "$project_dir/tmp/tooling/godot-4.7.2/Godot.app/Contents/MacOS/Godot" \
  "$tooling_dir/godot-4.7.2/Godot.app/Contents/MacOS/Godot" \
  "$HOME/.cache/godot/4.7.2/Godot.app/Contents/MacOS/Godot" \
  "/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$godot_bin" && "$("$godot_bin" --version)" == 4.7.2.stable.* ]]; then
    "$godot_bin" --headless --editor --path "$project_dir" --import
    exec "$godot_bin" --path "$project_dir" res://source/main-menu/Play.tscn "${native_flags[@]}"
  fi
done
if command -v godot >/dev/null 2>&1 && [[ "$(godot --version)" == 4.7.2.stable.* ]]; then
  godot --headless --editor --path "$project_dir" --import
  exec godot --path "$project_dir" res://source/main-menu/Play.tscn "${native_flags[@]}"
fi
print "Godot 4.7.2 is required. Open project.godot in Godot and choose SKIRMISH."
exit 1
