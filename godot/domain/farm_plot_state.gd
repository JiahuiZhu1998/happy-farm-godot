## FarmPlotState
## Pure data object representing the runtime state of one farm plot.
## No methods that mutate GameState — all mutations go through GameState autoload.
class_name FarmPlotState

## 0-based index (0–5)
var plot_index: int = 0
## -1 means empty
var crop_id: int = -1
## Unix epoch seconds; 0.0 means empty
var plant_timestamp: float = 0.0
## Harvestable yield; 0 means empty
var yield_count: int = 0
## Remaining steal attempts; 0 when empty
var steals_remaining: int = 0


func is_empty() -> bool:
	return crop_id == -1


static func make_empty(index: int) -> FarmPlotState:
	var s := FarmPlotState.new()
	s.plot_index = index
	return s


func to_dict() -> Dictionary:
	return {
		"plot_index": plot_index,
		"crop_id": crop_id,
		"plant_timestamp": plant_timestamp,
		"yield_count": yield_count,
		"steals_remaining": steals_remaining,
	}


static func from_dict(d: Dictionary) -> FarmPlotState:
	var s := FarmPlotState.new()
	s.plot_index = d.get("plot_index", 0)
	s.crop_id = d.get("crop_id", -1)
	s.plant_timestamp = d.get("plant_timestamp", 0.0)
	s.yield_count = d.get("yield_count", 0)
	s.steals_remaining = d.get("steals_remaining", 0)
	return s
