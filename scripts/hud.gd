extends Control
## Presentation only: local HUD and hold-to-read controls, outside world camera transforms.
var game: Node
var connection_panel: Control
var shop: Label
var held: Label
var held_icon: TextureRect
var exp_bar: ProgressBar
var day_bar: ProgressBar
var notice: Label
var notice_until := 0
var help_layer: CanvasLayer
var help_panel: PanelContainer
var help_status: Label
var last_message := ""
var panels: Array[Control] = []
const VISITOR_CARD = preload("res://scripts/visitor_card.gd")
var order_cards: Dictionary = {}
var merchant_card: PanelContainer
var customer_badge: PanelContainer
var merchant_badge: PanelContainer
var customer_count: Label
var toast_queue: Array[String] = []
var events_ready := false
var seen: Dictionary = {}

func skin() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.085, 0.115, 0.95)
	style.border_color = Color(0.36, 0.33, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func card(anchor: Vector2, offset: Vector2, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", skin())
	add_child(panel)
	panel.anchor_left = anchor.x
	panel.anchor_right = anchor.x
	panel.anchor_top = anchor.y
	panel.anchor_bottom = anchor.y
	panel.offset_left = offset.x
	panel.offset_right = offset.x + width
	panel.offset_top = offset.y
	panel.offset_bottom = -16 if anchor.y == 1 else offset.y + 1
	if anchor.y == 1: panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size.x = width
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	panels.append(panel)
	return column

func label(text: String, size: int = 14) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func move_label(node: Control, parent: Node, size: int) -> void:
	node.reparent(parent)
	node.position = Vector2.ZERO
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func bar(parent: Node) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size.y = 5
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("303745")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("d4a75b")
	node.add_theme_stylebox_override("background", background)
	node.add_theme_stylebox_override("fill", fill)
	parent.add_child(node)
	return node

func setup(session: Node, layer: CanvasLayer, menu_panel: Control) -> void:
	game = session
	connection_panel = menu_panel
	layer.add_child(self)
	layer.move_child(self, 0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color", Color("e5dccb"))
	var store := card(Vector2.ZERO, Vector2(16, 16), 268)
	store.add_child(label("SMITHY", 12))
	shop = label("", 17)
	store.add_child(shop)
	move_label(game.merchant_label, store, 12)
	var day := card(Vector2(0.5, 0), Vector2(-150, 16), 300)
	move_label(game.day_label, day, 16)
	day_bar = bar(day)
	game.open_button.reparent(day)
	game.open_button.position = Vector2.ZERO
	game.open_button.text = "Open shop"
	var player := card(Vector2(0, 1), Vector2(16, -90), 320)
	move_label(game.progression_label, player, 14)
	exp_bar = bar(player)
	var row := HBoxContainer.new()
	player.add_child(row)
	held_icon = TextureRect.new()
	held_icon.custom_minimum_size = Vector2(28, 28)
	held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	held_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(held_icon)
	held = label("")
	held.hide()
	row.add_child(held)
	game.order_label.hide()
	var visitors := HBoxContainer.new()
	visitors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visitors)
	visitors.anchor_left = 1
	visitors.anchor_right = 1
	visitors.anchor_top = 1
	visitors.anchor_bottom = 1
	visitors.offset_left = -124
	visitors.offset_right = -16
	visitors.offset_top = -64
	visitors.offset_bottom = -16
	customer_badge = visitor_badge(visitors, false)
	merchant_badge = visitor_badge(visitors, true)
	merchant_card = VISITOR_CARD.new()
	add_child(merchant_card)
	var actions := HBoxContainer.new()
	add_child(actions)
	actions.anchor_left = 1
	actions.anchor_right = 1
	actions.offset_left = -280
	actions.offset_right = -16
	actions.offset_top = 16
	actions.offset_bottom = 52
	actions.custom_minimum_size.x = 264
	game.build_button.reparent(actions)
	game.build_button.position = Vector2.ZERO
	game.build_button.text = "Workshop"
	game.build_button.custom_minimum_size.x = 120
	var leave := Button.new()
	leave.text = "Leave"
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(func(): game.disconnect_game("Disconnected"))
	actions.add_child(leave)
	var help_badge := label("F1 · Help", 12)
	help_badge.modulate = Color("a6a6a9")
	actions.add_child(help_badge)
	notice = label("", 13)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(notice)
	notice.anchor_left = 0.5
	notice.anchor_right = 0.5
	notice.anchor_top = 1
	notice.anchor_bottom = 1
	notice.offset_left = -220
	notice.offset_right = 220
	notice.offset_top = -60
	notice.offset_bottom = -15
	make_help()

func make_help() -> void:
	help_layer = CanvasLayer.new()
	help_layer.layer = 10
	game.add_child(help_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.03, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_layer.add_child(shade)
	help_panel = PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", skin())
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_panel.offset_left = 48
	help_panel.offset_right = -48
	help_panel.offset_top = 38
	help_panel.offset_bottom = -38
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_layer.add_child(help_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	help_panel.add_child(column)
	column.add_child(label("HEARTH & HAMMER · FIELD GUIDE", 23))
	column.add_child(label("Hold F1 to read · Release to return · Gameplay continues", 14))
	var grid := HBoxContainer.new()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 24)
	column.add_child(grid)
	var guides := [
		"[b]MOVEMENT & HANDS[/b]\nA/D or arrows: walk\nSpace: jump / release ladder\nW/S or up/down: climb\n\nE: pick up nearby loose objects first\nE with an item: load / store / deliver\nF: throw · Q: drop\nOne item in hand at a time\n\n[b]BUILDING & SKILLS[/b]\nTab: Workshop menu\nBuy, then click a green floor preview\nRed preview: blocked\nEsc: close / refund unplaced kit\nR: pack an empty, idle placeable\n\nTab → Skills: spend skill points\nMining +2 EXP · Crafting +3 EXP\nEach delivered item +5 EXP\nLevel costs: 10, 15, 20 EXP, etc.\nEach level grants one skill point",
		"[b]CRAFTING & MINING[/b]\nE: load · Hold E empty-handed: work\nMove / jump / release E to pause\nHelpers do not stack work speed\nForge: throw raw ore into its bin\nHold E to smelt an iron ingot\nAnvils require ingots, not raw ore\n\nAnvil recipes: 1 horseshoe · 2 blade\n3 axe head · 4 assemble axe\nGrinder: unfinished blade → sword\nWoodbench: wood → shaft\nAxe assembly: axe head + shaft\n\nBasement shaft: three mine levels\nTwo veins per level · Hold E to mine\nMining only during shop hours\n\n[b]STORAGE[/b]\nE: store / retrieve selected product\nT: cycle product in fixed storage\nIntermediate bins catch thrown parts\nFinished shelves require manual E\nMovable parts bin: E pick up, F/Q move\nG: withdraw a part from a loose bin",
		"[b]SHOP & CUSTOMERS[/b]\nMorning: prepare, then Open shop\nShop hours: 120 seconds\nEvening: finish remaining customers\nOnly the front customer can be served\nAmber: decide · Green: accepted\nY: accept · N: reject (10 seconds)\nAccepted orders: 30 seconds to finish\nE: deliver one matching item\nFull order +2 reputation\nReject / unanswered −3 · Failed −6\nB near purple merchant: buy wood\n\n[b]ELEVATOR & RAILS[/b]\nTab → Transport: buy upgrades / rails\nUpgrade elevator top to bottom\nAt a landing, W/S calls the lift\nOn its platform, W/S travels a stop\nRails must extend existing tracks\nC: couple / release nearby cart\nA/D: push · Jump: release\nCart moves first, then player at its edge\nE: load / withdraw ore · 25 ore per cart\nPark cart on lift to change floors"
	]
	for text in guides:
		var guide := RichTextLabel.new()
		guide.bbcode_enabled = true
		guide.text = text
		guide.add_theme_font_size_override("normal_font_size", 14)
		guide.add_theme_font_size_override("bold_font_size", 15)
		guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		guide.scroll_active = false
		guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(guide)
	help_status = label("", 12)
	help_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help_status)
	help_layer.hide()

func notify(message: String) -> void:
	last_message = message
	var short := message.split(". ")[0]
	if "Order complete!" in message: return # Shared completion event supplies one toast.
	if message.begins_with("Request accepted:"): short = "Order accepted · 30s"
	elif message.begins_with("Request rejected:"): short = "Order declined · " + message.get_slice(": ", 1).replace(" reputation.", " rep")
	elif message.begins_with("Storage:"): short = "Storage unavailable"
	elif message.begins_with("Wrong or duplicate"): short = "Wrong ingredient"
	elif message.begins_with("Cannot buy:"): short = "Purchase unavailable"
	elif message.begins_with("Cannot upgrade:"): short = "Upgrade unavailable"
	elif message.begins_with("Blocked placement:"): short = "Placement blocked"
	elif message.begins_with("Only empty, idle"): short = "Empty it before moving"
	elif message.begins_with("B buys wood:"): short = "Wood unavailable"
	elif message.begins_with("Mine closed"): short = "Mining unavailable"
	else:
		for control in ["E:", "Hold E", "Q:", "F:", "G:", "T:", "Tab:", "Picked up"]:
			if control in short: return
	show_toast(short.left(80))

func show_toast(text: String) -> void:
	notice.text = text
	notice_until = Time.get_ticks_msec() + 2400

func event_toast(text: String) -> void:
	if text == notice.text and Time.get_ticks_msec() < notice_until or text in toast_queue: return
	if Time.get_ticks_msec() >= notice_until: show_toast(text)
	else:
		if toast_queue.size() >= 8: toast_queue.pop_front()
		toast_queue.append(text)

func event_totals() -> Dictionary:
	return {"arrivals": game.orders.number, "failed": game.orders.missed, "served": game.orders.completed, "unanswered": game.orders.unanswered, "visits": game.merchant.visits, "merchant_present": game.merchant.remaining > 0, "phase": game.cycle.phase, "day": game.cycle.day}

func reset_events() -> void:
	seen = event_totals()
	events_ready = true
	toast_queue.clear()
	notice_until = 0

func observe_events() -> void:
	if not events_ready: return
	var now := event_totals()
	if now.arrivals > seen.arrivals:
		var count: int = now.arrivals - seen.arrivals
		event_toast("Customer arrived" if count == 1 else "%s customers arrived" % count)
	if now.visits > seen.visits and now.merchant_present: event_toast("Merchant arrived")
	elif seen.merchant_present and not now.merchant_present: event_toast("Merchant left")
	if now.served > seen.served: event_toast("Order complete · +2 rep")
	if now.unanswered > seen.unanswered: event_toast("Request expired · −3 rep")
	if now.failed > seen.failed: event_toast("Request failed · −6 rep")
	if now.day > seen.day: event_toast("Day %s" % now.day)
	elif now.phase != seen.phase:
		if now.phase == "shop": event_toast("Shop opened")
		elif now.phase == "evening": event_toast("Shop closed")
	seen = now

func visitor_badge(parent: Control, merchant: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", skin())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/textures/customer.svg")
	icon.custom_minimum_size = Vector2(22, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if merchant: icon.modulate = Color(0.85, 0.65, 1, 1)
	row.add_child(icon)
	if not merchant:
		customer_count = label("")
		row.add_child(customer_count)
	panel.hide()
	return panel

func tether(card: Control, npc: Node2D) -> void:
	var point: Vector2 = game.world.get_global_transform_with_canvas() * (npc.position + Vector2(0, -26))
	card.position = point - Vector2(card.size.x / 2, card.size.y + 5)
	card.visible = npc.visible and get_viewport_rect().has_point(point)

func update_visitors() -> void:
	customer_badge.visible = not game.orders.queue.is_empty()
	customer_count.text = str(game.orders.queue.size())
	merchant_badge.visible = game.merchant.remaining > 0
	var live: Dictionary = {}
	for index in range(game.orders.queue.size()):
		var order: Dictionary = game.orders.queue[index]
		live[order.id] = true
		if not order_cards.has(order.id):
			order_cards[order.id] = VISITOR_CARD.new()
			add_child(order_cards[order.id])
		var card = order_cards[order.id]
		var color := Color("7db59b") if order.accepted else (Color("d5af65") if index == 0 else Color("697482"))
		card.update_card(game.material_texture(order.kind), order.get("quantity", 1) - order.get("delivered", 0), order.remaining, 30.0 if order.accepted else 10.0, color)
		if game.customer_nodes.has(order.id): tether(card, game.customer_nodes[order.id])
	for id in order_cards.keys():
		if not live.has(id):
			order_cards[id].free()
			order_cards.erase(id)
	merchant_card.visible = game.merchant.remaining > 0
	if merchant_card.visible:
		merchant_card.update_card(game.material_texture("wood"), game.merchant.stock, game.merchant.remaining, game.MERCHANT_STATE.STAY, Color("b59ad3"), game.progression.purchase_price(game.multiplayer.get_unique_id(), game.MERCHANT_STATE.WOOD_PRICE))
		tether(merchant_card, game.merchant_node)

func _process(_delta: float) -> void:
	visible = game.active
	connection_panel.visible = not game.active
	var help_held: bool = Input.is_action_pressed("show_help")
	help_layer.visible = help_held
	help_status.text = game.status.text + ("\n" + last_message if last_message != "" else "")
	game.hint.hide()
	game.recipe_label.hide()
	if not game.active:
		events_ready = false
		toast_queue.clear()
		return
	observe_events()
	if Time.get_ticks_msec() >= notice_until and not toast_queue.is_empty(): show_toast(toast_queue.pop_front())
	update_visitors()
	game.order_label.hide()
	shop.text = "Coins: %s    Rep: %s" % [game.orders.coins, game.orders.reputation]
	game.merchant_label.visible = false
	game.merchant_label.text = "Wood %sc · %s left · %ss" % [game.progression.purchase_price(game.multiplayer.get_unique_id(), game.MERCHANT_STATE.WOOD_PRICE), game.merchant.stock, ceili(game.merchant.remaining)]
	var local: int = game.multiplayer.get_unique_id()
	var item: int = game.ore.carried_by(local)
	held_icon.texture = null
	held.text = ""
	held.hide()
	if item != -1:
		var kind: String = game.ore.pieces[item].kind
		held_icon.texture = game.material_texture(kind)
		held_icon.tooltip_text = kind.replace("_", " ").capitalize() if kind != "ore_bin" else "Parts bin · %s/10" % game.ore.pieces[item].contents.size()
	elif game.workshop.pending.has(local):
		var kind: String = game.workshop.pending[local].kind
		held_icon.texture = game.STATION_VIEW.TEXTURES[kind]
		held_icon.tooltip_text = "Kit · " + game.WORKSHOP_STATE.display_name(kind)
	elif game.transport.pending.has(local):
		held_icon.texture = preload("res://assets/textures/rail.svg")
		held_icon.tooltip_text = "Rail section"
	if game.progression.dwarfs.has(local):
		var dwarf: Dictionary = game.progression.dwarfs[local]
		game.progression_label.text = "Level %s · %s/%s EXP%s" % [dwarf.level, dwarf.exp, game.progression.required(dwarf.level), " · +%s skill point%s" % [dwarf.points, "" if dwarf.points == 1 else "s"] if dwarf.points > 0 else ""]
		game.progression_label.modulate = Color("f1c56e") if dwarf.points > 0 else Color.WHITE
		exp_bar.max_value = game.progression.required(dwarf.level)
		exp_bar.value = dwarf.exp
	day_bar.visible = game.cycle.phase == "shop"
	day_bar.max_value = game.DAY_STATE.SHOP_DURATION
	day_bar.value = game.cycle.remaining
	notice.visible = Time.get_ticks_msec() < notice_until and game.cycle.phase not in ["summary", "transition"]
	notice.modulate.a = clampf((notice_until - Time.get_ticks_msec()) / 500.0, 0, 1)
	var at: Vector2 = game.players[local].position if game.players.has(local) else Vector2.INF
	for id in game.station_nodes:
		var nearby: bool = absf(game.workshop.stations[id].at.x - at.x) < 60 and absf(game.workshop.stations[id].at.y - at.y) < 12
		game.station_nodes[id].get_node("Label").visible = nearby
		game.station_nodes[id].get_node("ProductIcon").visible = nearby
	for id in game.vein_nodes:
		game.vein_nodes[id].get_node("WorkLabel").visible = false
	for id in game.ore_bodies:
		if game.ore.pieces[id].kind == "ore_bin": game.ore_bodies[id].get_node("Count").visible = game.world.to_local(game.ore_bodies[id].global_position).distance_to(at) < 65
	for id in game.cart_nodes:
		game.cart_nodes[id].get_node("Count").visible = game.transport.carts[id].at.distance_to(at) < 65
	for customer in game.customer_nodes.values():
		customer.get_node("Request").visible = false
	game.merchant_node.get_node("Label").visible = false
	game.order_label.modulate = Color("efb274") if not game.orders.queue.is_empty() and not game.orders.queue[0].accepted else Color.WHITE
