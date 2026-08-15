extends Control

## Warehouse panel - shows harvested crops and lets the player sell them.

@onready var item_list: VBoxContainer = %ItemList
@onready var status_label: Label = %StatusLabel

var _selected_crop_id: int = -1

const STATUS_SUCCESS: int = 0
const STATUS_ERROR: int = 1
const STATUS_INFO: int = 2


func _ready() -> void:
	GameState.warehouse_changed.connect(_refresh)
	status_label.text = ''
	_refresh()


func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	if GameState.warehouse.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Warehouse is empty.\nHarvest crops to store them here."
		empty_label.modulate = Color(0.75, 0.75, 0.75)
		item_list.add_child(empty_label)
		return

	for entry in GameState.warehouse:
		var crop_id: int = entry['crop_id']
		var count: int = entry['count']
		var def: CropDefinition = GameState.get_crop_def(crop_id)
		var display_name: String = def.display_name if def else 'Crop %d' % crop_id
		var sell_price: int = def.sell_price if def else 0

		var row := HBoxContainer.new()
		var name_label := Label.new()
		var count_label := Label.new()
		var price_label := Label.new()
		var qty_spin := SpinBox.new()
		var sell_btn := Button.new()

		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_label.text = 'Stock: %d' % count
		price_label.text = '%d ea' % sell_price
		qty_spin.min_value = 1
		qty_spin.max_value = count
		qty_spin.value = 1
		qty_spin.allow_greater = true
		qty_spin.allow_lesser = true
		sell_btn.text = 'Sell'
		sell_btn.pressed.connect(func(): _sell(crop_id, int(qty_spin.value), display_name, sell_price))

		row.add_child(name_label)
		row.add_child(count_label)
		row.add_child(price_label)
		row.add_child(qty_spin)
		row.add_child(sell_btn)
		item_list.add_child(row)


func _sell(crop_id: int, count: int, display_name: String, sell_price: int) -> void:
	var def: CropDefinition = GameState.get_crop_def(crop_id)
	if def == null:
		_show_status('Invalid crop.', STATUS_ERROR)
		return
	if count <= 0:
		_show_status('Invalid quantity. Enter 1 or more.', STATUS_ERROR)
		return
	var available: int = GameState.get_warehouse_count(crop_id)
	if available < count:
		_show_status('Not enough in warehouse. %s has %d, you requested %d.' % [display_name, available, count], STATUS_ERROR)
		return
	var earnings: int = def.sell_price * count
	var ok := GameState.sell_crop(crop_id, count)
	if ok:
		_show_status('Sold %d x %s for %d coins.' % [count, display_name, earnings], STATUS_SUCCESS)
	else:
		_show_status('Sale failed.', STATUS_ERROR)


## Writes a status message and colours it by kind so success and failure differ.
func _show_status(message: String, kind: int) -> void:
	status_label.text = message
	match kind:
		STATUS_SUCCESS:
			status_label.modulate = Color(0.2, 0.9, 0.3)
		STATUS_ERROR:
			status_label.modulate = Color(1.0, 0.45, 0.35)
		_:
			status_label.modulate = Color(0.85, 0.9, 1.0)
