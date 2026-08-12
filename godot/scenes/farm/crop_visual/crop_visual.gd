extends Node2D

## CropVisual — displays the correct crop sprite for the current plot state.
## Updated by FarmPlot.refresh() which is called by FarmScene.

@onready var crop_sprite: Sprite2D = $CropSprite
@onready var stage_label: Label = $StageLabel  # optional debug label; hide in production


## Update the visual to match the current plot state.
## state: the FarmPlotState (may be empty)
## def: the CropDefinition (may be null if plot is empty)
func update_visual(state: FarmPlotState, def: CropDefinition) -> void:
	if state == null or state.is_empty() or def == null:
		crop_sprite.texture = null
		crop_sprite.visible = false
		if stage_label:
			stage_label.text = ""
		return

	crop_sprite.visible = true
	var tex := CropGrowthSystem.get_current_texture(state, def)
	crop_sprite.texture = tex

	if stage_label:
		var stage := CropGrowthSystem.compute_stage(state, def)
		var mature := CropGrowthSystem.is_mature(state, def)
		if mature:
			stage_label.text = "READY"
		else:
			var secs := CropGrowthSystem.seconds_to_next_stage(state, def)
			stage_label.text = "Stage %d | %ds" % [stage + 1, int(secs)]
