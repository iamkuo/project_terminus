# Archived Bugs - Fixed Issues

## Bug 1: Fullscreen Text Closes Immediately After Start Button (FIXED)
**Status:** ✅ FIXED

### Symptoms
- When pressing the start button, fullscreen text/dialog from cutscenes would close automatically without requiring `ui_skip` input
- Animation flash would occur as scene transitions

### Root Cause
`SceneSwitcher` was managing the entire `fullscreen_ui` node that `GuiManager` also used. At the end of scene transitions:
```gdscript
fullscreen_ui.hide()  # Wrong: Closes GuiManager's UI prematurely
```

This caused any dialogs or fullscreen text queued by `GuiManager` to be hidden before the player could press `ui_skip` to advance.

### Solution
Modified `scene_switcher.gd` to:
1. Keep `fullscreen_ui.show()` at the start (so `transition_rect` child is visible)
2. Remove `fullscreen_ui.hide()` at the end
3. Only manage `transition_rect` (black overlay), not the entire fullscreen_ui

**Files Changed:**
- `important_scripts/scene_switcher.gd` - Removed problematic UI hiding logic

**Commit:** Fixed scene transition UI management

---

## Bug 2: Torch `mem_ending_trial` Appears Lit at Game Start (FIXED)
**Status:** ✅ FIXED

### Symptoms
- In the backpack UI, the `mem_ending_trial` torch appeared lit (burning) immediately at game start
- This torch should only be lit after collecting the memory at stage req_exp=30
- When the game starts, exp is 0, so the torch should be unlit

### Root Cause
The torch scene `torch.tscn` had hardcoded the default animation state:
```gdscript
[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
sprite_frames = SubResource("SpriteFrames_x1r1x")
animation = &"lit"  # All torches start as "lit"!
```

When torches were instantiated, they immediately displayed as lit. Even though `mem_ending_trial` wasn't in `unlocked_memory_ids`, the visual showed it as collected. The `refresh_visuals()` call would eventually correct this, but the initial state was wrong.

### Solution
Changed torch.tscn default animation from `&"lit"` to `&"unlit"`:
```gdscript
animation = &"unlit"  # Correct initial state
```

Now torches display unlit by default and only animate to "lit" when `refresh_visuals(true)` is called.

**Files Changed:**
- `scenes/torch.tscn` - Changed default animation from "lit" to "unlit"

**Commit:** Fixed torch default animation state

---

## Bug 3: Ending Trial Cutscene Plays Instead of Early Milestone (FIXED - Complete Solution)
**Status:** ✅ FIXED (Final comprehensive fix applied)

### Symptoms
- After pressing the start button (+10 exp), wrong cutscenes played or none at all
- When spamming button presses before previous cutscene finishes, multiple stages advance at once
- Ending trial or later cutscenes would play instead of the correct early milestone cutscene
- Random behavior depending on timing

### Root Cause - Complete Analysis

**Part 1: Concurrent Async Cutscenes** (Fixed in previous update)
- `CutsceneManager.play()` was implicitly async but called without awaiting
- Multiple concurrent cutscenes could conflict, corrupting system state

**Part 2: Rapid Setter Calls** (NEW - Fixed in current update)
The `current_exp` property setter called `_check_stage_progression()` immediately:

```gdscript
// OLD CODE - allows multiple rapid calls
var current_exp: int = 0:
	set(value):
		_current_exp = value
		_check_stage_progression()  // Instant call
```

**Race Condition Scenario with Rapid Button Presses:**
1. User presses start button → `current_exp += 10` (exp = 10)
   - Setter calls `_check_stage_progression()` immediately
   - Processes stage 1 (early_milestone, req_exp=10)
   - Calls `CutsceneManager.play("early_milestone_cutscene")`

2. User presses start button again (before scene switch) → `current_exp += 10` (exp = 20)
   - Setter calls `_check_stage_progression()` immediately (again!)
   - Processes stage 2 (tutorial, req_exp=20)
   - Calls `CutsceneManager.play("tutorial_stage_2")`
   - Queues in CutsceneManager behind early_milestone

3. User presses again → `current_exp += 10` (exp = 30)
   - Processes stage 3 (ending_trial, req_exp=30)
   - Calls `CutsceneManager.play("ending_trial")`
   - Queues in CutsceneManager

**Result:** Queue = ["tutorial_stage_2", "ending_trial"]
- Early milestone plays (correct)
- Then tutorial plays
- Then ending_trial plays instead of stopping at early milestone

