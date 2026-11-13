extends PanelContainer
## Screen-space card tethered above a visitor; never scales with camera zoom.
var product: TextureRect
var count: Label
var timer: Label
var price: Label
var price_icon: TextureRect
var progress: ProgressBar
var frame: StyleBoxFlat
var accept_button: Button
var reject_button: Button
var buy_button: Button
var actions: HBoxContainer

func icon(texture: Texture2D, side: int) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.custom_minimum_size = Vector2(side, side)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(88, 62)
	frame = StyleBoxFlat.new()
	frame.bg_color = Color(0.06, 0.075, 0.1, 0.97)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(4)
	frame.content_margin_left = 7
	frame.content_margin_right = 7
	frame.content_margin_top = 5
	frame.content_margin_bottom = 5
	add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	product = icon(null, 22)
	row.add_child(product)
	count = Label.new()
	count.add_theme_font_size_override("font_size", 15)
	row.add_child(count)
	var timing := HBoxContainer.new()
	timing.alignment = BoxContainer.ALIGNMENT_CENTER
	timing.add_theme_constant_override("separation", 3)
	column.add_child(timing)
	timing.add_child(icon(preload("res://assets/textures/clock_icon.svg"), 9))
	timer = Label.new()
	timer.add_theme_font_size_override("font_size", 12)
	timing.add_child(timer)
	price_icon = icon(preload("res://assets/textures/coin_icon.svg"), 9)
	timing.add_child(price_icon)
	price = Label.new()
	price.add_theme_font_size_override("font_size", 12)
	timing.add_child(price)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 3
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("303745")
	progress.add_theme_stylebox_override("background", bg)
	column.add_child(progress)
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 5)
	column.add_child(actions)
	accept_button = action_button(preload("res://assets/textures/accept_icon.svg"), "Accept order")
	reject_button = action_button(preload("res://assets/textures/reject_icon.svg"), "Reject order")
	buy_button = action_button(preload("res://assets/textures/buy_icon.svg"), "Buy wood")

func action_button(texture: Texture2D, description: String) -> Button:
	var button := Button.new()
	button.icon = texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 18)
	button.custom_minimum_size = Vector2(27, 25)
	button.tooltip_text = description
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	actions.add_child(button)
	return button

func set_customer(accepted: bool) -> void:
	accept_button.visible = not accepted
	reject_button.visible = true
	reject_button.tooltip_text = "Fail accepted order (−6 reputation)" if accepted else "Reject order"
	buy_button.hide()

func set_merchant(can_buy: bool) -> void:
	accept_button.hide()
	reject_button.hide()
	buy_button.show()
	buy_button.disabled = not can_buy


func update_card(texture: Texture2D, quantity: int, remaining: float, duration: float, color: Color, cost: int = -1) -> void:
	product.texture = texture
	count.text = "×%s" % quantity
	timer.text = "%ss" % maxi(0, ceili(remaining))
	timer.modulate = Color("ee9885") if remaining < 5 else Color.WHITE
	price.visible = cost >= 0
	price_icon.visible = cost >= 0
	price.text = str(cost)
	frame.border_color = color
	progress.max_value = duration
	progress.value = remaining
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	progress.add_theme_stylebox_override("fill", fill)
