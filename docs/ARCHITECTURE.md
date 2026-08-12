# Architecture — Happy Farm (Godot 4.7.1)

**Engine:** Godot 4.7.1 stable  
**Language:** GDScript (typed, `class_name` used throughout)  
**Rendering:** 2D  
**Platform target:** Desktop (Windows, macOS, Linux)  
**Save location:** `user://save.json`

---

## 1. Guiding Principles

1. **Data / Behavior / Presentation separation.** Data lives in `SaveData` and `CropDefinition` resources. Behavior lives in `GameState` autoload and scene scripts. Presentation lives in scene nodes.
2. **Timestamp-based growth — no threads, no Timers per plot.** Current growth stage is always computed on demand from `(now - plant_timestamp)` vs cumulative stage durations. A single 1-second `Timer` in `FarmScene` triggers a visual refresh.
3. **Immutable crop definitions.** `CropDefinition` resources are loaded once and never mutated. All mutable plot state lives in `FarmPlotState` objects owned by `GameState`.
4. **Conservative Autoloads.** Only two Autoloads: `GameState` (runtime state + signals) and `SaveManager` (file I/O). Everything else is a scene node or a plain GDScript class.
5. **Signal-driven UI.** No direct references from UI nodes to domain logic. UI reacts to signals emitted by `GameState`.
6. **Versioned save schema.** Save file carries `save_version: int`. Migration functions handle old versions forward.

---

## 2. Directory Layout

```
godot/
├── project.godot
├── export_presets.cfg
│
├── autoloads/
│   ├── game_state.gd          # Autoload: runtime state + signals
│   └── save_manager.gd        # Autoload: load/save user://save.json
│
├── data/
│   └── crops/
│       ├── crop_1.tres        # CropDefinition resource for crop 1
│       ├── crop_2.tres        # … etc for all 16
│       └── …
│
├── domain/
│   ├── crop_definition.gd     # class_name CropDefinition extends Resource
│   ├── farm_plot_state.gd     # class_name FarmPlotState
│   ├── save_data.gd           # class_name SaveData
│   └── crop_growth_system.gd  # class_name CropGrowthSystem (pure functions)
│
├── scenes/
│   ├── boot/
│   │   └── boot.tscn          # Boots, loads crop defs, goes to Login or Farm
│   ├── login/
│   │   ├── login.tscn
│   │   └── login.gd
│   ├── register/
│   │   ├── register.tscn
│   │   └── register.gd
│   ├── farm/
│   │   ├── farm.tscn          # Main game scene
│   │   ├── farm.gd
│   │   ├── farm_plot/
│   │   │   ├── farm_plot.tscn # Single plot node (instanced ×6)
│   │   │   └── farm_plot.gd
│   │   └── crop_visual/
│   │       ├── crop_visual.tscn
│   │       └── crop_visual.gd
│   ├── shop/
│   │   ├── shop.tscn
│   │   └── shop.gd
│   ├── inventory/
│   │   ├── inventory.tscn
│   │   └── inventory.gd
│   ├── warehouse/
│   │   ├── warehouse.tscn
│   │   └── warehouse.gd
│   └── ui/
│       ├── hud.tscn           # EXP / Level / Money / Notice bar
│       ├── hud.gd
│       └── dialog.tscn        # Reusable AcceptDialog wrapper
│
└── assets/
    ├── crops/
    │   ├── crop_1/            # seed.png, stage_0.png … stage_N.png, planted.png, harvested.png
    │   └── …
    ├── backgrounds/           # bg_1.png … bg_5.png
    ├── land/                  # plot_1.png … plot_5.png
    └── avatars/               # avatar_1.png … avatar_20.png (converted from GIF)
```

---

## 3. Autoloads

### `GameState` (`autoloads/game_state.gd`)

Holds all mutable runtime state and emits signals when it changes. No scene references.

