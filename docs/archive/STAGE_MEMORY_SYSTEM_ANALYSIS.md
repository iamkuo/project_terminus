# Stage & Memory System Analysis
**Date:** May 7, 2026 | **Status:** Comprehensive Review with Refactor Recommendations

---

## Executive Summary

The Stage and Memory systems are **functional but fragile**. The current implementation uses direct `unlocks_memory_id` binding (a good design), but lacks crucial features outlined in `STAGE_SYSTEM_REFINEMENT.md`. Key issues include:

1. **Missing `req_exp` values** on startup stages
2. **No sequential stage locking** - any stage can trigger regardless of order
3. **No manual trigger support** - all progression is EXP-based
4. **Inconsistent memory-stage relationships** across game modes
5. **Memory ordering is separate** from stage progression logic

---

## System Overview

### Current Architecture

```
ProgressManager (Autoload)
├── active_stages: Array[StageData]     [Sorted by req_exp]
├── active_memories: Array[MemoryData]   [Ordered by MemoryOrder resource]
├── active_cutscenes: Dict               [ID → CutsceneScript]
├── current_stage_index: int             [Current completion milestone]
├── current_exp: int                     [Triggers _check_stage_progression()]
└── unlocked_memory_ids: Array[String]   [Collected memories]

Data Files
├── resources/stages/{mode}/*.tres       [StageData resources]
├── resources/memories/*.tres            [MemoryData resources]
├── resources/memories/orders/*_memory_order.tres [Ordering per mode]
└── resources/cutscenes/*.tres          [CutsceneScript resources]
```

### Data Structures

**StageData (6 fields)**
```gdscript
@export var id: String
@export var name: String
@export var req_exp: int               # ⚠️ OFTEN MISSING (startup stages)
@export var cutscene_id: String        # Plays when stage reached
@export var unlocks_memory_id: String  # ✅ Direct memory binding (since Bug 3 fix)
```

**MemoryData (5 fields)**
```gdscript
@export var id: String
@export var name: String
@export var description: String
@export var cutscene_id: String        # Plays when memory viewed (optional)
@export var icon: Texture2D
```

**MemoryOrder (1 field)**
```gdscript
@export var ordered_memory_ids: Array[String]  # Display order in backpack
```

---

## Current Progression Flow

### Trigger Mechanism
```
Any code with reference to ProgressManager:
  current_exp += amount
        ↓
  Property setter (if value != _current_exp):
    - Update _current_exp
    - Emit data_updated
    - call_deferred("_check_stage_progression")  ← Key: Deferred!
        ↓
  [Frame ends]
        ↓
  _check_stage_progression():
    while current_exp >= next_stage.req_exp:
      - Increment current_stage_index
      - If unlocks_memory_id: collect_memory(id)
      - If cutscene_id: CutsceneManager.play(cutscene_id)
      - Emit data_updated
      - Loop for next stage
        ↓
  CutsceneManager queues cutscenes
        ↓
  On cutscene_finished signal:
    [External code may trigger next actions]
```

### Example Progression Timeline (Trial Mode)

```
Stage 0: mem_startup (req_exp=0, assumed)
         └─ Unlocks: mem_startup
         └─ Triggers: startup_intro

Stage 1: mem_mini_level (req_exp=100)
         └─ Unlocks: mem_mini_level
         └─ Triggers: mini_level

Stage 2: mem_open_world (req_exp=200)
         └─ Unlocks: mem_open_world
         └─ Triggers: open_world

...

Stage 8: mem_ending_trial (req_exp=500)
         └─ Unlocks: mem_ending_trial
         └─ Triggers: ending_trial
```

---

## Identified Flaws & Issues

### 🔴 CRITICAL: Missing `req_exp` Values

**Location:** Startup stages in all modes
**Severity:** High - Breaks progression if exp=0 on load

```
Test Mode:  startup.tres       → req_exp MISSING (should be 0)
Trial Mode: startup.tres       → req_exp MISSING (should be 0)
Full Mode:  startup.tres       → req_exp MISSING (should be 0)
```

