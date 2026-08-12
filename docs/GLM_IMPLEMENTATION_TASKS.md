# GLM Implementation Tasks — Happy Farm (Godot 4.7.1)

**Handoff document for GLM-5.2 agent.**
This document defines your exact scope, the contracts you must honour, and the tasks in priority order.

---

## 1. What You Are Building

You are implementing the **visual and interaction layer** of a Godot 4.7.1 farm game. The domain logic, save system, and all data structures are already complete and frozen. You fill in the remaining UI/visual code to connect those systems to the player.

**You work inside:** `godot/scenes/` and `godot/data/`
**You must NOT modify:** `godot/domain/`, `godot/autoloads/`, `godot/project.godot`

---

## 2. Architecture You Are Working Against

Read [docs/ARCHITECTURE.md](ARCHITECTURE.md) before starting. The key rules:

- All game state lives in the `GameState` autoload. You read from it and call its action methods. You never modify `GameState.farm_plots`, `GameState.inventory`, or `GameState.player_stats` directly.
- Persistence is handled entirely by `SaveManager`. You never call file I/O yourself.
- All crop growth math is in `CropGrowthSystem` (pure static). You call its methods; you never re-implement growth logic.
- UI is driven by signals emitted from `GameState`. Connect to them in `_ready()`; never poll in `_process()`.

---

## 3. Frozen Contracts — Interfaces You Must Implement Against

### 3.1 GameState signals you must connect

| Signal | Signature | Use for |
|--------|-----------|---------|
| `exp_changed` | `(new_exp: int)` | Update HUD EXP label |
| `level_changed` | `(new_level: int)` | Update HUD level label |
| `money_changed` | `(new_money: int)` | Update HUD money label |
| `notice_changed` | `(text: String)` | Update HUD notice text |
| `inventory_changed` | `()` | Refresh inventory panel list |
| `warehouse_changed` | `()` | Refresh warehouse panel list |
| `plot_changed` | `(plot_index: int)` | Refresh single FarmPlot visual |
| `selected_seed_changed` | `(crop_id: int)` | Highlight selected seed in inventory |

### 3.2 GameState action methods you may call

```gdscript
GameState.plant_crop(plot_index: int, crop_id: int) -> bool
GameState.harvest_plot(plot_index: int) -> int          # returns yield count
GameState.uproot_plot(plot_index: int) -> void
GameState.buy_seed(crop_id: int, count: int) -> bool
GameState.sell_crop(crop_id: int, count: int) -> bool
GameState.select_seed(crop_id: int) -> void
GameState.deselect_seed() -> void
GameState.get_crop_def(crop_id: int) -> CropDefinition  # may return null
GameState.get_level() -> int
```

### 3.3 CropGrowthSystem methods you may call

```gdscript
CropGrowthSystem.compute_stage(state: FarmPlotState, def: CropDefinition) -> int
CropGrowthSystem.is_mature(state: FarmPlotState, def: CropDefinition) -> bool
CropGrowthSystem.get_current_texture(state: FarmPlotState, def: CropDefinition) -> Texture2D
CropGrowthSystem.seconds_to_next_stage(state: FarmPlotState, def: CropDefinition) -> float
```

### 3.4 FarmPlot signal you must emit

```gdscript
signal action_requested(plot_index: int, action: String)
# action values: "plant" | "harvest" | "uproot"
```

### 3.5 CropVisual method you must implement

```gdscript
func update_visual(state: FarmPlotState, def: CropDefinition) -> void
# state or def may be null when plot is empty
```

### 3.6 FarmPlot method you must implement

```gdscript
func refresh(state: FarmPlotState, def: CropDefinition) -> void
# Called every second by FarmScene and on any plot_changed signal
```

---

## 4. Task List (Priority Order)

### Task 1 — FarmPlot collision shape and CropVisual textures

**Files:** [godot/scenes/farm/farm_plot/farm_plot.tscn](../godot/scenes/farm/farm_plot/farm_plot.tscn), [godot/scenes/farm/crop_visual/crop_visual.gd](../godot/scenes/farm/crop_visual/crop_visual.gd)

**Work required:**
1. In `farm_plot.tscn`, open the `CollisionShape2D` node under `PlotArea` and assign a `RectangleShape2D` of size `Vector2(128, 128)`. This enables click detection.
2. Verify `crop_visual.gd` correctly calls `CropGrowthSystem.get_current_texture(state, def)` and sets it on `$CropSprite`. The skeleton is already written; read it and confirm it compiles.
3. Verify `StageLabel` (debug text) shows the correct stage info from `CropGrowthSystem.compute_stage()`.

