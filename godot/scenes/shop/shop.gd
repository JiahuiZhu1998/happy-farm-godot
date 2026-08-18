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
		var card := _build_crop_card(def)
		item_list.add_child(card)


## Builds a rounded card row with a crop icon, name, price, level and a Select button.
## Locked crops (current level too low) are visually muted and their button disabled.
func _build_crop_card(def: CropDefinition) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(false))
	card.custom_minimum_size = Vector2(340, 64)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 56)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(56, 56)
	var icon := _make_crop_icon(def)
	icon_holder.add_child(icon)
	row.add_child(icon_holder)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.28, 0.2, 0.14, 1))
	info.add_child(name_label)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 12)
	var price_label := Label.new()
	price_label.text = "%d coins" % def.seed_price
	price_label.add_theme_color_override("font_color", Color(0.5, 0.36, 0.1, 1))
	meta.add_child(price_label)
	var level_label := Label.new()
	level_label.text = "Lv.%d+" % def.required_level
	level_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5, 1))
	meta.add_child(level_label)
	info.add_child(meta)
	row.add_child(info)

	var select_btn := Button.new()
	select_btn.custom_minimum_size = Vector2(92, 0)
	select_btn.pressed.connect(_on_crop_selected.bind(def.crop_id))

	var locked := GameState.get_level() < def.required_level
	if locked:
		select_btn.text = "Locked"
		select_btn.disabled = true
		select_btn.tooltip_text = "Requires Level %d" % def.required_level
		name_label.modulate = Color(0.6, 0.6, 0.6, 1)
		price_label.modulate = Color(0.6, 0.6, 0.6, 1)
		level_label.modulate = Color(0.85, 0.3, 0.3, 1)
		icon.modulate = Color(0.55, 0.55, 0.55, 0.6)
	else:
		select_btn.text = "Select"
		select_btn.tooltip_text = "Select %s seeds to buy" % def.display_name

	row.add_child(select_btn)
	card.add_child(row)
	return card


## Returns a small circular icon showing the crop's first growth stage texture,
## or a tinted panel placeholder when no texture is available.
func _make_crop_icon(def: CropDefinition) -> Control:
	var tex: Texture2D = null
	if def.stage_textures.size() > 0:
		tex = def.stage_textures[0]
	if tex != null:
		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(48, 48)
		holder.add_theme_stylebox_override("panel", _card_style(true))
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
	sb.bg_color = Color(0.55, 0.78, 0.45, 1)
	sb.corner_radius_top_left = 23
	sb.corner_radius_top_right = 23
	sb.corner_radius_bottom_right = 23
	sb.corner_radius_bottom_left = 23
	placeholder.add_theme_stylebox_override("panel", sb)
	return placeholder


## Builds a reusable card stylebox. Set bordered=true for the inner icon frame.
func _card_style(bordered: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.99, 0.92, 1) if not bordered else Color(0.95, 0.93, 0.82, 1)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	if bordered:
		sb.border_color = Color(0.7, 0.6, 0.4, 1)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	else:
		sb.border_color = Color(0.55, 0.7, 0.4, 1)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	return sb


func _on_crop_selected(crop_id: int) -> void:
	_selected_crop_id = crop_id
	var def := GameState.get_crop_def(crop_id)
	if def:
		var note := 'Selected: %s (%d coins each)' % [def.display_name, def.seed_price]
		if GameState.get_level() < def.required_level:
			note += ' - Lv.%d required to buy' % def.required_level
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