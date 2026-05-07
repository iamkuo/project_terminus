# Stage & Memory System Refactor - Consolidated Plan
**Date:** May 7, 2026 | **Status:** PROPOSAL (Awaiting Approval)

---

## Problem Statement

**Current Issues:**
1. **Memory Order Disconnected from Progression** - Separate `MemoryOrder.tres` files can get out of sync with stage progression
2. **Duplicate Authority** - Both stages and MemoryOrder define memory ordering
3. **Manual Triggers Coupled to Progression** - Original plan tied manual cutscenes to progression system
4. **Over-engineered Sequential Locking** - Planned complex state management not needed (cutscenes already handle manual sequencing)

**Design Insight:** Cutscenes already handle manual triggering via `cutscene.tscn` world objects. Progression should focus on EXP-driven content only.

---

## Proposed Unified Solution

### Core Principle: Single Source of Truth
**Memory order derives automatically from Stage progression sequence**, eliminating the need for separate `MemoryOrder` files.

### Key Changes

#### 1. Simplify Memory Ordering (NEW APPROACH)
**Current (Fragile):**
- Stages have `unlocks_memory_id` field
- Separate `MemoryOrder.tres` defines display order
- Can be out of sync

**Proposed (Unified):**
- Stages have `memory_id` field (renamed from `unlocks_memory_id`)
- Memory display order = Stage completion order (no separate files needed)
- If designer wants non-linear order: manually create stages in desired sequence

**Implementation:**
```gdscript
# In ProgressManager._ready():
# Auto-sort memories by their stage unlock order
func _build_memory_order() -> void:
    memory_display_order = []  # Array of memory IDs in display order
    
    for stage in active_stages:
        if stage.memory_id and stage.memory_id not in memory_display_order:
            memory_display_order.append(stage.memory_id)
```

**Benefit:** No separate resource files to maintain; memory order is self-evident.

---

#### 2. Update StageData Structure
**Remove:** `trigger_by_exp` (only EXP-based progression for now)
**Rename:** `unlocks_memory_id` → `memory_id` (clearer naming)
**Keep:** `id`, `name`, `req_exp`, `cutscene_id`

```gdscript
# resources/data_structures/stage_data.gd
extends Resource
class_name StageData

@export var id: String
@export var name: String
@export var req_exp: int = 0
@export var cutscene_id: String = ""
@export var memory_id: String = ""  # Renamed, optional
```

**Minimal Changes:** Only rename field (backward compatible via migration script if needed)

---

#### 3. Simplified ProgressManager
**Remove complexity:**
- No `trigger_by_exp` field checking
- No `completed_stage_index` vs `current_stage_index` split
- No manual trigger queue system

**Keep it simple:**
- `current_exp` → triggers `_check_stage_progression()`
- Loop through stages, check if `current_exp >= req_exp`
- Unlock memory (if any) and play cutscene
- Done

**Result:** Less state, fewer bugs, easier to understand.

---

#### 4. Handle Non-Linear Content (Already Solved)
**Approach:** Use `cutscene.tscn` world objects for special events
- Place cutscene nodes in world
- When player triggers: `CutsceneManager.play(script_id)`
- Cutscene can do anything: trigger exp gains, special dialogs, etc.
- **Progression system doesn't need to know about it**

**Example:**
```
World Layout:
├─ Player
├─ Normal Stage 3 Trigger (exp-driven)
├─ Boss Trigger (cutscene.tscn)
│  └─ Plays "boss_cutscene" on contact
│     └─ Can grant exp/rewards independently
└─ Mystery Event Trigger (cutscene.tscn)
   └─ Plays special event regardless of exp level
```

**Benefit:** Separates concerns - progression = EXP, special events = cutscenes.

---

## Implementation Phases

### Phase 1: Stability ✅ (COMPLETE)
- [x] Fixed missing `req_exp` in startup stages
- [x] Added mode validation
- [x] Added resource validation

### Phase 2: Unified Memory System (NEW - 4-6 HOURS)

**Step 1: Rename field in StageData**
- Change `unlocks_memory_id` → `memory_id` in class definition
- Update validation logic
- Create migration guide for existing stages

**Step 2: Auto-build memory order**
- Add `_build_memory_order()` function
- Call in `_ready()` after loading stages
- Populate `memory_display_order: Array[String]`

**Step 3: Update torch display logic**
- Torches loop through `memory_display_order` (not separate MemoryOrder file)
- Sort torches by this order automatically
- **Remove dependency on `MemoryOrder.tres` files**

**Step 4: Migrate existing data**
- Update all stage files: `unlocks_memory_id` → `memory_id`
- Verify MemoryOrder files are no longer needed
- Optional: Delete MemoryOrder files after validation

