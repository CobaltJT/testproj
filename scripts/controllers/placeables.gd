extends RefCounted
## Stationary production and recovery; interaction methods retain independent priorities.
const CONTEXT = preload("res://scripts/interaction/context.gd")
const WORKSHOP = preload("res://scripts/workshop_state.gd")
const JOB = preload("res://scripts/station_job.gd")
const NEEDS = preload("res://scripts/needs_state.gd")
const MAP = preload("res://scripts/map_layout.gd")
signal items_changed
signal workshop_changed
signal feedback_requested(id: int, message: String)
var workshop: RefCounted
var items: RefCounted
var needs: RefCounted
var cycle: RefCounted
var find_vein: Callable
var views: Dictionary = {}

signal experience_requested(id: int, task: String)
signal output_ready(piece: int, at: Vector2)
signal production_completed
signal mining_completed
var players: Dictionary = {}
var work_held: Dictionary = {}
var progression: RefCounted
var mine_veins: Dictionary = {}
var authoritative := false

const TRANSPORT = preload("res://scripts/transport_state.gd")
const STATION_SCENE = preload("res://scenes/workstation.tscn")
const STATION_VIEW = preload("res://scripts/station_view.gd")
signal build_changed
signal transport_changed
var world: Node2D
var transport: RefCounted
var economy: RefCounted
var preview: Sprite2D
var lift_node: Node2D
var lift_riders: Dictionary = {}
var rail_nodes: Array = []
var shown_tracks: Array = []
var shaft_nodes: Array = []

func bind(stations: RefCounted, inventory: RefCounted, vitals: RefCounted, day: RefCounted, mining_query: Callable) -> void:
	workshop = stations
	items = inventory
	needs = vitals
	cycle = day
	find_vein = mining_query

func station(context: CONTEXT) -> int:
	return context.query(&"station", workshop.nearest)

func try_mine(context: CONTEXT) -> bool:
	if context.action != &"interact" or context.query(&"vein", find_vein) == -1: return false
	feedback_requested.emit(context.player_id, "Mine closed until shop hours." if cycle.phase != "shop" else "Hold E with empty hands to mine ore. Prospector speeds up extraction.")
	return true

func try_storage(context: CONTEXT) -> bool:
	if context.action != &"interact": return false
	var id := station(context)
	if id == -1 or workshop.stations[id].kind not in WORKSHOP.STORAGE: return false
	var transferred: bool = workshop.storage_transfer(context.player_id, context.position, items, id)
	var message := "Stored item." if transferred and context.carried_item != -1 else ("Retrieved item. T: select another stored product." if transferred else "Storage: check category, capacity and selected product. T: cycle products.")
	workshop_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func try_care(context: CONTEXT) -> bool:
	if context.action != &"interact": return false
	var id := station(context)
	if id == -1 or workshop.stations[id].kind not in WORKSHOP.CARE: return false
	var entry: Dictionary = workshop.stations[id]
	var message: String
	if entry.kind == "bed": message = "Hold E with empty hands to sleep."
	elif context.carried_item != -1 and needs.dwarfs[context.player_id].food < 100 and entry.job.load_material(context.player_id, items): message = "Meal loaded. Hold E to eat."
	else: message = "Carry food to an empty table, then hold E to eat."
	workshop_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func try_load(context: CONTEXT) -> bool:
	if context.action != &"interact" or context.carried_item == -1: return false
	var id := station(context)
	if id == -1: return false
	var job = workshop.stations[id].job
	var message := "Ingredient loaded. Hold E with empty hands to work." if job.load_material(context.player_id, items) else ("Throw ore into the attached forge bin, then hold E to smelt." if job.kind == "forge" else "Wrong or duplicate ingredient for this station recipe.")
	workshop_changed.emit()
	items_changed.emit()
	feedback_requested.emit(context.player_id, message)
	return true

func try_cycle(context: CONTEXT) -> bool:
	if context.action != &"cycle_storage": return false
	var id := station(context)
	if id == -1: return false
	if workshop.stations[id].kind == "anvil":
		var job = workshop.stations[id].job
		var next: String = JOB.ANVIL_RECIPES[(JOB.ANVIL_RECIPES.find(job.recipe) + 1) % JOB.ANVIL_RECIPES.size()]
		if job.select(next): workshop_changed.emit()
		return true
	if workshop.stations[id].kind not in WORKSHOP.STORAGE: return false
	if workshop.cycle_storage(context.player_id, context.position, items, id): workshop_changed.emit()
	return true

