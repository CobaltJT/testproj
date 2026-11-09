# Hearth & Hammer

A small side-view co-op game about dwarfs running a smithy.

## Run this milestone

Open `project.godot` in **Godot 4.6.x (standard / GDScript)** and press **F5** to open the LAN menu. For a standalone single-player check,
open `scenes/smithy.tscn` and press **F6**. No plugins or external assets
are required. From a terminal: `godot --path .`.

Stage 06 adds the first anvil recipe to the building: upstairs workshop/storage, ground-floor
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
The whole building stays visible; transport ore, then work the forge.

## Throw ore into the forge bin

- The basement starts with **8 individual physics ore pieces**.
- **E** picks up the nearest loose piece within reach; carry one at a time.
- **F** throws in the dwarf's facing direction, with an upward arc.
- **Q** gently drops the carried piece.
- Aim throws into the open top of the ground-floor bin. A good starting position
  is roughly 50 pixels left of the bin (on the 480-pixel world canvas), facing right.
  **E no longer deposits ore.**

Loose ore falls, bounces, and settles against floors, walls, other ore, and the
bin. Missed throws remain in the world and can be picked up again. Fast-moving
ore hits knock dwarfs back, including off ladders; the thrower gets a short grace
period to avoid hitting themselves immediately. There is no health damage yet.
The bin stores each piece once and updates the shared count.

The host owns physics, pickup decisions, impacts, and bin capture; clients receive
ore transforms and inventories. Late joiners receive loose, carried, and stored
ore state. Disconnecting drops carried ore at the dwarf's location. A new hosted
game resets all materials and forge progress. Mining replenishment and persistence come later.

## Forge an ingot (five seconds)

1. Throw ore into the shared bin.
2. Stand on the ground floor beside the forge at the right, with empty hands.
3. **Hold E for five seconds of work**. The forge reserves one ore from the bin
   when the job starts, and its shared progress bar fills.
4. Release E, walk away, jump, climb, or get knocked back to pause. Any eligible
   dwarf can continue the same job. Only one worker advances progress at a time;
   extra players do not speed it up or consume extra ore.
5. A physical ingot drops onto the small output tray to the left of the forge.
   It can be picked up with E, carried, thrown with F, or dropped with Q.

Holding E after completion starts another job if ore remains. Ingots do not count
as raw ore and cannot be smelted again by throwing them into the ore bin. Paused
jobs survive worker disconnects. Late joiners receive material kinds, progress,
worker status, and output positions. The first anvil recipe is a hammer; customer orders come later.

## Shape an ingot into a hammer

1. Pick up a finished ingot from the forge output tray with **E**.
2. Carry it to the central anvil and press **E** to load it. Raw ore and finished
   tools are rejected, and an occupied anvil cannot take a second item.
3. With empty hands, **hold E for five seconds** beside the anvil. Releasing E,
   moving away, jumping, or getting hit pauses the job. Another dwarf can resume.
4. A physical hammer appears on the small tray to the right of the anvil.
   Pick it up, carry it, throw it with **F**, or drop it with **Q**.

One worker advances each station at a time. Loading consumes the carried ingot
into the shared job; completion transforms that same material into one hammer.
Paused jobs survive worker departures. The forge and anvil can operate in parallel.
Hammers are products for now, with no tool action or customer delivery yet.

## Play together on a LAN

1. All players use the same revision of this project and Godot 4.6.x.
2. One player presses **Host LAN game**. The host plays their own dwarf too.
3. Others enter the host computer's LAN IPv4 address (for example `192.168.1.20`)
   and press **Join LAN game**. Keep the same UDP port on all machines (default
   **24567**). `127.0.0.1` is for testing multiple instances on one computer only.
4. Allow Godot inbound **UDP 24567** on the host's local-network firewall if
   prompted. Devices must be on the same reachable LAN; guest Wi-Fi isolation
   may prevent connections. No port forwarding, dedicated server, or internet
   matchmaking is included.

Your dwarf is marked **YOU**; other players have colored sprites and labels.
Dwarfs pass through each other. Late joiners receive the current roster and
positions. **Leave game** returns to the menu. If the host leaves, everyone
returns to the menu; there is no host migration or saved session yet.

The host simulates physics and accepts only controls belonging to each sender.
Clients receive movement snapshots at 20 Hz. This first implementation has no
client prediction or interpolation, so clients may feel latency or visible
stepping; tune that after initial LAN playtesting. Multiplayer verification here
uses three independent processes on loopback, not separate physical machines.

## Agreed direction

- Godot 4 + GDScript, 2D platformer, pixel art.
- Player-hosted LAN co-op for more than two players; no dedicated server.
- No gameplay player cap yet; ENet has a technical limit of 4095 remote peers.
  Large player counts have not been tested.
- Players stay within the building; the cellar provides access to mining tasks.
- Review each milestone before starting the next.

## Milestones

1. Complete: project and building layout.
2. Complete: one dwarf, movement, jumping, collision, and ladders; fixed building view.
3. Complete: LAN host/join, independent dwarfs, and host-authoritative movement.
4. Complete: physical ore, pickup, carrying, throwing, knockback, and bin capture.
5. Complete: five-second shared forge job, pausing, handoff, and physical ingots.
6. **Current:** load an ingot, work the anvil, and produce a physical hammer.
7. Customer orders, more recipes, mining, and merchants after review.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 10
```

In the cloud sandbox, run `bash tools/check.sh` to give Godot writable temporary
settings and cache folders.

`bash tools/check.sh` also runs physics checks for movement, jumping, wall/floor
collisions, both ladder routes, holding on ladders, and jumping off. It then runs
`python3 tools/check_multiplayer.py`: one host and two clients exercising roster
sync, independent movement, jumps, ladders, the full ore transport route, client
departure, and host loss. `tests/ore.gd` checks station reach, one-piece capacity,
piece contention, duplicate capture, identity conservation, and snapshots.
`tests/ore_physics.gd` checks settling, drops, thrown bin capture, missed throws,
impact knockback, and drops on disconnect. `tests/forge.gd` checks exact work
duration, reservation, pause/handoff, contention, and snapshots.
`tests/forge_physics.gd` checks held-E work, output physics, pickup, and reset.
The three-process multiplayer test also checks forge handoff, competing workers,
shared progress, and synchronized ingot output. `tests/anvil.gd` and
`tests/anvil_physics.gd` cover loading, wrong materials, occupied jobs, exact
duration, handoff, output physics, carrying, throwing, and reset. The network
test continues from the forge to a shared anvil job and replicated hammer.

The standalone commands above check project loading and startup; they do not replace visual review.
Generated Godot caches are ignored. No cloud configuration is published by this project.
