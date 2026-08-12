## SaveManager Autoload
## Handles all file I/O for the game save. Debounces rapid save requests.
extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const DEBOUNCE_SECONDS := 0.5

var _pending_save: SaveData = null
var _save_timer: Timer


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = DEBOUNCE_SECONDS
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)


## Load the save file. Returns a SaveData instance.
## If no file exists or file is corrupt, returns a default (new-game placeholder).
## Caller must check save_data.profile.is_empty() to know if login is required.
func load_game() -> SaveData:
	if not FileAccess.file_exists(SAVE_PATH):
		return SaveData.new()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open save file for reading")
		return SaveData.new()
	var text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: save file is not valid JSON")
		return SaveData.new()
	var raw: Dictionary = parsed
	raw = _migrate(raw)
	return SaveData.from_dict(raw)


## Write a SaveData to disk immediately.
func save_game(data: SaveData) -> void:
	var dir_path := SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing")
		return
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	file.close()
	GameState.emit_signal("save_completed")


## Schedule a save. If called repeatedly within DEBOUNCE_SECONDS, only one write occurs.
func request_save() -> void:
	_pending_save = GameState.to_save_data()
	if _save_timer.is_stopped():
		_save_timer.start()
	else:
		_save_timer.start()  # reset the debounce window


func _flush_save() -> void:
	if _pending_save != null:
		save_game(_pending_save)
		_pending_save = null


## Apply forward migrations when loading an old save version.
func _migrate(raw: Dictionary) -> Dictionary:
	var version: int = raw.get("save_version", 0)
	if version < 1:
		# v0 → v1: no prior format existed; treat as corrupt new-game state
		raw["save_version"] = 1
		if not raw.has("plots"):
			raw["plots"] = []
		if not raw.has("inventory"):
			raw["inventory"] = []
		if not raw.has("warehouse"):
			raw["warehouse"] = []
		if not raw.has("profile"):
			raw["profile"] = {}
		if not raw.has("stats"):
			raw["stats"] = {"exp": 0, "money": 200}
	return raw
