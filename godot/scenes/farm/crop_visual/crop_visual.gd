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
@onready var ready_border: ColorRect = $ReadyBorder

# Color per growth stage so visual stage changes are observable without art.
const _STAGE_COLORS: Array[Color] = [
	Color(0.35, 0.75, 0.35, 1),  # sprout   (green)
	Color(0.9, 0.85, 0.25, 1),   # growing  (yellow-green)
	Color(0.95, 0.55, 0.15, 1),  # budding  (orange)
	Color(0.85, 0.2, 0.2, 1),    # mature   (red)
]
const _EMPTY_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const _READY_BORDER_COLOR: Color = Color(1.0, 0.95, 0.2, 1)

var _ready_frame: Panel = _create_ready_frame()

func _create_ready_frame() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.offset_left = -56.0
	panel.offset_top = -56.0
	panel.offset_right = 56.0
	panel.offset_bottom = 56.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.border_color = _READY_BORDER_COLOR
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.visible = false
	add_child(panel)
	return panel


## Update the visual to match the current plot state.
## state: the FarmPlotState (may be empty)
## def: the CropDefinition (may be null if plot is empty)
func update_visual(state: FarmPlotState, def: CropDefinition) -> void:
	if state == null or state.is_empty() or def == null:
		crop_sprite.texture = null
		crop_sprite.visible = false
		debug_rect.visible = false
		debug_rect.color = _EMPTY_COLOR
		ready_border.visible = false
		_ready_frame.visible = false
		if stage_label:
			stage_label.text = ""
			stage_label.modulate = Color(1, 1, 1, 1)
		return

	crop_sprite.visible = true
	var tex := CropGrowthSystem.get_current_texture(state, def)
	crop_sprite.texture = tex

	var stage := CropGrowthSystem.compute_stage(state, def)
	var mature := CropGrowthSystem.is_mature(state, def)

	# Debug placeholder: a single native rect whose size and color both
	# advance with the growth stage so stages are easy to tell apart.
	if tex == null:
		var ratio := float(stage + 1) / float(def.stage_count)
		var half: float = lerp(12.0, 48.0, ratio)
		debug_rect.offset_left = -half
		debug_rect.offset_top = -half
		debug_rect.offset_right = half
		debug_rect.offset_bottom = half
		debug_rect.color = _STAGE_COLORS[clampi(stage, 0, _STAGE_COLORS.size() - 1)]
		debug_rect.visible = true
	else:
		debug_rect.visible = false

	# Obvious READY indication: a bright ring plus a clear label.
	ready_border.visible = false
	_ready_frame.visible = mature
	ready_border.color = _READY_BORDER_COLOR

	if stage_label:
		if mature:
			stage_label.text = "READY!"
			stage_label.modulate = Color(1.0, 0.95, 0.2, 1)
		else:
			var secs := CropGrowthSystem.seconds_to_next_stage(state, def)
			stage_label.text = "Stage %d | %ds" % [stage + 1, int(secs)]
			stage_label.modulate = Color(1, 1, 1, 1)
