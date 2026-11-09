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
godot --headless --path . --script res://tests/movement.gd
