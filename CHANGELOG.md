# Changelog

All notable changes to Happy Farm are documented in this file.

## v0.1.0

Initial public release of the Godot 4.7.1 remake of the classic Happy Farm.

### Added

- **Godot remake** of the original `hjl-happy-farm-project`, rebuilt in typed GDScript
  with a clean data / behavior / presentation architecture.
- **Farming gameplay loop**: register/login, select a seed, plant, watch crops
  grow, harvest, store in the warehouse, and sell for coins -- fully playable end to end.
- **16 crops** (Carrot, Sunflower, and more through Dragon Fruit) with real
  four-stage growth artwork and per-crop pricing.
- **Crop growth system**: timestamp-based stage computation with no per-plot
  timers, plus a clear READY indicator when a crop can be harvested.
- **Shop / Inventory / Warehouse**: buy seeds (level-gated), manage owned seeds
  with a selected-seed highlight, and sell harvested crops for coins.
- **Save system**: versioned JSON save at `user://save.json` with forward
  migration support; EXP/level, coins, plots, inventory, and warehouse all persist.
- **UI polish**: cohesive farm theme, live HUD (level / EXP / coins / selected
  seed), locked-crop display, dialog feedback, and `Esc` to close panels or
  deselect the current seed.

### Notes

- Artwork is derived from the upstream `hjl-happy-farm-project` and is used with
  attribution; see [LICENSE](LICENSE) for asset terms.
- Known limitation: player avatar art from the upstream project is not yet wired
  into the UI in this release.
