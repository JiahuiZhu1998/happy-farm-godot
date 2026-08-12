extends Control

## Warehouse panel — shows harvested crops and lets the player sell them.

@onready var item_list: VBoxContainer = %ItemList
@onready var status_label: Label = %StatusLabel

var _selected_crop_id: int = -1


func _ready() -> void:
	GameState.warehouse_changed.connect(_refresh)
	status_label.text = ""
	_refresh()


func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	if GameState.warehouse.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Warehouse is empty."
		item_list.add_child(empty_label)
		return

	for entry in GameState.warehouse:
		var crop_id: int = entry["crop_id"]
		var count: int = entry["count"]
		var def := GameState.get_crop_def(crop_id)
		var display_name := def.display_name if def else "Crop %d" % crop_id
		var sell_price := def.sell_price if def else 0

		var row := HBoxContainer.new()
		var name_label := Label.new()
		var count_label := Label.new()
		var price_label := Label.new()
		var sell_btn := Button.new()

		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_label.text = "×%d" % count
		price_label.text = "%d ea" % sell_price
		sell_btn.text = "Sell All"
		sell_btn.pressed.connect(_on_sell_pressed.bind(crop_id, count))

		row.add_child(name_label)
		row.add_child(count_label)
		row.add_child(price_label)
		row.add_child(sell_btn)
		item_list.add_child(row)


func _on_sell_pressed(crop_id: int, count: int) -> void:
	var def := GameState.get_crop_def(crop_id)
	var earnings := (def.sell_price if def else 0) * count
	var ok := GameState.sell_crop(crop_id, count)
	if ok:
		status_label.text = "Sold %d for %d coins!" % [count, earnings]
	else:
		status_label.text = "Sale failed."
