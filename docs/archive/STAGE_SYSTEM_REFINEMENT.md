# Stage and Memory System Refinement Plan

This document outlines the architecture and implementation details for the refined Stage and Memory systems, ensuring they are tightly synchronized and handle non-linear triggering with linear narrative playback.

## 1. System Overview

The system manages the progression of the game through **Stages**, which are directly tied to **Memory Shards**. While stages can be triggered in various ways, the narrative (cutscenes) and rewards (memories) follow a strict, predefined sequence.

### Core Principles
- **Double Binding**: Every `StageData` corresponds to exactly one `MemoryData`.
- **Source of Truth for Order**: The `MemoryOrder` resource defines the sequence for both memories and stages.
- **Incremental EXP**: Experience requirements are relative (deltas) rather than absolute totals.
- **Selective Sequential Locking**: Only EXP-based stages are locked by their predecessors.

---

## 2. Data Structure Changes

### StageData.gd
- **`trigger_by_exp: bool`**: (New) Determines if the stage triggers automatically via EXP or manually via script.
- **`req_exp: int`**: (Modified) Now represents the **incremental EXP** needed since the last EXP-locked stage was completed.
- **`memory_id: String`**: (New) Explicit ID of the memory shard bound to this stage.
- **`cutscene_id: String`**: ID of the cutscene to play.
- **Validation**: `req_exp` will use `@export_range(0, 100000)` to ensure positive values.

---

## 3. ProgressManager Logic

### Initialization
1. Load the `MemoryOrder` resource.
2. Load all `StageData` and `MemoryData` resources.
3. Map stages to the `MemoryOrder` sequence using `memory_id`.
4. `completed_stage_index` tracks the last fully accomplished stage (triggered + cutscene finished).

### EXP Tracking
- **`exp_since_last_milestone: int`**: Tracks EXP gained since the last `trigger_by_exp = true` stage was finalized.
- When a new EXP stage is reached, this value is effectively "spent" or reset by subtracting the requirement.

### Triggering & Locking
- **Manual Stages**: Can be triggered (`triggered_stage_ids.append(id)`) at any time by external signals.
- **EXP Stages**: 
    - Only the **next available EXP stage** in the sequence is checked.
    - It is "locked" until the previous EXP stage in the sequence is finalized.
    - Once unlocked, it monitors `exp_since_last_milestone >= req_exp`.

### Execution (Playback Queue)
- The system checks the `active_stages[completed_stage_index + 1]`.
- If that stage's ID is in `triggered_stage_ids`, its cutscene starts.
- Once the cutscene (and any bound memory cutscene) finishes, the stage is **Finalized**.
- **Finalization**:
    1. Mark memory shard as `unlocked`.
    2. Increment `completed_stage_index`.
    3. If the stage was EXP-locked, reset/adjust `exp_since_last_milestone`.
    4. Re-check for the next stage in the sequence.

---

## 4. Race Conditions & Transitions

- **CutsceneManager Integration**: All cutscene requests are sent to `CutsceneManager.play()`, which handles queueing during scene transitions and prevents overlapping playback.
- **Signal-Driven**: `ProgressManager` strictly waits for the `cutscene_finished` signal before proceeding to the next stage in the sequence, ensuring no state corruption occurs during rapid progression.

---

## 5. Verification Plan

- **Sequential Test**: Trigger Stage 3 (Manual) while Stage 1 (EXP) is incomplete. Verify Stage 3 waits for Stage 1.
- **EXP Delta Test**: Verify that reaching Stage 1 (50 EXP) and Stage 2 (50 EXP) requires a total of 100 EXP, with the counter resetting correctly between them.
- **HUD Compatibility**: `current_exp` will represent progress *within* the current level. `get_next_level_exp()` will return the target for the current level. This ensures the HUD's `EXP: current / next` display remains correct.
- **Memory Bind Test**: Verify that the correct memory is unlocked only after the stage cutscene finishes.