**Part 3: Single-Stage Processing**
The original `_check_stage_progression()` only processed ONE stage per call:

```gdscript
// OLD CODE - only processes next stage
var next_idx = current_stage_index + 1
if current_exp < stage.req_exp: return  // Stops immediately if not enough exp
// Process stage and return (no loop)
```

This meant rapid setter calls could cause the function to be called multiple times before recognizing all qualifying stages, leading to stages being processed in separate calls = multiple cutscene plays.

### Solution - Two Part Fix

**Fix 1: Defer Progression Checks**
Changed the property setter to defer progression checks to the end of the frame using `call_deferred()`:

```gdscript
var current_exp: int = 0:
	set(value):
		if value != _current_exp:
			_current_exp = value
			# Defer to end of frame - only ONE call per frame max
			call_deferred("_check_stage_progression")
```

**Benefit:** Multiple rapid button presses in the same frame only trigger ONE progression check at the end of the frame, not multiple immediate calls.

**Fix 2: Loop Through All Qualifying Stages**
Changed `_check_stage_progression()` to process ALL stages in a single call until exp no longer qualifies:

```gdscript
func _check_stage_progression() -> void:
	# Loop through all stages that the current exp qualifies for
	while true:
		var next_idx = current_stage_index + 1
		if active_stages.is_empty() or next_idx >= active_stages.size(): break

		var stage = active_stages[next_idx]
		if current_exp < stage.req_exp: break  // Stop when exp insufficient

		# Process this stage
		current_stage_index = next_idx
		# ... queue cutscenes etc ...
		# Loop continues to next stage
```

**Benefit:** Even if multiple stages are unlocked by a single exp change, they're all processed in one function call, and cutscenes queue in the correct order.

**Files Changed:**
- `important_scripts/progress_manager.gd`:
  - Modified property setter to use `call_deferred()` for non-blocking progression checks
  - Converted `_check_stage_progression()` from single-check to while-loop for complete stage processing
- `important_scripts/cutscene_manager.gd`:
  - Already has queue system to serialize cutscene playback (from previous fix)

### Result
✅ Rapid button presses no longer cause multiple stages to progress separately
✅ All qualifying stages process in one deferred call at the end of the frame
✅ Cutscenes queue in correct order
✅ Wrong cutscenes never play

---

### Part 3: Fragile Resource System Refactored

**Secondary Issue:** The indirect nature of memory collection (using cutscene_id matching) meant that torches didn't light during normal gameplay if the resource IDs were mismatched. This wasn't the primary cause of the bug, but it masked the problem and made debugging harder.

**Old System (Fragile):**
- **Memory Collection Logic**: Looped through all memories to find ones matching the stage's `cutscene_id`
- **Problem**: Silent failures if IDs don't match - no error, memory just doesn't unlock
- **Problem**: `cutscene_id` served dual purpose (trigger action + use as match key)
- **Problem**: Hard to see which memory belongs to which stage without reading code

```gdscript
// OLD CODE in progress_manager.gd
if not stage.cutscene_id.is_empty():
	for mem in active_memories:
		if mem.cutscene_id == stage.cutscene_id:  // Match by cutscene ID
			collect_memory(mem.id)
			break
```

**New System (Robust):**
- **Added Field**: `unlocks_memory_id: String` to `StageData` class
- **Direct Reference**: Stage explicitly declares which memory it unlocks
- **Explicit in Editor**: Opening a stage .tres file shows exactly which memory it unlocks
- **No Matching Logic**: Direct dictionary lookup, no loops or comparisons

```gdscript
// Stage definition file: startup.tres
cutscene_id = "startup_intro_cutscene"
unlocks_memory_id = "mem_test_shard"  // Direct link

// NEW CODE in progress_manager.gd
if stage.unlocks_memory_id:
	collect_memory(stage.unlocks_memory_id)  // Direct, no matching
```

**Scope of Changes:**
- Updated `StageData` class definition to add new field
- Updated progression logic in `ProgressManager` to use direct unlocks
- Updated ALL 29 stages across test/trial/full modes with correct memory mappings
- Removed old memory collection code that relied on cutscene_id matching

**Files Changed:**
- `resources/data_structures/stage_data.gd` - Added `unlocks_memory_id: String` field
- `important_scripts/progress_manager.gd` - Changed progression to use direct unlock instead of cutscene matching
- All stage files: `resources/stages/test/*.tres`, `resources/stages/trial/*.tres`, `resources/stages/full/*.tres`