func catch_item(piece: int, body: RigidBody2D) -> bool:
	if not items.is_loose(piece) or body.linear_velocity.y < 0: return false
	for id in workshop.stations:
		if not views.has(id): continue
		var entry: Dictionary = workshop.stations[id]
		var caught := false
		if entry.kind in WORKSHOP.STORAGE and WORKSHOP.STORAGE[entry.kind].group == "intermediate" and views[id].get_node("PartsCatch").overlaps_body(body):
			caught = workshop.catch_intermediate(id, piece, items)
		elif entry.kind == "forge" and views[id].get_node("BinCatch").overlaps_body(body):
			caught = entry.job.store_ore(piece, items)
		if caught:
			workshop_changed.emit()
			return true
	return false

func bind_workers(actors: Dictionary, held: Dictionary, skills: RefCounted, veins: Dictionary, simulate: bool) -> void:
	players = actors
	work_held = held
	progression = skills
	mine_veins = veins
	authoritative = simulate

func available(id: int) -> bool:
	var dwarf = players[id]
	return work_held.get(id, false) and not workshop.pending.has(id) and not dwarf.transport_locked and dwarf.is_on_floor() and not dwarf.climbing and dwarf.hit_stun == 0 and dwarf.controls.is_zero_approx() and not dwarf.jump_held and items.carried_by(id) == -1

func forget_actor(id: int) -> void:
	lift_riders.erase(id)
	for entry in workshop.stations.values():
		if entry.job.diner == id:
			for piece in entry.job.slots.values():
				items.pieces[piece].consumed = true
				items.pieces[piece].processing = false
			entry.job.slots.clear()
			entry.job.progress = 0
			entry.job.worker = 0
			entry.job.diner = 0

func step_workstations(delta: float) -> void:
	if not authoritative: return
	var changed := false
	for station_id in workshop.stations:
		var entry: Dictionary = workshop.stations[station_id]
		if entry.kind in WORKSHOP.STORAGE or entry.kind in WORKSHOP.CARE:
			continue
		var eligible: Array[int] = []
		for id in players:
			if available(id) and needs.working(id) > 0 and workshop.nearest(players[id].position) == station_id:
				eligible.append(id)
		eligible.sort()
		var worker: int = entry.job.worker if entry.job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		var specialty := "woodworking" if entry.kind == "woodbench" else "smithing"
		var before: float = entry.job.progress
		var output: int = entry.job.step(delta * progression.speed(worker, specialty) * needs.working(worker), eligible, items)
		if worker != 0 and (entry.job.progress > before or output != -1): needs.exert(worker, delta)
		if output != -1:
			experience_requested.emit(worker, "crafting")
			output_ready.emit(output, entry.at + Vector2(28, -18))
			changed = true
	if changed: production_completed.emit()

func step_mining(delta: float) -> void:
	if not authoritative: return
	for vein in mine_veins:
		var job = mine_veins[vein]
		var eligible: Array[int] = []
		if cycle.phase == "shop":
			for id in players:
				if available(id) and needs.working(id) > 0 and find_vein.call(players[id].position) == vein:
					eligible.append(id)
		eligible.sort()
		var worker: int = job.worker if job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		var before: float = job.progress
		var finished: bool = job.step(delta * progression.speed(worker, "mining") * needs.working(worker), eligible)
		if worker != 0 and (job.progress > before or finished): needs.exert(worker, delta)
		if finished:
			experience_requested.emit(worker, "mining")
			var piece_id: int = items.add_mined_ore()
			var output: Vector2 = MAP.VEINS[vein] + Vector2(-46, -12)
			output_ready.emit(piece_id, output)
			mining_completed.emit()

func care_eligible(id: int, station: int) -> bool:
	return available(id) and workshop.nearest(players[id].position) == station

