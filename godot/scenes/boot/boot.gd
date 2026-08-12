extends Node

## Boot scene controller.
## 1. Loads all CropDefinition resources into GameState.
## 2. Attempts to load the save file.
## 3. Routes to Login (no save) or Farm (save exists).

const CROP_COUNT := 16
const CROP_RES_PATH := "res://data/crops/crop_%d.tres"


func _ready() -> void:
	_load_crop_definitions()
	var save_data := SaveManager.load_game()
	if save_data.profile.is_empty():
		# No existing save — go to login/register
		get_tree().change_scene_to_file("res://scenes/login/login.tscn")
	else:
		GameState.apply_save(save_data)
		get_tree().change_scene_to_file("res://scenes/farm/farm.tscn")


func _load_crop_definitions() -> void:
	for i in range(1, CROP_COUNT + 1):
		var path := CROP_RES_PATH % i
		if ResourceLoader.exists(path):
			var def: CropDefinition = load(path)
			if def != null:
				GameState.crop_definitions[def.crop_id] = def
		else:
			push_warning("Boot: missing crop definition at %s" % path)