```gdscript
# State
var crop_definitions: Dictionary  # int → CropDefinition
var player_profile: Dictionary
var player_stats: Dictionary       # {exp: int, money: int}
var farm_plots: Array              # Array[FarmPlotState], always 6 elements
var inventory: Array               # Array[{crop_id: int, count: int}]
var warehouse: Array               # Array[{crop_id: int, count: int}]
var selected_seed_id: int = -1     # -1 = nothing selected

# Derived
func get_level() -> int: return player_stats.exp / 100
func get_crop_def(crop_id: int) -> CropDefinition

# Mutating actions (all emit signals + call SaveManager.request_save())
func plant_crop(plot_index: int, crop_id: int) -> bool
func harvest_plot(plot_index: int) -> int          # returns yield gained
func uproot_plot(plot_index: int) -> bool
func buy_seed(crop_id: int, count: int) -> bool    # deducts money + adds inventory
func sell_crop(crop_id: int, count: int) -> bool   # removes from warehouse + adds money
func add_exp(amount: int) -> void
func select_seed(crop_id: int) -> void
func deselect_seed() -> void

# Signals
signal exp_changed(new_exp: int)
signal money_changed(new_money: int)
signal level_changed(new_level: int)
signal notice_changed(text: String)
signal inventory_changed
signal warehouse_changed
signal plot_changed(plot_index: int)
signal selected_seed_changed(crop_id: int)
signal save_completed
```

### `SaveManager` (`autoloads/save_manager.gd`)

Handles all file I/O. Receives requests from `GameState`. Debounces rapid successive saves.

```gdscript
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

func load_game() -> SaveData      # Reads file, deserializes, returns SaveData (or new game)
func save_game(data: SaveData) -> void   # Serializes + writes file
func request_save() -> void       # Debounced: schedules a save in ≤1s

# Internal
func _serialize(data: SaveData) -> Dictionary
func _deserialize(raw: Dictionary) -> SaveData
func _migrate(raw: Dictionary, from_version: int) -> Dictionary
```

---

## 4. Domain Classes

### `CropDefinition` (`domain/crop_definition.gd`)

```gdscript
class_name CropDefinition
extends Resource

@export var crop_id: int
@export var display_name: String
@export var stage_count: int
@export var stage_durations: Array[float]   # seconds per stage (not cumulative)
@export var stage_textures: Array[Texture2D]
@export var seed_texture: Texture2D
@export var planted_texture: Texture2D
@export var harvested_texture: Texture2D
@export var seed_price: int
@export var sell_price: int
@export var required_level: int
```

Instances live in `res://data/crops/crop_N.tres`. Loaded once at boot, cached in `GameState.crop_definitions`.

---

### `FarmPlotState` (`domain/farm_plot_state.gd`)

```gdscript
class_name FarmPlotState

var plot_index: int       # 0–5
var crop_id: int          # -1 = empty
var plant_timestamp: float  # Unix epoch seconds; 0.0 = empty
var yield_count: int      # 0 = empty
var steals_remaining: int # 0 = empty; 3 when planted

func is_empty() -> bool: return crop_id == -1
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> FarmPlotState
```

---

### `CropGrowthSystem` (`domain/crop_growth_system.gd`)

Pure functions — no state, no signals. Testable in isolation.

```gdscript
class_name CropGrowthSystem

## Returns the current growth stage index (0-based) for the given plot.
## Returns -1 if plot is empty.
static func compute_stage(state: FarmPlotState, def: CropDefinition) -> int:
    if state.is_empty():
        return -1
    var elapsed := Time.get_unix_time_from_system() - state.plant_timestamp
    var cumulative := 0.0
    for i in def.stage_count:
        cumulative += def.stage_durations[i]
        if elapsed < cumulative:
            return i
    return def.stage_count - 1

## Returns true if the crop is ready to harvest.
static func is_mature(state: FarmPlotState, def: CropDefinition) -> bool:
    if state.is_empty():
        return false
    return compute_stage(state, def) >= def.stage_count - 1

## Returns the texture for the current state.
static func get_current_texture(state: FarmPlotState, def: CropDefinition) -> Texture2D:
    if state.is_empty():
        return def.harvested_texture  # empty / harvested look
    var stage := compute_stage(state, def)
    if stage < def.stage_textures.size():
        return def.stage_textures[stage]
    return def.stage_textures[-1]
```

