#!/usr/bin/env bash
# Isolate Godot's writable settings for sandboxed/cloud validation.
set -euo pipefail
cd "$(dirname "$0")/.."
check_dirs=$(mktemp -d /tmp/hearth-hammer-check.XXXXXX)
trap 'rm -rf "$check_dirs"' EXIT
export XDG_DATA_HOME="$check_dirs/data"
export XDG_CONFIG_HOME="$check_dirs/config"
export XDG_CACHE_HOME="$check_dirs/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 10
godot --headless --path . --script res://tests/transport.gd
godot --headless --path . --script res://tests/transport_physics.gd
godot --headless --path . --script res://tests/mine_levels.gd
godot --headless --path . --script res://tests/mobile_bin.gd
godot --headless --path . --script res://tests/mobile_bin_physics.gd
godot --headless --path . --script res://tests/bin_physics.gd
godot --headless --path . --script res://tests/storage.gd
godot --headless --path . --script res://tests/storage_physics.gd
godot --headless --path . --script res://tests/difficulty.gd
godot --headless --path . --script res://tests/day.gd
godot --headless --path . --script res://tests/day_physics.gd
godot --headless --path . --script res://tests/progression.gd
godot --headless --path . --script res://tests/progression_physics.gd
godot --headless --path . --script res://tests/camera.gd
godot --headless --path . --script res://tests/movement.gd
godot --headless --path . --script res://tests/ore.gd
godot --headless --path . --script res://tests/ore_physics.gd
godot --headless --path . --script res://tests/workshop.gd
godot --headless --path . --script res://tests/build_physics.gd
godot --headless --path . --script res://tests/customers.gd
godot --headless --path . --script res://tests/customers_physics.gd
godot --headless --path . --script res://tests/mining.gd
godot --headless --path . --script res://tests/mining_physics.gd
godot --headless --path . --script res://tests/forge.gd
godot --headless --path . --script res://tests/forge_physics.gd
python3 tools/check_multiplayer.py

GODOT_MULTIPLAYER_SCRIPT=res://tests/transport_multiplayer.gd python3 tools/check_multiplayer.py
