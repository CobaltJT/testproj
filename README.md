# Hearth & Hammer

A small Godot 4.6.x / GDScript LAN co-op platformer about running a dwarven smithy.
Open `project.godot` and press **F5**. One player hosts; others enter that player's
LAN IP and use the same UDP port (default **24567**). Allow that port through the
host's LAN firewall. `127.0.0.1` is for multiple instances on one computer.

## Larger map and player cameras

The smithy is now **640 pixels wide** instead of 480, with about **42% more usable
floor space** on all three levels. The right wing has solid floors, matching
walls, and room for more stations. The counter and building ladders remain, with a mine entrance in the basement
in their familiar locations.

Each player has a personal camera following their own dwarf, horizontally and
between floors. The default resolution is **1280×720**. The view is **160 world pixels high**,
roughly **two floors**,
with smooth following and bounds at the map edges. Remote dwarfs never control
your camera. The HUD and build catalog stay fixed on screen; station placement
uses the camera transform. Resize the window without changing the vertical world
coverage. The connection menu returns to an overview of the whole building.

## Build your workshop

The starting building has **no workstations**. The mine entrance, counter, ladders, door,
walls, and floors are fixed. You start with **100 shared coins** and eight loose
ore pieces in the basement.

Press **Tab** or click **Build / Skills** to open the menu. Its **Build** tab offers:

| Station | Cost | Purpose |
| --- | --- | --- |
| Anvil | 20 | Shape ingots; assemble axe heads and shafts |
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

Metal recipes require **smelted iron ingots**. Purchase a **forge with its
attached ore bin**, throw in raw iron ore, and smelt it before using the anvil.
Raw ore cannot be loaded into an anvil. Carry each ingredient to a station and press **E**
to load it, then **hold E with empty hands for five seconds** to work. Release,
move away, jump, or get knocked back to pause; another dwarf can continue.
Helpers never multiply work speed. Outputs drop onto each station's right tray.

At an empty anvil, select its shared recipe with keys **1–4**:

| Key | Anvil recipe | Input → output |
| --- | --- | --- |
| 1 | Horseshoe | Ingot → finished horseshoe |
| 2 | Blade | Ingot → unfinished sword |
| 3 | Axe head | Ingot → axe head |
| 4 | Assemble axe | Axe head + worked shaft → finished axe |

- **Horseshoe:** smelt an ingot at the forge, then shape it at an anvil.
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
next queued ore. Anvils require the resulting ingots for horseshoes, blades, and axe heads.
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
On an interact press, nearby loose objects take priority over placeable objects,
including loaded workstations. Clear nearby clutter before holding E to work.
Carried ore can also be deposited into a nearby movable ore bin before using
a placeable.
Furniture lets dwarfs walk past it; output trays collide with physical items.

## Mine ore and buy wood

The old basement mining spot at **(390, 288)** is now the **mine entrance**.
Use **Down / Up** on its single continuous ladder to travel through three
underground floors at y=368, 448, and 528. The ladder passes through openings in
each floor; walk sideways onto a landing to leave it. The local camera follows
through the entire mine while keeping its existing two-floor viewport height.

There are **two ore veins on each level**, at x=240 and x=500. Stand beside a
vein with empty hands, stay still, and **hold E for three seconds** to produce a
physical ore piece beside that vein. Each vein has independent work progress:
release E, move away, jump, or get hit to pause; another dwarf can finish the
same vein. Players on separate veins can work concurrently. Prospector speed
bonuses and +2 mining EXP apply as before. Veins do not deplete yet.

Mining is enabled during shop hours and pauses in morning and evening; progress
persists across days and reconnects. The ladder remains navigable. Placeable
workstations remain limited to the building, while movable ore bins can be
carried underground. The entrance itself no longer produces ore.

Wood comes **only from the merchant**. The merchant first visits 12 seconds after
opening, stays 20 seconds, and returns every 45 seconds. Each visit offers four
wood at **5 coins each**. Stand beside the purple merchant between the counter
and the ground-floor build area, with empty hands, and press **B** per purchase.
Pick up the physical wood and take it to a woodworking bench. Buying is checked
by the host for stock, funds, position, and free hands.

## Storage containers

Open **TAB → Build** to buy a container, then place it with the same green floor
preview used for stations. Both categories offer these sizes (before Bargainer
discounts):

| Size | Capacity, individual items | Price |
| --- | --- | --- |
| Small | 5 | 10 coins |
| Medium | 15 | 20 coins |
| Large | 30 | 35 coins |

**Intermediate storage** uses open bins with blue trim and accepts ingots, unfinished swords, axe heads,
and shafts. **Finished storage** uses open shelves with gold trim and accepts horseshoes, swords, and
axes. Raw ore and wood are excluded. Each container can mix the products in its
category; all products share its capacity. The sizes use distinct image textures.