---

### `SaveData` (`domain/save_data.gd`)

```gdscript
class_name SaveData

var save_version: int = 1
var profile: Dictionary   # username, password_hash, nickname, bio, avatar_id, notice
var stats: Dictionary     # exp, money
var plots: Array          # Array[FarmPlotState]
var inventory: Array      # Array[{crop_id, count}]
var warehouse: Array      # Array[{crop_id, count}]

static func new_game(username: String, password_hash: String) -> SaveData
```

---

## 5. Scene Architecture

### Boot Scene (`scenes/boot/boot.tscn`)
1. Shows loading screen.
2. Loads all 16 `CropDefinition` resources into `GameState.crop_definitions`.
3. Attempts `SaveManager.load_game()`.
4. If save exists → `SceneTree.change_scene_to_file("res://scenes/farm/farm.tscn")`.
5. If no save → `SceneTree.change_scene_to_file("res://scenes/login/login.tscn")`.

### Login Scene (`scenes/login/login.tscn`)
- `LineEdit` for username, password.
- Validates against loaded save profile.
- On success → Farm scene.
- Link to Register scene.

### Register Scene (`scenes/register/register.tscn`)
- `LineEdit` for username, password, confirm password.
- Validates format (username 3–10 chars, password 6–12 chars).
- Calls `SaveManager` to create a new save with default stats (exp=100, money=200).
- On success → Farm scene.

### Farm Scene (`scenes/farm/farm.tscn`)

Root: `Node2D`
```
FarmScene (Node2D)
├── Background (TextureRect)
├── FarmGrid (Node2D)              ← contains 6 FarmPlot instances
│   ├── FarmPlot[0..5] (Node2D)   ← instanced from farm_plot.tscn
├── HUD (CanvasLayer)
│   └── HUDPanel (hud.tscn)       ← EXP / Level / Money / Notice
├── PanelContainer (CanvasLayer)  ← tabbed panels
│   ├── ShopPanel (shop.tscn)
│   ├── InventoryPanel (inventory.tscn)
│   └── WarehousePanel (warehouse.tscn)
├── GrowthTimer (Timer)           ← 1.0s, autostart, triggers visual refresh
└── DialogLayer (CanvasLayer)     ← AcceptDialog for messages
```

`farm.gd` connects:
- `GrowthTimer.timeout` → `_refresh_all_plots()` (updates CropVisual textures)
- `GameState.plot_changed` → `_on_plot_changed(index)` (refresh one plot)
- `GameState.inventory_changed` → refresh inventory panel
- Input: left-click on plot when `selected_seed_id != -1` → `GameState.plant_crop()`

### FarmPlot Scene (`scenes/farm/farm_plot/farm_plot.tscn`)

```
FarmPlot (Node2D)
├── LandSprite (Sprite2D)         ← land/plot background tile
├── CropVisual (Node2D)           ← instanced from crop_visual.tscn
└── PlotArea (Area2D)             ← click detection
    └── CollisionShape2D
```

`farm_plot.gd`:
- `var plot_index: int` — assigned by FarmScene at startup
- `_on_plot_area_input_event()` — routes clicks to GameState actions based on context:
  - Empty + seed selected → `GameState.plant_crop(plot_index, selected_seed_id)`
  - Mature + no seed selected → `GameState.harvest_plot(plot_index)`
  - Any crop + right click or uproot button → `GameState.uproot_plot(plot_index)`
- `refresh(state: FarmPlotState)` — called by FarmScene; updates CropVisual

### CropVisual Scene (`scenes/farm/crop_visual/crop_visual.tscn`)

```
CropVisual (Node2D)
└── CropSprite (Sprite2D)
```

`crop_visual.gd`:
- `func update(state: FarmPlotState, def: CropDefinition) -> void`
  - Sets `CropSprite.texture` from `CropGrowthSystem.get_current_texture(state, def)`
  - Hides/shows based on `state.is_empty()`

