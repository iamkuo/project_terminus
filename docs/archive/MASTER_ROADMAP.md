# Stage & Memory System Refactor - Master Roadmap
**Project Terminus** | **Date:** May 7, 2026

---

## TL;DR: The Problem & Solution

**Problem:** Memory Order (backpack display) is disconnected from stage progression, causing potential sync issues. Manual triggers unnecessarily coupled to progression system.

**Solution:** Auto-derive memory order from stage completion sequence. Use `cutscene.tscn` for special events (already working). Simplified, single-source-of-truth design.

**Timeline:** Phase 1 ✅ DONE (4 hrs) | Phase 2 → 4-6 hrs | Total refactor: ~10 hours

---

## Phase 1: Stability ✅ COMPLETE

### What Was Done
1. ✅ Fixed missing `req_exp = 0` in all 3 startup stages
2. ✅ Added mode validation to ProgressManager
3. ✅ Added resource validation (checks for broken references)
4. ✅ Created comprehensive test suite

### Files Changed
- `scripts/global/progress_manager.gd` - Added `_validate_mode()` and `_validate_resources()`
- `resources/stages/*/startup.tres` - Added `req_exp = 0` (3 files)
- `test_phase1_validation.gd` - New test script

### Result
System now validates on startup, preventing silent failures.

---

## Phase 2: Unified Memory System (PROPOSED)

### Core Changes

**1. Simplify StageData**
```gdscript
# RENAME: unlocks_memory_id → memory_id
@export var memory_id: String = ""
```

**2. Auto-Build Memory Order**
```gdscript
# In ProgressManager._ready():
func _build_memory_order() -> void:
    memory_display_order = []
    for stage in active_stages:
        if stage.memory_id and stage.memory_id not in memory_display_order:
            memory_display_order.append(stage.memory_id)
```

**3. Update Backpack Display**
- Use `memory_display_order` instead of reading `MemoryOrder.tres` file
- Torches auto-sort by completion order
- No separate ordering files needed

**4. Handle Special Events (Already Working)**
- Use `cutscene.tscn` nodes in world for special triggers
- Example: Boss trigger, mystery events, etc.
- Independent of progression system
- No changes needed - already functional

### Implementation Steps
1. Rename field in `stage_data.gd`
2. Add `_build_memory_order()` in `progress_manager.gd`
3. Update torch/backpack logic to use `memory_display_order`
4. Migrate all 29 stage files (field rename)
5. Test and validate

### Files to Change (~32 files total)
- `resources/data_structures/stage_data.gd` - 1 line rename
- `scripts/global/progress_manager.gd` - New function + one call
- All `resources/stages/*/*.tres` - Find/replace `unlocks_memory_id` → `memory_id` (~29 files)
- Backpack/torch display script - Reference `memory_display_order` instead of MemoryOrder file

### Testing
```gdscript
✓ Progression unlocks memories in stage order
✓ Backpack displays torches in completion order
✓ Special event triggers work independently
✓ No regression in existing systems
```

### Estimate: 4-6 hours
- Field rename: 1 hour
- Code changes: 2 hours
- Testing & validation: 1-2 hours
- Documentation: 1 hour

---

## Architecture

### Before (Fragile)
```
Stages (progression driver)
      ↓
unlocks_memory_id field
      ↓
Compared against MemoryOrder.tres
      ↓
X Possible sync issues
```

### After (Unified)
```
Stages (single source of truth)
      ↓
Sorted by req_exp
      ↓
Stage 1 → memory_id="mem_A"
Stage 2 → memory_id="mem_B"
Stage 3 → memory_id="mem_C"
      ↓
Auto-build memory_display_order = [mem_A, mem_B, mem_C]
      ↓
✓ Always in sync, automatic
```

### Special Events (Separate)
```
cutscene.tscn nodes in world
      ↓
Player triggers
      ↓
CutsceneManager.play(script_id)
      ↓
Independent of progression
✓ Can grant exp, unlock memories, etc.
✓ No impact on stage progression
```

---

## Comparison: Original Plan vs Proposed

| Aspect | Original Plan | Proposed |
|--------|---------------|----------|
| **Manual Triggers** | Complex system with `trigger_by_exp` field | Removed - use cutscene.tscn |
| **Memory Ordering** | Separate MemoryOrder files + validation | Auto-derived from stages |
| **Sequential Locking** | Complex `completed_stage_index` tracking | Unnecessary - cutscenes handle sequencing |
| **Complexity** | High | Low |
| **Implementation** | ~12 hours | ~4-6 hours |
| **Special Events** | Coupled to progression | Independent (cutscene.tscn) |

---

## Quick Reference: What Stays, What Changes

### No Changes Needed
- ✓ `CutsceneManager` - Already robust
- ✓ `cutscene.tscn` world objects - Already work
- ✓ Battle system - Unaffected
- ✓ Skill system - Unaffected
- ✓ Phase 1 validation - Already in place

### Minimal Changes
- 1-2 lines per script: field renames
- New function: `_build_memory_order()` (~10 lines)
- Migration: Simple find/replace across 29 files

### Removed Complexity
- ❌ `trigger_by_exp` field (not needed)
- ❌ `completed_stage_index` tracking (not needed)
- ❌ Manual trigger API (use cutscene.tscn instead)
- ❌ Sequential locking validation (not needed)

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|-----------|
| Field rename breaks stages | LOW | Simple rename, easy to validate |
| Backpack sort breaks | LOW | Extensive testing |
| Special events fail | VERY LOW | Already working, no changes |
| Save/load issues | NONE | No save system yet |

---

## Approval Checklist

✅ = Ready to approve  
⏳ = Awaiting feedback

| Item | Status |
|------|--------|
| Remove manual trigger complexity? | ⏳ |
| Auto-derive memory order from stages? | ⏳ |
| Use cutscene.tscn for special events? | ⏳ |
| Estimated 4-6 hours acceptable? | ⏳ |
| Proceed with Phase 2 implementation? | ⏳ |

---

## Command Summary

Once approved, run these commands in order:

```bash
# 1. Run Phase 1 tests (should all pass)
# 2. Implement field rename in stage_data.gd
# 3. Add _build_memory_order() to progress_manager.gd
# 4. Migrate all 29 stage files (find/replace)
# 5. Update torch/backpack display logic
# 6. Run full test suite
# 7. Update documentation
```

---

## Documentation References

- **Current Analysis:** `STAGE_MEMORY_SYSTEM_ANALYSIS.md` (detailed, pre-Phase 1)
- **Phase 1 Summary:** `PHASE1_IMPLEMENTATION_SUMMARY.md` (completed work)
- **This Roadmap:** `REFACTOR_PROPOSAL_UNIFIED.md` (approval needed)
- **Architecture:** See `docs/ARCHITECTURE.md` (update after Phase 2)

---

## Next Steps

1. **Review & Approve** - Confirm approach above
2. **Implement Phase 2** - Estimated 4-6 hours
3. **Test Thoroughly** - Full validation suite
4. **Update Docs** - Remove original planning docs after completion
5. **Ready for Expansion** - Can easily add new stages/memories afterward

---

**Status:** ⏳ AWAITING YOUR APPROVAL

**Questions:**
- Approve this approach?
- Want to adjust the timeline?
- Any concerns about removing manual trigger system?
- Should we keep MemoryOrder files as backup or delete them?

