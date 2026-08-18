extends Control

## Warehouse panel - shows harvested crops and lets the player sell them.

@onready var item_list: VBoxContainer = %ItemList
@onready var status_label: Label = %StatusLabel

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
		item_list.add_child(_empty_state())
		return

	for entry in GameState.warehouse:
		var crop_id: int = entry['crop_id']
		var count: int = entry['count']
		var def: CropDefinition = GameState.get_crop_def(crop_id)
		var display_name: String = def.display_name if def else 'Crop %d' % crop_id
		var sell_price: int = def.sell_price if def else 0
		item_list.add_child(_build_crop_card(def, display_name, count, crop_id, sell_price))


## Empty-state placeholder card.
func _empty_state() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var label := Label.new()
	label.text = "Warehouse is empty.\nHarvest crops to store them here."
	label.horizontal_alignment = 1
	label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.5, 1))
	card.add_child(label)
	return card


## Builds a harvested-crop card with icon, stock, price and a Sell button.
func _build_crop_card(def: CropDefinition, display_name: String, count: int, crop_id: int, sell_price: int) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.custom_minimum_size = Vector2(340, 64)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 56)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(56, 56)
	icon_holder.add_child(_make_crop_icon(def))
	row.add_child(icon_holder)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 12)
	var stock_label := Label.new()
	stock_label.text = "Stock: %d" % count
	stock_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.2, 1))
	meta.add_child(stock_label)
	var price_label := Label.new()
	price_label.text = "%d ea" % sell_price
	price_label.add_theme_color_override("font_color", Color(0.5, 0.36, 0.1, 1))
	meta.add_child(price_label)
	info.add_child(meta)
	row.add_child(info)

	var qty_spin := SpinBox.new()
	qty_spin.min_value = 1
	qty_spin.max_value = count
	qty_spin.value = 1
	qty_spin.allow_greater = true
	qty_spin.allow_lesser = true
	qty_spin.custom_minimum_size = Vector2(80, 0)
	row.add_child(qty_spin)

	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(82, 0)
	sell_btn.pressed.connect(func(): _sell(crop_id, int(qty_spin.value), display_name, sell_price))
	row.add_child(sell_btn)

	card.add_child(row)
	return card


## Returns a small circular icon using the crop\'s last (mature) stage texture, or a placeholder.
func _make_crop_icon(def: CropDefinition) -> Control:
	var tex: Texture2D = null
	if def != null and def.stage_textures.size() > 0:
		tex = def.stage_textures[def.stage_textures.size() - 1]
	if tex != null:
		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(48, 48)
		holder.add_theme_stylebox_override("panel", _icon_bg())
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(40, 40)
		holder.add_child(tex_rect)
		return holder
	var placeholder := Panel.new()
	placeholder.custom_minimum_size = Vector2(46, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.7, 0.55, 0.35, 1)
	sb.corner_radius_top_left = 23
	sb.corner_radius_top_right = 23
	sb.corner_radius_bottom_right = 23
	sb.corner_radius_bottom_left = 23
	placeholder.add_theme_stylebox_override("panel", sb)
	return placeholder


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


func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.99, 0.92, 1)
	sb.border_color = Color(0.55, 0.7, 0.4, 1)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	return sb


func _icon_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.93, 0.82, 1)
	sb.border_color = Color(0.7, 0.6, 0.4, 1)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	return sb