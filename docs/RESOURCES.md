# Resource Documentation

This document provides a complete inventory of all game resources including stages, memories, skills, and cutscenes across all game modes (test, trial, and full).

---

## Resource Overview

All game data is stored as Godot `.tres` resource files in the `resources/` directory, organized by type:

- **`resources/stages/`** - Game progression stages (by mode: `test/`, `trial/`, `full/`)
- **`resources/memories/`** - Memory shards (collectible lore items)
- **`resources/memories/orders/`** - Memory display order per mode
- **`resources/skills/`** - Player abilities and skills
- **`resources/cutscenes/`** - Dialogue and narrative sequences
- **`resources/data_structures/`** - GDScript class definitions

Resource loading is handled by `ProgressManager._load_resources()` which recursively loads all `.tres` files from a given directory.

---

## Game Modes

The project supports three distinct game modes, each with its own progression pipeline:

| Mode | Path | Description | Default Mode |
|------|------|-------------|:-:|
| **test** | `resources/stages/test/` | Quick testing and prototyping | ✓ Yes |
| **trial** | `resources/stages/trial/` | Balanced gameplay experience | - |
| **full** | `resources/stages/full/` | Complete narrative experience | - |

The active mode is set in `ProgressManager.gd`:
```gdscript
var mode: String = "test"  # Change to "trial" or "full" to switch modes
```

---

## Stages by Mode

### Test Mode (`resources/stages/test/`)

Stages are automatically triggered when `current_exp >= req_exp`. Listed in progression order:
I plugged some random memory just to test it.

| Index | ID                  | req_exp | Name              | Unlocks Memory             | Triggers Cutscene       |
|-------|---------------------|---------|-------------------|----------------------------|-------------------------|
| 0     | `universal_startup` | 0       | 通用啟動          | `mem_test_shard`           | `startup_intro_cutscene` |
| 1     | `early_milestone`   | 10      | 早期里程碑          | `mem_mini_level`           | `mini_level`            |
| 2     | `tutorial`          | 20      | 教學引導          | `memory_tutorial_guidance` | `tutorial_stage_2`      |
| 3     | `end`               | 30      | 測試結束               | `mem_ending_trial`         | (none)                  |

**Testing Sequence:**
- Game starts at exp=0 → Stage 0 triggered
- Press start button → exp += 10 → Stage 1 triggered
- Gain 10 more exp → exp = 20 → Stage 2 triggered
- Gain 10 more exp → exp = 30 → Stage 3 triggered

---

### Trial Mode (`resources/stages/trial/`)

Balanced progression with more stages:

| Index | ID                      | req_exp | Name              | Unlocks Memory             | Triggers Cutscene       |
|-------|-------------------------|---------|-------------------|----------------------------|-------------------------|
| 0     | `universal_startup`     | 0       | 通用啟動          | `mem_test_shard`           | `startup_intro_cutscene` |
| 1     | `trial_early_milestone` | 100     | 早期里程碑          | `mem_mini_level`           | `mini_level`            |
| 2     | `trial_first_village`   | 200     | 第一座村莊          | `mem_first_village`        | `first_village`         |
| 3     | `trial_get_map`         | 300     | 取得地圖               | `mem_get_map`              | `get_map`               |
| 4     | `trial_open_world`      | 400     | 開放世界             | `mem_open_world`           | `open_world`            |
| 5     | `trial_human_territory` | 500     | 人類領地          | `mem_human_territory`      | `human_territory`       |
| 6     | `trial_human_capital`   | 600     | 人類王都          | `mem_human_capital`        | `human_capital`         |
| 7     | `trial_goblin_capital`  | 700     | 哥布林王都           | `mem_goblin_capital`       | `goblin_capital`        |
| 8     | `trial_ending`          | 800     | 試玩版結局            | `mem_ending_trial`         | `ending_trial`          |

---

### Full Mode (`resources/stages/full/`)

Complete narrative with extensive progression:

| Index | ID                     | req_exp | Name              | Unlocks Memory             | Triggers Cutscene       |
|-------|------------------------|---------|-------------------|----------------------------|-------------------------|
| 0     | `universal_startup`    | 0       | 通用啟動          | `mem_test_shard`           | `startup_intro_cutscene` |
| 1     | `full_early_milestone` | 100     | 早期里程碑          | `mem_mini_level`           | `mini_level`            |
| 2     | `full_first_village`   | 200     | 第一座村莊          | `mem_first_village`        | `first_village`         |
| 3     | `full_get_map`         | 400     | 取得地圖               | `mem_get_map`              | `get_map`               |
| 4     | `full_open_world`      | 500     | 開放世界             | `mem_open_world`           | `open_world`            |
| 5     | `full_human_territory` | 600     | 人類領地          | `mem_human_territory`      | `human_territory`       |
| 6     | `full_human_capital`   | 800     | 人類王都          | `mem_human_capital`        | `human_capital`         |
| 7     | `full_goblin_capital`  | 1000    | 哥布林王都           | `mem_goblin_capital`       | `goblin_capital`        |
| 8     | `full_attack_towns`    | 1200    | 進攻城鎮            | (none)                     | `attack_towns`          |
| 9     | `full_defeat_villages` | 1400    | 擊敗村莊          | (none)                     | `defeat_villages`       |
| 10    | `full_level_up_1`      | 1500    | 等級提升 1               | (none)                     | (none)                  |
| 11    | `full_level_up_2`      | 2000    | 等級提升 2               | (none)                     | (none)                  |
| 12    | `full_level_up_3`      | 2500    | 等級提升 3               | (none)                     | (none)                  |
| 13    | `full_level_up_4`      | 3000    | 等級提升 4               | (none)                     | (none)                  |
| 14    | `full_ending`          | 3500    | 完整版結局            | `mem_ending_full`          | `ending_full`           |

---

## Memories (Collectable Shards)

Memory shards appear as lit torch buttons in the Backpack UI once unlocked. Each memory has:
- **ID** - Unique string identifier
- **Name** - Display name in UI
- **Description** - Lore text shown to player
- **Cutscene ID** - Cutscene that plays when memory is viewed
- **Unlock Trigger** - Which stage unlocks this memory

### All Memory Shards

| Memory ID                  | Name                 | Description                                     | Cutscene                | Unlocked By Stage              |
|----------------------------|----------------------|-------------------------------------------------|-------------------------|--------------------------------|
| `mem_test_shard`           | Test Memory Shard    | A shard for testing purposes.                   | `startup_intro_cutscene` | `universal_startup` (exp 0)   |
| `mem_mini_level`           | Mini Level           | Memory of the mini level.                       | `mini_level`            | `early_milestone` (exp 10+)   |
| `memory_tutorial_guidance` | Echoes of Guidance   | Recollection of the initial lessons learned.    | `tutorial_stage_2`      | `tutorial` (test mode, exp 20+) |
| `mem_ending_trial`         | Ending Trial         | Memory from the trial ending.                   | `ending_trial`          | Various stages by mode        |
| `mem_first_village`        | First Village        | Memory of arriving at the first village.        | `first_village`         | `first_village` stage         |
| `mem_get_map`              | Get Map              | Memory of acquiring the map.                    | `get_map`               | `get_map` stage               |
| `mem_open_world`           | Open World           | Memory of discovering the open world.           | `open_world`            | `open_world` stage            |
| `mem_human_territory`      | Human Territory      | Memory of human territory.                      | `human_territory`       | `human_territory` stage       |
| `mem_human_capital`        | Human Capital        | Memory of the human capital.                    | `human_capital`         | `human_capital` stage         |
| `mem_goblin_capital`       | Goblin Capital       | Memory of the goblin capital.                   | `goblin_capital`        | `goblin_capital` stage        |
| `mem_ending_full`          | Ending Full          | Memory from the full game ending.               | `ending_full`           | `ending` stage (full mode only) |
| `memory_stage_start`       | Startup              | Initial startup memory.                         | (none)                  | (possibly unused)             |

---

## Memory Display Order

Memory shards appear in the Backpack UI in a specific order defined by `MemoryOrder` resources. Each game mode has its own order file:

### Test Mode Order (`test_memory_order.tres`)
```
1. mem_test_shard
2. mem_mini_level
3. mem_tutorial_guidance
4. mem_ending_trial
```

### Trial Mode Order (`trial_memory_order.tres`)
```
1. mem_test_shard
2. mem_mini_level
3. mem_first_village
4. mem_get_map
5. mem_open_world
6. mem_human_territory
7. mem_human_capital
8. mem_goblin_capital
9. mem_ending_trial
```

### Full Mode Order (`full_memory_order.tres`)
```
1. mem_test_shard
2. mem_mini_level
3. mem_first_village
4. mem_get_map
5. mem_open_world
6. mem_human_territory
7. mem_human_capital
8. mem_goblin_capital
9. mem_ending_full
```

---

## Skills

Currently minimal skill system (single test skill):

| Skill ID | Name       | Description          | Base Cost |
|----------|------------|----------------------|-----------|
| `test`   | Test Skill | A skill for testing. | 100       |
| `skill_fireball` | Fireball | Unleash a compact sphere of intense heat. | 150 |
| `skill_heal` | Healing Wind | A soothing breeze that restores vitality. | 200 |
| `skill_dash` | Swift Dash | Quickly propel yourself forward. | 120 |

Located in: `resources/skills/test.tres`

**Note:** Skill system is under development. Skill data integration and UI presentation planned for future updates.

---

## Cutscenes

Cutscenes are triggered by stages and memories. Each cutscene contains a sequence of steps (dialog, animations, media). All cutscenes are located in `resources/cutscenes/`:

| Cutscene ID            | Triggered By                              | Purpose                       |
|------------------------|-------------------------------------------|-------------------------------|
| `startup_intro_cutscene` | `universal_startup` stage (exp 0)         | Initial game introduction     |
| `startup_intro`        | (referenced but not directly triggered)   | Alternative intro variant     |
| `mini_level`           | `early_milestone` stage                   | Mini level narrative          |
| `tutorial_stage_2`     | `tutorial` stage (test mode)              | Tutorial guidance             |
| `first_village`        | `first_village` stage                     | First village arrival         |
| `get_map`              | `get_map` stage                           | Map acquisition narrative     |
| `open_world`           | `open_world` stage                        | Open world discovery          |
| `human_territory`      | `human_territory` stage                   | Human lands exploration       |
| `human_capital`        | `human_capital` stage                     | Human capital discovery       |
| `goblin_capital`       | `goblin_capital` stage                    | Goblin capital discovery      |
| `attack_towns`         | `attack_towns` stage (full mode)          | Town attack sequence          |
| `defeat_villages`      | `defeat_villages` stage (full mode)       | Village defeat sequence       |
| `ending_trial`         | `ending` stage (trial mode)               | Trial mode ending             |
| `ending_full`          | `ending` stage (full mode)                | Full game ending              |
| `level_up`             | (unused - replaced by stages)             | Legacy level up cutscene      |
| `failure_cutscene`     | Fallback if stage cutscene missing        | Error recovery cutscene       |

---

## Resource Loading Flow

The `ProgressManager` initializes resources in this order:

1. **Load Stages**: Load all stages for current mode from `resources/stages/{mode}/`
2. **Sort Stages**: Sort by `req_exp` (ascending)
3. **Load Skills**: Load all skills from `resources/skills/`
4. **Initialize Skill Levels**: Set all skills to level 1
5. **Load Cutscenes**: Load all cutscenes from `resources/cutscenes/`
6. **Load Memories**: Load all memories from `resources/memories/`
7. **Load Memory Order**: Load mode-specific order from `resources/memories/orders/{mode}_memory_order.tres`
8. **Arrange Memories**: Order memories according to MemoryOrder resource
9. **Check Progression**: Trigger any stages that current exp qualifies for

See [`README.md`](README.md#resource-management) for detailed resource architecture information.

---

## Adding New Resources

### To Add a New Stage

1. Create a new `.tres` file in `resources/stages/{mode}/`
2. Set `StageData` class with:
   - `id` - Unique identifier
   - `name` - Display name
   - `req_exp` - Experience requirement (must be >= previous stage)
   - `cutscene_id` - Cutscene to play (empty string for none)
   - `unlocks_memory_id` - Memory to collect (empty string for none)

### To Add a New Memory

1. Create a new `.tres` file in `resources/memories/`
2. Set `MemoryData` class with:
   - `id` - Unique identifier
   - `name` - Display name
   - `description` - Lore text
   - `cutscene_id` - Cutscene to play when viewed
3. Update all mode-specific order files in `resources/memories/orders/` to include the new ID in desired position

### To Add a New Cutscene

1. Create a new `.tres` file in `resources/cutscenes/`
2. Set `CutsceneScript` class with steps (dialog, movement, media, etc.)
3. Reference the cutscene ID in stages or memories via their `cutscene_id` field

### To Add a New Skill

1. Create a new `.tres` file in `resources/skills/`
2. Set `SkillData` class with:
   - `id` - Unique identifier
   - `name` - Display name
   - `description` - Skill description
   - `base_cost` - Crystal/experience cost for level 1
   - `icon` - Texture2D for UI display

---

## Common Issues & Troubleshooting

### Memory doesn't unlock at expected stage
- Check stage's `unlocks_memory_id` field matches memory `id`
- Verify stage `req_exp` is achievable in current game mode
- Confirm memory ID is in the mode's MemoryOrder file

### Wrong cutscene plays
- Check stage `cutscene_id` matches actual cutscene file ID
- Verify cutscene exists in `resources/cutscenes/`
- See [`BUGS_ARCHIVED.md`](BUGS_ARCHIVED.md) Bug #3 for concurrent cutscene issues

### Torch appears lit incorrectly
- Default torch animation is now `"unlit"` (fixed in past update, see [`BUGS_ARCHIVED.md`](BUGS_ARCHIVED.md) Bug #2)
- Check `BackpackUI` is calling `torch.refresh_visuals()` with correct unlock status
- Verify memory ID is in `ProgressManager.unlocked_memory_ids`

---

**Last Updated:** April 2, 2026  
**Related Documentation:** [`README.md`](README.md) | [`BUGS_ARCHIVED.md`](BUGS_ARCHIVED.md) | [`AGENTS.md`](AGENTS.md)