func step_care(delta: float) -> void:
	if not authoritative: return
	var changed := false
	for station in workshop.stations:
		var entry: Dictionary = workshop.stations[station]
		if entry.kind not in WORKSHOP.CARE: continue
		var eligible: Array[int] = []
		for id in players:
			if care_eligible(id, station) and (entry.kind == "bed" and needs.dwarfs[id].energy < 100 or entry.kind == "dining" and entry.job.diner == id and needs.dwarfs[id].food < 100): eligible.append(id)
		eligible.sort()
		var job = entry.job
		job.worker = job.worker if job.worker in eligible else (eligible[0] if not eligible.is_empty() else 0)
		if job.worker == 0: continue
		if entry.kind == "bed":
			needs.change(job.worker, NEEDS.SLEEP_RATE * delta, 0)
		elif job.slots.has("food"):
			var rate: float = NEEDS.MEAL_FOOD / NEEDS.MEAL_DURATION
			var elapsed := minf(delta, minf(NEEDS.MEAL_DURATION - job.progress, (100 - needs.dwarfs[job.worker].food) / rate))
			needs.change(job.worker, 0, elapsed * rate)
			job.progress += elapsed
			if job.progress >= NEEDS.MEAL_DURATION - 0.00001 or needs.dwarfs[job.worker].food >= 100 - 0.00001:
				items.pieces[job.slots.food].processing = false
				items.pieces[job.slots.food].consumed = true
				job.slots.clear()
				job.diner = 0
				job.worker = 0
				job.progress = 0
				changed = true
	if changed: items_changed.emit()

func bind_placement(tracks: RefCounted, shop_economy: RefCounted) -> void:
	transport = tracks
	economy = shop_economy

func can_act(id: int) -> bool:
	return authoritative and players.has(id) and cycle.phase not in ["summary", "transition"]

func purchase(id: int, kind: String) -> void:
	if not can_act(id) or transport.pending.has(id): return
	if not workshop.purchase(id, kind, economy, items, 1.0 - 0.1 * progression.rank(id, "purchasing")):
		feedback_requested.emit(id, "Cannot buy: check coins, empty hands, and any unplaced kit.")
	build_changed.emit()

func place(id: int, at: Vector2) -> void:
	if not can_act(id): return
	if workshop.place(id, at) == -1:
		feedback_requested.emit(id, "Blocked placement: keep paths, fixed fixtures, and other stations clear.")
	build_changed.emit()

func cancel_build(id: int) -> void:
	if not can_act(id): return
	release_build(id)

## Disconnect cleanup must refund kits even while the day summary pauses input.
func release_build(id: int) -> void:
	if not authoritative: return
	transport.cancel(id, economy)
	transport_changed.emit()
	workshop.cancel(id, economy)
	build_changed.emit()

func pack(id: int) -> void:
	if not can_act(id) or transport.pending.has(id): return
	if not workshop.pack(id, players[id].position, items):
		feedback_requested.emit(id, "Only empty, idle stations or containers can be packed; keep your hands free.")
	build_changed.emit()

func buy_transport(id: int, kind: String, level: int) -> void:
	if not can_act(id) or items.carried_by(id) != -1 or workshop.pending.has(id) or transport.pending.has(id): return
	var ok := false
	if kind == "lift": ok = transport.upgrade(level, economy, progression.purchase_price(id, TRANSPORT.UPGRADE_PRICE))
	elif kind == "rail": ok = transport.buy_rail(id, economy, progression.purchase_price(id, TRANSPORT.RAIL_PRICE))
	elif kind == "cart":
		var at: Vector2 = players[id].position
		for rail in transport.tracks:
			if absf(rail.y - at.y) < 6 and absf(rail.x - at.x) < 24:
				ok = transport.buy_cart(rail, economy, progression.purchase_price(id, TRANSPORT.CART_PRICE)) != -1
				break
	feedback_requested.emit(id, "Transport purchased." if ok else "Cannot buy: check coins, empty hands, upgrade order, and nearby rails for a cart.")
	transport_changed.emit()

func place_rail(id: int, at: Vector2) -> void:
	if not can_act(id): return
	transport.place_rail(id, at)
	transport_changed.emit()

func use_lift(id: int, direction: int) -> void:
	if not can_act(id) or direction not in [-1, 1] or absf(players[id].position.x - 390) > 30: return
	var stop := -1
	for i in range(transport.upgrades + 1):
		if absf(players[id].position.y - TRANSPORT.STOPS[i]) < 6: stop = i
	if stop == -1: return
	var aboard: bool = absf(players[id].position.x - 390) <= 16
	for cart in transport.carts.values():
		if cart.driver == id and absf(cart.at.x - 390) <= 16: aboard = true
	if absf(transport.lift_y - TRANSPORT.STOPS[stop]) <= 2 and not aboard: return
	var destination := stop if absf(transport.lift_y - TRANSPORT.STOPS[stop]) > 2 else stop + direction
	var old: float = transport.lift_y
	if transport.start_lift(destination):
		lift_riders.clear()
		for peer in players:
			if absf(players[peer].position.x - 390) <= 16 and absf(players[peer].position.y - old) < 6:
				lift_riders[peer] = true
				players[peer].climbing = false
				players[peer].transport_locked = true
		transport_changed.emit()

