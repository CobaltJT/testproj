# Hearth & Hammer

A small Godot 4.6.x / GDScript LAN co-op platformer about running a dwarven smithy.
Open `project.godot` and press **F5**. One player hosts; others enter that player's
LAN IP and use the same UDP port (default **24567**). Allow that port through the
host's LAN firewall. `127.0.0.1` is for multiple instances on one computer.

## Expand the smithy

Start with **two ground-floor rooms** and no mine or workstations. Click the
**green + markers outside the current room** to purchase adjoining rooms.
Arrows show the expansion direction and each marker shows its coin price.
Only markers adjoining your dwarf’s current room appear; entering another room
updates them.
Walk toward a room edge to bring its marker into your camera view. Room purchases
are separate from the workshop menu. Ladders connect vertically adjacent
building rooms automatically. Move any workstation blocking a new ladder before expanding.

| Building level | Cost per room |
| --- | --- |
| Basement | 15 |
| Ground floor | 25 |
| First floor | 45 |
| Second floor | 70 |

Buy **basement room 2**, then click the **mine signpost purchase marker**
for its **30-coin entrance**, including the first underground chamber. Expand sideways at a purchased depth, or down the
central shaft in room 2 to unlock the next depth. Deeper shaft rooms must be
bought in order. Additional chambers cost **25 / 40 / 60 coins** at depths 1 / 2 / 3.
Each underground room unlocks its own ore vein. This first version supports five
room columns, four building levels and three underground depths.

Expansion changes walls, floors, ladders, mine access and camera bounds for all
players. Stations and rails require purchased floor space; elevator upgrades
require the corresponding mine depth. Purchases use shared coins, count in daily
spending, and receive the buyer's Bargainer discount. Duplicate purchases never
charge twice. Rooms remain across days and reconnects; starting a new hosted
session restores the two-room layout.

## Player cameras

Each player has a personal camera following their own dwarf, horizontally and
between floors. The default resolution is **1280×720**. The view is **160 world pixels high**,
roughly **two floors**,
with smooth following and bounds at the map edges. Remote dwarfs never control
your camera. The HUD and build catalog stay fixed on screen; station placement
uses the camera transform. Resize the window without changing the vertical world
coverage. The connection menu returns to an overview of the whole building.

## Build your workshop

The starting building has **no workstations**. The counter and door are fixed;
rooms, mine access and furniture are purchased. You start with **100 shared coins**
and eight loose ore pieces on the ground floor.

Press **Tab** or click **Workshop** to open the menu. Its **Build** tab offers:

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
You can place multiple stations of each type and use all purchased building floors.

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

At an empty anvil, press **T** to cycle its shared recipe in this order:

| Cycle order | Anvil recipe | Input → output |
| --- | --- | --- |
| 1 | Horseshoe | Ingot → finished horseshoe |
| 2 | Blade | Ingot → unfinished sword |
| 3 | Axe head | Ingot → axe head |
| 4 | Assemble axe | Axe head + worked shaft → finished axe |

- **Horseshoe:** smelt an ingot at the forge, then shape it at an anvil.
- **Sword:** make a blade at an anvil, then load and work it at a grinder to sharpen it.
- **Axe:** make a head at an anvil; make a shaft from wood at a woodworking bench;
  load both at an anvil set to Assemble axe and work to assemble the axe.

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
Carried intermediate products can also be deposited into a nearby movable
parts bin before using a placeable; carried ore can be deposited into mine carts.
Furniture lets dwarfs walk past it; output trays collide with physical items.

## Mine ore and buy wood

Purchase the basement entrance at **(390, 288)** using its signpost marker.
The purchased entrance has a timber frame and pickaxe sign. An **80-pixel dark earth
layer** separates the basement from the first mine chamber; the ladder runs
through a narrow shaft in that layer.
Its ladder starts with one underground floor and extends as deeper central
chambers are bought, reaching y=448, 528, and 608. Walk sideways onto a landing
to leave the ladder. The local camera follows through the mine with a two-floor
viewport. Each purchased underground room has one ore vein. Stand beside a
vein with empty hands, stay still, and **hold E for three seconds** to produce a
physical ore piece beside that vein. Each vein has independent work progress:
release E, move away, jump, or get hit to pause; another dwarf can finish the
same vein. Players on separate veins can work concurrently. Prospector speed
bonuses and +2 mining EXP apply as before. Veins do not deplete yet.

Mining is enabled during shop hours and pauses in morning and evening; progress
persists across days and reconnects. The ladder remains navigable. Placeable
workstations remain limited to the building, while movable parts bins can be
carried underground. The entrance itself no longer produces ore.

Wood comes **only from the merchant**. The merchant first visits 12 seconds after
opening, stays 20 seconds, and returns every 45 seconds. Each visit offers four
wood at **5 coins each**. Stand beside the purple merchant between the counter
and the ground-floor build area with empty hands, then click the **coin-bag
buy button** on the merchant card. It is disabled without stock, funds, proximity
or free hands; the host rechecks those conditions.
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

## Movable parts bins and draw order

The Build catalog also sells a **movable parts bin** for **15 coins**, before
Bargainer discounts. It holds **10 intermediate products** and is purchased directly into
empty hands. It is a physics object rather than grid-placed furniture.

- **C**: pick up or drop the bin, including its contents. The nearer bin or cart is selected;
  C releases an already coupled cart first.
- **Q / F**: drop or throw the bin. It stays upright and retains its contents.
- Loose bins catch falling/thrown intermediate products through their open top. Wrong items and
  overflow stay loose. Carried bins do not catch items.
- **E**, carrying an intermediate product near a loose bin: deposit it manually.
- **E**, empty hands near a stocked loose bin: take one original product out.
  E on an empty movable bin does nothing.

