extends Node2D

## FarmPlot — represents one of the 6 farm plots.
## Visual state is updated by FarmScene via refresh().
## User interactions are routed back to FarmScene via action_requested signal.

signal action_requested(plot_index: int, action: String)

var plot_index: int = 0

@onready var crop_visual = $CropVisual
@onready var plot_area: Area2D = $PlotArea


func _ready() -> void:
	plot_area.input_event.connect(_on_area_input_event)


## Called by FarmScene every second and when state changes.
## def may be null if the plot is empty.
func refresh(state: FarmPlotState, def: CropDefinition) -> void:
	crop_visual.update_visual(state, def)


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	if mb.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click()


func _handle_left_click() -> void:
	var state: FarmPlotState = GameState.farm_plots[plot_index]
	if state.is_empty():
		# If a seed is selected, plant it
		if GameState.selected_seed_id != -1:
			emit_signal("action_requested", plot_index, "plant")
		# If nothing selected, ignore (UI can show a tooltip)
	else:
		# Plot has a crop — attempt harvest
		emit_signal("action_requested", plot_index, "harvest")


func _handle_right_click() -> void:
	var state: FarmPlotState = GameState.farm_plots[plot_index]
	if not state.is_empty():
		emit_signal("action_requested", plot_index, "uproot")
