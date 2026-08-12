# Migration Map — Java Happy Farm → Godot 4.7.1

This document provides a direct concept-by-concept and class-by-class mapping from the legacy Java implementation to the target Godot 4.7.1 GDScript architecture.

---

## 1. Conceptual Mapping Overview

| Java Concept | Godot Equivalent | Notes |
|---|---|---|
| `static` fields in `GameMember` | Autoload singletons | Split into `GameState`, `SaveManager` |
| `CropBean` (definition half) | `CropDefinition` (Resource) | Data-only, no mutable state |
| `CropBean.current` (runtime stage) | `FarmPlotState.current_stage` | Computed from timestamp, not polled |
| `LandItemBean` (data) | `FarmPlotState` (plain Dictionary / inner class) | Pure data, no actions |
| `LandItemBean` (actions) | `FarmPlot` Node (scene) | UI + action methods as signals |
| `CropGrowThread` | No equivalent needed | Timestamps make threads obsolete |
| `PackageItemBean` | `InventoryEntry` (Dictionary) | `{crop_id, count}` |
| `StoreHouseItemBean` | `WarehouseEntry` (Dictionary) | `{crop_id, count}` |
| `UserBean` | `PlayerProfile` (Dictionary in SaveData) | `{user_id, username, nickname, bio, avatar_id, notice}` |
| `UserData` | `PlayerStats` (part of SaveData) | `{exp, money}` — level is derived |
| `GameMember.mouseState` + `selectdCropid` | `GameState.selected_seed_id` (int, -1=none) | Unified selection state |
| `FileUtils.readFile()` / `writeFile()` | `SaveManager.save()` / `load()` | JSON to `user://save.json` |
| `UserWin` (auth) | `LoginScene` + `RegisterScene` | Godot scenes, no interface |
| `FaceHelper` (static HUD updater) | Signals from `GameState` autoload | `money_changed`, `exp_changed` |
| `GameHelper.addLandItem()` | `FarmScene` child nodes | 6 `FarmPlot` scene instances |
| `MessageDialogHelper.showMessageDialog()` | `UIManager.show_dialog()` or `AcceptDialog` node | Native Godot dialog |
| `JOptionPane.showMessageDialog()` | `AcceptDialog` / `UIManager` | Same as above |
| `HFguiHelper.jar` interfaces (all) | Godot Signals + Node methods | Entire jar is replaced |
| Properties files (`cron.properties`) | Godot Resources (`CropDefinition.tres`) | Type-safe, editor-visible |
| Flat text files (`_land.txt` etc.) | Single JSON save file (`user://save.json`) | Versioned schema |
| Multi-user local list | Single-player only (v1) | Multi-user was a demo feature |

---

## 2. Class-by-Class Mapping

### `CropBean` → `CropDefinition` (Resource)

```
Java CropBean field          →  GDScript CropDefinition field
─────────────────────────────────────────────────────────────
cropId (int)                 →  crop_id: int
cropName (String)            →  display_name: String
stage (int)                  →  stage_count: int
allStageTime (List<Integer>) →  stage_durations: Array[float]  (seconds, not ms)
allStagePic (List<String>)   →  stage_textures: Array[Texture2D]
seedPic (String)             →  seed_texture: Texture2D
beginPic (String)            →  planted_texture: Texture2D
endPic (String)              →  harvested_texture: Texture2D
price (int)                  →  seed_price: int
sellPrice (int)              →  sell_price: int
buyLevel (int)               →  required_level: int
current (int, mutable)       →  (REMOVED — moved to FarmPlotState)
```

`CropDefinition` extends `Resource`. Instances are `.tres` files in `res://data/crops/`.  
`stage_durations` stores seconds (float) not milliseconds — cleaner for designers.

---

### `LandItemBean` (data) → `FarmPlotState` (plain class / Dictionary)

```
Java LandItemBean field      →  GDScript FarmPlotState field
─────────────────────────────────────────────────────────────
landId (int)                 →  plot_index: int  (0-based internally, displayed as 1-6)
cropBean (CropBean | null)   →  crop_id: int     (-1 = empty)
beginTime (Date | null)      →  plant_timestamp: float  (Unix epoch seconds, 0.0 = empty)
count (int, yield)           →  yield_count: int  (0 = empty)
pickCount (int)              →  steals_remaining: int  (3 when planted, 0 when empty)
zhaiqufalg (boolean)         →  (REMOVED — derived from context)
cropGrowThread               →  (REMOVED — no thread needed)
```

`FarmPlotState` is a lightweight data object used inside `SaveData`. It has no methods — all logic lives in `FarmPlot` node or `CropGrowthSystem`.

