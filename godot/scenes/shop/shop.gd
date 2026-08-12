extends Control

## Shop panel — lists all available CropDefinitions and lets the player buy seeds.

@onready var item_list: VBoxContainer = %ItemList
@onready var buy_count_spin: SpinBox = %BuyCountSpin
@onready var buy_button: Button = %BuyButton
@onready var status_label: Label = %StatusLabel

var _selected_crop_id: int = -1


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	status_label.text = ""
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
		price_label.text = "%d coins" % def.seed_price
		level_label.text = "Lv.%d+" % def.required_level
		select_btn.text = "Select"
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
		status_label.text = "Selected: %s (%d coins each)" % [def.display_name, def.seed_price]


func _on_buy_pressed() -> void:
	if _selected_crop_id == -1:
		status_label.text = "Select a crop first."
		return
	var count := int(buy_count_spin.value)
	var ok := GameState.buy_seed(_selected_crop_id, count)
	if ok:
		status_label.text = "Purchased %d seeds!" % count
	else:
		var def := GameState.get_crop_def(_selected_crop_id)
		if def and GameState.get_level() < def.required_level:
			status_label.text = "Level %d required." % def.required_level
		else:
			status_label.text = "Not enough coins."
