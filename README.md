# Godot Project: godot_test

## Project Overview
This is a 2D RPG/Adventure game developed with **Godot 4.5 (Forward Plus)**. The game features a data-driven architecture using Godot Resources, a centralized management system through Autoloads, and a standard 4-way movement player character.

### Core Technologies
- **Engine**: Godot 4.5
- **Language**: GDScript
- **Rendering**: Forward Plus
- **Resolution**: 1152x648 (Base Design), Responsive scaling enabled
- **Stretch Mode**: `canvas_items` (sharp UI), Aspect: `expand`
- **Asset Filter**: Nearest Neighbor (`default_texture_filter=0`)

---

## Core Architecture

### Singletons (Autoloads)
The project is structured around several key singletons that manage different aspects of the game:

- **`SceneSwitcher`**: Handles animated transitions between game scenes.
- **`GuiManager`**: Manages the user interface, updating it based on game state changes.
- **`CutsceneManager`**: Executes sequence-based cutscenes and dialogue.
- **`ProgressManager`**: Central hub for game state, including player experience, crystals, and unlocked "memories." It emits signals to notify other components of changes.

### Component Interactions
- `ProgressManager` interacts with `SceneSwitcher` and `CutsceneManager` to progress the game state and trigger scene changes or cutscenes.
- `GuiManager` is updated by `ProgressManager` through signals to reflect the current game state.
- The game's progression is data-driven, with stages, memories, and skills defined in resource files loaded by `ProgressManager`.

---

## Resource Management

**For a complete inventory of all resources, stages, memories, and their relationships, see [`RESOURCES.md`](RESOURCES.md).**

The game's data-driven logic relies on custom `Resource` types defined in `resources/data_structures/`. Actual data instances are stored as `.tres` files in their respective folders under `resources/`. **Resources are loaded recursively from their respective directories, allowing for subfolder-based organization (e.g., for labels or grouping).**

### Resource Types

#### **1. Cutscene (`CutsceneScript`)**
- **Location**: `resources/cutscenes/` (Supports subfolders)
- **Definition**: `resources/data_structures/cutscene_script.gd`
- **Purpose**: Defines a sequential series of events (dialogue, movement, fullscreen media).
- **Key Fields**:
  - `id`: Unique string ID used to trigger the cutscene.
  - `steps`: An array of `CutsceneStep` resources.
- **`CutsceneStep` Types**:
  - `DIALOG`: Speaker name and text.
  - `MOVE`: Moves an actor to a target position over a duration.
  - `FULLSCREEN_TEXT`: Displays centered text on the screen.
  - `FULLSCREEN_IMAGE`: Displays a centered texture on the screen.

