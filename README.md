# Hearth & Hammer

A small Godot 4.6.x / GDScript LAN co-op platformer about running a dwarven smithy.
Open `project.godot` and press **F5**. One player hosts; others enter that player's
LAN IP and use the same UDP port (default **24567**). Allow that port through the
host's LAN firewall. `127.0.0.1` is for multiple instances on one computer.

## Build your workshop

The starting building has **no workstations**. The mine, counter, ladders, door,
walls, and floors are fixed. You start with **100 shared coins** and eight loose
ore pieces in the basement.

Press **Tab** or click **Build** to open the catalog:

| Station | Cost | Purpose |
| --- | --- | --- |
| Anvil | 20 | Shape ore; assemble axe heads and shafts |
| Grinder | 25 | Sharpen unfinished swords |
| Woodworking bench | 25 | Turn purchased wood into shafts |

Buy with empty hands, then move the mouse and **left-click a green preview** to
place the kit on a floor. Placement snaps to an 8-pixel grid. Red previews mean
blocked placement: fixed fixtures, storefront/merchant space, ladders and their
landings, mine access, walls, floor gaps, and existing stations stay clear.
You can place multiple stations of each type and use all three floors.

A purchase charges once and reserves one kit per player. Invalid placement keeps
the kit. **Esc** cancels an unplaced kit for a full refund. Stand beside an empty
station and press **R** to pack it, then place it elsewhere or press Esc to refund
it. Loaded or working stations cannot be packed. Disconnecting refunds an
unplaced kit; placed stations belong to the whole team and remain.

The first anvil placement opens the shop and starts customer and merchant clocks.
Once open, the clocks keep running even while stations are being rearranged.

## Produce goods

Metal is now worked **directly from ore**. There is no separate smelter, ingot
step, or preinstalled ore bin. Carry each ingredient to a station and press **E**
to load it, then **hold E with empty hands for five seconds** to work. Release,
move away, jump, or get knocked back to pause; another dwarf can continue.
Helpers never multiply work speed. Outputs drop onto each station's right tray.

At an empty anvil, select its shared recipe with keys **1–4**:

| Key | Anvil recipe | Input → output |
| --- | --- | --- |
| 1 | Horseshoe | Ore → finished horseshoe |
| 2 | Blade | Ore → unfinished sword |
| 3 | Axe head | Ore → axe head |
| 4 | Assemble axe | Axe head + worked shaft → finished axe |

- **Horseshoe:** needs only an anvil, replacing the old hammer recipe.
- **Sword:** make a blade at an anvil, then load and work it at a grinder to sharpen it.
- **Axe:** make a head at an anvil; make a shaft from wood at a woodworking bench;
  load both at an anvil set to recipe 4 and work to assemble the axe.

Grinders and woodworking benches have fixed recipes. Assembly ingredients may
be supplied in either order and by different players. Loaded recipes lock until
the job finishes. Wrong and duplicate inputs stay in your hands. A shaft is
consumed once when the axe is assembled; unfinished parts cannot fulfill orders.

## Move and handle items

- **A/D or Left/Right:** walk. **Space:** jump.
- **W/S or Up/Down:** climb ladders, including diagonal movement.
- **E:** pick up nearby loose items or load a station. **Hold E:** work or mine.
- **F:** throw the carried item in the facing direction. **Q:** drop it.

You can carry one item. Loose items fall, bounce, stay where they land, and can
knock dwarfs back. Jumping off a ladder prevents immediate reattachment while
ascending; held Up can catch it at the apex. Down + Jump detaches into a fall.
Work takes priority over pickup while a nearby station contains a loaded job.
Furniture lets dwarfs walk past it; output trays collide with physical items.

## Mine ore and buy wood

Hold **E for three seconds**, empty-handed beside the vein at the right of the
basement, to extract a new ore piece. It falls out a short distance to the left.
Mining supports pausing, handoffs, and unlimited repeat cycles for this prototype.

Wood comes **only from the merchant**. The merchant first visits 12 seconds after
opening, stays 20 seconds, and returns every 45 seconds. Each visit offers four
wood at **5 coins each**. Stand beside the purple merchant between the counter
and the ground-floor build area, with empty hands, and press **B** per purchase.
Pick up the physical wood and take it to a woodworking bench. Buying is checked
by the host for stock, funds, position, and free hands.

## Customers and reputation

After the shop opens, the first customer arrives at 8 seconds, then one arrives
every 20 seconds independently of the queue. Requests rotate through horseshoe,
sword, and axe. Every customer has **30 seconds from arrival**, including walking
in and queuing. Advancing to the front does not restart that timer.

Carry the exact finished product to the left counter and press **E**. Only the
**front customer** can be served. Horseshoes sell for **10 coins**, swords for
**15**, and axes for **25**. Delivery gives **+1 shared reputation**. Every expired
order costs **1 reputation** and no coins. The HUD shows specific requests,
patience, coins, and reputation. Reputation can fall below zero.

## Multiplayer and scope

The host owns station purchases/placement, inventories, physics, work progress,
mining, merchant stock, orders, and rewards. Late joiners receive the layout,
loaded jobs, unfinished parts, and economy state. Each dwarf is independent and
passes through other dwarfs. Clients receive snapshots at 20 Hz; prediction and
interpolation remain future work. Verification uses one host and two clients on
loopback; separate-computer LAN play still needs user testing.

Leave returns to the menu. Host departure ends the session. New hosted games
reset stations, resources, budget, reputation, and clocks. No persistence,
upgrades, dedicated servers, internet matchmaking, or separate mine level yet.

## Validation

Run **`bash tools/check.sh`** with Godot 4.6.x and Python 3 available. It isolates
Godot's writable settings in temporary folders, imports and starts the project,
and runs:

- Movement, ladder, collision, loose-item physics, and knockback checks.
- Material identity, purchase/placement validation, recipe routes, exact work
  duration, loading rules, handoffs, packing, relocation, refunds, and snapshots.
- Actual catalog-button, placement-click, recipe, work, customer and mining inputs.
- Customer deadlines, front-only service, economy and reputation checks.
- A real host and two clients exercising all station types, co-op jobs, wood
  purchases, intermediate products, deliveries, placement races, relocation,
  refunds on disconnect, and reconnect restoration of loaded paused jobs.

The old fixed-forge/ingot tests were replaced by the new station and production
route checks. Images are original SVG textures rendered with nearest filtering;
workstations are independent scenes, not baked into the building background.
The environment configuration is not published by project commands.
