extends Node2D

## FarmScene — main game scene.
## Owns 6 FarmPlot child nodes and wires them to GameState.

@onready var growth_timer: Timer = $GrowthTimer
@onready var dialog: AcceptDialog = $DialogLayer/Dialog

# FarmPlot node references (populated in _ready)
var _plots: Array = []


func _ready() -> void:
	# Gather the 6 FarmPlot child nodes from FarmGrid
	var farm_grid: Node2D = $FarmGrid
	for i in 6:
		var plot: Node = farm_grid.get_node("FarmPlot%d" % i)
		if plot == null:
			push_error("FarmScene: missing FarmPlot%d under FarmGrid" % i)
			continue
		plot.plot_index = i
		plot.action_requested.connect(_on_plot_action_requested)
		_plots.append(plot)

	# Connect GameState signals
	GameState.plot_changed.connect(_on_plot_changed)
	GameState.inventory_changed.connect(_refresh_all_plots)

	# Connect growth timer
	growth_timer.timeout.connect(_refresh_all_plots)
	growth_timer.start()

	# Initial visual refresh
	_refresh_all_plots()


## Called every second by GrowthTimer to update crop visuals.
func _refresh_all_plots() -> void:
	for i in GameState.farm_plots.size():
		_refresh_plot(i)


## Called by GameState.plot_changed signal.
func _on_plot_changed(plot_index: int) -> void:
	_refresh_plot(plot_index)


func _refresh_plot(plot_index: int) -> void:
	if plot_index < 0 or plot_index >= _plots.size():
		return
	var state: FarmPlotState = GameState.farm_plots[plot_index]
	var def: CropDefinition = null
	if not state.is_empty():
		def = GameState.get_crop_def(state.crop_id)
	_plots[plot_index].refresh(state, def)


## Receives action requests from FarmPlot nodes.
func _on_plot_action_requested(plot_index: int, action: String) -> void:
	match action:
		"plant":
			if GameState.selected_seed_id == -1:
				_show_dialog("Select a seed from your inventory first.")
				return
			var ok := GameState.plant_crop(plot_index, GameState.selected_seed_id)
			if not ok:
				_show_dialog("Cannot plant here. Check that you have seeds and the plot is empty.")
		"harvest":
			var state: FarmPlotState = GameState.farm_plots[plot_index]
			var def := GameState.get_crop_def(state.crop_id)
			if def != null and not CropGrowthSystem.is_mature(state, def):
				_show_dialog("This crop is not ready to harvest yet.")
				return
			var yield_gained := GameState.harvest_plot(plot_index)
			if yield_gained > 0:
				_show_dialog("Harvested %d crops!" % yield_gained)
		"uproot":
			GameState.uproot_plot(plot_index)
			_show_dialog("Crop removed.")
		_:
			push_warning("FarmScene: unknown action '%s'" % action)


func _show_dialog(msg: String) -> void:
	dialog.dialog_text = msg
	dialog.popup_centered()
