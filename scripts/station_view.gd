extends Node2D
const PRODUCT_ICONS := {
	"horseshoe": preload("res://assets/textures/horseshoe.svg"), "dull_sword": preload("res://assets/textures/dull_sword.svg"), "axe_head": preload("res://assets/textures/axe_head.svg"), "axe": preload("res://assets/textures/axe.svg"), "sword": preload("res://assets/textures/sword.svg"), "shaft": preload("res://assets/textures/shaft.svg"), "ingot": preload("res://assets/textures/ingot.svg")
}
const TEXTURES = {"anvil": preload("res://assets/textures/station_anvil.svg"), "grinder": preload("res://assets/textures/station_grinder.svg"), "woodbench": preload("res://assets/textures/station_woodbench.svg"), "forge": preload("res://assets/textures/station_forge.svg"), "intermediate_small": preload("res://assets/textures/storage_intermediate_small.svg"), "intermediate_medium": preload("res://assets/textures/storage_intermediate_medium.svg"), "intermediate_large": preload("res://assets/textures/storage_intermediate_large.svg"), "finished_small": preload("res://assets/textures/storage_finished_small.svg"), "finished_medium": preload("res://assets/textures/storage_finished_medium.svg"), "finished_large": preload("res://assets/textures/storage_finished_large.svg")}
func update_view(entry: Dictionary, materials: RefCounted) -> void:
	position = entry.at
	$Sprite.texture = TEXTURES[entry.kind]
	var storage: bool = entry.kind in preload("res://scripts/workshop_state.gd").STORAGE
	$Sprite.position = Vector2(8, -$Sprite.texture.get_height() / 2.0) if storage else Vector2(8, -16)
	$Progress.visible = not storage and entry.job.progress > 0
	$TrayBody.collision_layer = 0 if storage else 8
	$Progress.value = entry.job.progress
	var forge: bool = entry.kind == "forge"
	$BinWalls.collision_layer = 8 if forge else 0
	$BinWalls.collision_mask = 4 if forge else 0
	$BinCatch.monitoring = forge
	var intermediate: bool = storage and preload("res://scripts/workshop_state.gd").STORAGE[entry.kind].group == "intermediate"
	$PartsWalls.collision_layer = 8 if intermediate else 0
	$PartsWalls.collision_mask = 4 if intermediate else 0
	$PartsCatch.monitoring = intermediate
	if intermediate:
		var width: float = $Sprite.texture.get_width()
		var height: float = $Sprite.texture.get_height()
		$PartsWalls/Left.position = Vector2(8 - width / 2 + 1, -height / 2)
		$PartsWalls/Right.position = Vector2(8 + width / 2 - 1, -height / 2)
		$PartsWalls/Left.scale = Vector2(1, height / 14)
		$PartsWalls/Right.scale = Vector2(1, height / 14)
		$PartsWalls/Bottom.position = Vector2(8, -1.5)
		$PartsWalls/Bottom.scale = Vector2(width / 20, 1)
		$PartsCatch.position = Vector2(8, -height / 2)
		$PartsCatch/Shape.scale = Vector2((width - 6) / 10, (height - 4) / 8)
	if not has_node("ProductIcon"):
		var icon := Sprite2D.new()
		icon.name = "ProductIcon"
		icon.position = Vector2(8, -43)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(icon)
	if storage:
		var definition: Dictionary = preload("res://scripts/workshop_state.gd").STORAGE[entry.kind]
		$ProductIcon.texture = PRODUCT_ICONS.get(entry.selected)
		$Label.text = "%s/%s" % [entry.items.size(), definition.capacity]
	else:
		$ProductIcon.texture = PRODUCT_ICONS.get(entry.job.OUTPUTS[entry.job.recipe])
		$Label.text = ""
