## GameState Autoload
## Single source of truth for all runtime game state.
## Emits signals whenever state changes so UI nodes can react without polling.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal exp_changed(new_exp: int)
signal level_changed(new_level: int)
signal money_changed(new_money: int)
signal notice_changed(text: String)
signal inventory_changed
signal warehouse_changed
signal plot_changed(plot_index: int)
signal selected_seed_changed(crop_id: int)
signal save_completed

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

## All 16 CropDefinition resources keyed by crop_id.
var crop_definitions: Dictionary = {}

## Logged-in player profile. Keys: username, password_hash, nickname, bio, avatar_id, notice.
var player_profile: Dictionary = {}

## EXP and money. Keys: exp (int), money (int).
var player_stats: Dictionary = {"exp": 0, "money": 200}

## Always exactly 6 FarmPlotState objects.
var farm_plots: Array = []

## Seed inventory. Each entry: {crop_id: int, count: int}.
var inventory: Array = []

## Harvest warehouse. Each entry: {crop_id: int, count: int}.
var warehouse: Array = []

## Currently selected seed's crop_id. -1 means nothing is selected.
var selected_seed_id: int = -1

## v0.1 deterministic harvest yield. Exactly one warehouse unit per planted seed.
const HARVEST_YIELD_PER_PLANT: int = 1

# ---------------------------------------------------------------------------
# Derived helpers
# ---------------------------------------------------------------------------

func get_level() -> int:
	return player_stats.get("exp", 0) / 100


func get_crop_def(crop_id: int) -> CropDefinition:
	return crop_definitions.get(crop_id, null)


## Returns the inventory entry dict for a crop, or null.
func find_inventory_entry(crop_id: int) -> Dictionary:
	for entry in inventory:
		if entry["crop_id"] == crop_id:
			return entry
	return {}


## Returns seed count in inventory for a crop_id.
func get_seed_count(crop_id: int) -> int:
	var entry := find_inventory_entry(crop_id)
	return entry.get("count", 0)


## Returns harvest count in warehouse for a crop_id.
func get_warehouse_count(crop_id: int) -> int:
	for entry in warehouse:
		if entry["crop_id"] == crop_id:
			return entry.get("count", 0)
	return 0

# ---------------------------------------------------------------------------
# Mutating actions
# ---------------------------------------------------------------------------

## Plant a crop on the given plot. Returns true on success.
func plant_crop(plot_index: int, crop_id: int) -> bool:
	if plot_index < 0 or plot_index >= farm_plots.size():
		push_warning("GameState.plant_crop: invalid plot_index %d" % plot_index)
		return false
	var state: FarmPlotState = farm_plots[plot_index]
	if not state.is_empty():
		return false
	var def := get_crop_def(crop_id)
	if def == null:
		push_warning("GameState.plant_crop: unknown crop_id %d" % crop_id)
		return false
	if get_seed_count(crop_id) < 1:
		return false
	if get_level() < def.required_level:
		return false
	# Deduct one seed
	_deduct_inventory(crop_id, 1)
	# Create plot state
	var new_state := FarmPlotState.new()
	new_state.plot_index = plot_index
	new_state.crop_id = crop_id
	new_state.plant_timestamp = Time.get_unix_time_from_system()
	new_state.yield_count = HARVEST_YIELD_PER_PLANT
	new_state.steals_remaining = 3
	farm_plots[plot_index] = new_state
	# EXP reward
	_add_exp(5)
	emit_signal("plot_changed", plot_index)
	SaveManager.request_save()
	return true


## Harvest a mature plot. Returns the yield gained, or 0 on failure.
func harvest_plot(plot_index: int) -> int:
	if plot_index < 0 or plot_index >= farm_plots.size():
		return 0
	var state: FarmPlotState = farm_plots[plot_index]
	if state.is_empty():
		return 0
	var def := get_crop_def(state.crop_id)
	if def == null:
		return 0
	if not CropGrowthSystem.is_mature(state, def):
		return 0
	# Deterministic yield: one unit per planted seed, regardless of any
	# legacy yield_count value previously stored in saved plots.
	var yield_gained := HARVEST_YIELD_PER_PLANT
	# Add to warehouse
	_add_to_warehouse(state.crop_id, yield_gained)
	# EXP reward (easter egg: crop 16 gives +99 bonus)
	var exp_gain := 1
	if state.crop_id == 16:
		exp_gain += 99
	_add_exp(exp_gain)
	# Clear the plot
	farm_plots[plot_index] = FarmPlotState.make_empty(plot_index)
	emit_signal("plot_changed", plot_index)
	SaveManager.request_save()
	return yield_gained


