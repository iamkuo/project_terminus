# Project Terminus - Development Roadmap
**Consolidated from planning documents | Updated: May 7, 2026**

---

## Current Status

### ✅ Completed (Phase 1 - Stability)
- Fixed missing `req_exp = 0` in all startup stages
- Added mode validation to ProgressManager
- Added resource validation (checks for broken references)
- Created comprehensive test suite

### ✅ In Progress (Phase 2 - Enhanced Memory Order System)
**Goal:** Fix memory order sync issues while supporting special event insertion
**Estimated Time:** 6-8 hours

**Recent Bug Fixes:**
- Fixed TypedArray find() error in validation function
- Corrected memory ID mismatch in test_memory_order.tres
- Validation now properly checks memory references

---

## Phase 2: Enhanced Memory Order System

### Current Problems
- **Sync Risk**: Stage memories and MemoryOrder.tres can get out of sync
- **Limited Special Events**: Special memories can't insert at specific narrative points
- **Missing Validation**: No checks for memory order consistency

### Solution: Enhanced MemoryOrder System
Keep MemoryOrder system but add validation and better sync with stages. Special events are supported by adding memories directly to MemoryOrder files.

### Implementation Steps

#### 1. Update StageData Structure
```gdscript
# RENAME: unlocks_memory_id → memory_id (for clarity)
@export var memory_id: String = ""
```

#### 2. Add Memory Order Validation
```gdscript
# In ProgressManager:
func _validate_memory_order() -> void:
    var order_res = load(PATH_ORDERS + mode + "_memory_order.tres") as MemoryOrder
    if not order_res:
        push_error("Missing MemoryOrder file for mode: " + mode)
        return
    
    # Check all memories in order exist
    for mem_id in order_res.ordered_memory_ids:
        if mem_id not in active_memories:
            push_warning("MemoryOrder references missing memory: " + mem_id)
    
    # Check all stage memories are included
    for stage in active_stages:
        if stage.memory_id and stage.memory_id not in order_res.ordered_memory_ids:
            push_warning("Stage memory not in MemoryOrder: " + stage.memory_id)
```

#### 3. Enhanced Special Event Support
- Special events via `cutscene.tscn` unlock memories normally
- **MemoryOrder controls WHERE special memories appear** - just add them to the ordered list
- Designers have full control over narrative sequence

#### 4. Example MemoryOrder Usage
```gdscript
# In trial_memory_order.tres:
ordered_memory_ids = [
    "mem_startup",           # Stage 0 memory
    "mem_boss_secret",       # Special event memory (inserted here)
    "mem_mini_level",        # Stage 1 memory
    "mem_open_world",        # Stage 2 memory
    "mem_mystery_event",     # Special event memory (inserted here)
    "mem_first_village"      # Stage 3 memory
]
```

### Files to Change (~30 total)
- `resources/data_structures/stage_data.gd` - 1 line rename
- `scripts/global/progress_manager.gd` - Add validation function
- All `resources/stages/*/*.tres` - Find/replace `unlocks_memory_id` → `memory_id` (~29 files)
- No changes needed to backpack - it already uses MemoryOrder correctly

---

## Future Development Priorities

### 1. Core Systems & Persistence
- **Save/Load System**
  - Player Stats (`crystal_count`, `current_exp`)
  - Collection Progress (`unlocked_memory_ids`)
  - Skill Upgrades (`player_skill_levels`)
- **Settings Persistence**
  - Audio levels and display settings to `config.cfg`

### 2. Content Expansion
- **Skill Tree**: Expand from 3 to 10-15 unique skills
- **Narrative Arc**: Ensure all 17+ cutscenes form cohesive story
- **Map Variety**: Create distinct zones (Whispering Forest, Industrial Capital, etc.)
- **Enemy Diversity**: New unit types (Tank, Support, Artillery)

### 3. UI/UX & Polish
- **Tutorial & Onboarding**: Guided "Prologue" stage
- **Audio Expansion**: Unique tracks for exploration, combat, menus
- **Visual Effects**: Combat particles, environmental polish
- **HUD Improvements**: Better feedback for experience and memory collection

### 4. Technical Debt
- **Manager Decoupling**: Reduce tight coupling between systems
- **Performance Tuning**: Optimize `main_world.tscn` loading
- **Resource Validation**: Implement comprehensive resource checking

---

## Architecture Overview

### Current System Flow
```
ProgressManager (Autoload)
├── active_stages: Array[StageData]     [Sorted by req_exp]
├── active_memories: Array[MemoryData]   
├── current_stage_index: int             
├── current_exp: int                     [Triggers progression]
└── unlocked_memory_ids: Array[String]   [Collected memories]
```

### Data Structures
**StageData**
```gdscript
@export var id: String
@export var name: String
@export var req_exp: int = 0
@export var cutscene_id: String = ""
@export var memory_id: String = ""        # Will be renamed from unlocks_memory_id
```

**MemoryData**
```gdscript
@export var id: String
@export var name: String
@export var description: String
@export var cutscene_id: String = ""
@export var icon: Texture2D
```

---

## Testing Strategy

### Phase 2 Validation
- ✓ Progression unlocks memories in stage order
- ✓ Backpack displays torches in completion order
- ✓ Special event triggers work independently
- ✓ No regression in existing systems

### Test Commands
```gdscript
# Run validation test:
# Add test_phase1_validation.gd as autoload or run manually
# Expected: All tests pass, no console errors
```

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|-----------|
| Field rename breaks stages | LOW | Simple rename, easy to validate |
| Backpack sort breaks | LOW | Extensive testing |
| Special events fail | VERY LOW | Already working, no changes |
| Save/load issues | NONE | No save system yet |

---

## Next Steps

1. **Complete Phase 2** - Implement memory system unification (4-6 hours)
2. **Test Thoroughly** - Full validation suite
3. **Update Documentation** - Remove old planning docs
4. **Begin Content Expansion** - Skills, maps, enemies
5. **Implement Persistence** - Save/load system

---

## File Organization (After Cleanup)

### Keep
- `DEVELOPMENT_ROADMAP.md` (this file - consolidated roadmap)
- `ARCHITECTURE.md` (system architecture)
- `RESOURCES.md` (asset documentation)

### Archive/Remove
- `MASTER_ROADMAP.md` (superseded by this file)
- `ROADMAP.md` (superseded by this file)
- `PHASE1_IMPLEMENTATION_SUMMARY.md` (completed, info integrated here)
- `PHASE2_IMPLEMENTATION_SPEC.md` (superseded by this file)
- `REFACTOR_PROPOSAL_UNIFIED.md` (superseded by this file)
- `STAGE_MEMORY_SYSTEM_ANALYSIS.md` (superseded by this file)
- `STAGE_SYSTEM_REFINEMENT.md` (superseded by this file)
- `PROPOSAL_CHECKLIST.md` (completed)
- `APPROVAL_REQUIRED.md` (completed)
- `ARCHITECTURE_COMPARISON_VISUAL.md` (reference only)
- `BUGS_ARCHIVED.md` (reference only)

### Test Files (Move to tests/ directory)
- `test_phase1_validation.gd`
- `test_game_modes.gd`

---

**Status:** Ready to proceed with Phase 2 implementation
**Questions:**
- Approve simplified memory ordering approach?
- Timeline of 4-6 hours acceptable?
- Keep any old planning docs as reference?