**Impact:**
- If `req_exp` is 0 (default), stage triggers immediately on game load
- Visually corrupts the backpack (torch appears lit before cutscene plays)
- Race condition: multiple stages process before first cutscene finishes

**Test Case:**
```gdscript
# At game start with exp=0:
ProgressManager.current_exp = 0
# Should NOT trigger startup cutscene (only triggers when exp >= req_exp)
# Yet currently does because req_exp is missing/0
```

---

### 🟡 MAJOR: No Sequential Stage Locking

**Current Behavior:** Any stage can be manually triggered at any time
```gdscript
# This works (and shouldn't if we want linear progression):
ProgressManager.current_exp = 0
# User manually calls (hypothetically):
CutsceneManager.play("ending_trial")  # Plays immediately
```

**Planned Behavior (from STAGE_SYSTEM_REFINEMENT.md):**
- Stages have `trigger_by_exp: bool` field
- EXP stages are locked until predecessors complete
- Manual stages can trigger anytime

**Current Code Gap:**
```gdscript
# No such check exists:
func _check_stage_progression() -> void:
    # Always processes if exp qualifies
    # Never validates stage order
```

---

### 🟡 MAJOR: No Manual Trigger Support

**Planned Feature (from STAGE_SYSTEM_REFINEMENT.md):**
- Add `trigger_by_exp: bool` to StageData
- Support manual triggering via external signals
- Track `triggered_stage_ids: Array[String]`

**Current Gap:** All progression is strictly EXP-based
- Battle victories cannot unlock cutscenes
- Special events cannot trigger out-of-order
- Boss defeats cannot trigger stage progression

**Would Enable:**
```gdscript
# After defeating a boss:
ProgressManager.trigger_manual_stage("boss_defeated_stage")

# After special world event:
ProgressManager.trigger_manual_stage("world_event_cutscene")
```

---

### 🟡 MAJOR: Incremental vs. Absolute EXP Model

**Current Model:** Absolute EXP thresholds
```
Stage 0: req_exp = 0
Stage 1: req_exp = 100   (absolute)
Stage 2: req_exp = 200   (absolute)
Stage 3: req_exp = 300   (absolute)
```

**Planned Model (from STAGE_SYSTEM_REFINEMENT.md):** Incremental (delta-based)
```
Stage 0: req_exp = 0
Stage 1: req_exp = 100   (delta since Stage 0 completion)
Stage 2: req_exp = 100   (delta since Stage 1 completion) → Total: 200
Stage 3: req_exp = 100   (delta since Stage 2 completion) → Total: 300
```

**Advantage:** Clearer progression design
- Designer sees "each level requires +100 exp"
- Not "stage 7 needs 1500 exp total"
- Easier to balance difficulty curves

**Implementation:** Requires new field + tracking
```gdscript
var exp_since_last_milestone: int = 0
# When stage completes:
exp_since_last_milestone = 0  # Reset
```

---

### 🟠 MODERATE: No Validation of Resource Consistency

**Current Issue:** Silent failures possible
- Stage references non-existent memory ID → no error
- Memory ID missing from MemoryOrder → torch appears but doesn't sort
- Cutscene ID doesn't exist → cutscene silently skips

**Should Have:** Load-time validation
```gdscript
func _validate_stage_resources() -> void:
    for stage in active_stages:
        if stage.unlocks_memory_id and stage.unlocks_memory_id not in active_memories:
            push_error("Stage %s references missing memory: %s" % [stage.id, stage.unlocks_memory_id])
        if stage.cutscene_id and stage.cutscene_id not in active_cutscenes:
            push_warning("Stage %s references missing cutscene: %s" % [stage.id, stage.cutscene_id])
```

---

### 🟠 MODERATE: Memory Order Separate from Progression

**Current Design:**
- Stages define progression via `current_stage_index`
- Memories display in custom order via `MemoryOrder` resource
- These are not inherently synchronized

