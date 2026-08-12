# Legacy Analysis — hjl-happy-farm-project

**Source repository:** https://github.com/Hongjilin/hjl-happy-farm-project  
**Language:** Java SE (no version tag; approximately Java 8)  
**UI framework:** Swing/JFrame + HFguiHelper.jar (closed-source helper library)  
**Persistence:** Flat text files, Properties files for crop data  
**Threading:** One `java.lang.Thread` per planted plot

---

## 1. Feature Inventory

| Feature | Status in legacy | Notes |
|---|---|---|
| Login / Register | Fully implemented | `UserWin.loginCheckUser()` / `registerUser()` |
| Player profile (nickname, bio, avatar) | Fully implemented | `UserBean` fields; avatar = GIF from `resources/head/` |
| 6-plot farm per user | Fully implemented | Default 6 empty `LandItemBean` objects |
| Seed shop (buy seeds) | Fully implemented | `ShopItemBean.itemClick()` / `GameMember.buySeed()` |
| Planting | Fully implemented | `LandItemBean.plantAction()` |
| Crop growth (multi-stage, time-based) | Fully implemented | `CropGrowThread` + `LandItemBean.growing()` |
| Harvesting own crops | Fully implemented | `LandItemBean.pickAction()` — own farm path |
| Selling harvested crops | Fully implemented | `StoreHouseItemBean.doSellItem()` |
| Visit friend farms | Fully implemented | `currentUser` vs `loginUser` distinction |
| Steal crops from friends | Fully implemented | `pickAction()` — visitor path with random success |
| Steal detection & blacklist | Fully implemented | `userpick`, `BlackListBean`, blacklist TTL 1 hour |
| Uproot (remove) crops | Fully implemented | `LandItemBean.uprootAction()` |
| EXP / Level system | Fully implemented | `UserData.exp`; level = exp / 100 |
| Money (coins) system | Fully implemented | `UserData.money`; deducted on buy, added on sell |
| Change password | Fully implemented | `UserWin.changePassword()` |
| Change profile info | Fully implemented | `UserWin.changeUserInfo()` |
| Background slideshow | Fully implemented | 5 background PNGs, `GameMember.loadBackGround()` |
| Multi-user listing | Fully implemented | `UserWin.getUserList()` — shows all users, own first |

---

## 2. Class-to-Feature Map

### Domain Beans (`com.zqsoft.bean`)

#### `CropBean`
- **Role:** Dual-purpose object — static crop definition AND runtime stage counter
- **Key fields:**
  - `cropId` (int) — 1–16
  - `cropName` (String)
  - `stage` (int) — total growth stages
  - `allStagePic` (List\<String>) — image path per growth stage
  - `allStageTime` (List\<Integer>) — milliseconds per stage
  - `seedPic`, `beginPic`, `endPic` — special state images
  - `price` (int) — buy price
  - `sellPrice` (int) — sell price
  - `buyLevel` (int) — minimum player level to purchase
  - `current` (int, mutable) — current growth stage counter
- **Anti-pattern:** Mixes static definition data with mutable runtime state (`current`). In Godot, these are split into `CropDefinition` (Resource) and `FarmPlotState`.

#### `LandItemBean` (540 lines — core class)
- **Role:** One farm plot. Contains crop reference, yield counter, timestamps, steal counter, and all gameplay actions.
- **Key fields:**
  - `cropBean` (CropBean | null) — null if plot is empty
  - `landId` (int, 1–6) — plot index
  - `count` (int) — harvestable yield, random(50) on plant
  - `beginTime` (Date) — timestamp when planted
  - `cropGrowThread` (CropGrowThread) — thread driving growth
  - `pickCount` (int, init 3) — steals remaining on this plot
  - `zhaiqufalg` (boolean) — harvest/steal mode flag
- **Persistence `toString()`:**
  - Planted: `"landId,cropId,count,beginTimeMillis\r\n"`
  - Empty: `"landId,,,\r\n"`
- **`plantAction()`:** Guard: plot empty + own farm only. Deducts seed from package. Sets `beginTime = new Date()`, `count = random(50)`. Saves land file. Starts `CropGrowThread`. +5 EXP.
- **`pickAction()`:** Own-farm harvest OR steal from friend. Steal: `random(1-10)` — if >5, silent steal; if ≤5, caught (-10 EXP to thief, unless EXP < 200). `pickCount` decrements; at 0 plot is cleared. Records steal in `userpick` file. +1 EXP on harvest; crop 16 gives +99 bonus EXP (easter egg).
- **`growing()`:** Called every 300ms by thread. Computes `cms >= bms + pms` (currentMs >= plantMs + cumulativeStageDurationMs). Advances stage via `cropBean.goNextStage()`.
- **`uprootAction()`:** Clears plot, +3 EXP, saves land file.

