# Visual Architecture Comparison
**Problem & Solution at a Glance**

---

## CURRENT SYSTEM (Fragile - Memory Order Disconnected)

```
┌─────────────────────────────────────┐
│   Stage Progression System          │
├─────────────────────────────────────┤
│                                     │
│  active_stages (sorted by req_exp)  │
│  ├─ Stage 0: mem_startup            │
│  ├─ Stage 1: mem_tutorial           │
│  └─ Stage 2: mem_ending             │
│                                     │
│  When exp >= req_exp:               │
│  ├─ Collect memory_id               │
│  ├─ Play cutscene                   │
│  └─ Emit signal                     │
│                                     │
└─────────────────────────────────────┘
                    │
                    ├──────────────────────┐
                    ↓                      ↓
            ┌──────────────┐     ┌────────────────────┐
            │ Backpack UI  │     │ MemoryOrder.tres   │
            ├──────────────┤     ├────────────────────┤
            │ Torch 1      │     │ [mem_startup,      │
            │ Torch 2      │     │  mem_ending,       │  ← POSSIBLE
            │ Torch 3      │     │  mem_tutorial]     │    MISMATCH!
            └──────────────┘     └────────────────────┘
                    │
                    └─ ✗ Synced by convention, not guaranteed
```

**Problem:** Two systems define order independently. Can get out of sync.

---

## PROPOSED SYSTEM (Unified - Single Source of Truth)

```
┌──────────────────────────────────────────────────────┐
│   Unified Stage-Memory System                        │
├──────────────────────────────────────────────────────┤
│                                                      │
│  active_stages (sorted by req_exp)                   │
│  ├─ Stage 0: memory_id = "mem_startup"              │
│  ├─ Stage 1: memory_id = "mem_tutorial"             │
│  └─ Stage 2: memory_id = "mem_ending"               │
│                                                      │
│  In _ready():                                        │
│  memory_display_order = []                           │
│  for stage in active_stages:                         │
│      memory_display_order.append(stage.memory_id)   │
│                                                      │
│  Result: [mem_startup, mem_tutorial, mem_ending]    │
│                                                      │
└──────────────────────────────────────────────────────┘
                    │
                    ↓
        ┌──────────────────────┐
        │    Backpack UI       │
        ├──────────────────────┤
        │ Torch 1 (mem_startup)    │
        │ Torch 2 (mem_tutorial)   │
        │ Torch 3 (mem_ending)     │
        └──────────────────────┘
                    │
                    └─ ✓ Always in sync (auto-derived)
```

**Benefit:** One system, always synchronized automatically.

---

## Special Events (Independent System)

```
┌────────────────────────────────────────┐
│ World Objects (cutscene.tscn nodes)    │
├────────────────────────────────────────┤
│                                        │
│  Cutscene Trigger 1                    │
│  ├─ script_id = "boss_encounter"       │
│  ├─ Player walks in                    │
│  └─ CutsceneManager.play("boss...")    │
│                                        │
│  Cutscene Trigger 2                    │
│  ├─ script_id = "mystery_event"        │
│  ├─ Player finds it                    │
│  └─ CutsceneManager.play("mystery...")│
│                                        │
└────────────────────────────────────────┘
                    │
                    ├──────────────────────────┐
                    ↓                          ↓
        ┌──────────────────┐     ┌──────────────────┐
        │ Play Cutscene    │     │ Update Exp/      │
        │ & Show Dialog    │     │ Unlock Memory    │
        └──────────────────┘     └──────────────────┘
                    │                      │
                    └──────────┬───────────┘
                               ↓
                    Independent of Stage
                    Progression System
                    ✓ Can unlock memories
                    ✓ Can grant exp
                    ✓ Can trigger cutscenes
                    ✓ NO effect on current_stage_index
```

**Benefit:** Separate concern from progression; gives full creative freedom.

---

## Data Flow Comparison

