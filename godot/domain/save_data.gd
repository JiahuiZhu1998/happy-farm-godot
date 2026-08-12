## SaveData
## Plain data container representing the full serializable game state.
## Created by SaveManager.load_game() and consumed by GameState.apply_save().
class_name SaveData

const CURRENT_VERSION := 1

var save_version: int = CURRENT_VERSION
var profile: Dictionary = {}
var stats: Dictionary = {}
var plots: Array = []      # Array of FarmPlotState
var inventory: Array = []  # Array of {crop_id: int, count: int}
var warehouse: Array = []  # Array of {crop_id: int, count: int}


static func new_game(username: String, password_hash: String) -> SaveData:
	var sd := SaveData.new()
	sd.profile = {
		"username": username,
		"password_hash": password_hash,
		"nickname": username,
		"bio": "A new farmer just getting started.",
		"avatar_id": 1,
		"notice": "Welcome to my farm!",
	}
	sd.stats = {"exp": 100, "money": 200}
	sd.plots = []
	for i in 6:
		sd.plots.append(FarmPlotState.make_empty(i))
	sd.inventory = []
	sd.warehouse = []
	return sd


func to_dict() -> Dictionary:
	var plots_raw: Array = []
	for p in plots:
		plots_raw.append((p as FarmPlotState).to_dict())
	return {
		"save_version": save_version,
		"profile": profile.duplicate(),
		"stats": stats.duplicate(),
		"plots": plots_raw,
		"inventory": inventory.duplicate(true),
		"warehouse": warehouse.duplicate(true),
	}


static func from_dict(d: Dictionary) -> SaveData:
	var sd := SaveData.new()
	sd.save_version = d.get("save_version", 1)
	sd.profile = d.get("profile", {}).duplicate()
	sd.stats = d.get("stats", {"exp": 0, "money": 200}).duplicate()
	sd.inventory = d.get("inventory", []).duplicate(true)
	sd.warehouse = d.get("warehouse", []).duplicate(true)
	sd.plots = []
	var raw_plots: Array = d.get("plots", [])
	# Ensure exactly 6 plots
	for i in 6:
		var found := false
		for rp in raw_plots:
			if rp.get("plot_index", -1) == i:
				sd.plots.append(FarmPlotState.from_dict(rp))
				found = true
				break
		if not found:
			sd.plots.append(FarmPlotState.make_empty(i))
	return sd
