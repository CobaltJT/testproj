# Hearth & Hammer

A small Godot 4.6.x / GDScript LAN co-op platformer about running a dwarven smithy.
Open `project.godot` and press **F5**. One player hosts; others enter that player's
LAN IP and use the same UDP port (default **24567**). Allow that port through the
host's LAN firewall. `127.0.0.1` is for multiple instances on one computer.

## Larger map and player cameras

The smithy is now **640 pixels wide** instead of 480, with about **42% more usable
floor space** on all three levels. The right wing has solid floors, matching
walls, and room for more stations. The existing counter, mine, and ladders remain
in their familiar locations.

Each player has a personal camera following their own dwarf, horizontally and
between floors. The default resolution is **1280×720**. The view is **160 world pixels high**,
roughly **two floors**,
with smooth following and bounds at the map edges. Remote dwarfs never control
your camera. The HUD and build catalog stay fixed on screen; station placement
uses the camera transform. Resize the window without changing the vertical world
coverage. The connection menu returns to an overview of the whole building.

## Build your workshop

The starting building has **no workstations**. The mine, counter, ladders, door,
walls, and floors are fixed. You start with **100 shared coins** and eight loose
ore pieces in the basement.

Press **Tab** or click **Build / Skills** to open the menu. Its **Build** tab offers:

| Station | Cost | Purpose |
| --- | --- | --- |
| Anvil | 20 | Shape ore; assemble axe heads and shafts |
| Grinder | 25 | Sharpen unfinished swords |
| Woodworking bench | 25 | Turn purchased wood into shafts |
| Forge with attached bin | 25 | Collect thrown ore and smelt ingots |

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

Place stations during preparation, then use **Open shop** to start the day.
Station placement itself does not start customer or merchant clocks.

## Produce goods

Metal can be worked **directly from ore**, preserving the anvil-only horseshoe
route. You can also purchase a **forge with its attached ore bin** and smelt
ingots; anvils accept ingots in place of ore for horseshoes, blades, and heads. Carry each ingredient to a station and press **E**
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

## Forge and included ore bin

The forge costs **25 coins including its bin**. Buy and place it through the same
Tab catalog as other stations. It is not preinstalled. Throw ore into the open
bin on the forge's left, then stand beside the forge and **hold E for five seconds**
to smelt one ore into a physical ingot on the right output tray. E does not deposit
ore directly. The bin can queue multiple ore pieces and rejects other materials.

Releasing E pauses the smelt; another dwarf can continue. Holding E processes the
next queued ore. Anvils accept the resulting ingots as alternatives to raw ore.
The forge and bin are one station: purchase, placement, relocation, and refund
apply to both. A forge can only be packed when its bin and active job are empty.
Bin contents, smelting progress, and ingot outputs synchronize for late joiners.

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

## Daily cycle

Each new session begins on **Day 1, Morning**. Morning lasts until any connected
player presses **Open shop**. There are no customer arrivals or merchant visits,
and the mine is closed. Players can prepare, rearrange stations, and craft.

**Shop hours last 120 seconds.** The mine opens, customers arrive first after
8 seconds and then every 20 seconds, and merchants follow their normal visit
schedule. The HUD shows the shared day, phase, and time until closing.

At closing, **Evening** begins: no new customers appear, the merchant leaves,
and the mine closes. Existing requests retain their decision and fulfilment
timers. Players can continue crafting and serving the queue. Once all customers
have left, including their departure animations, a shared daily summary appears:
customer count, served requests, failed accepted requests, rejected/unanswered
requests, money gained from sales, money spent on purchases, and refunds.
Starting funds are excluded; purchases and refunds are reported separately.

The summary blocks gameplay actions. Any player can press **Close summary ·
Next morning**. Everyone fades to black, then into the following morning.
Stations, pending kits, resources, paused work, coins, reputation, EXP, and skills
remain. Daily statistics start fresh. The host owns phase changes and timers;
joining clients receive the current phase and any active report. Stale or
duplicate transition requests cannot skip phases or open the next day.

## Customers and reputation

After the shop opens, the first customer arrives at 8 seconds, then one arrives
every 20 seconds independently of the queue. Requests rotate through horseshoe,
sword, and axe. At the counter, press **Y** to accept or **N** to reject the
front customer's request within **10 seconds**. This decision timer starts once
they reach the front; queued customers retain their full decision window.
Rejecting or leaving a request unanswered costs **3 reputation**.