### BEFORE (Current - Problem)
```
current_exp += 10
       ↓
if current_exp >= stage.req_exp:
    collect_memory(stage.unlocks_memory_id)
       ↓
Check separate MemoryOrder.tres file
       ↓
Display in backpack
       ↓
??? What if MemoryOrder has different order?
```

### AFTER (Proposed - Solution)
```
current_exp += 10
       ↓
if current_exp >= stage.req_exp:
    collect_memory(stage.memory_id)
       ↓
memory_id is already in memory_display_order
       ↓
Display in backpack in memory_display_order sequence
       ↓
✓ Always correct by design
```

---

## File Dependencies

### BEFORE (Complex)
```
StageData.tres files
    ├─ unlocks_memory_id
    └─ → MemoryOrder.tres  ← Separate file
         └─ ordered_memory_ids
              └─ → BackpackUI (reads both places)
```

### AFTER (Simple)
```
StageData.tres files
    ├─ memory_id
    └─ → ProgressManager
         ├─ Builds memory_display_order
         └─ → BackpackUI (reads memory_display_order)
```

---

## Change Impact Matrix

| Component | Before | After | Changes |
|-----------|--------|-------|---------|
| **StageData** | `unlocks_memory_id` | `memory_id` | 1 field rename |
| **ProgressManager** | No auto-sort | Auto-builds order | +1 function |
| **Stage Files** | 29 files | 29 files | Field rename only |
| **MemoryOrder.tres** | 3 files | Not needed | Delete/ignore |
| **BackpackUI** | Reads MemoryOrder | Reads memory_display_order | ~5 lines |
| **Code Complexity** | High | Low | Reduced |
| **Sync Issues** | Possible | Impossible | Eliminated |

---

## Memory Life Cycle

### Stage 0: Startup (req_exp = 0)
```
Game loads:
  current_exp = 0
  ↓
_check_stage_progression():
  0 >= 0? YES
  ↓
  memory_id = "mem_startup"
  ↓
  memory_display_order = ["mem_startup"]
  ↓
  Backpack shows 1 torch (lit)
```

### Stage 1: Tutorial (req_exp = 100)
```
Player gains exp:
  current_exp = 100
  ↓
_check_stage_progression():
  100 >= 100? YES
  ↓
  memory_id = "mem_tutorial"
  ↓
  memory_display_order = ["mem_startup", "mem_tutorial"]
  ↓
  Backpack shows 2 torches (both lit)
```

### Stage 2: Boss (req_exp = 200)
```
Player gains exp:
  current_exp = 200
  ↓
_check_stage_progression():
  200 >= 200? YES
  ↓
  memory_id = "mem_boss"
  ↓
  memory_display_order = ["mem_startup", "mem_tutorial", "mem_boss"]
  ↓
  Backpack shows 3 torches (all lit)
  
✓ Order is always: completion sequence
✓ Automatic, no separate files
✓ Guaranteed in sync
```

### Special Event: Mystery Quest (Any time)
```
Player finds cutscene.tscn trigger:
  script_id = "mystery_event"
  ↓
CutsceneManager.play("mystery_event")
  ↓
  Play dialog + effects
  ↓
  Cutscene grants exp: current_exp += 50 (optional)
  ↓
  Can also unlock special memory:
    ProgressManager.collect_memory("mem_mystery")
  ↓
  Does NOT advance current_stage_index
  ✓ Independent of progression
  ✓ Creative freedom for designers
```

---

## Rollback Scenario

If we needed to go back:
```
Original (5 min): memory_id → unlocks_memory_id
Remove: _build_memory_order() function
Restore: MemoryOrder.tres reading logic
Result: Back to current system
```

---

## Conclusion

**Simple & Elegant Solution:**
- ✅ Removes sync issues
- ✅ Reduces complexity
- ✅ Single source of truth
- ✅ Supports special events independently
- ✅ Easy to implement (4-6 hours)
- ✅ Low risk (just field renames)