**Current stage** is always computed on demand:
```gdscript
func compute_stage(state: FarmPlotState, def: CropDefinition) -> int:
    if state.plant_timestamp == 0.0:
        return -1
    var elapsed := Time.get_unix_time_from_system() - state.plant_timestamp
    var cumulative := 0.0
    for i in def.stage_count:
        cumulative += def.stage_durations[i]
        if elapsed < cumulative:
            return i
    return def.stage_count - 1  # fully mature
```

---

### `LandItemBean` (actions) → `FarmPlot` (Node2D scene)

```
Java LandItemBean method     →  GDScript FarmPlot method / signal
─────────────────────────────────────────────────────────────────
plantAction()                →  attempt_plant(crop_id: int) → emits crop_planted
pickAction()  (own)          →  attempt_harvest() → emits crop_harvested
pickAction()  (steal)        →  attempt_steal() → emits crop_stolen / steal_failed
uprootAction()               →  attempt_uproot() → emits crop_uprooted
growing()                    →  (REMOVED — replaced by _process polling or Timer signal)
getCurrentpic()              →  CropVisual.update_visual(state, def) — visual node
```

---

### `CropGrowThread` → `_process()` or `GameClock` Timer

```
Java CropGrowThread          →  Godot equivalent
─────────────────────────────────────────────────
Thread per plot (×6+)        →  Single _process() in FarmScene
300ms poll interval          →  process delta accumulator or 1s Timer
growing() call               →  CropGrowthSystem.tick_all_plots()
goNextStage() mutation       →  (stage computed from timestamp, no mutation)
Thread.start() / stop()      →  (no lifecycle management needed)
```

---

### `GameMember` (static global state) → Autoloads

`GameMember` is split across two Autoloads:

**`GameState` Autoload:**
```
GameMember.loginUser         →  GameState.player_profile: Dictionary
GameMember.currentUser       →  GameState.viewing_user_id: int
GameMember.userData          →  GameState.player_stats: Dictionary  {exp, money}
GameMember.allcropBean       →  GameState.crop_definitions: Dictionary[int, CropDefinition]
GameMember.allUserPackages   →  GameState.inventory: Array[Dictionary]  [{crop_id, count}]
GameMember.allUserLand       →  GameState.farm_plots: Array[FarmPlotState]  (6 items)
GameMember.allUserStore      →  GameState.warehouse: Array[Dictionary]  [{crop_id, count}]
GameMember.mouseState        →  GameState.selected_seed_id: int  (-1 = none selected)
GameMember.selectdCropid     →  (merged into selected_seed_id)
GameMember.allUserPick       →  (not implemented in v1 — single player)
GameMember.allBackList       →  (not implemented in v1 — single player)
```

**`SaveManager` Autoload:**
```
FileUtils.readFile()         →  SaveManager.load_game() → loads user://save.json
FileUtils.writeFile()        →  SaveManager.save_game() → writes user://save.json
LandDAO.getUserLandBean()    →  SaveManager._deserialize_plots()
LandDAO.saveUserLand()       →  SaveManager._serialize_plots()
PackageDAO.getUserPackage()  →  SaveManager._deserialize_inventory()
StoreHouseDAO               →  SaveManager._deserialize_warehouse()
UserDateDao                 →  SaveManager._deserialize_stats()
UserDAO                     →  (single-player: no user DB)
```

---

### `UserWin` (auth) → `LoginScene` / `RegisterScene`

```
Java UserWin method          →  Godot scene / method
─────────────────────────────────────────────────────
loginCheckUser()             →  LoginScene._on_login_pressed()
registerUser()               →  RegisterScene._on_register_pressed()
changePassword()             →  ProfileScene._on_change_password()
changeUserInfo()             →  ProfileScene._on_save_profile()
getUserList()                →  (deferred to multi-user feature)
getUserFaceList()            →  AvatarPicker.get_available_avatars()
```

---

### `UserBean` → Save Schema `player_profile`

```
Java UserBean field          →  JSON save key
─────────────────────────────────────────────
userId (int)                 →  (removed — single player, implicit)
useName (String)             →  "username": String
password (String)            →  "password_hash": String  (bcrypt or SHA-256, not plaintext)
nickName (String)            →  "nickname": String
userModText (String)         →  "bio": String
pic (String path)            →  "avatar_id": int  (index into avatar array)
notice (String)              →  "notice": String
```

> **Security fix:** Legacy stores plaintext passwords. Godot version hashes with SHA-256 minimum.

---

### `UserData` → Save Schema `player_stats`