**Acceptance:** Clicking a plot in-game triggers `_on_area_input_event`. A planted crop displays its first stage texture.

---

### Task 2 — FarmPlot click routing

**Files:** [godot/scenes/farm/farm_plot/farm_plot.gd](../godot/scenes/farm/farm_plot/farm_plot.gd)

**Work required:**
The skeleton is already written. Read the script and verify:
1. Left click on empty plot with seed selected → emits `action_requested(plot_index, "plant")`
2. Left click on occupied plot → emits `action_requested(plot_index, "harvest")`
3. Right click on occupied plot → emits `action_requested(plot_index, "uproot")`
4. Left click on empty plot with no seed selected → does nothing (no signal)

If any path is wrong, fix it without changing the signal contract.

**Acceptance:** All four click paths route correctly as described above.

---

### Task 3 — HUD live updates

**Files:** [godot/scenes/ui/hud.gd](../godot/scenes/ui/hud.gd)

**Work required:**
The skeleton is already written. Read it and verify:
1. All four `GameState` signals are connected in `_ready()`.
2. Initial values are read from `GameState.player_stats` and `GameState.player_profile` on `_ready()`.
3. Each signal handler updates the correct label.

One gap to fill: `GameState.get_level()` is called in `_ready()`. Verify that method exists in `game_state.gd`. If it does not, add it:
```gdscript
func get_level() -> int:
    var exp: int = player_stats.get("exp", 0)
    return max(1, exp / 100)
```
Only add this to `game_state.gd` if it is missing — `get_level()` is the only method you are permitted to add to autoloads.

**Acceptance:** EXP, Level, Money labels update immediately when any GameState action is performed.

---

### Task 4 — Inventory panel: seed selection flow

**Files:** [godot/scenes/inventory/inventory.gd](../godot/scenes/inventory/inventory.gd)

**Work required:**
The skeleton is written. Verify and complete:
1. `_refresh()` correctly renders one row per inventory entry using `GameState.inventory`.
2. Clicking "Use" on a seed that is already selected calls `GameState.deselect_seed()`; otherwise calls `GameState.select_seed(crop_id)` — toggle behaviour.
3. `_on_selected_seed_changed(crop_id)` updates `selected_label` with the crop's display name or "No seed selected."
4. Wire the scene: create a minimal `inventory.tscn` with a `VBoxContainer` uniquely named `%ItemList` and a `Label` uniquely named `%SelectedLabel`, and attach `inventory.gd`.

**Acceptance:** Selecting a seed in Inventory causes that seed's name to appear in `selected_label`, and the FarmPlot responds to plant clicks.

---

### Task 5 — Shop panel: buy seeds

**Files:** [godot/scenes/shop/shop.gd](../godot/scenes/shop/shop.gd)

**Work required:**
The skeleton is written. Verify and complete:
1. `_populate()` builds one row per `CropDefinition` in `GameState.crop_definitions`, sorted by `crop_id`.
2. Selecting a row sets `_selected_crop_id` and updates `status_label`.
3. Clicking "Buy" calls `GameState.buy_seed(_selected_crop_id, int(buy_count_spin.value))`.
4. On failure, display an appropriate message (insufficient coins vs. level requirement).
5. Create `shop.tscn` with `VBoxContainer` (`%ItemList`), `SpinBox` (`%BuyCountSpin`), `Button` (`%BuyButton`), `Label` (`%StatusLabel`).

**Acceptance:** Player can buy seeds; money decreases; seeds appear in Inventory.

---

### Task 6 — Warehouse panel: sell crops

**Files:** [godot/scenes/warehouse/warehouse.gd](../godot/scenes/warehouse/warehouse.gd)

**Work required:**
The skeleton is written. Verify and complete:
1. `_refresh()` rebuilds the list from `GameState.warehouse`.
2. "Sell All" calls `GameState.sell_crop(crop_id, count)` and shows earnings in `status_label`.
3. Create `warehouse.tscn` with `VBoxContainer` (`%ItemList`) and `Label` (`%StatusLabel`).

**Acceptance:** Harvested crops appear in warehouse; selling them increments money in HUD.

---

### Task 7 — Placeholder CropDefinition resources

**Files:** `godot/data/crops/crop_1.tres` through `crop_16.tres`

**Work required:**
Create 16 minimal `.tres` files so Boot does not emit warnings. Exact format for each:

