extends Control

## Inventory panel — shows seeds in the player's package.
## Clicking a seed row selects it for planting.

@onready var item_list: VBoxContainer = %ItemList
@onready var selected_label: Label = %SelectedLabel


func _ready() -> void:
	GameState.inventory_changed.connect(_refresh)
	GameState.selected_seed_changed.connect(_on_selected_seed_changed)
	selected_label.text = "No seed selected."
	_refresh()


func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	for entry in GameState.inventory:
		var crop_id: int = entry["crop_id"]
		var count: int = entry["count"]
		var def := GameState.get_crop_def(crop_id)
		var display_name := def.display_name if def else "Crop %d" % crop_id

		var row := HBoxContainer.new()
		var name_label := Label.new()
		var count_label := Label.new()
		var select_btn := Button.new()

		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_label.text = "×%d" % count
		select_btn.text = "Use"
		select_btn.pressed.connect(_on_seed_selected.bind(crop_id))

		row.add_child(name_label)
		row.add_child(count_label)
		row.add_child(select_btn)
		item_list.add_child(row)


func _on_seed_selected(crop_id: int) -> void:
	if GameState.selected_seed_id == crop_id:
		GameState.deselect_seed()
	else:
		GameState.select_seed(crop_id)


func _on_selected_seed_changed(crop_id: int) -> void:
	if crop_id == -1:
		selected_label.text = "No seed selected."
	else:
		var def := GameState.get_crop_def(crop_id)
		var name := def.display_name if def else "Crop %d" % crop_id
		selected_label.text = "Selected: %s (click a plot to plant)" % name