**Architecture Note:**
This implements **Plan 1** of the resource system analysis:
- Simple, explicit one-to-one stage-to-memory relationships
- Can easily scale to **Plan 2** (array-based multiple unlocks) if future design needs it
- Type-safe: can validate at load time that memory ID exists

---

## Summary: Why Bug 3 Occurred

**Three separate but related issues combined**:

1. **Concurrent cutscenes** - Async cutscenes could run at the same time and conflict
2. **Rapid setter calls** - Property setter called progression immediately, multiple times per frame
3. **Fragile resource design** - Memory collection relied on indirect cutscene ID matching, masking the real issues

**All three are now fixed**:
- ✅ Cutscene queue system prevents concurrency
- ✅ Deferred progression + while-loop prevents multiple separate stage advances
- ✅ Direct memory unlocking makes the system explicit and robust

---

## Bug 4: Teleport Point Doesn't Trigger Scene Transition (FIXED)
**Status:** ✅ FIXED

### Symptoms
- Character walks into a teleport point's detection range but nothing happens
- No scene transition occurs when entering the trigger area

### Root Cause
The teleport point was binding to the wrong signal. The code used `area_entered`:
```gdscript
area_entered.connect(func(area):
	if area.name == "Player":
		SceneSwitcher.switch_scene(target_scene, transition_type)
)
```

The problem: `area_entered` only detects `Area2D` objects. The player character has a `CharacterBody2D` physics body, not an Area2D, so the signal never fired.

### Solution
Changed the signal from `area_entered` to `body_entered`:
```gdscript
body_entered.connect(func(body):
	if body.name == "Player":
		SceneSwitcher.switch_scene(target_scene, transition_type)
)
```

`body_entered` detects any node with a physics body (rigid bodies, character bodies, etc.), which properly catches the player character.

**Files Changed:**
- `other_scripts/tp_point.gd` - Changed signal binding from area_entered to body_entered

---

## Bug 5: Scene Switching Deletes Game Node Instead of Unloading Scenes (FIXED)
**Status:** ✅ FIXED

### Symptoms
- When switching between scenes (MainMenu → MainWorld), the entire game crashes or fails to load
- The Game node itself is being deleted instead of just swapping scene content

### Root Cause
Older implementation tried to directly manipulate the Root node hierarchy:
```gdscript
# BAD: Trying to delete the last child of Root
var root = get_tree().root
root.remove_child(root.get_child(root.get_child_count() - 1))
```

This could accidentally delete the Game node (or other critical nodes) instead of just the scene content.

### Solution
The current `scene_switcher.gd` uses a proper container pattern:
```gdscript
@onready var scene_container = get_node("/root/Game/SceneContainer")
var current_scene = null

# Store reference to current scene
current_scene = scene_container.get_child(0)

# When switching:
current_scene.queue_free()  # Clean up the OLD scene
var new_scene = load("res://scenes/%s.tscn" % scene_name)
current_scene = new_scene.instantiate()
scene_container.add_child(current_scene)  # Add to the container
current_scene = new_scene  # Update reference
```

Key improvements:
1. Uses a dedicated `SceneContainer` child node to hold scenes
2. Stores `current_scene` reference for safe cleanup
3. Uses `queue_free()` for proper cleanup without deleting parent nodes
4. Only operates within the container, not the root

This preserves the Game node and cleanly swaps scenes within the designated container.

**Files Changed:**
- `important_scripts/scene_switcher.gd` - Implemented container-based scene management

---

## Bug 6: Back Button Unclickable in Test Area Scene (FIXED)
**Status:** ✅ FIXED

### Symptoms
- In `test_area.tscn`, the "Back" button could not be clicked
- The button existed and had the correct script attached, but no response to clicks
- Input was completely blocked to the button

### Root Cause
The `FullscreenUI` Control node in `gui.tscn` was blocking mouse input to all nodes below it. The problem:

1. `FullscreenUI` is a fullscreen Control node (anchors_preset = 15, covers entire screen)
2. It's on CanvasLayer 2 (above the game scenes)
3. It had no `mouse_filter` property set, defaulting to `MOUSE_FILTER_STOP`
4. This meant it consumed all mouse clicks before they could reach the button in test_area.tscn