```
[gd_resource type="Resource" script_class="CropDefinition" load_steps=2 format=3]
[ext_resource type="Script" path="res://domain/crop_definition.gd" id="1"]
[resource]
script = ExtResource("1")
crop_id = N
display_name = "Crop N"
stage_count = 4
stage_durations = [30.0, 60.0, 90.0, 120.0]
seed_price = 10
sell_price = 25
required_level = 1
```

Replace `N` with 1–16. Do not assign textures yet (leave as null). Real data will be filled in Phase 4.

**Acceptance:** Boot scene loads without `missing crop definition` warnings.

---

### Task 8 — Panel open/close buttons on Farm HUD

**Files:** [godot/scenes/farm/farm.tscn](../godot/scenes/farm/farm.tscn), [godot/scenes/farm/farm.gd](../godot/scenes/farm/farm.gd)

**Work required:**
Add three toggle buttons to the HUD row:
- "Shop" → shows/hides the shop panel
- "Inventory" → shows/hides inventory panel
- "Warehouse" → shows/hides warehouse panel

Add three `PanelContainer` nodes to `FarmScene` under a new `CanvasLayer` (layer 15), each containing the respective scene. Wire show/hide to the toggle buttons via `visible` flag. Only one panel should be open at a time (closing others when one opens is preferred but not required for this task).

**Acceptance:** All three panels can be opened and closed from the farm screen.

---

## 5. What You Must NOT Do

| Forbidden action | Reason |
|-----------------|--------|
| Modify any file in `godot/domain/` | Domain layer is frozen |
| Modify `godot/autoloads/game_state.gd` (except Task 3 `get_level()` gap) | State contract is frozen |
| Modify `godot/autoloads/save_manager.gd` | Save system is frozen |
| Modify `godot/project.godot` | Project config is frozen |
| Modify `docs/ARCHITECTURE.md` | Architecture is frozen |
| Add a third Autoload | Violates 2-autoload constraint |
| Implement growth math yourself | Use `CropGrowthSystem` exclusively |
| Write directly to `GameState.farm_plots[i]` | Use `GameState.plant_crop()` etc. |
| Use `_process()` to poll state | Use signals |

---

## 6. Verification Checklist

Before declaring each task complete, verify:

- [ ] No GDScript parse errors in Godot editor
- [ ] `get_errors` returns no errors for modified files
- [ ] Signal connections are made in `_ready()`, not in `_process()`
- [ ] All `@onready` node paths match the actual scene tree
- [ ] Unique names (`%NodeName`) match between script and `.tscn`
- [ ] No `push_error` lines fire at runtime for normal usage

---

## 7. File Reference Map

```
godot/
├── domain/                    # FROZEN — read-only
│   ├── crop_definition.gd
│   ├── farm_plot_state.gd
│   ├── save_data.gd
│   └── crop_growth_system.gd
├── autoloads/                 # FROZEN — read-only (except get_level() gap)
│   ├── game_state.gd
│   └── save_manager.gd
├── data/crops/                # Task 7 — create crop_1.tres through crop_16.tres
├── scenes/
│   ├── boot/                  # Done
│   ├── login/                 # Done
│   ├── register/              # Done
│   ├── farm/
│   │   ├── farm.gd            # Skeleton done — Task 8 (add panel buttons)
│   │   ├── farm.tscn          # Skeleton done — Task 8 (add panel containers)
│   │   ├── farm_plot/
│   │   │   ├── farm_plot.gd   # Skeleton done — Task 2 (verify click routing)
│   │   │   └── farm_plot.tscn # Task 1 (add collision shape)
│   │   └── crop_visual/
│   │       ├── crop_visual.gd # Skeleton done — Task 1 (verify texture update)
│   │       └── crop_visual.tscn # Done (embedded in farm_plot.tscn)
│   ├── ui/
│   │   ├── hud.gd             # Skeleton done — Task 3 (verify + get_level() gap)
│   │   └── hud.tscn           # Done (embedded in farm.tscn)
│   ├── shop/
│   │   ├── shop.gd            # Skeleton done — Task 5 (verify + create .tscn)
│   │   └── shop.tscn          # Task 5 — create
│   ├── inventory/
│   │   ├── inventory.gd       # Skeleton done — Task 4 (verify + create .tscn)
│   │   └── inventory.tscn     # Task 4 — create
│   └── warehouse/
│       ├── warehouse.gd       # Skeleton done — Task 6 (verify + create .tscn)
│       └── warehouse.tscn     # Task 6 — create
```