#### **2. Memory (`MemoryData`)**
- **Location**: `resources/memories/` (Supports subfolders)
- **Definition**: `resources/data_structures/memory_data.gd`
- **Purpose**: Collectible "memory shards" that provide lore and trigger cutscenes.
- **Key Fields**:
  - `id`: Unique string ID.
  - `name`: Display name in the UI.
  - `description**: Lore text.
  - `cutscene_id`: ID of the `CutsceneScript` to play upon interaction.
  - `icon`: Texture2D used for display.

#### **3. Skill (`SkillData`)**
- **Location**: `resources/skills/` (Supports subfolders)
- **Definition**: `resources/data_structures/skill_data.gd`
- **Purpose**: Defines player or unit abilities.
- **Key Fields**:
  - `id`: Unique string ID.
  - `name`, `description`: Display info.
  - `base_cost`: The crystal/experience cost to unlock or use.
  - `icon`: Associated icon.

#### **4. Stage (`StageData`)**
- **Location**: `resources/stages/` (Supports subfolders: `test/`, `trial/`, `full/` for different game modes)
- **Definition**: `resources/data_structures/stage_data.gd`
- **Purpose**: Defines progression milestones that unlock memories and trigger cutscenes when player reaches required experience.
- **Key Fields**:
  - `id`: Unique string ID.
  - `name`: Display name (for debug/editor reference).
  - `req_exp`: Experience points required to unlock this stage.
  - `cutscene_id`: ID of the `CutsceneScript` to play when stage is reached.
  - `unlocks_memory_id`: ID of the `MemoryData` shard to collect when this stage is reached (empty string if stage doesn't unlock a memory). **This is the direct, explicit way memories are collected during progression.**

**Memory Collection Design:** Stages unlock specific memories via `unlocks_memory_id` reference. This direct approach (as opposed to matching cutscene IDs) ensures memories light up correctly in the backpack UI. See `BUGS_ARCHIVED.md` for the reasoning behind this design pattern (Bug 3 fix).

#### **5. Memory Order (`MemoryOrder`)**
- **Location**: `resources/memories/memory_order.tres`
- **Definition**: `resources/data_structures/memory_order.gd`
- **Purpose**: Defines the sequence in which memory shards are displayed in the backpack UI.

---

### Managing Resources in Godot

#### **How to Add a New Resource**
1. In the **FileSystem** dock, right-click the desired directory (e.g., `resources/memories/`).
2. Select **Create New** -> **Resource**.
3. In the search box, type the class name (e.g., `MemoryData` or `CutsceneScript`).
4. Give it a name ending in `.tres` and click **Save**.

#### **How to Modify a Resource**
1. Double-click the `.tres` file in the **FileSystem** dock.
2. Edit properties in the **Inspector** dock (ensure the `id` is unique and matches references elsewhere). Changes are saved automatically.

#### **How to Access Resources in Code**
- **Direct Loading**: `var my_res = load("res://resources/memories/my_shard.tres")`
- **By ID**: Use the corresponding manager. For example, `CutsceneManager.play("startup_intro_cutscene")` will search for a `CutsceneScript` with that `id`.
- **Global Data**: `ProgressManager` loads and tracks collected memories and player stats globally.

---

## Project Structure

- **`/assets`**: Sprites, fonts, music, and sound effects.
- **`/important_scripts`**: Core logic, managers (singletons), and the player controller.
- **`/other_scripts`**: Game-specific logic (battle management, interactables, UI).
- **`/resources`**: Custom `.tres` files and their GDScript definitions.
- **`/scenes`**: Godot `.tscn` files for levels, UI, and game objects.

---

## Development & Building

### Prerequisites
- **Godot 4.5** or later.

### Controls & Input Map
- **Movement**: WASD / Arrow Keys (`ui_left`, `ui_right`, `ui_up`, `ui_down`)
- **Interact**: `E` key
- **Pause/Back**: `Esc` key (`ui_cancel`) - Pauses game and goes back in menus

### Physics Layers
1. **Player**
2. **Enemy**
3. **Environment**
4. **Interactables**

### Running the Project
- **Open in Editor**: Open `project.godot` with Godot.
- **Run Game**: Press `F5` in the editor or run `godot --path .` from the command line.
- **Export**: Use `Project > Export` to build for Windows, Linux, or Web.

---

## Roadmap & Areas for Improvement

- **Decoupling**: Reduce tight coupling between `ProgressManager` and other managers.
- **Data Externalization**: Move hardcoded stage definitions into dedicated `Resource` files or external configs.
- **Modular Loading**: Implement a more modular approach to resource loading and asset management.
- **Animation Enhancement**: Integrate `AnimationTree` for more complex character state management (idle, run, jump transitions).
- **UI Robustness**: Consolidate resource loading ownership to simplify UI synchronization and state updates.
- **Consistent IDs**: Ensure unique and consistent naming conventions for all data resources (memories, cutscenes).

---

## Documentation Reference

- **[`RESOURCES.md`](RESOURCES.md)** - Complete inventory of all game resources: stages by mode, memories, skills, cutscenes, and their relationships
- **[`BUGS_ARCHIVED.md`](BUGS_ARCHIVED.md)** - Historical bugs and their solutions for reference and regression prevention
- **[`AGENTS.md`](AGENTS.md)** - AI agent instructions and development patterns
