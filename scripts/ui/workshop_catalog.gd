extends PanelContainer
## Owns the catalog controls. Signals express intent; this view never purchases.
signal station_requested(kind: String)
signal skill_requested(skill: String)
signal mobile_bin_requested
signal transport_requested(kind: String, level: int)
const WORKSHOP = preload("res://scripts/workshop_state.gd")
const PROGRESSION = preload("res://scripts/progression_state.gd")
const ITEMS = preload("res://scripts/ore_state.gd")
const TRANSPORT = preload("res://scripts/transport_state.gd")
var station_buttons: Dictionary = {}
var skill_buttons: Dictionary = {}
var transport_buttons: Dictionary = {}
var mobile_bin_button: Button
@onready var tabs: TabContainer = $Tabs
@onready var skill_summary: Label = $Tabs/Skills/Summary
@onready var transport_info: Label = $Tabs/Transport/Info

func button(parent: Node, action: Callable) -> Button:
	var control := Button.new()
	control.focus_mode = Control.FOCUS_NONE
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func _ready() -> void:
	for kind in WORKSHOP.PRICES:
		var parent: Node = $Tabs/Build/Choices/Storage if kind in WORKSHOP.STORAGE else $Tabs/Build/Choices/Stations
		station_buttons[kind] = button(parent, func(): station_requested.emit(kind))
	mobile_bin_button = button($Tabs/Build/Choices/Storage, func(): mobile_bin_requested.emit())
	for branch in ["Craft", "Trade"]:
		var path := VBoxContainer.new()
		path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$Tabs/Skills/Branches.add_child(path)
		var heading := Label.new()
		heading.text = branch + " · each rank costs 1 skill point"
		path.add_child(heading)
		for key in PROGRESSION.SKILLS:
			var definition: Dictionary = PROGRESSION.SKILLS[key]
			if definition.branch != branch: continue
			skill_buttons[key] = button(path, func(): skill_requested.emit(key))
			var detail := Label.new()
			detail.text = definition.effect.replace("anvil, grinder and forge", "metalwork")
			detail.add_theme_font_size_override("font_size", 12)
			path.add_child(detail)
	for level in range(1, 4):
		transport_buttons[level] = button($Tabs/Transport, func(): transport_requested.emit("lift", level))
	for kind in ["rail", "cart"]:
		transport_buttons[kind] = button($Tabs/Transport, func(): transport_requested.emit(kind, 0))

func refresh_progression(local: int, progression: RefCounted) -> void:
	var text := "Level 1 · EXP 0 / 10 · 0 skill points"
	if progression.dwarfs.has(local):
		var dwarf: Dictionary = progression.dwarfs[local]
		text = "Level %s · EXP %s / %s · %s skill points" % [dwarf.level, dwarf.exp, progression.required(dwarf.level), dwarf.points]
	skill_summary.text = text
	for key in skill_buttons:
		var definition: Dictionary = PROGRESSION.SKILLS[key]
		var prerequisite: String = "" if definition.parent == "" else "← " + PROGRESSION.SKILLS[definition.parent].title + " · "
		skill_buttons[key].text = "%s%s [%s/%s] +" % [prerequisite, definition.title, progression.rank(local, key), definition.max]
		skill_buttons[key].disabled = not progression.can_buy(local, key)
	mobile_bin_button.text = "Movable parts bin (10) · %s coins" % progression.purchase_price(local, ITEMS.BIN_PRICE)
	for kind in station_buttons:
		station_buttons[kind].text = "%s · %s coins" % [WORKSHOP.display_name(kind), progression.purchase_price(local, WORKSHOP.PRICES[kind])]

func refresh_transport(local: int, progression: RefCounted, transport: RefCounted, depth: int) -> void:
	transport_info.text = "Elevator: %s/3 segments · Rails: %s · Carts: %s" % [transport.upgrades, transport.tracks.size(), transport.carts.size()]
	for level in range(1, 4):
		transport_buttons[level].text = "Upgrade elevator to mine level %s · %s coins" % [level, progression.purchase_price(local, TRANSPORT.UPGRADE_PRICE)]
		transport_buttons[level].disabled = level != transport.upgrades + 1 or level > depth
	transport_buttons.rail.text = "Buy rail section · %s coins" % progression.purchase_price(local, TRANSPORT.RAIL_PRICE)
	transport_buttons.cart.text = "Buy mine cart · %s coins (stand beside rails)" % progression.purchase_price(local, TRANSPORT.CART_PRICE)

func toggle() -> void:
	visible = not visible
