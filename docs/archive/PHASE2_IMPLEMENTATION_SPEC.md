# Phase 2 Implementation Specification
**Status:** AWAITING APPROVAL | **Estimated Time:** 4-6 hours

---

## Overview
Replace separate `MemoryOrder.tres` system with auto-derived ordering based on stage progression. Simplifies architecture and guarantees memory order stays in sync.

---

## Implementation Checklist

### Step 1: Update StageData Class ⏳
**File:** `resources/data_structures/stage_data.gd`
**Change Type:** Field rename (1 line)

```gdscript
# BEFORE:
@export var unlocks_memory_id: String

# AFTER:
@export var memory_id: String
```

**Impact:** No functional change - just clearer naming

---

### Step 2: Add Auto-Build Function to ProgressManager ⏳
**File:** `scripts/global/progress_manager.gd`
**Change Type:** New function + one call

```gdscript
# Add this variable at top with other state variables:
var memory_display_order: Array[String] = []

# Add this function in "Validation Functions" section:
func _build_memory_order() -> void:
    """Auto-derive memory display order from stage progression sequence."""
    memory_display_order.clear()
    for stage in active_stages:
        if stage.memory_id and stage.memory_id not in memory_display_order:
            memory_display_order.append(stage.memory_id)

# Add this call in _ready() after validation:
_build_memory_order()
```

**Impact:** Memories now auto-sort by stage completion order

---

### Step 3: Migrate All Stage Files ⏳
**Files:** All `resources/stages/*/*.tres` (~29 files)
**Change Type:** Find/replace field name

**Command:**
```bash
# Find all occurrences:
unlocks_memory_id

# Replace with:
memory_id
```

**Affected Stages:**
- `resources/stages/test/*.tres` (4 files)
- `resources/stages/trial/*.tres` (10 files)
- `resources/stages/full/*.tres` (15 files)

**Validation:** After migration, verify no files still contain `unlocks_memory_id`

---

### Step 4: Update ProgressManager References ⏳
**File:** `scripts/global/progress_manager.gd`
**Change Type:** Update field reference

```gdscript
# In _check_stage_progression(), change:
if stage.unlocks_memory_id:
    collect_memory(stage.unlocks_memory_id)

# TO:
if stage.memory_id:
    collect_memory(stage.memory_id)
```

Also update `_validate_resources()`:

```gdscript
# Change:
if stage.unlocks_memory_id and stage.unlocks_memory_id not in active_memories:

# TO:
if stage.memory_id and stage.memory_id not in active_memories:
```

**Impact:** Progression now uses new field name

---

### Step 5: Update Backpack/Torch Display ⏳
**File:** (likely in GUI manager or backpack script)
**Change Type:** Update memory ordering source

```gdscript
# OLD: Read from MemoryOrder file
var order_res = load(order_path) as MemoryOrder
for mem_id in order_res.ordered_memory_ids:
    # display...

# NEW: Read from ProgressManager
for mem_id in ProgressManager.memory_display_order:
    # display...
```

**Note:** If backpack instantiates torches dynamically:
```gdscript
# Ensure torches use memory_display_order for sorting
var torches = []
for mem_id in ProgressManager.memory_display_order:
    var torch = instantiate_torch(mem_id)
    torches.append(torch)
```

---

### Step 6: Testing & Validation ⏳
**What to Test:**

1. **Memory Order Correctness**
   - Unlock memory in stage order
   - Verify `memory_display_order` array matches
   - Confirm backpack displays in correct order

2. **Progression Still Works**
   - Run `test_phase1_validation.gd`
   - All tests should pass

3. **Special Events Independent**
   - Test cutscene.tscn triggers work
   - Verify they don't affect `current_stage_index`
   - Confirm special memories unlock as expected

4. **No Regressions**
   - All existing cutscenes play
   - No new errors in console
   - Save/load unaffected (if implemented)