**Risk Scenario:**
```
Stage 5 unlocks mem_D
Stage 7 unlocks mem_C  
MemoryOrder says: [mem_A, mem_B, mem_C, mem_D]

Result: Backpack shows mem_C after mem_D (confusing!)
```

**Better Approach:** Let stages define display order implicitly
```gdscript
# Auto-sort memories by completion order:
active_memories.sort_custom(func(a, b): 
    return active_stages.find(...) < active_stages.find(...)
)
```

**Note:** Current system works because level designers maintain consistency, but it's fragile.

---

### 🟠 MODERATE: No `completed_stage_index` Tracking

**Planned Feature (from STAGE_SYSTEM_REFINEMENT.md):**
- Add `completed_stage_index: int` to track last FINALIZED stage
- Separate from `current_stage_index`

**Current Gap:** Single `current_stage_index`
- Used to track both "reached" and "finalized" states
- When stage triggers but cutscene hasn't finished, index jumps
- No way to know if story has caught up to progression

**Would Enable:**
```gdscript
# Check if story has caught up:
if completed_stage_index < current_stage_index:
    print("Waiting for cutscenes to finish...")

# Prevent manual triggers until story catches up:
if manual_stage_index <= completed_stage_index:
    print("Can't trigger - out of order")
```

---

### 🔵 MINOR: Hardcoded Game Mode Paths

**Current:**
```gdscript
const PATH_STAGES = "res://resources/stages/"
const PATH_MEMORIES = "res://resources/memories/"
...
var stage_map = _load_resources(PATH_STAGES + mode + "/", StageData)
```

**Issue:** Assumes directory structure matches `mode` names
- Adding new modes requires file system changes + code
- No validation that mode directory exists

**Better:**
```gdscript
var mode_paths = {
    "test": "res://resources/stages/test/",
    "trial": "res://resources/stages/trial/",
    "full": "res://resources/stages/full/"
}
if mode not in mode_paths:
    push_error("Unknown mode: " + mode)
    return
```

---

## Memory Display System (Backpack/Torches)

### Current Flow
```
torch_button.gd (UI component per memory)
├── _last_unlocked_state: Variant
├── _pending_is_unlocked: Variant
├── animated_sprite: AnimatedSprite2D
└── memory_label: Label

Lifecycle:
1. Node created (unlit by default)
2. ProgressManager.memory_collected.connect()
3. For each unlocked_memory_id:
   torch_button.refresh_visuals(true)
4. Animation plays ("lit") + color changes (white)
```

### Issues with Torches
1. **Pending State Hack** - `_pending_is_unlocked` added to handle ordering race conditions
2. **Manual Label Update** - Requires external call to `set_memory_name()`
3. **No Animation Queuing** - If multiple memories unlock quickly, animations overlap

---

## Refactor Recommendations (Priority Order)

### Phase 1: Stability (Week 1)
**Goal:** Fix critical bugs and missing data

#### 1.1 Fix Missing `req_exp` Values
```gdscript
# Affected files:
resources/stages/test/startup.tres         → add req_exp = 0
resources/stages/trial/startup.tres        → add req_exp = 0
resources/stages/full/startup.tres         → add req_exp = 0

# Then add validation:
if stage.req_exp == null or stage.req_exp < 0:
    push_error("Stage %s has invalid req_exp" % stage.id)
```

#### 1.2 Add Resource Validation at Load Time
```gdscript
func _validate_resources() -> void:
    var errors = []
    var warnings = []
    
    for stage in active_stages:
        if stage.unlocks_memory_id and stage.unlocks_memory_id not in active_memories:
            errors.append("Stage '%s' references missing memory '%s'" % [stage.id, stage.unlocks_memory_id])
        if not stage.cutscene_id.is_empty() and stage.cutscene_id not in active_cutscenes:
            warnings.append("Stage '%s' references missing cutscene '%s'" % [stage.id, stage.cutscene_id])
    
    for error in errors:
        push_error("[ProgressManager] " + error)
    for warning in warnings:
        push_warning("[ProgressManager] " + warning)
    
    if not errors.is_empty():
        push_error("ProgressManager failed validation!")
```

