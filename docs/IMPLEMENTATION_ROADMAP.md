# Implementation Roadmap — Happy Farm (Godot 4.7.1)

## Overview

This roadmap organises work into four sequential phases. Each phase has a clear acceptance gate before the next begins. Complexity ratings (S/M/L/XL) reflect both code volume and architectural risk.

---

## Phase 1 — Project Skeleton (DONE)

**Goal:** A Godot project that opens, boots, and routes correctly with no runtime errors.

| Task | Complexity | Status |
|------|-----------|--------|
| `godot/project.godot` configured (autoloads, main scene, viewport) | S | ✅ |
| Domain layer: `CropDefinition`, `FarmPlotState`, `SaveData`, `CropGrowthSystem` | M | ✅ |
| Autoloads: `GameState`, `SaveManager` | L | ✅ |
| Boot scene: loads crop defs, routes login/farm | S | ✅ |
| Login scene: validates credentials, SHA-256 check | S | ✅ |
| Register scene: creates new save | S | ✅ |
| All `.tscn` scene files (skeleton nodes) | M | ✅ |

**Acceptance gate:** Project opens in Godot 4.7.1 with no parse errors; boot routes to login.

---

## Phase 2 — Core Gameplay Loop (Next Priority)

**Goal:** A player can plant, watch crops grow, and harvest on the farm screen.

| Task | Complexity | Owner |
|------|-----------|-------|
| Assign real `RectangleShape2D` to each FarmPlot's `CollisionShape2D` | S | GLM |
| `CropVisual.update_visual()` displays correct stage textures | M | GLM |
| `FarmPlot._on_area_input_event()` left/right click routing works | M | GLM |
| `FarmScene` instantiates + positions 6 plots correctly | S | GLM |
| `GrowthTimer` → per-second visual refresh | S | GLM |
| Inventory panel: select seed highlights plot cursor | M | GLM |
| HUD labels update live from `GameState` signals | S | GLM |
| 16 placeholder `crop_N.tres` resource files loaded by Boot | S | GLM |

**Acceptance gate:** Player can log in, plant one seed, wait for growth stages, harvest, and see money/EXP update in HUD.

---

## Phase 3 — Economy & Polish

**Goal:** Shop, Inventory, Warehouse fully functional; game is completable.

| Task | Complexity | Owner |
|------|-----------|-------|
| Shop panel: buy seeds, level gating enforced | M | GLM |
| Warehouse panel: sell all / sell selected | M | GLM |
| Win condition: check `total_harvests >= win_threshold` after each harvest | S | GLM |
| Background texture assigned in `farm.tscn` | S | GLM |
| Land/plot tile textures assigned per `FarmPlot` | S | GLM |
| Avatar display on HUD (crop‐dependent or static) | M | GLM |
| Sound effects (plant, harvest, buy) — placeholder AudioStreamPlayer | M | GLM |
| Scene transitions: fade animator | M | GLM |
| Keyboard shortcut: Esc deselects seed | S | GLM |

**Acceptance gate:** All shop/inventory/warehouse flows work end-to-end; a session from register → buy seed → plant → harvest → sell completes without errors.

---

## Phase 4 — Real Assets & Data

**Goal:** Replace placeholder textures and data with the actual legacy assets.

| Task | Complexity | Owner |
|------|-----------|-------|
| Convert ~40 avatar GIFs to PNG (ImageMagick batch) | S | Human |
| Import all 16 × 8-stage PNG strips into Godot | M | Human |
| Populate 16 real `crop_N.tres` with correct `stage_durations`, prices, textures | L | GLM |
| Assign background textures from legacy repo | S | GLM |
| Tune grow times to match original `cron.properties` values | S | GLM |
| Final QA pass: all 16 crops plant/grow/harvest correctly | M | Human + GLM |

**Acceptance gate:** Game is visually identical to the legacy Java version for all 16 crops.

---

## Out-of-Scope for v1

These features existed in the legacy Java game but are explicitly excluded from this Godot v1:

- Multi-user / friend system
- Steal mechanic (`steals_remaining` field preserved in save schema for future use)
- Server-side persistence
- Leaderboard / ranking
- Chat / messaging

---

## Key Technical Constraints (All Phases)

1. **No C#.** All scripts are typed GDScript.
2. **Domain layer is frozen after Phase 1.** `domain/` files must not be modified by UI work.
3. **Save schema version = 1.** Any addition requires bumping `CURRENT_VERSION` and adding a migration in `save_manager.gd`.
4. **No threads.** All growth computation is pure math over Unix timestamps (`Time.get_unix_time_from_system()`).
5. **Autoload count stays at 2.** `GameState` and `SaveManager` only; no new autoloads without architectural review.
