# Project Terminus - Development Roadmap

This document outlines the remaining tasks and features required to bring **Project Terminus** to a "complete" state.

---

## 1. Resources & Game Content
A complete RPG requires a deep well of content to keep players engaged throughout a full narrative arc.

- **[ ] Expand the Skill Tree**
  - Current skills: `dash`, `fireball`, `heal`.
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
- **[ ] Resource Validation**: Implement a system to check for missing cutscene or memory IDs during load.
- [ ] **Refactor `tp_point.gd` & Battle Config**:
  - **Cleanup**: Remove unused variables (`battle_id`, `battle_name`, `background_color`, `music_track`) and fix "ghost" properties in `.tscn`.
  - **Data Structure**: Replace manual dictionary mapping in `_build_config()` with a dedicated `BattleResource` to unify battle parameters and reduce redundancy.
  - **Inheritance**: Review `AnimatedSprite2D` base class; switch to a simpler node (e.g., `Area2D`) if native animation remains unused.
- **[ ] Performance Tuning**: Optimize the `main_world.tscn` (currently ~6.5MB) for smoother loading.

---

*Last Updated: 2026-04-25*
