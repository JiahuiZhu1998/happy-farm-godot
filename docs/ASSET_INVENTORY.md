# Asset Inventory — hjl-happy-farm-project

All assets sourced from: https://github.com/Hongjilin/hjl-happy-farm-project/tree/master/HappyFarm/resources

---

## 1. Crop Assets

16 crop types, each in `resources/crops/cronN/` (N = 1–16).

### Per-crop file structure

| File | Purpose | Format | Est. size | Godot action |
|---|---|---|---|---|
| `seed.png` | Seed icon (shop + inventory) | PNG | 3–8 KB | Import directly |
| `cron_start.png` | Freshly planted state | PNG | 3–8 KB | Import directly |
| `cron_end.png` | Harvested / empty plot state | PNG | 3–8 KB | Import directly |
| `1.png` | Growth stage 1 | PNG | 5–12 KB | Import directly |
| `2.png` | Growth stage 2 | PNG | 5–15 KB | Import directly |
| `3.png` | Growth stage 3 | PNG | 5–15 KB | Import directly |
| `4.png` | Growth stage 4 (if exists) | PNG | 5–15 KB | Import directly |
| `5.png` | Growth stage 5 (if exists) | PNG | 5–15 KB | Import directly |
| `cron.properties` | Crop definition data | Java Properties | 1 KB | **Convert to .tres** |
| `cron.txt` | Alternate data file (some crops) | Text | 1 KB | **Convert to .tres** |
| `Thumbs.db` | Windows thumbnail cache | Binary | varies | **Discard** |

### Crop list

| Crop ID | Folder | Known name | Stage count (approx.) | Notes |
|---|---|---|---|---|
| 1 | `cron1` | Unknown | 3–5 | Properties file present |
| 2 | `cron2` | Unknown | 3–5 | |
| 3 | `cron3` | Unknown | 3–5 | |
| 4 | `cron4` | Unknown | 3–5 | |
| 5 | `cron5` | Unknown | 3–5 | |
| 6 | `cron6` | Unknown | 3–5 | |
| 7 | `cron7` | Unknown | 3–5 | |
| 8 | `cron8` | Unknown | 3–5 | |
| 9 | `cron9` | Unknown | 3–5 | Referenced in test code |
| 10 | `cron10` | Unknown | 3–5 | |
| 11 | `cron11` | Unknown | 3–5 | |
| 12 | `cron12` | Unknown | 3–5 | |
| 13 | `cron13` | Unknown | 3–5 | |
| 14 | `cron14` | Unknown | 3–5 | |
| 15 | `cron15` | Unknown | 3–5 | |
| 16 | `cron16` | Unknown | 3–5 | **Easter egg:** harvesting gives +99 EXP |

> Exact crop names are in the `cron.properties` files (`ITEM_NAME` property). These must be read during migration to populate `CropDefinition.display_name`.

### Total crop PNG count (estimate)
- 16 crops × ~8 images (seed + start + end + up to 5 stages) = **~128 PNG files**
- All PNG, small sizes (3–26 KB each) — no conversion required

---

## 2. Background Assets

Path: `resources/background/`

| File | Size | Purpose | Godot action |
|---|---|---|---|
| `1.png` | ~193 KB | Background variant 1 | Import directly |
| `2.png` | ~300 KB | Background variant 2 | Import directly |
| `3.png` | ~400 KB | Background variant 3 | Import directly |
| `4.png` | ~600 KB | Background variant 4 | Import directly |
| `5.png` | ~915 KB | Background variant 5 | Import directly |

5 background images. Legacy code cycles through all 5 via `gameHelper.setBackground(list)`. In Godot these are assigned to a `TextureRect` or `Sprite2D` node; scene transition or `AnimationPlayer` handles cycling.

**Resolution:** Unknown from metadata, but file sizes suggest full-window backgrounds (likely 800×600 or 1024×768 given the era). Import with lossless compression or as-is.

---

## 3. Land / Plot Assets

Path: `resources/land/`

| File | Size | Purpose | Godot action |
|---|---|---|---|
| `1.png` | ~25 KB | Plot state 1 (empty) | Import directly |
| `2.png` | ~28 KB | Plot state 2 | Import directly |
| `3.png` | ~30 KB | Plot state 3 | Import directly |
| `4.png` | ~32 KB | Plot state 4 | Import directly |
| `5.png` | ~35 KB | Plot state 5 | Import directly |