Accepting starts a separate **30-second** fulfilment timer. Carry the exact
finished product to the left counter and press **E**. Only the **front customer**
can be served. Horseshoes sell for **10 coins**, swords for **15**, and axes for
**25**. Timely delivery gives **+2 shared reputation**; failing an accepted order
costs **6 reputation**. Accepted orders cannot be rejected. The HUD shows each
request's phase, timer, coins, and reputation, which can fall below zero.

## Player progression

Every dwarf starts at level 1. Completing a mining cycle earns **2 EXP**, station
work earns **3 EXP**, and delivering an accepted order earns **5 EXP**. Work EXP
goes to the worker who finishes the cycle, including after a handoff. Picking up,
buying, loading, placing, and rejecting do not grant EXP.

The first level needs **10 EXP**, then **15**, **20**, and so on (5 more per level).
Each level grants **one skill point**; surplus EXP carries forward. Open **TAB →
Skills** to see personal EXP, available points, prerequisites, and ranks. Each
rank costs one point. Buying a branch root unlocks its child skills:

| Branch | Skill | Effect per rank | Maximum ranks |
| --- | --- | --- | --- |
| Craft root | Sure-footed | +10% horizontal movement speed | 3 |
| Requires Sure-footed | Metalworker | +20% anvil, grinder, forge work speed | 3 |
| Requires Sure-footed | Prospector | +20% mining speed | 3 |
| Requires Sure-footed | Woodworker | +20% woodbench speed | 3 |
| Trade root | Bargainer | −10% workstation and merchant wood prices | 3 |
| Requires Bargainer | Salesperson | +10% delivery sale prices | 3 |
| Requires Bargainer | Diplomat | −1 reputation lost on explicit rejection | 2 |

Speed bonuses add to the base rate: one work rank makes a 5-second job take
5 / 1.2 = **4.17 seconds**. The current worker supplies the bonus; helpers do not
stack speed. Trade bonuses use the buyer, seller, or rejecting dwarf's skills,
while coins and reputation remain shared. Coin prices round up; kit refunds
return the original amount paid, including after packing or disconnecting.
Diplomat does not reduce the 3-point penalty for leaving a request unanswered or
the 6-point penalty for failing an accepted order.

The menu does not pause gameplay. Progression is per connected dwarf for the
current session; leaving and rejoining creates a fresh level-1 dwarf. Other
players keep their progress. There is no disk save yet.

## Multiplayer and scope

The host owns station purchases/placement, inventories, physics, work progress,
mining, merchant stock, orders, and rewards. Late joiners receive the layout,
loaded jobs, unfinished parts, and economy state. Each dwarf is independent and
passes through other dwarfs. Clients receive snapshots at 20 Hz; prediction and
interpolation remain future work. Verification uses one host and two clients on
loopback; separate-computer LAN play still needs user testing.

Leave returns to the menu. Host departure ends the session. New hosted games
reset stations, resources, budget, reputation, day, and clocks. No persistence,
upgrades, dedicated servers, internet matchmaking, or separate mine level yet.

## Validation

Run **`bash tools/check.sh`** with Godot 4.6.x and Python 3 available. It isolates
Godot's writable settings in temporary folders, imports and starts the project,
and runs:

- Camera ownership, follow motion, floor-height framing, map bounds, resize,
  overview restoration, zoomed placement, and new-wing floors/build areas.
- Movement, ladder, collision, loose-item physics, and knockback checks.
- Forge/bin collection, queueing, smelting, relocation, ingot use, and snapshots.
- Material identity, purchase/placement validation, recipe routes, exact work
  duration, loading rules, handoffs, packing, relocation, refunds, and snapshots.
- Actual catalog-button, placement-click, recipe, work, customer and mining inputs.
- Customer deadlines, front-only service, economy and reputation checks.
- A real host and two clients exercising all station types, co-op jobs, wood
  purchases, intermediate products, deliveries, placement races, relocation,
  refunds on disconnect, independent local cameras, and reconnect restoration of
  loaded paused jobs and camera ownership.

The old fixed-forge/ingot tests were replaced by the new station and production
route checks. Images are original SVG textures rendered with nearest filtering;
workstations are independent scenes, not baked into the building background.
The environment configuration is not published by project commands.
