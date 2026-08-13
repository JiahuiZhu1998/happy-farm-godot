extends Node2D

## CropVisual — displays the correct crop sprite for the current plot state.
## Updated by FarmPlot.refresh() which is called by FarmScene.
##
## Real crop art is not imported yet. When CropGrowthSystem reports a null
## texture (definitions ship without stage_textures), a Godot-native debug
## placeholder is drawn so the planted crop is still clearly identifiable.

@onready var crop_sprite: Sprite2D = $CropSprite
@onready var stage_label: Label = $StageLabel
@onready var debug_rect: ColorRect = $DebugRect

# Color per growth stage so visual stage changes are observable without art.
const _STAGE_COLORS: Array[Color] = [
	Color(0.35, 0.75, 0.35, 1),  # sprout   (green)
	Color(0.9, 0.85, 0.25, 1),   # growing  (yellow-green)
	Color(0.95, 0.55, 0.15, 1),  # budding  (orange)
	Color(0.85, 0.2, 0.2, 1),    # mature   (red)
]
const _EMPTY_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)


## Update the visual to match the current plot state.
## state: the FarmPlotState (may be empty)
## def: the CropDefinition (may be null if plot is empty)
func update_visual(state: FarmPlotState, def: CropDefinition) -> void:
	if state == null or state.is_empty() or def == null:
		crop_sprite.texture = null
		crop_sprite.visible = false
		debug_rect.visible = false
		debug_rect.color = _EMPTY_COLOR
		if stage_label:
			stage_label.text = ""
		return

	crop_sprite.visible = true
	var tex := CropGrowthSystem.get_current_texture(state, def)
	crop_sprite.texture = tex

	# Debug fallback when the real texture is missing.
	if tex == null:
		var stage := CropGrowthSystem.compute_stage(state, def)
		var mature := CropGrowthSystem.is_mature(state, def)
		var color_idx: int = clampi(stage, 0, _STAGE_COLORS.size() - 1)
		debug_rect.color = _STAGE_COLORS[color_idx]
		debug_rect.visible = true
		if stage_label:
			if mature:
				stage_label.text = "READY!"
			else:
				var secs := CropGrowthSystem.seconds_to_next_stage(state, def)
				stage_label.text = "Stage %d | %ds" % [stage + 1, int(secs)]
	else:
		debug_rect.visible = false
		if stage_label:
			var stage := CropGrowthSystem.compute_stage(state, def)
			var mature := CropGrowthSystem.is_mature(state, def)
			if mature:
				stage_label.text = "READY!"
			else:
				var secs := CropGrowthSystem.seconds_to_next_stage(state, def)
				stage_label.text = "Stage %d | %ds" % [stage + 1, int(secs)]