### HUD (`scenes/ui/hud.tscn`)

Connects to `GameState` signals:
- `exp_changed` → update EXP label
- `level_changed` → update Level label  
- `money_changed` → update Money label
- `notice_changed` → update farm notice label

---

## 6. Data Flow

### Plant action (full flow)

```
User clicks empty plot (seed selected in inventory)
  → FarmPlot._on_area_clicked()
  → GameState.plant_crop(plot_index, crop_id)
    → validate: plot empty, crop in inventory, loginUser == currentUser
    → deduct 1 seed from inventory  (inventory_changed signal)
    → create FarmPlotState {crop_id, plant_timestamp=now, yield_count=randi()%50, steals_remaining=3}
    → farm_plots[plot_index] = new state
    → add_exp(5)  (exp_changed, level_changed signals)
    → emit plot_changed(plot_index)
    → SaveManager.request_save()
  → FarmScene._on_plot_changed(plot_index)
  → FarmPlot.refresh(state)
  → CropVisual.update(state, def)  → shows planted_texture
```

### Growth visual update (timer-driven)

```
GrowthTimer.timeout (every 1 second)
  → FarmScene._refresh_all_plots()
  → for each plot: FarmPlot.refresh(GameState.farm_plots[i])
  → CropVisual.update(state, def)
  → CropGrowthSystem.get_current_texture(state, def)  ← computes stage from timestamp
  → CropSprite.texture = result
```

### Harvest action

```
User clicks mature plot (no seed selected)
  → FarmPlot._on_area_clicked()
  → GameState.harvest_plot(plot_index)
    → validate: crop mature (CropGrowthSystem.is_mature)
    → yield = state.yield_count
    → add yield to warehouse  (warehouse_changed signal)
    → bonus_exp: 1 normally; +99 extra if crop_id == 16
    → add_exp(1 or 100)
    → clear plot: farm_plots[plot_index] = FarmPlotState.empty(plot_index)
    → emit plot_changed(plot_index)
    → SaveManager.request_save()
```

### Save flow

```
SaveManager.request_save()
  → _save_timer.start(0.5)   ← debounce: resets on multiple rapid requests
  → _save_timer.timeout
  → save_game(GameState.to_save_data())
  → JSON.stringify(data) → FileAccess.open("user://save.json") → write
  → GameState.emit save_completed
```

---

## 7. Signal Reference

| Signal | Emitter | Payload | Connected to |
|---|---|---|---|
| `exp_changed` | `GameState` | `new_exp: int` | `HUD` |
| `level_changed` | `GameState` | `new_level: int` | `HUD` |
| `money_changed` | `GameState` | `new_money: int` | `HUD` |
| `notice_changed` | `GameState` | `text: String` | `HUD` |
| `inventory_changed` | `GameState` | — | `InventoryPanel`, `FarmScene` |
| `warehouse_changed` | `GameState` | — | `WarehousePanel` |
| `plot_changed` | `GameState` | `plot_index: int` | `FarmScene` |
| `selected_seed_changed` | `GameState` | `crop_id: int` | `FarmScene`, `InventoryPanel` |
| `save_completed` | `GameState` | — | (debug HUD, if any) |

---

## 8. Security Considerations

- **Password storage:** SHA-256 hash only. Never store plaintext. Use `Crypto.generate_random_bytes()` salt + `HashingContext`.
- **Input validation:** All user input (username, password) validated for length and character class before processing.
- **Save file integrity:** Save file is local `user://` data; no network transmission in v1.
- **No eval / exec:** No dynamic code execution anywhere in the codebase.

---

## 9. What Is Explicitly Out of Scope (v1)

| Feature | Reason deferred |
|---|---|
| Multi-user / friend visiting | Requires networking or shared file system |
| Steal / blacklist system | Depends on multi-user |
| User avatar changing | Nice-to-have; UI complexity |
| Background slideshow animation | Low priority visual feature |
| Selling individual crop counts from warehouse | Can be added in v1.1 |
| Admin user (`admin` / `123456` hardcoded) | Security risk; removed entirely |