func step_lift(delta: float) -> Dictionary:
	if not authoritative: return {}
	for id in players: players[id].transport_locked = false
	var riders: Dictionary = lift_riders.duplicate()
	transport.step_lift(delta)
	for id in lift_riders:
		if players.has(id):
			players[id].transport_locked = true
			players[id].position = Vector2(players[id].position.x, transport.lift_y)
			players[id].velocity = Vector2.ZERO
	if not transport.moving: lift_riders.clear()
	return riders

func attach_world(root: Node2D) -> void:
	world = root
	preview = Sprite2D.new()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(preview)
	preview.hide()
	lift_node = Node2D.new()
	lift_node.z_index = 10
	world.add_child(lift_node)
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/textures/elevator.svg")
	sprite.position = Vector2(0, -24)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lift_node.add_child(sprite)
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 2
	lift_node.add_child(body)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(32, 4)
	shape.shape = rectangle
	shape.one_way_collision = true
	shape.one_way_collision_margin = 1.0
	shape.position.y = 2
	body.add_child(shape)

func refresh_stations() -> void:
	for id in views.keys():
		if not workshop.stations.has(id):
			views[id].free()
			views.erase(id)
	for id in workshop.stations:
		if not views.has(id):
			var view: Node2D = STATION_SCENE.instantiate()
			world.add_child(view)
			views[id] = view
		views[id].update_view(workshop.stations[id], items)

func refresh_transport_views() -> void:
	if lift_node == null: return
	lift_node.visible = transport.upgrades > 0
	lift_node.position = Vector2(390, transport.lift_y)
	lift_node.get_child(1).collision_layer = 16 if transport.upgrades > 0 else 0
	for id in players: players[id].mine_ladder_top = TRANSPORT.STOPS[transport.upgrades]
	while shaft_nodes.size() < transport.upgrades:
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/textures/shaft_lift.svg")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -9
		var segment := shaft_nodes.size()
		var top: float = TRANSPORT.STOPS[segment]
		var bottom: float = TRANSPORT.STOPS[segment + 1]
		sprite.position = Vector2(390, (top + bottom) / 2)
		sprite.scale.y = (bottom - top) / 80.0
		world.add_child(sprite)
		shaft_nodes.append(sprite)
	for i in range(shaft_nodes.size()): shaft_nodes[i].visible = i < transport.upgrades
	if shown_tracks != transport.tracks:
		shown_tracks = transport.tracks.duplicate()
		for node in rail_nodes: node.free()
		rail_nodes.clear()
		for at in transport.tracks:
			var sprite := Sprite2D.new()
			sprite.texture = preload("res://assets/textures/rail.svg")
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = at - Vector2(0, 2)
			sprite.z_index = 10
			world.add_child(sprite)
			rail_nodes.append(sprite)

func update_preview(id: int, mouse_at: Vector2, active: bool) -> bool:
	if preview == null: return false
	var carrying_kit: bool = active and cycle.phase not in ["summary", "transition"] and workshop.pending.has(id)
	preview.visible = carrying_kit
	if carrying_kit:
		var at: Vector2 = workshop.snap(mouse_at)
		preview.position = at + Vector2(8, -16)
		preview.texture = STATION_VIEW.TEXTURES[workshop.pending[id].kind]
		preview.modulate = Color(0.4, 1, 0.5, 0.7) if workshop.can_place(at) else Color(1, 0.3, 0.3, 0.7)
	if active and transport.pending.has(id) and cycle.phase not in ["summary", "transition"]:
		var at: Vector2 = transport.snap_rail(mouse_at)
		preview.visible = true
		preview.texture = preload("res://assets/textures/rail.svg")
		preview.position = at - Vector2(0, 2)
		preview.modulate = Color(0.4, 1, 0.5, 0.7) if transport.can_rail(at) else Color(1, 0.3, 0.3, 0.7)
	return preview.visible

func clear() -> void:
	authoritative = false
	for actor in players.values(): actor.transport_locked = false
	lift_riders.clear()
	for view in views.values(): view.free()
	views.clear()
	for node in rail_nodes: node.free()
	rail_nodes.clear()
	shown_tracks.clear()
	for node in shaft_nodes: node.free()
	shaft_nodes.clear()
	if preview != null: preview.hide()
	if lift_node != null:
		lift_node.hide()
		lift_node.get_child(1).collision_layer = 0
