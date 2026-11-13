extends PanelContainer
## Screen-space card tethered above a visitor; never scales with camera zoom.
var product: TextureRect
var count: Label
var timer: Label
var price: Label
var price_icon: TextureRect
var progress: ProgressBar
var frame: StyleBoxFlat

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