## Uproot (remove) a crop regardless of growth stage. Returns true on success.
func uproot_plot(plot_index: int) -> bool:
	if plot_index < 0 or plot_index >= farm_plots.size():
		return false
	var state: FarmPlotState = farm_plots[plot_index]
	if state.is_empty():
		return false
	farm_plots[plot_index] = FarmPlotState.make_empty(plot_index)
	_add_exp(3)
	emit_signal("plot_changed", plot_index)
	SaveManager.request_save()
	return true


## Buy seeds from the shop. Deducts money, adds to inventory. Returns true on success.
func buy_seed(crop_id: int, count: int) -> bool:
	var def := get_crop_def(crop_id)
	if def == null:
		return false
	if get_level() < def.required_level:
		return false
	var total_cost := def.seed_price * count
	if player_stats.get("money", 0) < total_cost:
		return false
	player_stats["money"] = player_stats["money"] - total_cost
	_add_to_inventory(crop_id, count)
	emit_signal("money_changed", player_stats["money"])
	SaveManager.request_save()
	return true


## Sell harvested crops from the warehouse. Returns true on success.
func sell_crop(crop_id: int, count: int) -> bool:
	var def := get_crop_def(crop_id)
	if def == null:
		return false
	if get_warehouse_count(crop_id) < count:
		return false
	_deduct_warehouse(crop_id, count)
	var earnings := def.sell_price * count
	player_stats["money"] = player_stats.get("money", 0) + earnings
	emit_signal("money_changed", player_stats["money"])
	SaveManager.request_save()
	return true


## Set the currently selected seed. Pass -1 to deselect.
func select_seed(crop_id: int) -> void:
	selected_seed_id = crop_id
	emit_signal("selected_seed_changed", crop_id)


func deselect_seed() -> void:
	select_seed(-1)

# ---------------------------------------------------------------------------
# Save / Load integration
# ---------------------------------------------------------------------------

## Load state from a SaveData object (called at boot after SaveManager.load_game()).
func apply_save(data: SaveData) -> void:
	player_profile = data.profile.duplicate()
	player_stats = data.stats.duplicate()
	farm_plots = []
	for p in data.plots:
		farm_plots.append(p)
	inventory = data.inventory.duplicate(true)
	warehouse = data.warehouse.duplicate(true)
	# Re-emit HUD signals
	emit_signal("exp_changed", player_stats.get("exp", 0))
	emit_signal("level_changed", get_level())
	emit_signal("money_changed", player_stats.get("money", 0))
	emit_signal("notice_changed", player_profile.get("notice", ""))
	emit_signal("inventory_changed")
	emit_signal("warehouse_changed")


## Build a SaveData snapshot from the current runtime state.
func to_save_data() -> SaveData:
	var sd := SaveData.new()
	sd.profile = player_profile.duplicate()
	sd.stats = player_stats.duplicate()
	sd.plots = []
	for p in farm_plots:
		sd.plots.append(p)
	sd.inventory = inventory.duplicate(true)
	sd.warehouse = warehouse.duplicate(true)
	return sd

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _add_exp(amount: int) -> void:
	var old_level := get_level()
	player_stats["exp"] = player_stats.get("exp", 0) + amount
	emit_signal("exp_changed", player_stats["exp"])
	var new_level := get_level()
	if new_level != old_level:
		emit_signal("level_changed", new_level)


func _add_to_inventory(crop_id: int, count: int) -> void:
	for entry in inventory:
		if entry["crop_id"] == crop_id:
			entry["count"] = entry["count"] + count
			emit_signal("inventory_changed")
			return
	inventory.append({"crop_id": crop_id, "count": count})
	emit_signal("inventory_changed")


func _deduct_inventory(crop_id: int, count: int) -> void:
	for i in inventory.size():
		if inventory[i]["crop_id"] == crop_id:
			inventory[i]["count"] -= count
			if inventory[i]["count"] <= 0:
				inventory.remove_at(i)
			emit_signal("inventory_changed")
			return


func _add_to_warehouse(crop_id: int, count: int) -> void:
	for entry in warehouse:
		if entry["crop_id"] == crop_id:
			entry["count"] = entry["count"] + count
			emit_signal("warehouse_changed")
			return
	warehouse.append({"crop_id": crop_id, "count": count})
	emit_signal("warehouse_changed")


func _deduct_warehouse(crop_id: int, count: int) -> void:
	for i in warehouse.size():
		if warehouse[i]["crop_id"] == crop_id:
			warehouse[i]["count"] -= count
			if warehouse[i]["count"] <= 0:
				warehouse.remove_at(i)
			emit_signal("warehouse_changed")
			return
