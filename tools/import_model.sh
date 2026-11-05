#!/bin/sh
# Imports a model from Blender into the game in one go (CONTENT.md, "Models"):
#   0. given a .blend, its export to a .glb beside it (tools/export_blend.py; the "Guides"
#      collection left out);
#   1. ships only: its fit to Constants.SHIP_MODEL_LENGTH nose to tail (tools/fit_length.py; the
#      .glb is rescaled in place, so a ship can be made at any size: its preset sizes it in the
#      game), then its levels of detail (tools/generate_lods.py): <folder>/lod/<name>_LOD<n>.glb;
#   2. Godot's import of the new files (the editor, run without a window; materials stay inside
#      the model: project.godot's importer_defaults);
#   3. its hit surface (tools/bake_hit_shapes.gd, ships only): <folder>/hit/<name>_hit.res;
#   4. its scene, unless it exists (tools/new_model_scene.gd): scenes/prefabs/ships/<name>.tscn,
#      or scenes/prefabs/station/<name>.tscn;
#   5. a check of the scene against the rules (tools/check_model.gd).
# Re-run it after every change in Blender. Then point the preset's ship_scene (or the
# HavenMarker's model) at the scene, and run the tests.
# Usage, from anywhere:
#     tools/import_model.sh [--station] [--ratio 0.7] [--levels 3] assets/models/ships/<name>/<name>.blend
# (or .glb). Start a model from assets/models/starters/.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
STATION=""
RATIO=0.7  # Hard-surface models fall apart under a steeper ratio
LEVELS=3
while [ $# -gt 1 ]; do
	case "$1" in
		--station) STATION="--station"; shift ;;
		--ratio) RATIO="$2"; shift 2 ;;
		--levels) LEVELS="$2"; shift 2 ;;
		*) break ;;
	esac
done
MODEL="${1#res://}"
[ -f "$MODEL" ] || { echo "No model file: $MODEL"; exit 1; }
case "$MODEL" in
	*.blend)
		tools/blender -b "$MODEL" -P tools/export_blend.py | grep -E "^EXPORTED" || { echo "Export failed: $MODEL"; exit 1; }
		MODEL="${MODEL%.blend}.glb"
		;;
esac
if [ -z "$STATION" ]; then
	LENGTH="$(sed -n 's/^const SHIP_MODEL_LENGTH = \([0-9.]*\).*/\1/p' src/autoload/Constants.gd)"
	tools/blender -b -P tools/fit_length.py -- --length "$LENGTH" "$MODEL" | grep -E "^FIT" || { echo "Fit failed: $MODEL"; exit 1; }
	tools/blender -b -P tools/generate_lods.py -- --levels "$LEVELS" --ratio "$RATIO" "$MODEL"
fi
for pass in 1 2; do  # The first pass finds the new files, the second imports them
	"$GODOT" --no-window --editor --quit >/dev/null 2>&1 || true
done
if [ -z "$STATION" ]; then
	"$GODOT" --no-window -s tools/bake_hit_shapes.gd "res://$MODEL"
fi
"$GODOT" --no-window -s tools/new_model_scene.gd -- "res://$MODEL" $STATION | grep -E "^(OK|KEEP|FAIL)"
NAME="$(basename "$MODEL" .glb)"
SCENE="res://scenes/prefabs/ships/$NAME.tscn"
[ -n "$STATION" ] && SCENE="res://scenes/prefabs/station/$NAME.tscn"
"$GODOT" --no-window -s tools/check_model.gd -- "$SCENE" $STATION | grep -E "^(OK|PROBLEM)"