Raw ore, wood and finished products are rejected. Loaded bins retain the exact item identities across movement, multiplayer,
reconnects, and days. The host validates purchases, capacity, access range and
transfers; moving and storing items grants no EXP.

The world renders background first, then stationary objects, then characters,
then movable objects (including carried objects). This order is consistent for
hosts and clients and does not change collision behavior.

## Mine transport: elevator, rails and ore carts

Open **TAB → Transport**. Each elevator segment costs **30 coins**, rail sections
cost **5**, and mine carts cost **25**, before Bargainer discounts. Purchases use
shared coins and appear in daily spending.

Upgrade the shaft from the basement down, **mine level 1 → 2 → 3**. Only the
next segment can be purchased; levels cannot be skipped or bought twice.
Upgraded ladder sections become an elevator shaft. The ladder below the lowest
upgraded stop remains usable, including descending through the lowest platform.
At an unlocked landing, **W/S** calls the elevator to that landing when it is
elsewhere. Step onto the platform and press **W/S** again to travel one stop up
or down. All players standing on the platform and carts parked on it ride along.
The elevator cannot travel into locked levels.

Each unlocked elevator landing has free **starting rails on both sides**.
Buy a rail section, then click a green preview to extend an existing rail on the
same floor. Sections are 32 pixels long and cannot float, overlap, skip a gap,
cover the shaft, or extend into locked levels. **Esc** refunds an unplaced rail.
Rails are limited to the basement and the three mine floors.

Stand beside rails with empty hands to buy a cart. **C** couples or releases a
nearby unoccupied cart without moving either the player or the cart. **A/D**
pushes it along its rails. The player remains stationary until the far edge of
the moving cart reaches them, then follows that edge. Reversing direction lets
the cart move back across the player before they follow its opposite edge.
**Jump** also releases
it. A cart stops at the end of the connected track and cannot be picked up,
thrown, or driven across gaps. A stationary elevator platform bridges the shaft;
roll the cart onto it, then use W/S to travel between unlocked floors.

Carts hold **25 raw ore**, catching falling/thrown ore automatically. **E** loads
carried ore into a nearby cart; **E**, with empty hands, retrieves one ore.
The same E interaction withdraws from stocked movable parts bins.
Intermediate and finished products are rejected, and overflow stays loose.
Loaded carts retain exact ore identities during movement, elevator rides,
reconnects and day changes. The host owns all transport movement and purchases.

## HUD and help

The gameplay HUD shows shared coins/reputation, the day phase and shop clock,
the held item's icon, EXP, and highlighted unspent skill points. Small customer
and merchant icons appear only while those visitors are present; the customer
icon includes the waiting count. There is no text customer panel or empty-hands
label.

Customers have screen-space cards above them with a product icon, quantity still
needed, and remaining time. Amber marks requests awaiting a decision; green marks accepted orders,
including queued orders. The card buttons accept or reject that specific order. Merchant cards
show a wood icon, stock, price and remaining visit time. Cards follow their
visitors and stay the same size as the camera moves. Station recipes use icons,
and work progress uses bars without progress text. Mine labels are removed.

Concise notifications cover customer/merchant arrivals,
completed or failed requests, unanswered expiry, shop opening/closing and new
days. Shared event notifications are queued, and joining players do not replay
historical events. Accepting an order and routine storage, loading, or retrieval
actions do not produce toasts. Detailed action feedback remains in the F1 guide.

**Hold F1** for a compact control reference; release it to close. It lists
movement, interaction, workshop, recipe, storage, customer, cart and elevator
keys without the longer gameplay explanations. It does not
pause the game. Connection details and recent detailed feedback live there too.

Map control captions and debug-style character labels have been removed.
Product icons, storage counts and progress bars appear near the local dwarf;
visitor details appear on their overhead cards. Short action notifications fade
away, while persistent control instructions stay in the F1 overlay.

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

Click the **green check** on any customer card to accept, or the **red cross**
to reject. Decisions do not require standing at the counter and can be made
while customers are walking in or waiting behind others. The **10-second
decision timer starts on arrival** and runs for every customer independently.
Rejecting or leaving an unaccepted request unanswered costs **3 reputation**
(before Diplomat discounts for explicit rejection only).

Accepting starts a fresh **30-second** fulfilment timer, which continues during
walking and queuing. An accepted request cannot be accepted again to reset its
deadline. Its red cross remains available: rejecting it counts as a **failed
order**, costs **6 reputation** with no Diplomat discount, and counts in the
daily failed-order statistic. It does not count as an unaccepted rejection.
The Y/N decision keys and B merchant-buy key have been removed.

Only the **front customer**, once at the counter, can receive products. Carry a
matching finished product to the counter and press **E**. Players can deliver
one item at a time cooperatively. Cards show the quantity still needed and the
remaining timer. Horseshoes sell for **10 coins each**, swords for **15**, and
axes for **25**, before the delivering dwarf's sales bonus. Each item pays
immediately and earns **5 EXP**. Partial deliveries do not reset the timer or
award reputation. Completing the entire request gives **+2 shared reputation**
and counts as one served request. An accepted order that times out, even while
queued, costs **6 reputation**. Already delivered items remain sold and paid.

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
| Trade root | Bargainer | −10% purchase prices, including rooms and transport | 3 |
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
reset stations, resources, budget, reputation, day, and clocks. No disk persistence,
dedicated servers, internet matchmaking, or mine depletion yet.

## Validation

Run **`bash tools/check.sh`** with Godot 4.6.x and Python 3 available. It isolates
Godot's writable settings in temporary folders, imports and starts the project,
and runs:

- Room pricing, adjacency, locked areas, mine unlocking, ladder connections,
  world collision changes, purchase races and room restoration for late joiners.
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
