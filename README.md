# Hearth & Hammer

A small side-view co-op game about dwarfs running a smithy.

## Run this milestone

Open `project.godot` in **Godot 4.6.x (standard / GDScript)** and press **F6** on
`scenes/smithy.tscn`, or **F5** to run the project. No plugins or external assets
are required. From a terminal: `godot --path .`.

Stage 02 adds a controllable dwarf to the building: upstairs workshop/storage, ground-floor
customer counter and forge, and a basement with ore storage and a mine entrance.
Ladders mark planned routes. The building is an original pixel-style image texture in
`assets/textures/smithy.svg`, displayed by a Sprite2D with nearest filtering.
Captions are separate Label nodes in the scene. Edit the SVG in an image/vector
editor; there is no runtime drawing script. Walk with **A/D** or **Left/Right**, jump with **Space**, and climb with
**W/S** or **Up/Down** while at a ladder. Release to hold on a ladder. Move horizontally or diagonally while attached;
leaving the ladder width or pressing jump detaches. Upward movement stops at the
top, where you can move sideways onto a landing. Attaching never centers the dwarf. After jumping off, holding a climb direction
does not reattach until you land or release and press a climb direction again.
Holding Up also catches the ladder at the peak of an upward jump if still in
reach. Down + Space detaches into a fall without an upward jump.
Floors, ceiling, and outer walls are solid. Furniture remains background scenery.
The whole building stays visible; interactions and networking come later.

## Agreed direction

- Godot 4 + GDScript, 2D platformer, pixel art.
- Player-hosted LAN co-op for more than two players; no dedicated server.
- Player capacity remains undecided and will be configurable when networking is added.
- Players stay within the building; the cellar provides access to mining tasks.
- Review each milestone before starting the next.

## Milestones

1. Complete: project and building layout.
2. **Current:** one dwarf, movement, jumping, collision, and ladders; fixed building view.
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

`bash tools/check.sh` also runs physics checks for movement, jumping, wall/floor
collisions, both ladder routes, holding on ladders, and jumping off.

The standalone commands above check project loading and startup; they do not replace visual review.
Generated Godot caches are ignored. No cloud configuration is published by this project.