Stand beside a container and press **E** while carrying an accepted product to
store it. You can also **throw intermediate products into the open bins**; only
descending compatible items are caught, up to capacity. Full bins or wrong
products leave the item as a loose physics object. Finished shelves require
manual storage with E and never catch thrown products. With empty hands, **E** retrieves one item of the selected product
straight into your hands. Press **T** to cycle the product to retrieve. Selection
is shared, and the container label shows the selected product's count and total
capacity usage. A full or incompatible container leaves the carried item intact.

Stored items retain their identities and cannot be picked up, processed, or
sold until retrieved. Storage grants no EXP. Retrieved items can be carried,
worked, thrown, dropped, or delivered normally. **R** packs only an empty
container; filled containers cannot be packed or refunded. Empty containers use
the normal placement and original-price refund rules. The host validates access,
category, capacity, selection, and every transfer. Contents synchronize for late
joiners and persist across days; leaving the host session resets them.

## Movable ore bins and draw order

The Build catalog also sells a **movable ore bin** for **15 coins**, before
Bargainer discounts. It holds **10 raw ore** and is purchased directly into
empty hands. It is a physics object rather than grid-placed furniture.

- **E**, empty hands: pick up the bin, including its contents.
- **Q / F**: drop or throw the bin. It stays upright and retains its ore.
- Loose bins catch falling/thrown ore through their open top. Wrong items and
  overflow stay loose. Carried bins do not catch items.
- **E**, carrying ore near a loose bin: deposit that ore manually.
- **G**, empty hands near a loose bin: take one original ore out. You can then
  throw it into the forge bin or carry it elsewhere.

Loaded bins retain the exact ore identities across movement, multiplayer,
reconnects, and days. The host validates purchases, capacity, access range and
transfers; moving and storing items grants no EXP.

The world renders background first, then stationary objects, then characters,
then movable objects (including carried objects). This order is consistent for
hosts and clients and does not change collision behavior.

## Daily cycle

Each new session begins on **Day 1, Morning**. Morning lasts until any connected
player presses **Open shop**. There are no customer arrivals or merchant visits,
and the mine is closed. Players can prepare, rearrange stations, and craft.

**Shop hours last 120 seconds.** The mine opens, customers arrive at randomized
intervals based on reputation, and merchants follow their normal visit schedule. The HUD shows the shared day, phase, and time until closing.

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

After the shop opens, customers arrive independently of the queue. The host
randomly chooses **horseshoe, sword, or axe** for each request with equal odds;
consecutive customers can request the same product. Each request contains
**one product kind**, with a random quantity from 1 to the current maximum.

Reputation sets the difficulty tier: one tier per **10 reputation**, capped at
tier 9. Negative reputation uses tier 0. The first arrival of each day and every
subsequent arrival use a freshly randomized interval:

| Reputation | Random arrival interval | Quantity per request |
| --- | --- | --- |
| 0–9 (and negative) | 18–26 seconds | 1 |
| 10–19 | 16.7–24.2 seconds | 1–2 |
| 50–59 | 11.5–17 seconds | 1–6 |
| 90+ | 6.3–9.8 seconds | 1–10 |

Each interval is sampled when scheduled; reputation changes affect future
scheduled intervals and newly arriving orders. Existing quantities stay fixed.

At the counter, press **Y** to accept or **N** to reject the
front customer's request within **10 seconds**. This decision timer starts once
they reach the front; queued customers retain their full decision window.
Rejecting or leaving a request unanswered costs **3 reputation**.

Accepting starts a separate **30-second** fulfilment timer. Carry the exact
finished product to the left counter and press **E**. Only the **front customer**
can be served. Players can deliver one item at a time cooperatively; the HUD
shows **delivered / requested**. Horseshoes sell for **10 coins each**, swords for
**15**, and axes for **25**, before the delivering dwarf's sales bonus. Each item
pays immediately and earns **5 EXP** for its deliverer. Partial deliveries do not
reset the timer or award reputation. Completing the entire request gives
**+2 shared reputation** and counts as one served request in the daily report.
Failing an accepted order, including a partially delivered one, costs **6
reputation** and counts as one failed request. Already delivered items remain
sold and paid. Accepted orders cannot be rejected. The HUD shows each request's
phase, quantity, timer, unit price, coins, and reputation, which can fall below zero.

## Player progression

Every dwarf starts at level 1. Completing a mining cycle earns **2 EXP**, station
work earns **3 EXP**, and delivering each requested item earns **5 EXP**. Work EXP
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
upgrades, dedicated servers, internet matchmaking, or mine depletion yet.

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
