# Project Terminus - Development Roadmap
**Consolidated from planning documents | Updated: May 29, 2026**

This document outlines the current status, remaining tasks, and features required to bring **Project Terminus** to a "complete" state.

---

## Current Status

### ✅ Completed (Phase 1 & Recent Updates)
- Implemented ConfigManager singleton to centralize battle configuration.
- Stage system refined with `unlocks_memory_id` field for direct memory unlocking.
- Reorganized Game Resource Folders into `resources/mode_data/` for easier mode management.
- Added mode validation and resource validation to `ProgressManager`.
- Merged cutscene loading functions to simplify directory traversal.
- Renamed StageCollection Resource Script to `stage_order.gd` for clarity.

### 🔄 In Progress
- **Manager Decoupling**: Reduce tight coupling between systems.
- **Save/Load System Persistence**.

---

## 1. Resources & Game Content
A complete RPG requires a deep well of content to keep players engaged throughout a full narrative arc.

- **[ ] Expand the Skill Tree**
  - Current skills: `allies_multiplier`, `player_speed`, `tower_health`.
  - Goal: 10-15 unique skills including passive buffs, debuffs, and area-of-effect (AoE) abilities.
- **[ ] Complete the Narrative Arc**
  - Ensure all 17+ cutscenes and 13+ memories form a cohesive story from the intro to the finale.
  - Add missing "climax" and "resolution" cutscenes.
- **[ ] Map Variety & Level Design**
  - Create distinct zones (e.g., Whispering Forest, Industrial Capital, Ruined Temple).
  - Add secret areas or optional side-path shards.
- **[ ] Unit & Enemy Diversity**
  - Design new unit types for the battle system (e.g., Tank, Support, Long-range Artillery).
  - Balance enemy AI and stats across all stages.

---

## 2. Core Systems & Persistence
These systems provide the structural integrity needed for a professional game.

- **[ ] Persistence System (Save/Load)**
  - Implement disk-based saving for:
    - Player Stats (`crystal_count`, `current_exp`).
    - Collection Progress (`unlocked_memory_ids`).
    - Skill Upgrades (`player_skill_levels`).
- **[ ] Settings Persistence**
  - Save audio levels (Master/Music/SFX) and display settings (Fullscreen/Resolution) to a `config.cfg` file.
- **[ ] Game Flow Completion**
  - **Game Over Screen**: Handle player defeat in battle or world events.
  - **Ending/Credits**: Create a proper sequence for completing the game.

---

## 3. UI/UX & Polishing (The "Juice")
This category focuses on the player experience and visual fidelity.

- **[ ] Tutorial & Onboarding**
  - Create a guided "Prologue" stage that explains:
    - Movement and Interaction.
    - Collecting Shards/Memories.
    - Battle System mechanics (Elixir management and Unit spawning).
- **[ ] Audio Expansion**
  - **Music**: Add unique tracks for exploration, combat, and menus.
  - **SFX**: High-quality impact sounds, UI clicks, and ambient world sounds.
- **[ ] Visual Effects (VFX)**
  - Combat impact particles and ability animations.
  - Environmental polish (fog, lighting transitions, particle-based torches).
- **[ ] HUD Improvements**
  - Add more visual feedback for experience gain and memory collection.

---

## 4. Technical Debt & Optimization
- **[ ] Manager Decoupling**: Reduce tight coupling between `ProgressManager` and other systems.
- **[ ] Performance Tuning**: Optimize the `main_world.tscn` (currently ~6.5MB) for smoother loading.
- **[ ] Refactor `tp_point.gd` & Battle Config**:
  - Cleanup unused variables in `tp_point.gd` and fix "ghost" properties in `.tscn`.
