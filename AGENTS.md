---
name: Godot Project Assistant
description: AI agent for the Godot RPG project with full architecture understanding
applyTo: ["**/*.gd", "**/*.tscn", "**/*.tres", "*.md"]
---

# Godot Project Assistant Agent

## Prerequisites
Before assisting with any task in this workspace, you **MUST** read and understand:
- `README.md` - Complete project architecture, resource management system, and core design patterns
- `RESOURCES.md` - Complete inventory of all game resources (stages, memories, skills, cutscenes) organized by game mode
- `BUGS_ARCHIVED.md` - Historical bugs and their solutions (prevents regression)

## Core Responsibilities

### Documentation Maintenance
**Always update markdown files when making changes:**
1. **BUGS_ARCHIVED.md** - Add any bugs you fix with problem, root cause, and solution
2. **RESOURCES.md** - Update if adding/modifying stages, memories, skills, or cutscenes
3. **README.md** - Update architecture notes if you change core systems
4. **AGENTS.md** - Update this file if you discover new patterns or best practices to document

Format for bug documentation:
- Clear problem statement with symptoms
- Root cause with code examples
- Solution with files changed
- Key learnings to prevent regression

### Architecture Understanding
Read `README.md` to understand:
- **Singletons (Autoloads):** SceneSwitcher, GuiManager, CutsceneManager, ProgressManager
- **Resource System:** Custom `.tres` files with recursive folder loading patterns
- **Data Structures:** CutsceneScript, MemoryData, SkillData, StageData, MemoryOrder
- **Component Interactions:** How managers communicate and emit signals
- **Physics Layers:** Player (1), Enemy (2), Environment (3), Interactables (4)

### Common Patterns
When writing code:
1. **Signal-based updates:** Use ProgressManager signals for state changes
2. **Resource IDs:** Always match IDs in code with resource file IDs
3. **UI management ownership:** Each manager owns its UI (no cross-manager UI control)
4. **Recursive resource loading:** Resources load from folders + subfolders automatically
5. **Async patterns:** Use `await` for cutscenes, transitions, and long operations

### Bug Prevention
Reference `BUGS_ARCHIVED.md` to avoid:
- SceneSwitcher managing GuiManager's UI nodes
- Duplicate function calls in property setters
- Incorrect default scene animation states
- Non-matching memory IDs across systems

## When To Ask Questions
If unclear about:
- Project initialization flow → Read `_ready()` in important_scripts
- How resources are loaded → Check `_load_resources()` in progress_manager.gd
- Signal flow between managers → Trace calls in important_scripts
- Scene structure → Check scenes/ folder and attached scenes in main_world.tscn

## Tools & Commands
- **Forward Plus rendering:** Default in project.godot
- **Nearest Neighbor filtering:** For pixel art (default_texture_filter=0)
- **Input map:** ui_left/right/up/down for movement, E for interact, Esc for pause
- **Export:** Use Project > Export in editor for builds

## File Organization
```
/important_scripts/    - Singletons and core managers (DO NOT MODIFY lightly)
/other_scripts/        - Game-specific logic (safer to modify)
/resources/            - Data-driven content and definitions
  /cutscenes/          - CutsceneScript resources
  /memories/           - MemoryData resources  
  /skills/             - SkillData resources
  /stages/             - StageData resources
  /data_structures/    - GDScript class definitions
/scenes/               - Godot .tscn files
/assets/               - Sprites, fonts, audio
```

---

**Last Updated:** April 1, 2026
**Project:** godot_test (2D RPG/Adventure, Godot 4.5)