**Node Structure:**
```
CanvasLayer (GUI)
  ├─ Dialog (Panel - only visible during dialog)
  └─ FullscreenUI (Control - ALWAYS active as parent)
      ├─ TransitionColorRect (hidden by default)
      ├─ DialogOverlay (hidden by default)
      ├─ Label (hidden by default)
      └─ TextureRect (hidden by default)
```

Even though the children had `mouse_filter = 2` (MOUSE_FILTER_IGNORE), the parent `FullscreenUI` was still blocking input because parent nodes block input before child visibility/mouse_filter matters.

### Solution
Set `mouse_filter = 2` (MOUSE_FILTER_IGNORE) on the `FullscreenUI` node:

```tscn
[node name="FullscreenUI" type="Control" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2  # NEW: Ignore input by default
```

**How it works:**
- `mouse_filter = 2` makes `FullscreenUI` pass input through to nodes below
- `TransitionColorRect` still has `mouse_filter = 2` normally (pass through)
- During scene transitions, `SceneSwitcher` explicitly sets `transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP` to block input
- This way: input is blocked ONLY when the black transition overlay is active, and passes through otherwise

**Input Flow:**
- **During gameplay**: FullscreenUI (pass) → button receives click ✓
- **During dialog**: FullscreenUI (pass) → Dialog panel handles input ✓
- **During transition**: TransitionColorRect (block) → blocks clicks ✓

**Files Changed:**
- `scenes/gui.tscn` - Added `mouse_filter = 2` to FullscreenUI node

**Key Learning:**
Parent Control nodes block input before children. Set parent `mouse_filter` based on whether ANY child should be interactive. When children conditionally need input blocking, manage their `mouse_filter` in code (like SceneSwitcher does).

---

## Bug 7: Backpack Torches Not Lighting Up on Collection (FIXED)
**Status:** ✅ FIXED

### Symptoms
- When picking up a memory shard in the game world, the corresponding torch in the backpack UI remains unlit (gray/dark).
- The torch only correctly updates its visual state if the backpack is closed and reopened, or if the scene is reloaded.

### Root Cause
The `BackpackUI` script was instantiating torches and immediately calling `refresh_visuals(is_unlocked)` on them. However, since the torches were just added to the scene tree, their `@onready` variables (including the `AnimatedSprite2D`) were not yet initialized.
In `torch_button.gd`:
```gdscript
func refresh_visuals(is_unlocked = null) -> void:
	if not is_inside_tree() or not animated_sprite: # animated_sprite is NULL here!
		return
```
This caused the initial "lit" state to be ignored. When a `memory_collected` signal was received later, if the backpack hadn't been opened yet, the same `animated_sprite is NULL` check would prevent the visual update.

### Solution
Modified `torch_button.gd` to store a "pending" unlocked state if `refresh_visuals` is called before the node is ready. 
Additionally, refactored `backpack_ui.gd` to use **Dictionary-based node mapping** for both Skills and Memories:
1.  **Immediate Removal**: In `setup_backpack`, added `remove_child(n)` before `queue_free(n)` to ensure the container is visually empty immediately, preventing name collisions and indexing errors in Godot's lifecycle.
2.  **O(1) Dictionary Mapping**: Replaced fragile `get_node_or_null` and index-based `get_child` lookups with `_skill_nodes` and `_memory_torches` Dictionaries.
3.  **Sync Logic**: Updated `_refresh_ui` and `_on_memory_collected` to use these dictionaries, ensuring O(1) performance and perfect sync even during rapid state changes.

**Files Changed:**
- `other_scripts/torch_button.gd` - Added pending state handling.
- `important_scripts/backpack_ui.gd` - Full refactor to Dictionary-based mapping and robust child clearing.

**Commit:** Implemented robust Dictionary-based UI mapping for backpack

---

## Key Learnings
1. **Ownership matters:** Managers should own and control their own UI. Don't have multiple systems manage the same node.
2. **Default values matter:** Ensure scene defaults match the initial state (torches should default to unlit, not lit).
3. **Avoid duplicate calls:** Property setters can trigger side effects - be careful with manual calls to the same function.
4. **Signal specificity:** Use the correct physics signal - `area_entered` for Area2D collision, `body_entered` for physics bodies.
5. **Scene tree structure:** Use dedicated containers for dynamic content. This prevents accidental deletion of critical nodes and makes scene switching predictable and safe.
6. **Async Initialization:** `@onready` variables are not available until the node is "ready". If a method depends on these variables and is called immediately after instantiation (before the next frame), it must handle the uninitialized state (e.g., by buffering the request).