**Test Script to Create:** (optional)
```gdscript
# Verify memory_display_order auto-builds
assert(ProgressManager.memory_display_order.size() > 0)

# Verify order matches stage progression
for i in range(ProgressManager.memory_display_order.size()):
    var mem_id = ProgressManager.memory_display_order[i]
    assert(mem_id != "")
    print("Memory %d: %s" % [i, mem_id])
```

---

### Step 7: Documentation Update ⏳
**Files to Update:**

1. **docs/ARCHITECTURE.md**
   - Remove mentions of separate MemoryOrder system
   - Document auto-derived ordering
   - Add diagram: Stage → Memory Order (automatic)

2. **README.md**
   - Update "Memory Collection Design" section
   - Clarify `memory_id` replaces `unlocks_memory_id`
   - Note: Order is automatic, no separate files needed

3. **docs/BUGS_ARCHIVED.md**
   - Update Bug 3 note about memory unlocking
   - Mention field rename in Phase 2 fix

4. **Delete/Archive:**
   - `STAGE_MEMORY_SYSTEM_ANALYSIS.md` (old analysis, can archive)
   - Keep `MASTER_ROADMAP.md` and `REFACTOR_PROPOSAL_UNIFIED.md` for reference
   - Keep `PHASE1_IMPLEMENTATION_SUMMARY.md` (completed work)

---

## Before/After Code Example

### Before (Fragile)
```gdscript
# Stage definition
req_exp = 100
unlocks_memory_id = "mem_tutorial"

# Separate file: test_memory_order.tres
ordered_memory_ids = ["mem_startup", "mem_tutorial", "mem_ending"]

# Result: Chance of mismatch
```

### After (Unified)
```gdscript
# Stage definition only
req_exp = 100
memory_id = "mem_tutorial"

# In ProgressManager:
memory_display_order = []
for stage in active_stages:
    if stage.memory_id:
        memory_display_order.append(stage.memory_id)

# Result: Always in sync
```

---

## File Impact Summary

| File | Lines Changed | Type | Notes |
|------|--------------|------|-------|
| `stage_data.gd` | 1 | Rename | Field name only |
| `progress_manager.gd` | ~15 | Add/Update | New function + field refs |
| Stage resources | 1 line each | Replace | ~29 files, simple rename |
| Backpack display | ~5 | Update | Use new ordering array |
| Docs | ~20 | Update | Document new approach |

**Total Changes:** ~70 lines across ~35 files

---

## Rollback Plan (If Needed)

If issues occur, revert:
1. Field name back: `memory_id` → `unlocks_memory_id`
2. Remove `_build_memory_order()` function
3. Restore MemoryOrder file reading logic
4. Update backpack to read from file again

**Estimated rollback time:** 30 minutes

---

## Success Criteria

- ✅ All 29 stage files successfully migrated
- ✅ `test_phase1_validation.gd` still passes
- ✅ Memory order auto-derives correctly
- ✅ Backpack displays torches in order
- ✅ No console errors at startup
- ✅ No regression in existing systems
- ✅ Documentation updated

---

## Open Questions for Approval

1. **Keep MemoryOrder files as backup?**
   - Option A: Delete them (cleaner)
   - Option B: Keep but ignore (safer)
   - Recommendation: Delete (system now auto-generates)

2. **Update backpack in Phase 2 or later?**
   - Option A: Do it now (complete system)
   - Option B: Do it later (minimal changes first)
   - Recommendation: Now (only ~5 line change)

3. **Test scope?**
   - Option A: Full test suite
   - Option B: Manual testing only
   - Recommendation: Both (create automated test for ordering)

---

## Timeline Breakdown

- **Planning & Design:** 1 hour ✅ (done)
- **Implementation:** 2-3 hours
  - Field rename: 30 min
  - Code changes: 1.5 hrs
  - Testing: 1 hour
- **Documentation:** 1 hour
- **Buffer:** 30 min
- **Total:** 4-6 hours

---

**Ready to implement?** Await your approval on:
- [ ] Approach (auto-derive memory order)
- [ ] Keep/delete MemoryOrder files
- [ ] Timeline (4-6 hours)
- [ ] Proceed with Phase 2

