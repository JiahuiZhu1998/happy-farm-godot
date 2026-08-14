extends Node2D

## FarmScene - main game scene.
## Owns 6 FarmPlot child nodes and wires them to GameState.
## Also hosts the Shop / Inventory / Warehouse overlay panels.

@onready var growth_timer: Timer = $GrowthTimer
@onready var dialog: AcceptDialog = $DialogLayer/Dialog
@onready var shop_button: Button = %ShopButton
@onready var inventory_button: Button = %InventoryButton
@onready var warehouse_button: Button = %WarehouseButton
@onready var selected_label: Label = %SelectedLabel
@onready var shop_panel: Control = $PanelLayer/ShopPanel
@onready var inventory_panel: Control = $PanelLayer/InventoryPanel
@onready var warehouse_panel: Control = $PanelLayer/WarehousePanel

# FarmPlot node references (populated in _ready)
var _plots: Array = []
# Which panel is currently open (null = none displayed)
var _active_panel: Control = null


func _ready() -> void:
	# Gather the 6 FarmPlot child nodes from FarmGrid
	var farm_grid: Node2D = $FarmGrid
	for i in 6:
		var plot: Node = farm_grid.get_node("FarmPlot%d" % i)
		if plot == null:
			push_error("FarmScene: missing FarmPlot%d under FarmGrid" % i)
			continue
		plot.set_plot_index(i)
		plot.action_requested.connect(_on_plot_action_requested)
		_plots.append(plot)

	# Connect GameState signals
	GameState.plot_changed.connect(_on_plot_changed)
	GameState.inventory_changed.connect(_refresh_all_plots)

	# Connect growth timer
	growth_timer.timeout.connect(_refresh_all_plots)
	growth_timer.start()

	# Panel toggle buttons
	shop_button.pressed.connect(_toggle_panel.bind(shop_panel))
	inventory_button.pressed.connect(_toggle_panel.bind(inventory_panel))
	warehouse_button.pressed.connect(_toggle_panel.bind(warehouse_panel))

	# Selected-seed HUD indicator
	GameState.selected_seed_changed.connect(_on_selected_seed_changed)
	_update_selected_seed_label(GameState.selected_seed_id)

	# Initial visual refresh
	_refresh_all_plots()


## Toggle a single overlay panel; close any other open panel.
func _toggle_panel(panel: Control) -> void:
	if _active_panel == panel:
		panel.visible = false
		_active_panel = null
		return
	if _active_panel != null:
		_active_panel.visible = false
	panel.visible = true
	_active_panel = panel


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
				_show_dialog("Cannot plant here. Check that you have seeds, the level, and an empty plot.")
		"harvest":
			var state: FarmPlotState = GameState.farm_plots[plot_index]
			if state.is_empty():
				return
			var def := GameState.get_crop_def(state.crop_id)
			if def != null and not CropGrowthSystem.is_mature(state, def):
				_show_dialog("This crop is not ready to harvest yet.")
				return
			var yield_gained := GameState.harvest_plot(plot_index)
			if yield_gained > 0:
				_show_dialog("Harvested %d crops!" % yield_gained)
			else:
				_show_dialog("Nothing to harvest here.")
		"uproot":
			var ok := GameState.uproot_plot(plot_index)
			if ok:
				_show_dialog("Crop removed.")
			else:
				_show_dialog("Nothing to uproot here.")
		_:
			push_warning("FarmScene: unknown action '%s'" % action)



# ---------------------------------------------------------------------------
# Selected-seed HUD + ESC handling
# ---------------------------------------------------------------------------

## Update the HUD label that shows the currently selected seed.
func _update_selected_seed_label(crop_id: int) -> void:
	if crop_id == -1:
		selected_label.text = "Selected: None"
		return
	var def := GameState.get_crop_def(crop_id)
	var crop_name := "Crop %d" % crop_id
	if def != null and def.display_name != "":
		crop_name = def.display_name
	selected_label.text = "Selected: %s" % crop_name

## React to selected-seed changes from GameState.
func _on_selected_seed_changed(crop_id: int) -> void:
	_update_selected_seed_label(crop_id)

## ESC behavior: close an open panel, else deselect the current seed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _active_panel != null:
			_toggle_panel(_active_panel)
			get_viewport().set_input_as_handled()
		elif GameState.selected_seed_id != -1:
			GameState.deselect_seed()
			get_viewport().set_input_as_handled()

func _show_dialog(msg: String) -> void:
	dialog.dialog_text = msg
	dialog.popup_centered()
