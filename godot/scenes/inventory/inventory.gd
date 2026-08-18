extends Control

## Inventory panel - shows seeds in the player\'s package.
## Clicking a seed row selects it for planting.
## GameState.selected_seed_id is the only source of truth for selection.

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

	var has_seeds: bool = not GameState.inventory.is_empty()
	if not has_seeds:
		item_list.add_child(_empty_state())
		return

	for entry in GameState.inventory:
		var crop_id: int = entry["crop_id"]
		var count: int = entry["count"]
		var def: CropDefinition = GameState.get_crop_def(crop_id)
		var display_name: String = def.display_name if def else "Crop %d" % crop_id
		var is_selected: bool = GameState.selected_seed_id == crop_id
		item_list.add_child(_build_seed_card(def, display_name, count, crop_id, is_selected))


## Empty-state placeholder card.
func _empty_state() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var label := Label.new()
	label.text = "No seeds in inventory.\nBuy seeds from the Shop."
	label.horizontal_alignment = 1
	label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.5, 1))
	card.add_child(label)
	return card


## Builds a seed card with crop icon, name, quantity and selected highlight.
func _build_seed_card(def: CropDefinition, display_name: String, count: int, crop_id: int, is_selected: bool) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _selected_style() if is_selected else _card_style())
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

	var count_label := Label.new()
	count_label.text = "Seeds: %d" % count
	count_label.add_theme_color_override("font_color", Color(0.5, 0.36, 0.1, 1))
	info.add_child(count_label)
	row.add_child(info)

	var select_btn := Button.new()
	select_btn.custom_minimum_size = Vector2(96, 0)
	if is_selected:
		select_btn.text = "Selected"
		select_btn.disabled = true
	else:
		select_btn.text = "Use"
		select_btn.pressed.connect(_on_seed_selected.bind(crop_id))
	row.add_child(select_btn)

	if is_selected:
		name_label.add_theme_color_override("font_color", Color(0.22, 0.55, 0.2, 1))
		count_label.add_theme_color_override("font_color", Color(0.22, 0.55, 0.2, 1))

	card.add_child(row)
	return card


## Returns a small circular icon using the crop\'s first stage texture, or a placeholder.
func _make_crop_icon(def: CropDefinition) -> Control:
	var tex: Texture2D = null
	if def != null and def.stage_textures.size() > 0:
		tex = def.stage_textures[0]
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
	sb.bg_color = Color(0.55, 0.78, 0.45, 1)
	sb.corner_radius_top_left = 23
	sb.corner_radius_top_right = 23
	sb.corner_radius_bottom_right = 23
	sb.corner_radius_bottom_left = 23
	placeholder.add_theme_stylebox_override("panel", sb)
	return placeholder


func _on_seed_selected(crop_id: int) -> void:
	if GameState.selected_seed_id == crop_id:
		GameState.deselect_seed()
	else:
		GameState.select_seed(crop_id)


func _on_selected_seed_changed(crop_id: int) -> void:
	if crop_id == -1:
		selected_label.text = "No seed selected."
	else:
		var def: CropDefinition = GameState.get_crop_def(crop_id)
		var name: String = def.display_name if def else "Crop %d" % crop_id
		selected_label.text = "Selected: %s" % name
	_refresh()


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


## Selected card stylebox: green-tinted with a thicker border.
func _selected_style() -> StyleBoxFlat:
	var sb := _card_style()
	sb.bg_color = Color(0.86, 0.96, 0.78, 1)
	sb.border_color = Color(0.3, 0.6, 0.28, 1)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	return sb


## Rounded background panel used behind the crop icon.
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