**Step 5: Documentation**
- Update architecture docs
- Add notes about cutscene-based special events
- Remove manual trigger docs

**Testing:**
- Run `test_phase1_validation.gd` - should still pass
- Test progression: exp gains unlock memories in order
- Test backpack: torches display in completion order
- Test special event: cutscene.tscn trigger works independently

---

## Architecture Diagram

### Before (Current - Fragile)
```
Stage Progression          Memory Display
      ↓                          ↓
active_stages ←----X----→ MemoryOrder.tres
  (unordered)     (can be out of sync)
      ↓                          ↓
Collect memory_id          Display in order
      ?                          ?
```

### After (Proposed - Unified)
```
Stage Progression (Single Source of Truth)
      ↓
active_stages (sorted by req_exp)
      ↓
For each stage:
  - Unlock memory_id
  - Add to memory_display_order (auto)
      ↓
Backpack displays in memory_display_order
      ↓
✓ Always in sync
✓ No separate files
✓ Self-evident order
```

---

## File Changes Summary

| File | Type | Change |
|------|------|--------|
| `resources/data_structures/stage_data.gd` | SCRIPT | Rename `unlocks_memory_id` → `memory_id` |
| `scripts/global/progress_manager.gd` | SCRIPT | Add `_build_memory_order()`, use it in `_ready()` |
| All `resources/stages/*/*.tres` | RESOURCES | Rename field `unlocks_memory_id` → `memory_id` (~29 files) |
| `resources/memories/orders/*.tres` | RESOURCES | **NO LONGER NEEDED** - can be deleted |
| `torch_button.gd` or backpack logic | SCRIPT | Read `memory_display_order` instead of MemoryOrder file |

---

## Benefits

| Aspect | Current | Proposed |
|--------|---------|----------|
| **Source of Truth** | Dual (stages + MemoryOrder) | Single (stages only) |
| **Sync Risk** | High | None (automatic) |
| **Special Events** | Unclear, mixed with progression | Clear (cutscene.tscn nodes) |
| **Complexity** | High | Low |
| **Files to Maintain** | Many | Fewer |
| **Bugs** | Fragile | Robust |

---

## Examples

### Example 1: Normal Progression
```
Stage 0 (req_exp=0, memory_id="mem_startup")
  ↓ Player starts, exp=0 triggers
Unlock "mem_startup"
  ↓ Torch 1 shows
Play "startup_intro" cutscene

Stage 1 (req_exp=100, memory_id="mem_tutorial")
  ↓ Player gains exp to 100
Unlock "mem_tutorial"
  ↓ Torch 2 shows
Play "tutorial_cutscene"
```

### Example 2: Special Event (via cutscene.tscn)
```
In world: cutscene.tscn node with script_id="mysterious_event"
  ↓ Player walks into trigger
CutsceneManager.play("mysterious_event")
  ↓ Cutscene runs
Cutscene can grant exp, unlock special memories, etc.
  ↓ Independent of progression system
Does NOT affect current_stage_index (progression independent)
```

---

## Migration Guide (Optional)

If existing stages use `unlocks_memory_id`:

```gdscript
# One-time migration script
for each stage_file in resources/stages/:
    Replace field: unlocks_memory_id → memory_id
```

All 29 existing stage files already have the data, just field name changes.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| Breaking existing stages | High | Simple field rename, easy to validate |
| Backpack sorting breaks | Medium | Add extensive tests |
| Cutscenes not working | Low | Already working, no changes |
| Memory order unexpected | Low | Clear auto-sort rules documented |

---

## Approval Checklist

Before implementation, confirm:

- [ ] Remove manual trigger complexity (yes - handled by cutscene.tscn)
- [ ] Auto-derive memory order from stages (yes - single source of truth)
- [ ] Simplify ProgressManager (yes - less state)
- [ ] Cutscene-based special events as alternative (yes - already working)
- [ ] Estimate 4-6 hours for Phase 2 (yes - simple field rename + auto-sort)
- [ ] Update docs to reflect new design (yes)

---

## Next Steps

1. **Get Approval** - Confirm design approach above
2. **Estimate Time** - 4-6 hours (vs 8-12 hours originally planned)
3. **Implement Phase 2** - Field renames + auto-ordering
4. **Test & Validate** - Ensure backpack ordering works
5. **Document** - Update ARCHITECTURE.md and README.md

---

## Questions for Approval

1. ✅ Is auto-deriving memory order from stage progression acceptable?
2. ✅ Should we delete the `MemoryOrder.tres` files after migration?
3. ✅ Is cutscene-based special events the right approach for non-linear content?
4. ✅ Estimated timeline: 4-6 hours for Phase 2 - acceptable?

---

**Status:** AWAITING APPROVAL

