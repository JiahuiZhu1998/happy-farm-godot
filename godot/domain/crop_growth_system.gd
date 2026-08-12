## CropGrowthSystem
## Pure static functions for computing crop growth state from timestamps.
## No mutable state, no signals. Safe to call from anywhere.
class_name CropGrowthSystem


## Returns the current growth stage index (0-based).
## Returns -1 if the plot is empty.
static func compute_stage(state: FarmPlotState, def: CropDefinition) -> int:
	if state.is_empty():
		return -1
	var elapsed: float = Time.get_unix_time_from_system() - state.plant_timestamp
	var cumulative: float = 0.0
	for i in def.stage_count:
		cumulative += def.stage_durations[i]
		if elapsed < cumulative:
			return i
	return def.stage_count - 1


## Returns true if the crop has reached its final stage and is ready to harvest.
static func is_mature(state: FarmPlotState, def: CropDefinition) -> bool:
	if state.is_empty():
		return false
	return compute_stage(state, def) >= def.stage_count - 1


## Returns the texture that should be displayed for the current state.
static func get_current_texture(state: FarmPlotState, def: CropDefinition) -> Texture2D:
	if state.is_empty():
		return def.harvested_texture
	var stage := compute_stage(state, def)
	# Just-planted: stage 0 before any time has passed — use planted_texture
	if stage == 0 and def.planted_texture != null:
		var elapsed: float = Time.get_unix_time_from_system() - state.plant_timestamp
		if elapsed < def.stage_durations[0] * 0.1:
			return def.planted_texture
	if stage >= 0 and stage < def.stage_textures.size():
		return def.stage_textures[stage]
	if not def.stage_textures.is_empty():
		return def.stage_textures[-1]
	return null


## Returns seconds remaining until the next stage transition.
## Returns 0.0 if already at final stage or empty.
static func seconds_to_next_stage(state: FarmPlotState, def: CropDefinition) -> float:
	if state.is_empty():
		return 0.0
	var elapsed: float = Time.get_unix_time_from_system() - state.plant_timestamp
	var cumulative: float = 0.0
	for i in def.stage_count:
		cumulative += def.stage_durations[i]
		if elapsed < cumulative:
			return cumulative - elapsed
	return 0.0
