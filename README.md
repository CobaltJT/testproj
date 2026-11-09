# Hearth & Hammer

A small side-view co-op game about dwarfs running a smithy.

## Run this milestone

Open `project.godot` in **Godot 4.6.x (standard / GDScript)** and press **F6** on
`scenes/smithy.tscn`, or **F5** to run the project. No plugins or external assets
are required. From a terminal: `godot --path .`.

Stage 01 is a static building study: upstairs workshop/storage, ground-floor
customer counter and forge, and a basement with ore storage and a mine entrance.
Ladders mark planned routes. All art is original procedural pixel-style placeholder
geometry, editable in `scripts/smithy.gd`; the `@tool` script also previews it in
the editor. There is no player, collision, interaction, or networking yet.

## Agreed direction

- Godot 4 + GDScript, 2D platformer, pixel art.
- Player-hosted LAN co-op for more than two players; no dedicated server.
- Player capacity remains undecided and will be configurable when networking is added.
- Players stay within the building; the cellar provides access to mining tasks.
- Review each milestone before starting the next.

## Milestones

1. **Current:** project and building layout.
2. One dwarf: movement, jumping, floor traversal, collision, and camera.
3. LAN host/join, independent dwarfs, and host-authoritative shared state.
4. A complete ore → smithing → customer delivery loop.
5. Mining, merchants, and additional tasks, one reviewed step at a time.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 10
```

In the cloud sandbox, run `bash tools/check.sh` to give Godot writable temporary
settings and cache folders.

These check project loading and startup; they do not replace visual review.
Generated Godot caches are ignored. No cloud configuration is published by this project.
