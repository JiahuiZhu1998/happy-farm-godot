# Happy Farm

**Happy Farm** is a cozy 2D farming game built as a faithful Godot 4.7 remake of
the classic `hjl-happy-farm-project`. Plant seeds, watch your crops grow in real
time, harvest them, and sell your produce to grow your farm.

> This is an independent Godot remake of the original Java project. Third-party
> artwork is used with attribution and is NOT covered by the code license. See
> [Asset Attribution](#asset-attribution) and [LICENSE](LICENSE).

## Features

- Full farming gameplay loop: register/login then select seed, plant, grow, harvest, warehouse, sell
- 16 unique crops, each with a four-stage growth visual
- Timestamp-based crop growth system (no per-plot timers)
- Shop, inventory, and warehouse panels
- Persistent save system (`user://save.json`)
- Level/EXP progression that unlocks higher-tier crops
- Cohesive, hand-tuned farm theme and UI polish

## Screenshots

> Screenshots coming soon. Add gameplay captures under `docs/screenshots/` and
> link them here.

| Screen    | Description                                              |
|-----------|----------------------------------------------------------|
| Farm      | Six plots with a HUD showing level, coins, seed selected |
| Shop      | Buy seeds; locked crops shown with their level gate      |
| Inventory | Owned seeds with a clear selected-seed highlight         |
| Warehouse | Harvested crops ready to sell for coins                  |

## Requirements

- **Godot Engine 4.7.1 (stable)** -- required to open and run the project
- Desktop OS: Windows, macOS, or Linux
- No external runtime dependencies

## How to Run from Source

1. Install [Godot 4.7.1](https://godotengine.org/download/).
2. Open Godot and **Import** this repository (select `godot/project.godot`).
3. Press **F5** (or click *Run Project*) to launch.

The game boots into a login/register screen. Create an account on first run; your
progress is saved locally afterwards.

## Controls

| Action                        | Input                                    |
|-------------------------------|------------------------------------------|
| Plant seed (empty plot)       | Left click, with a seed selected         |
| Harvest (mature plot)         | Left click                               |
| Uproot a crop                 | Right click                              |
| Open Shop / Inventory / Warehouse | HUD buttons                          |
| Close panel / deselect seed   | `Esc`                                    |

## Save Location

Game progress is stored at:

```
user://save.json
```

`user://` resolves to the OS-specific user data directory, for example:

- Windows: `%APPDATA%\Godot\app_userdata\Happy Farm\save.json`
- macOS:   `~/Library/Application Support/Godot/app_userdata/Happy Farm/save.json`
- Linux:   `~/.local/share/godot/app_userdata/Happy Farm/save.json`

## Development Status

Happy Farm **v0.1.0** -- the initial public release of the Godot remake. The core
gameplay loop, economy, and persistence are complete and playable. See
[CHANGELOG.md](CHANGELOG.md) for details.

## Asset Attribution

The crop, background, land, and avatar artwork is derived from
[`hjl-happy-farm-project`](https://github.com/Hongjilin/hjl-happy-farm-project)
by Hongjilin. The original license for those assets is **not verified**; they are
used here with attribution and are **not** covered by this repository's code
license. See [LICENSE](LICENSE) for the full terms.

## Links

- Internal development and architecture notes: [`docs/`](docs/)
  (`ARCHITECTURE.md`, `ASSET_INVENTORY.md`, `MIGRATION_MAP.md`,
  `LEGACY_ANALYSIS.md`, `IMPLEMENTATION_ROADMAP.md`)
- License: [LICENSE](LICENSE)
- Changelog: [CHANGELOG.md](CHANGELOG.md)