```
Java UserData field          →  JSON save key
─────────────────────────────────────────────
exp (int)                    →  "exp": int
money (int)                  →  "money": int
userid (int)                 →  (removed)
getUserLevel() = exp/100     →  GameState.get_level() → int  (computed property)
```

---

### Persistence Files → Single JSON Save

```
Legacy file                              →  JSON key in save.json
──────────────────────────────────────────────────────────────────
user/userbase.txt                        →  "profile" object
user/userdetails/{id}_data.txt           →  "stats" object
user/userdetail/{id}_land.txt            →  "plots" array
user/userdetail/{id}_package.txt         →  "inventory" array
user/userdetail/{id}_store.txt           →  "warehouse" array
user/userpick/{id}_pick.txt              →  (deferred to v2)
user/blacklist.txt                       →  (deferred to v2)
resources/crops/cronN/cron.properties    →  res://data/crops/crop_N.tres (CropDefinition)
```

**Save schema v1 (target):**
```json
{
  "save_version": 1,
  "profile": {
    "username": "player1",
    "password_hash": "sha256...",
    "nickname": "FarmerJoe",
    "bio": "...",
    "avatar_id": 3,
    "notice": "Welcome to my farm!"
  },
  "stats": { "exp": 150, "money": 500 },
  "plots": [
    { "plot_index": 0, "crop_id": 2, "plant_timestamp": 1722441399.0, "yield_count": 23, "steals_remaining": 3 },
    { "plot_index": 1, "crop_id": -1, "plant_timestamp": 0.0, "yield_count": 0, "steals_remaining": 0 }
  ],
  "inventory": [
    { "crop_id": 2, "count": 4 }
  ],
  "warehouse": [
    { "crop_id": 5, "count": 12 }
  ]
}
```

---

## 3. Signal Mapping (replacing HFguiHelper callbacks)

| Legacy callback mechanism | Godot Signal | Emitted by | Connected to |
|---|---|---|---|
| `FaceHelper.setExp(str)` | `GameState.exp_changed(new_exp)` | `GameState` | `HUDPanel` |
| `FaceHelper.setLevel(str)` | `GameState.level_changed(new_level)` | `GameState` | `HUDPanel` |
| `FaceHelper.setMoney(str)` | `GameState.money_changed(new_money)` | `GameState` | `HUDPanel` |
| `FaceHelper.setBoardText(str)` | `GameState.notice_changed(text)` | `GameState` | `FarmNoticeLabel` |
| `gameHelper.addLandItem()` | (scene tree instancing) | `FarmScene._ready()` | N/A |
| `gameHelper.setShopItemList()` | `GameState.shop_refreshed` | `GameState` | `ShopPanel` |
| `gameHelper.setPackageItemList()` | `GameState.inventory_changed` | `GameState` | `InventoryPanel` |
| `gameHelper.setStoreItemList()` | `GameState.warehouse_changed` | `GameState` | `WarehousePanel` |
| `LandItem.plantAction()` | `crop_planted(plot_index, crop_id)` | `FarmPlot` | `FarmScene`, `SaveManager` |
| `LandItem.pickAction()` | `crop_harvested(plot_index, crop_id, yield)` | `FarmPlot` | `FarmScene`, `GameState`, `SaveManager` |
| `LandItem.uprootAction()` | `crop_uprooted(plot_index)` | `FarmPlot` | `FarmScene`, `SaveManager` |
| `MessageDialogHelper.showMessageDialog()` | `UIManager.show_message(text)` | Any system | `UIManager` Autoload |

---

## 4. Anti-Pattern Fixes

| Legacy anti-pattern | Godot fix |
|---|---|
| `CropBean.current` — mutable definition mixed with state | Stage is computed from `plant_timestamp`; `CropDefinition` is immutable |
| Thread-per-plot (6+ threads) | Single `_process()` or 1-second `Timer` in `FarmScene` |
| Shared `CropBean` object for same crop type | `CropDefinition` is read-only resource; each plot stores only `crop_id` |
| `GameMember` everything-static god class | Split into `GameState` + `SaveManager` autoloads |
| Plaintext passwords in `userbase.txt` | SHA-256 hashed password stored in JSON |
| File write on every action | Debounced `SaveManager.request_save()` — writes at most once per second |
| No thread safety | No shared mutable state across threads (Godot is single-threaded by default) |
| Per-file persistence (7 different files per user) | Single `user://save.json` |
| Hard-coded `resources/crops/cronN/` path scan | `CropDefinition` resources preloaded into `CropRegistry` at startup |
| `buySeed()` doesn't deduct money | `buy_seed()` in `GameState` atomically deducts money AND adds inventory |
