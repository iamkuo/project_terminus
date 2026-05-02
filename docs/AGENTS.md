---
name: Godot Project Assistant
description: AI agent for the Godot RPG project with full architecture understanding
applyTo: ["**/*.gd", "**/*.tscn", "**/*.tres", "*.md"]
---

# Godot Project Assistant Agent

## Quick Reference
- **Architecture Details:** `README.md`, `docs/ARCHITECTURE.md`
- **Bug History:** `docs/BUGS_ARCHIVED.md` 
- **Resource System:** `docs/RESOURCES.md`
- **Development Plan:** `docs/ROADMAP.md`

## Core Responsibilities

### Documentation Maintenance
Update these files when making changes:
1. **docs/BUGS_ARCHIVED.md** - Bug fixes with problem, root cause, solution
2. **docs/ARCHITECTURE.md** - Cross-script signal interactions
3. **README.md** - Core system architecture changes

### Key Patterns
1. **Signal-based updates** - Use ProgressManager signals for state changes
2. **Direct global access** - Read manager variables directly (avoid single-line wrappers)
3. **UI ownership** - Each manager owns its UI (no cross-manager control)
4. **Resource ID matching** - Code IDs must match resource file IDs
5. **Async operations** - Use `await` for cutscenes, transitions

### Critical Singleton Managers
SceneSwitcher, GuiManager, CutsceneManager, ProgressManager, ConfigManager, BattleManager, ProjectileManager, MessageManager, SkillManager

### Bug Prevention
Check `docs/BUGS_ARCHIVED.md` for common issues:
- SceneSwitcher UI management conflicts
- Property setter duplicate calls
- Default animation states
- Memory ID mismatches

### When To Reference Documentation
- **Project flow:** `README.md` initialization sections
- **Resource loading:** `progress_manager.gd` `_load_resources()`
- **Signal flow:** `important_scripts` call traces
- **Scene structure:** `scenes/` folder and main_world.tscn

---

**Last Updated:** May 2, 2026