#### 1.3 Add Mode Validation
```gdscript
var valid_modes = ["test", "trial", "full"]
if mode not in valid_modes:
    push_error("Invalid game mode: %s. Valid modes: %s" % [mode, valid_modes])
    mode = "test"  # Fallback
```

---

### Phase 2: Architecture (Week 2-3)
**Goal:** Implement STAGE_SYSTEM_REFINEMENT.md features

#### 2.1 Extend StageData
```gdscript
extends Resource
class_name StageData

@export var id: String
@export var name: String
@export var trigger_by_exp: bool = true              # NEW: Manual vs. EXP trigger
@export var req_exp: int = 0
@export var memory_id: String                        # NEW: Direct binding (rename from unlocks_memory_id)
@export var cutscene_id: String = ""
```

#### 2.2 Update ProgressManager State
```gdscript
var completed_stage_index: int = -1                  # NEW: Last finalized stage
var current_stage_index: int = -1                    # Modified: Only reached (not finalized)
var triggered_manual_stages: Array[String] = []      # NEW: Manual triggers pending
var exp_since_last_milestone: int = 0                # NEW: Delta tracking
```

#### 2.3 Implement Sequential Locking
```gdscript
func _check_stage_progression() -> void:
    while true:
        var next_idx = completed_stage_index + 1
        if active_stages.is_empty() or next_idx >= active_stages.size():
            break
        
        var stage = active_stages[next_idx]
        
        # Check if this stage can trigger
        if stage.trigger_by_exp:
            if current_exp < stage.req_exp:
                break  # Not enough exp for next EXP stage
        else:
            # Manual stage - check if triggered
            if stage.id not in triggered_manual_stages:
                break  # Waiting for manual trigger
            triggered_manual_stages.erase(stage.id)
        
        # Finalize this stage
        _finalize_stage(stage)
```

#### 2.4 Add Manual Trigger API
```gdscript
func trigger_manual_stage(stage_id: String) -> bool:
    var stage = _find_stage_by_id(stage_id)
    if not stage:
        push_error("Stage not found: " + stage_id)
        return false
    
    if stage.trigger_by_exp:
        push_error("Stage '%s' is EXP-triggered, cannot manually trigger" % stage_id)
        return false
    
    triggered_manual_stages.append(stage_id)
    _check_stage_progression()
    return true
```

#### 2.5 Implement Delta-Based EXP (Optional)
```gdscript
# If incremental model is preferred:
# In _check_stage_progression():
if stage.trigger_by_exp:
    if exp_since_last_milestone >= stage.req_exp:
        exp_since_last_milestone -= stage.req_exp
    else:
        break
```

---

### Phase 3: Polish (Week 3-4)
**Goal:** Enhance UI and edge cases

#### 3.1 Improve Memory Order Handling
```gdscript
# Option A: Auto-sort by completion
func _update_memory_display_order() -> void:
    active_memories.sort_custom(func(a, b):
        var idx_a = _find_stage_unlock_index(a.id)
        var idx_b = _find_stage_unlock_index(b.id)
        return idx_a < idx_b
    )

# Option B: Keep MemoryOrder but validate consistency
func _validate_memory_order() -> void:
    var order_res = load(PATH_ORDERS + mode + "_memory_order.tres")
    if not order_res:
        push_warning("No memory order file for mode: " + mode)
        return
    
    for mem_id in order_res.ordered_memory_ids:
        if mem_id not in active_memories:
            push_warning("MemoryOrder references missing memory: " + mem_id)
```

