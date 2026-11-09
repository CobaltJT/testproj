# Hearth & Hammer

A small side-view co-op game about dwarfs running a smithy.

## Run this milestone

Open `project.godot` in **Godot 4.6.x (standard / GDScript)** and press **F5** to open the LAN menu. For a standalone single-player check,
open `scenes/smithy.tscn` and press **F6**. No plugins or external assets
are required. From a terminal: `godot --path .`.

Stage 03 adds LAN multiplayer to the building: upstairs workshop/storage, ground-floor
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
The whole building stays visible; task interactions come later.

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
3. **Current:** LAN host/join, independent dwarfs, and host-authoritative movement.
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
collisions, both ladder routes, holding on ladders, and jumping off. It then runs
`python3 tools/check_multiplayer.py`: one host and two clients exercising roster
sync, independent movement, jumps, ladders, client departure, and host loss.

The standalone commands above check project loading and startup; they do not replace visual review.
Generated Godot caches are ignored. No cloud configuration is published by this project.
