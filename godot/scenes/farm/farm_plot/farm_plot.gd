extends Node2D

## FarmPlot - represents one of the 6 farm plots.
## Visual state is updated by FarmScene via refresh().
## User interactions are routed back to FarmScene via action_requested signal.

signal action_requested(plot_index: int, action: String)

var plot_index: int = 0

## Typed setter so the displayed label stays in sync with the
## authoritative plot_index assigned by FarmScene.
func set_plot_index(value: int) -> void:
	plot_index = value
	if index_label != null:
		index_label.text = "Plot %d" % plot_index

@onready var crop_visual: Node2D = $CropVisual
@onready var plot_area: Area2D = $PlotArea
@onready var index_label: Label = $CropVisual/IndexLabel
@onready var plot_border: ColorRect = $PlotBorder


func _ready() -> void:
	plot_area.input_event.connect(_on_area_input_event)
	plot_area.mouse_entered.connect(_on_plot_mouse_entered)
	plot_area.mouse_exited.connect(_on_plot_mouse_exited)


func _on_plot_mouse_entered() -> void:
	plot_border.visible = true


func _on_plot_mouse_exited() -> void:
	plot_border.visible = false


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
		# Always request plant; FarmScene validates seed selection and
		# shows guidance when nothing is selected, so the click is never silent.
		emit_signal("action_requested", plot_index, "plant")
	else:
		# Plot has a crop - attempt harvest (GameState validates maturity).
		emit_signal("action_requested", plot_index, "harvest")


func _handle_right_click() -> void:
	var state: FarmPlotState = GameState.farm_plots[plot_index]
	if not state.is_empty():
		emit_signal("action_requested", plot_index, "uproot")
