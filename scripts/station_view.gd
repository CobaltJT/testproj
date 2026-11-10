extends Node2D
const TEXTURES = {"anvil": preload("res://assets/textures/station_anvil.svg"), "grinder": preload("res://assets/textures/station_grinder.svg"), "woodbench": preload("res://assets/textures/station_woodbench.svg"), "forge": preload("res://assets/textures/station_forge.svg")}
func update_view(entry: Dictionary) -> void:
	position = entry.at
	$Sprite.texture = TEXTURES[entry.kind]
	$Progress.value = entry.job.progress
	var forge: bool = entry.kind == "forge"
	$BinWalls.collision_layer = 8 if forge else 0
	$BinWalls.collision_mask = 4 if forge else 0
	$BinCatch.monitoring = forge
	if forge:
		$Label.text = "FORGE · BIN: %s" % entry.job.ore_queue.size()
		$Label.text += "\nTHROW ORE" if entry.job.slots.is_empty() and entry.job.ore_queue.is_empty() else "\n%s %.1f/5s" % ["SMELTING" if entry.job.worker else "HOLD E", entry.job.progress]
		return
	var needed: Array = []
	for ingredient in entry.job.INPUTS[entry.job.recipe]:
		if not entry.job.slots.has(ingredient):
			needed.append("ore / ingot" if entry.kind == "anvil" and ingredient == "ore" else ingredient.replace("_", " "))
	$Label.text = entry.job.recipe.replace("_", " ").to_upper()
	if not needed.is_empty():
		$Label.text += "\nE: " + ", ".join(needed)
	else:
		$Label.text += "\n%s %.1f/5s" % ["WORK" if entry.job.worker else "PAUSED", entry.job.progress]
