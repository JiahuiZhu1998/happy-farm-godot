extends Control

## Shop panel - lists all available CropDefinitions and lets the player buy seeds.

@onready var item_list: VBoxContainer = %ItemList
@onready var buy_count_spin: SpinBox = %BuyCountSpin
@onready var buy_button: Button = %BuyButton
@onready var status_label: Label = %StatusLabel

var _selected_crop_id: int = -1

const STATUS_SUCCESS: int = 0
const STATUS_ERROR: int = 1
const STATUS_INFO: int = 2


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	status_label.text = ''
	_populate()


func _populate() -> void:
	for child in item_list.get_children():
		child.queue_free()
	var sorted_defs: Array = GameState.crop_definitions.values()
	sorted_defs.sort_custom(func(a, b): return a.crop_id < b.crop_id)


	for def in sorted_defs:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		var price_label := Label.new()
		var level_label := Label.new()
		var select_btn := Button.new()

		name_label.text = def.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_label.text = '%d coins' % def.seed_price
		level_label.text = 'Lv.%d+' % def.required_level
		select_btn.text = 'Select'
		select_btn.pressed.connect(_on_crop_selected.bind(def.crop_id))

		row.add_child(name_label)
		row.add_child(price_label)
		row.add_child(level_label)
		row.add_child(select_btn)
		item_list.add_child(row)


func _on_crop_selected(crop_id: int) -> void:
	_selected_crop_id = crop_id
	var def := GameState.get_crop_def(crop_id)
	if def:
		var note := 'Selected: %s (%d coins each)' % [def.display_name, def.seed_price]
		if GameState.get_level() < def.required_level:
			note += ' | Lv.%d required' % def.required_level
		elif GameState.player_stats.get('money', 0) < def.seed_price:
			note += ' | Not enough coins'
		_show_status(note, STATUS_INFO)


func _on_buy_pressed() -> void:
	if _selected_crop_id == -1:
		_show_status('Select a crop first.', STATUS_ERROR)
		return
	var def := GameState.get_crop_def(_selected_crop_id)
	if def == null:
		_show_status('Invalid crop.', STATUS_ERROR)
		return
	var count := int(buy_count_spin.value)
	if count <= 0:
		_show_status('Invalid quantity. Enter 1 or more.', STATUS_ERROR)
		return
	if GameState.get_level() < def.required_level:
		_show_status('Level %d required to buy %s.' % [def.required_level, def.display_name], STATUS_ERROR)
		return
	var total_cost: int = def.seed_price * count
	var money: int = int(GameState.player_stats.get('money', 0))
	if money < total_cost:
		_show_status('Not enough coins. %d x %s costs %d, you have %d.' % [count, def.display_name, total_cost, money], STATUS_ERROR)
		return
	var ok := GameState.buy_seed(_selected_crop_id, count)
	if ok:
		_show_status('Bought %d x %s for %d coins.' % [count, def.display_name, total_cost], STATUS_SUCCESS)
	else:
		_show_status('Purchase failed.', STATUS_ERROR)


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