#### `UserBean`
- **Role:** Player account data.
- **Fields:** `userId` (int), `useName`, `password`, `nickName`, `userModText` (bio), `pic` (avatar path), `notice` (farm notice/announcement)
- **`toString()`:** Tab-separated display string (not used for persistence — DAO uses explicit field serialisation)
- **Persistence (UserDAO.saveUser):** `"userId;useName;password;nickName;userModText;pic;notice;\r\n"` in `user/userbase.txt`
- **`itemClick()`:** Sets `GameMember.currentUser = this`, reloads land (visits friend's farm)

#### `UserData`
- **Role:** Runtime game stats (separate from account data).
- **Fields:** `exp` (int), `money` (int), `userid` (int)
- **`getUserLevel()`:** `return (int) exp / 100` — level is derived, not stored
- **`toString()`:** `"userid;exp;money"` — written to `user/userdetails/{id}_data.txt`
- **New user defaults:** exp=100, money=200 (set in `registerUser`)

#### `PackageItemBean`
- **Role:** One seed stack in the player's inventory.
- **Fields:** `cropBean` (CropBean), `itemCount` (int)
- **`toString()`:** `"cropId:count"` — written to `user/userdetail/{id}_package.txt`

#### `StoreHouseItemBean`
- **Role:** One crop stack in the harvest warehouse.
- **Fields:** `cropBean` (CropBean), `count` (int)
- **`toString()`:** `"cropId:count"` — written to `user/userdetail/{id}_store.txt`
- **`doSellItem(money, count)`:** Deducts count from warehouse, adds money to `userData`.
- **`addCount(n)`:** Increments count.

#### `ShopItemBean`
- **Role:** Shop display wrapper around a `CropBean`.
- **`buyItem(count)`:** `cropBean.getPrice() * count` cost check.
- **`itemClick()`:** Checks `userData.getUserLevel() >= buyLevel`. On success calls `GameMember.buySeed()`.

### Frame / Controller (`com.zqsoft.frame`)

#### `GameMember` (global state hub)
- **Role:** Static singleton holding all in-memory application state.
- **Static fields:**
  - `loginUser` (UserBean) — authenticated player
  - `currentUser` (UserBean) — currently viewed farm owner (equals `loginUser` unless visiting a friend)
  - `userData` (UserData) — EXP/money/level for `loginUser`
  - `allcropBean` (List\<CropBean>) — all 16 crop definitions
  - `allUserPackages` (List\<PackageItem>) — loginUser's seed inventory
  - `allUserLand` (List\<LandItemBean>) — currentUser's land (6 plots)
  - `allUserStore` (List\<StoreHouseItem>) — loginUser's harvest warehouse
  - `allUserPick` (List\<userpick>) — steal log entries (used for blacklist logic)
  - `allBackList` (List\<BlackListBean>) — blacklist entries
  - `mouseState` (int, 0/1) — whether a seed is selected in inventory
  - `selectdCropid` (int) — currently selected seed's cropId
- **Key methods:**
  - `main()` — entry point: loads all data, starts UI
  - `loadUserLand()` — reads land from file, creates a `CropGrowThread` for EVERY plot (even empty ones!)
  - `loadShop()` — loads + sorts crop defs, passes to `gameHelper.setShopItemList()`
  - `buySeed(crop, count)` — merges into package, writes file
  - `subPackage(id)` — decrements seed count by 1
  - `reflashUserMoney()` — pushes money value to UI via `FaceHelper`
  - `loadUserData()` — pushes EXP/level/money/notice to UI via `FaceHelper`

#### `UserWin`
- **Role:** Implements `UserWindow` interface (from HFguiHelper). Handles auth + profile.
- **`loginCheckUser()`:** Validates format, checks credentials, sets `GameMember.loginUser/userData/currentUser/allUserPick/allBackList`.
- **`registerUser()`:** Validates format + uniqueness, generates ID via `NewID`, creates all user files (land, package, store, pick).
- **`getUserList()`:** Returns all users with loginUser first (for friend panel).
- **`getUserFaceList()`:** Lists all files in the current user's avatar directory.

### DAOs (`com.zqsoft.dao`)

#### `CropDAO`
- Reads `resources/crops/cronN/cron.properties` for each of 16 crop directories.
- Properties keys: `ITEM_ID`, `ITEM_NAME`, `ITEM_SEED_PIC`, `ITEM_STAGE`, `ITEM_SELL_MONEY`, `ITEM_PRICE`, `ITEM_NEED_LEVEL`, `ITEM_STAGE_1..N` (image filenames), `ITEM_STAGE_NEXT_TIME_1..N` (seconds, converted to ms via ×1000).

#### `LandDAO`
- **Read:** Parses `user/userland/{id}_land.txt` — CSV per line: `landId,cropId,count,beginMs`. If file empty → 6 blank plots.
- **Write:** `saveUserLand()` / `updateUserLand()` — iterate all plots, write `toString()` to file.

#### `UserDAO`
- **Read:** Parses `user/userbase.txt` — semicolon-delimited per line.
- **Write:** `saveUser()` — rebuilds entire file from all-user list.

#### `UserDateDao`
- **Read:** `user/userdetails/{id}_data.txt` — single line: `userid;exp;money`. Default exp=0, money=200 if file missing.
- **Write:** `updateUserData(data)` — overwrites file with `data.toString()`.

#### `PackageDAO`
- **Read:** `user/userdetail/{id}_package.txt` — lines of `cropId:count`.
- **Write:** `saveUserPackage()` — joins all entries with `\r\n`.

#### `StoreHouseDAO`
- **Read:** `user/userdetail/{id}_store.txt` — lines of `cropId:count`.
- **Write:** `updateUserStore()` — writes all entries.

### Threading (`com.zqsoft.thread`)

#### `CropGrowThread`
- Runs in a `while(true)` loop sleeping 300ms each iteration.
- Calls `landItem.growing()` on each wake.
- `growing()` itself does: compute `cms >= bms + pms`, if true call `cropBean.goNextStage()`.
- **Critical bug:** `loadUserLand()` starts a thread for EVERY land item including empty plots. Empty plots' threads call `growing()` which checks `cropBean == null` — the null check guards against NPE, but threads are never stopped when crop is harvested/uprooted.
- **One thread per plot:** 6 plots = minimum 6 threads. Visiting a friend's farm creates 6 more.

---

## 3. Persistence File Layout

```
user/
  userbase.txt                    — all accounts: "id;name;pwd;nick;bio;pic;notice;\r\n" per line
  blacklist.txt                   — steal blacklist: "passUserId:userId:pickTimeMs\r\n" per entry
  userland/{id}_land.txt          — land: "landId,cropId,count,beginMs\r\n" or "landId,,,\r\n"
  userdetail/{id}_package.txt     — seeds: "cropId:count\r\n" per entry
  userdetail/{id}_store.txt       — harvested: "cropId:count\r\n" per entry
  userdetails/{id}_data.txt       — stats: "userid;exp;money" (single line, note: 'details' vs 'detail')
  userpick/{id}_pick.txt          — steal log: "stealerUserId:timestampMs\r\n" per entry
```

> **Note:** There is a directory naming inconsistency in the original: package/store are under `userdetail/` (no trailing s) while stats are under `userdetails/` (with trailing s). Both exist.

### Sample data files found in repo

`user/userland/9213728_land.txt`:
```
6,,,
5,,,
3,,,
4,,,
1,2,0,1597940113321
2,4,34,1597940107892
```
(Plots 1 and 2 are planted with crops 2 and 4; plots 3–6 are empty.)

`user/userdetail/29790997_package.txt`:
```
2:1
```
(One seed of crop 2.)

---

## 4. Crop Growth Mechanism (Deep Analysis)

```
Growing condition:
  cms = System.currentTimeMillis()     // wall-clock now
  bms = this.beginTime.getTime()       // plant timestamp (epoch ms)
  pms = cropBean.getStageMillsTime(i)  // cumulative ms from stage 0 → stage i

  Advance when: cms >= bms + pms
```

`getStageMillsTime(i)` returns the **sum** of `allStageTime[0..i]` — it is cumulative, not per-stage. So a crop with 3 stages and times [5000, 10000, 15000] ms will:
- Advance to stage 1 at T+5s
- Advance to stage 2 at T+15s  
- Advance to stage 3 (mature) at T+30s

**Maturity check:** `current >= stage - 1` — crop is ready when it has completed all but the final stage transition.

**Key insight for migration:** The growth is already deterministic by timestamp. The polling thread exists only to _detect_ when the threshold is crossed. In Godot, no timer or thread is needed — stage can be computed on demand from `(Time.get_unix_time_from_system() - plant_timestamp)` vs the cumulative stage durations array. This is both simpler and more correct (no drift from missed polls).

---

## 5. Steal / Social System

- A visitor (`loginUser != currentUser`) can call `pickAction()` on another user's plots.
- `pickCount = 3` per plot — max 3 steals per plot.
- Each steal attempt: `random(1-10)`. If >5: steal succeeds silently. If ≤5: caught (thief loses 10 EXP, unless EXP ≤ 200 in which case penalty is waived).
- Steal is logged to the plot owner's `userpick` file (who stole and when).
- Steal entries older than 1 hour (3,600,000ms) are pruned.
- If pickCount reaches 0 or count reaches 0, plot is cleared.
- Blacklist entries older than 1 hour are pruned on `pickAction()` start.
- Blacklist logic: if a user is on the `allBackList` (they previously stole from loginUser), removing them from blacklist and re-adding steals. The blacklist is a bi-directional mutual exclusion list.

---

## 6. HFguiHelper.jar — Dependency Analysis

This closed-source JAR provides the UI framework. All we can determine is from how implementing classes use the interfaces:

| Interface / Helper | Implementing class | Inferred contract |
|---|---|---|
| `LandItem` | `LandItemBean` | `plantAction()`, `pickAction()`, `uprootAction()`, `getLandId()`, `getCropBean()`, `getCurrentPic()` |
| `ShopItem` | `ShopItemBean` | `itemClick()`, `buyItem(count)`, `getItemName()`, `getPrice()` |
| `StoreHouseItem` | `StoreHouseItemBean` | `itemClick()`, `doSellItem(money, count)`, `getItemName()`, `getItemCount()`, `addCount(n)`, `toString()` |
| `PackageItem` | `PackageItemBean` | `itemClick()`, `getItemName()`, `getItemCount()`, `setItemCount(delta)`, `toString()` |
| `UserItem` | `UserBean` | `itemClick()`, `getUserName()`, `getUserModText()`, `getPic()` |
| `UserWindow` | `UserWin` | `loginCheckUser()`, `registerUser()`, `changePassword()`, `changeUserInfo()`, `getUserList()`, `getUserFaceList()` |
| `FaceHelper` (static) | — | `setExp(String)`, `setLevel(String)`, `setMoney(String)`, `setBoardText(String)` — updates HUD labels |
| `GameHelper` (static) | — | `loadMod(UserWindow)`, `setShopItemList(List)`, `setPackageItemList(List)`, `setStoreItemList(List)`, `setBackground(List<String>)`, `addLandItem(int, LandItem)` |
| `MessageDialogHelper` (static) | — | `showMessageDialog(msg, title)`, `showConfirmDialog(msg, title)` |

**Conclusion:** The entire UI layer must be replaced. None of these interfaces survive into Godot. Godot scenes, nodes, and signals replace every callback mechanism.

---

## 7. Known Bugs & Design Flaws (to fix in migration)

1. **Thread leak:** `loadUserLand()` starts a `CropGrowThread` for every plot including empty ones. Threads are never stopped on harvest/uproot — they run forever.
2. **Mutable CropBean shared by all:** The `current` field on `CropBean` is shared state — if two land items have the same crop type, advancing one advances the global `CropBean`, corrupting all other plots with that crop type. This is a critical bug partially hidden by the fact that the game was single-player and likely only one plot per crop type existed.
3. **No thread safety:** All global state in `GameMember` is accessed from multiple threads without synchronisation.
4. **File writes on every action:** Every plant, pick, buy writes the entire file — no batching or transactions.
5. **Directory inconsistency:** `userdetail/` vs `userdetails/` (the stats file uses a different folder name than the others).
6. **`buySeed()` does not deduct money:** The `buySeed()` method adds seeds to the package and writes the file, but contains a commented-out line `// userData.setMoney(money)` — money deduction was never implemented for buying seeds.
7. **Level gating not enforced:** `ShopItemBean.itemClick()` checks `buyLevel` but the shop list is populated without filtering, so the UI can display locked crops even if the click is blocked.
