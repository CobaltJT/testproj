extends Node2D
const TEXTURES = {"anvil": preload("res://assets/textures/station_anvil.svg"), "grinder": preload("res://assets/textures/station_grinder.svg"), "woodbench": preload("res://assets/textures/station_woodbench.svg"), "forge": preload("res://assets/textures/station_forge.svg"), "intermediate_small": preload("res://assets/textures/storage_intermediate_small.svg"), "intermediate_medium": preload("res://assets/textures/storage_intermediate_medium.svg"), "intermediate_large": preload("res://assets/textures/storage_intermediate_large.svg"), "finished_small": preload("res://assets/textures/storage_finished_small.svg"), "finished_medium": preload("res://assets/textures/storage_finished_medium.svg"), "finished_large": preload("res://assets/textures/storage_finished_large.svg")}
func update_view(entry: Dictionary, materials: RefCounted) -> void:
	position = entry.at
	$Sprite.texture = TEXTURES[entry.kind]
	var storage: bool = entry.kind in preload("res://scripts/workshop_state.gd").STORAGE
	$Sprite.position = Vector2(8, -$Sprite.texture.get_height() / 2.0) if storage else Vector2(8, -16)
	$Progress.visible = not storage
	$TrayBody.collision_layer = 0 if storage else 8
	$Progress.value = entry.job.progress
	var forge: bool = entry.kind == "forge"
	$BinWalls.collision_layer = 8 if forge else 0
	$BinWalls.collision_mask = 4 if forge else 0
	$BinCatch.monitoring = forge
	if storage:
		var definition: Dictionary = preload("res://scripts/workshop_state.gd").STORAGE[entry.kind]
		var count := 0
		for piece in entry.items:
			if materials.pieces.has(piece) and materials.pieces[piece].kind == entry.selected: count += 1
		$Label.text = "%s %s/%s\n%s\nE: store/take · T: cycle" % ["PARTS" if definition.group == "intermediate" else "GOODS", entry.items.size(), definition.capacity, "%s x%s" % [entry.selected.replace("_", " ").to_upper(), count] if count else "EMPTY"]
		return
	if forge:
		$Label.text = "FORGE · BIN: %s" % entry.job.ore_queue.size()
		$Label.text += "\nTHROW ORE" if entry.job.slots.is_empty() and entry.job.ore_queue.is_empty() else "\n%s %s%%" % ["SMELTING" if entry.job.worker else "HOLD E", roundi(entry.job.progress / entry.job.DURATION * 100)]
		return
	var needed: Array = []
	for ingredient in entry.job.INPUTS[entry.job.recipe]:
		if not entry.job.slots.has(ingredient):
			needed.append("ore / ingot" if entry.kind == "anvil" and ingredient == "ore" else ingredient.replace("_", " "))
	$Label.text = entry.job.recipe.replace("_", " ").to_upper()
	if not needed.is_empty():
		$Label.text += "\nE: " + ", ".join(needed)
	else:
		$Label.text += "\n%s %s%%" % ["WORK" if entry.job.worker else "PAUSED", roundi(entry.job.progress / entry.job.DURATION * 100)]