5 land/plot tiles. Likely represent different soil states (dry, tilled, wet, etc.) or seasonal variants. These are used as the background of individual `FarmPlot` nodes.

---

## 4. Player Avatar Assets

Path: `resources/head/`

| Pattern | Count | Format | Purpose | Godot action |
|---|---|---|---|---|
| `N.GIF` | ~20 | GIF | Normal avatar state | **Convert to PNG** |
| `N-1.GIF` | ~20 | GIF | Highlighted/selected avatar state | **Convert to PNG** |

~40 total GIF files. Two variants per avatar number:
- `N.GIF` — standard display
- `N-1.GIF` — highlighted (used in `UserWin.changeUserInfo()` example: `resources/head/20-1.GIF`)

**GIF conversion required.** GDScript cannot load GIF files natively (Godot 4 supports PNG, JPG, WebP, SVG, BMP, TGA, EXR, HDR). Convert all GIFs to PNG using ImageMagick or similar:

```bash
# Convert all GIF avatars to PNG (run from repo root)
for f in HappyFarm/resources/head/*.GIF; do
    convert "$f" "${f%.GIF}.png"
done
```

After conversion, avatar references in save data should use `avatar_id: int` (1–20) rather than file paths. The `AvatarRegistry` autoload maps IDs to texture paths.

**Note on animated GIFs:** It is possible some GIFs are single-frame (static). If any are truly animated (blinking, etc.), they can be converted to `AnimatedTexture` in Godot or replaced with a simple idle animation. Inspect each before committing to a pipeline.

---

## 5. Demo / Documentation Assets (non-game)

Path: `tools/`

| File | Format | Purpose | Godot action |
|---|---|---|---|
| `展示图/*.gif` | GIF | Gameplay demo screen recordings | **Discard from game build** |
| `开心农场思维导图.png` | PNG | Original mind map of game design | Keep as reference only |
| `项目大致效果展示.pptx` | PowerPoint | Project presentation slides | Keep as reference only |

These are developer/documentation assets. Do not copy to the Godot project.

---

## 6. Asset Migration Checklist

### Required conversions

| Task | Priority | Tool |
|---|---|---|
| Convert `resources/head/*.GIF` → PNG | High | ImageMagick `convert` |
| Parse all `cron.properties` → `CropDefinition.tres` | High | Migration script |
| Verify stage count per crop (ITEM_STAGE value) | High | Manual check during .tres creation |

### Copy-as-is (no conversion)

| Source path | Destination in Godot project |
|---|---|
| `resources/crops/cronN/*.png` | `res://assets/crops/crop_N/` |
| `resources/background/*.png` | `res://assets/backgrounds/` |
| `resources/land/*.png` | `res://assets/land/` |
| `resources/head/*.png` (after conversion) | `res://assets/avatars/` |

### Discard

- All `Thumbs.db` files
- All `tools/` directory contents
- `cron.txt` files (superseded by `cron.properties`)
- Original `.GIF` files (after PNG conversion is verified)

---

## 7. Godot Import Settings Recommendations

| Asset type | Compress mode | Mipmaps | Filter | Notes |
|---|---|---|---|---|
| Crop stage PNGs (small sprites) | Lossless | Off | Nearest | Pixel art style — no bilinear blur |
| Background PNGs (large) | Lossy (WebP) | Off | Linear | OK to compress; quality 85% |
| Land tiles | Lossless | Off | Nearest | Pixel art style |
| Avatar PNGs | Lossless | Off | Linear | Small, keep crisp |

---

## 8. Summary Counts

| Category | Count | Format | Conversion needed |
|---|---|---|---|
| Crop stage images | ~128 | PNG | No |
| Crop seed images | 16 | PNG | No |
| Crop start/end images | ~32 | PNG | No |
| Background images | 5 | PNG | No |
| Land/plot tiles | 5 | PNG | No |
| Player avatars | ~40 | GIF | **Yes → PNG** |
| Crop data files | 16 | Properties | **Yes → .tres** |
| **Total game assets** | **~242** | mixed | 56 need conversion |