#### 3.2 Add Cutscene Queueing for Multiple Unlocks
```gdscript
func _finalize_stage(stage: StageData) -> void:
    # First play stage cutscene
    if not stage.cutscene_id.is_empty():
        CutsceneManager.play(stage.cutscene_id)
    
    # Then play memory's cutscene if it has one
    if stage.memory_id and stage.memory_id in active_memories:
        var mem = active_memories[stage.memory_id]
        if not mem.cutscene_id.is_empty():
            CutsceneManager.play(mem.cutscene_id)
```

#### 3.3 Fix Torch Animation Race Conditions
```gdscript
# In torch_button.gd:
func refresh_visuals(is_unlocked = null) -> void:
    if not is_inside_tree():
        _pending_is_unlocked = is_unlocked
        return
    
    # Use tween to animate smoothly
    var tween = create_tween()
    if is_unlocked:
        tween.tween_property(self, "modulate", Color.WHITE, 0.3)
        animated_sprite.play("lit")
    else:
        tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.6), 0.3)
        animated_sprite.play("unlit")
```

---

## Implementation Checklist

### Phase 1: Stability
- [ ] Add `req_exp = 0` to all startup stage files
- [ ] Implement `_validate_resources()` function
- [ ] Add mode validation
- [ ] Test that startup cutscene doesn't double-play

### Phase 2: Architecture
- [ ] Add `trigger_by_exp` field to StageData
- [ ] Rename `unlocks_memory_id` → `memory_id` for clarity
- [ ] Add `completed_stage_index` tracking
- [ ] Implement `_finalize_stage()` method
- [ ] Implement `trigger_manual_stage()` API
- [ ] Test sequential locking with manual stages

### Phase 3: Polish
- [ ] Auto-sort memories or enhance MemoryOrder validation
- [ ] Add cutscene queueing for memory-stage chains
- [ ] Fix torch animation overlap issues
- [ ] Add debug visualization for stage progression

---

## Testing Strategy

### Unit Tests (per system)
```gdscript
# Test 1: Missing req_exp triggers immediately
assert(ProgressManager.current_exp == 0)
# Should NOT trigger cutscene

# Test 2: Sequential locking
ProgressManager.current_exp = 1000  # Beyond stage 3
assert(ProgressManager.completed_stage_index == 0)  # Only stage 0 finalized
# Wait for cutscenes...
assert(ProgressManager.completed_stage_index == 1)

# Test 3: Manual trigger blocked by order
var blocked = ProgressManager.trigger_manual_stage("stage_5")
assert(not blocked)  # Stages 1-4 not complete yet
```

### Integration Tests
```gdscript
# Test 4: Full progression sequence
ProgressManager.current_exp = 0
# (Startup cutscene plays and finishes)
await cutscene_finished
assert(mem_startup in unlocked_memory_ids)

# Test 5: Multiple stages in one exp gain
ProgressManager.current_exp = 500  # Reaches stages 0, 1, 2
await cutscene_queue_finished
assert(completed_stage_index == 2)
```

---

## Risk Assessment

| Component | Risk | Mitigation |
|-----------|------|-----------|
| Missing `req_exp` | HIGH - Immediate crash | Add validation + default values |
| Sequential locking | MEDIUM - Complex state | Extensive testing, design doc |
| Manual triggers | MEDIUM - New feature | Start with disabled-by-default |
| Delta EXP model | LOW - Opt-in | Implement in Phase 3 |
| Memory order | LOW - Display only | Keep dual systems for safety |

---

## Conclusion

The current system is **functional but limited**. The planned refactors in STAGE_SYSTEM_REFINEMENT.md are essential for:
1. **Supporting non-linear gameplay** (manual triggers, boss events)
2. **Better progression design** (delta-based EXP)
3. **Robust error handling** (validation, sequential locking)

**Recommendation:** Implement Phases 1 & 2 before adding content beyond 17+ stages. Phase 3 is nice-to-have polish.

**Estimated Timeline:**
- Phase 1: 3-4 hours
- Phase 2: 8-12 hours
- Phase 3: 4-6 hours
- Testing: 4-6 hours

**Total: ~24-32 hours (3-4 days of focused work)**