---

## Bug 8: Resources Fail to Load in Exported Builds (FIXED)
**Status:** ✅ FIXED

### Symptoms
- When running from the Godot editor, all resources (stages, memories, etc.) load correctly.
- After exporting the game, no resources are loaded, breaking cutscenes and progression.

### Root Cause
In Godot 4.x, when text-based resources (like `.tres`) are exported, they are sometimes compiled to binary and saved with a `.remap` extension inside the exported PCK file (e.g., `my_memory.tres.remap`).
The `_load_resources` function in `progress_manager.gd` used `file_name.ends_with(".tres")` during directory scanning. In an exported build, `DirAccess` encounters `my_memory.tres.remap` and skips it because it doesn't end with `.tres`.

### Solution
Added `trim_suffix(".remap")` to the filename before checking its extension and before constructing the absolute path for `load()`.
Godot's `load()` function expects the original `.tres` path and resolves the `.remap` internally. By trimming `.remap`, we correctly parse the original filename and extension.

```gdscript
# Strip .remap if it exists (necessary for exported Godot builds)
var actual_file_name = file_name.trim_suffix(".remap")
var full_path = path.path_join(actual_file_name)
```

**Files Changed:**
- `important_scripts/progress_manager.gd` - Applied `trim_suffix(".remap")` in `_load_resources()`.

---

## Bug 9: Spawn UI Blocks Properties UI Button Input (FIXED)
**Status:** ✅ FIXED

### Symptoms
- When Spawn UI is visible, the attack mode switching menu (Properties UI) buttons don't work
- Close button and attack mode buttons (Stay, Follow, Attack Enemy, Attack Tower) are unclickable
- TAB key also stops working to close Spawn UI when Properties UI is open

### Root Cause
**Layering conflict between CanvasLayer and 2D world nodes:**

1. **SpawnUI** is a fullscreen Control on a `CanvasLayer` (UI layer) with `mouse_filter = STOP`
2. **PropertiesUI** is a child of units in the 2D world (not on CanvasLayer)
3. CanvasLayer nodes receive input **before** 2D world nodes, regardless of visual z-index
4. SpawnUI's `mouse_filter = STOP` blocks ALL mouse events from reaching anything underneath

**Why static scene settings couldn't fix it:**
- Can't put both on same layer: PropertiesUI must follow units as they move
- Can't leave SpawnUI as PASS/IGNORE: Then clicks would pass through to game world when clicking cards
- Dynamic requirement: SpawnUI must block clicks when alone, allow clicks through when PropertiesUI is visible

### Solution
Modified `spawn_ui.gd` to dynamically change `mouse_filter` based on Properties UI visibility:

```gdscript
func _input(event: InputEvent) -> void:
    # Check if any Properties UI is visible
    var all_properties = get_tree().get_nodes_in_group("properties_ui")
    var any_visible = false
    for p in all_properties:
        if p.visible:
            any_visible = true
            break
    
    # CRITICAL: Change mouse_filter to allow clicks through to Properties UI
    # 0 = PASS, 1 = STOP (blocks everything), 2 = IGNORE
    if any_visible:
        mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
    else:
        mouse_filter = Control.MOUSE_FILTER_STOP   # Normal blocking behavior
    
    if any_visible:
        return
    
    # ... rest of input handling
```

Additionally, Properties UI must be in the "properties_ui" group:
- Added `add_to_group("properties_ui")` in `properties_ui.gd` `_ready()`
- Scene file has `groups = ["properties_ui"]` for pre-instantiated units

**Files Changed:**
- `other_scripts/spawn_ui.gd` - Dynamic mouse_filter switching based on Properties UI visibility
- `important_scripts/ui/properties_ui.gd` - Added `add_to_group("properties_ui")` in `_ready()`
- `scenes/ui/properties_ui.tscn` - Added `groups = ["properties_ui"]` to node definition
- `scenes/spawn_ui.tscn` - Added comment documenting mouse_filter behavior

---

## Related Documentation
- [`README.md`](README.md) - Project architecture and core systems
- [`RESOURCES.md`](RESOURCES.md) - Complete inventory of stages, memories, skills, and cutscenes
- [`AGENTS.md`](AGENTS.md) - Agent instructions and best practices
