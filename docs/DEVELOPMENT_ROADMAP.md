# Project Terminus - Development Roadmap
**Consolidated from planning documents | Updated: May 7, 2026**

---

## Current Status

### ✅ Completed (Phase 1 - Stability)
- Fixed missing `req_exp = 0` in all startup stages
- Added mode validation to ProgressManager
- Added resource validation (checks for broken references)
- Created comprehensive test suite

### 🔄 In Progress (Phase 2 - Memory System Unification)
**Goal:** Simplify memory ordering by auto-deriving from stage completion sequence
**Estimated Time:** 4-6 hours

---

## Phase 2: Memory System Unification

### Problem
- Memory Order (backpack display) is disconnected from stage progression
- Separate `MemoryOrder.tres` files can get out of sync with stages
- Manual triggers unnecessarily coupled to progression system

### Solution
Auto-derive memory order from stage completion sequence using existing `cutscene.tscn` for special events.

### Implementation Steps

#### 1. Update StageData Structure
```gdscript
# RENAME: unlocks_memory_id → memory_id
@export var memory_id: String = ""
```

#### 2. Add Auto-Build Function
```gdscript
# In ProgressManager._ready():
func _build_memory_order() -> void:
    memory_display_order = []
    for stage in active_stages:
        if stage.memory_id and stage.memory_id not in memory_display_order:
            memory_display_order.append(stage.memory_id)
```

#### 3. Update Backpack Display
- Use `memory_display_order` instead of reading `MemoryOrder.tres` files
- Torches auto-sort by completion order
- No separate ordering files needed

#### 4. Handle Special Events (Already Working)
- Use `cutscene.tscn` nodes in world for special triggers
- Independent of progression system
- No changes needed - already functional

### Files to Change (~32 total)
- `resources/data_structures/stage_data.gd` - 1 line rename
- `scripts/global/progress_manager.gd` - New function + one call
- All `resources/stages/*/*.tres` - Find/replace `unlocks_memory_id` → `memory_id` (~29 files)
- Backpack/torch display script - Reference `memory_display_order` instead of MemoryOrder file

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
