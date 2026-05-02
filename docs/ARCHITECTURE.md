# Project Terminus - Complete System Architecture

This document provides a comprehensive overview of the entire game architecture, including system interactions, signal flows, and detailed component documentation.

---

## 1. Global Autoloads & Managers Flow

These systems operate globally and manage the core state and transitions of the game.

```mermaid
graph TD
    %% Autoloads
    PM["ProgressManager"]
    SS["SceneSwitcher"]
    GM["GuiManager"]
    CM["CutsceneManager"]
    BTM["BattleTransitionManager"]

    %% Interactions
    PM -->|data_updated| HUD["HUD / UI"]
    PM -->|memory_collected| HUD
    
    SS -->|scene_transition_finished| World["World Scripts"]
    
    GM -->|dialog_finished| Flow["Game Flow Control"]
    GM -->|fullscreen_finished| Flow
    
    CM -->|cutscene_finished| Flow
    
    BTM -->|battle_started| Battle["Battle Scene"]
    BTM -->|rewards_applied| HUD
```

---

## 2. Main World & Progression Flow

This flow covers how the player interacts with the world, triggers cutscenes, and collects items.

```mermaid
graph TD
    %% World Nodes
    Player["Player"]
    TP["tp_point"]
    Shard["Memory Shard"]
    Pause["Pause Menu"]
    HUD["HUD"]
    
    %% Managers
    PM["ProgressManager"]
    BTM["BattleTransitionManager"]

    %% Interactions
    Player -->|Enters Area| TP
    TP -->|Internal: _build_config| TP
    TP -->|start_battle| BTM
    
    Player -->|Interacts| Shard
    Shard -->|collect_memory| PM
    PM -->|memory_collected| Shard
    
    %% Signal Listeners
    PM -->|data_updated| HUD
    BTM -->|rewards_applied| HUD
    
    Pause -->|volume changes| AS["AudioServer"]
    Pause -->|toggles fullscreen| DS["DisplayServer"]
```

---

## 3. Battle System Architecture

### 3.1 Battle Transition Flow

This details the specific bidirectional transition between the RPG World and the Battle Scene.

```mermaid
sequenceDiagram
    participant World as Main World
    participant BTM as BattleTransitionManager
    participant SS as SceneSwitcher
    participant Battle as Battle Scene
    participant PM as ProgressManager
    
    Note over World, Battle: Entering Battle
    World->>BTM: start_battle(config_dict)
    BTM->>BTM: Store config
    BTM-->>Battle: emit battle_started(config)
    BTM->>SS: switch_scene("battle_scene")
    SS->>Battle: Scene Loaded
    Battle->>BTM: Read current_config
    
    Note over World, Battle: Leaving Battle
    Battle->>BTM: end_battle(exp, crystals)
    BTM->>PM: Update EXP and Crystals
    BTM-->>World: emit rewards_applied(exp, crystals)
    BTM->>SS: switch_scene("main_world")
```

### 3.2 Battle Scene Internal Flow

This flow maps out the complex internal interactions and signals within the Battle Scene during gameplay.

```mermaid
graph TD
    %% Battle Managers
    BM["BattleManager"]
    TM["TowerManager"]
    AM["AlliesManager"]
    EM["EnemiesManager"]
    PM_Proj["ProjectileManager"]
    Msg["MessageManager"]
    CM["ConfigManager"]
    
    %% UI & Entities
    SUI["SpawnUI"]
    ES["EndingScreen"]
    Tower["TowerBase"]
    Unit["UnitBase"]
    Card["Card"]
    HB["HealthBar UI"]
    
    %% Setup & Control
    BM -->|Reads config| BCM
    BM -->|Configures| SUI
    BM -->|Configures| TM
    
    %% Gameplay Signals
    SUI -->|elixir_changed| SUI
    Card -->|card_pressed| BM
    BM -->|spawn_ally| AM
    BM -->|spawn_enemy| EM
    
    AM -->|unit_spawned| Unit
    AM -->|spawn_failed| Msg
    
    %% Unit & Combat Signals
    Unit -->|health_changed| HB
    Unit -->|dealt_damage| Unit
    Unit -->|died| Unit
    Unit -->|spawn_projectile| PM_Proj
    
    Tower -->|health_changed| HB
    Tower -->|tower_destroyed| TM
    
    %% End Game Flow
    TM -->|tower_destroyed_notify| BM
    TM -->|all_towers_destroyed| BM
    BM -->|game_state_changed| BM
    BM -->|show_result_with_rewards| ES
    ES -->|end_battle| BTM
```

---

## 4. Core System Components

### 4.1 Battle Managers (Orchestration Layer)

#### **BattleManager** (`scripts/battle/main/battle_manager.gd`)
- **Role**: Central orchestrator of all battle systems
- **Key Responsibilities**:
  - Loads battle configuration via BattleConfigManager
  - Manages scene initialization and cleanup
  - Orchestrates AI spawning system
  - Tracks battle statistics (time, damage dealt, enemies killed)
  - Handles game ending and rewards

- **Key Methods**:
  - `start_battle(config, return_scene)` - Initialize battle with config dict
  - `get_spawn_point(team, lane)` - Returns spawn position for units
  - `spawn_ally(stats, lane)` - Player spawns unit (consumes elixir)
  - `spawn_enemy(stats, lane)` - AI spawns enemy unit
  - `_process_ai_spawning(delta)` - AI loop: checks cooldown, spawns random enemies
  - `show_ending_screen(winning_team)` - Display results screen

- **Key Properties**:
  - `game_state: GameState` - IDLE, READY, GAME_OVER
  - `current_config: Dictionary` - Battle settings
  - `unit_stats_registry: Dictionary` - Loaded enemy unit stats (by ID)
  - `ai_enabled, ai_cooldown_min/max` - AI configuration
  - `enemy_multiplyer` - Difficulty scaling for enemy health

#### **ConfigManager** (`scripts/battle/main/battle_config_manager.gd`)
- **Role**: Central authority for all battle configuration (loaded as singleton "ConfigManager")
- **Key Responsibilities**:
  - Load and validate battle configurations
  - Manage unit registry with caching
  - Provide configuration to all systems
  - Handle configuration overrides and debugging
  - Maintain battle state and statistics

- **Key Methods**:
  - `load_config(config: Dictionary)` - Load configuration from TP Point
  - `clear()` - Clear all configuration
  - `load_unit_stats(unit_stats_path: String)` - Load unit stats into registry

#### **TowerManager** (`scripts/battle/tower/tower_manager.gd`)
- **Role**: Tracks tower health and game end conditions
- **Key Methods**:
  - `_register_all_towers()` - Scan scene for all tower nodes
  - `_check_game_end()` - Verify victory/defeat conditions
  - `_on_tower_destroyed(tower)` - Handle tower destruction
  
- **Key Signals**:
  - `tower_destroyed_notify(tower)` - A tower was destroyed (for debug)
  - `all_towers_destroyed(winning_team)` - Game end: someone lost all towers

- **State Tracking**:
  - `towers: Array` - List of all towers
  - `player_towers: int` - Count of player towers still alive
  - `enemy_towers: int` - Count of enemy towers still alive

### 4.2 Unit Management Layer

#### **AlliesManager** (`scripts/battle/unit/allies_manager.gd`)
- **Role**: Spawn and manage player-controlled units
- **Features**:
  - Validates spawn position and elixir cost
  - Signals unit_spawned for UI updates
  - Sets default behavior pattern (ATTACK_NEAREST_ENEMY)
  - Adds units to groups ("units", "ally_units")

#### **EnemiesManager** (`scripts/battle/unit/enemies_manager.gd`)
- **Role**: Spawn and manage AI-controlled units
- **Features**:
  - Spawns enemy units at random lanes
  - Flips sprite for enemy team direction
  - No cost validation (AI spawning is free)
  - Adds units to groups ("units", "enemy_units")

#### **UnitBase** (`scripts/battle/unit/unit_base.gd`)
- **Role**: Individual unit behavior and combat logic
- **Key Methods**:
  - `_physics_process(delta)` - Main unit loop:
    1. Find target using behavior pattern
    2. Determine movement target
    3. Approach and attack if in range
    4. Update animation (walk/idle/attack)
  - `_find_target()` - Behavior-driven target selection
  - `_handle_combat(target, move_target)` - Attack if in range, move toward goal
  - `_perform_attack(target)` - Execute attack (direct or projectile)
  - `_move_towards(target_pos)` - Move using velocity

- **Key Properties**:
  - `stats: UnitStats` - Unit data (health, damage, speed, attack distance)
  - `team: Team` - PLAYER or OPPONENT
  - `lane: int` - Lane assignment (0-2)
  - `behavior_pattern: BehaviorPattern` - Targeting/movement strategy
  - `lifecycle_state: LifecycleState` - ALIVE, DYING, DEAD
  - `current_target: Node` - Active attack target

- **Key Signals**:
  - `health_changed(current, max)` - Update health bar
  - `died(unit)` - Unit death (for cleanup)
  - `enemy_killed(target)` - Unit killed an enemy
  - `damage_dealt(amount, target)` - Track battle stats

#### **BehaviorPattern** (`scripts/battle/unit/behavior_pattern.gd`)
- **Role**: Encapsulates unit AI logic
- **Pattern Types**:
  - `ATTACK_NEAREST_ENEMY` - Default (find closest enemy, march toward lane goal)
  - `FOLLOW_PLAYER` - Track player unit specifically
  - `DEFEND_TOWER` - Protect friendly tower

### 4.3 Tower System

#### **TowerBase** (`scripts/battle/tower/tower_base.gd`)
- **Role**: Individual tower with health and destruction
- **Key Methods**:
  - `take_damage(amount, attacker)` - Apply damage (reduced by defense)
  - `_destroy()` - Mark destroyed, remove restriction area, signal destruction

- **Key Properties**:
  - `team: Team` - PLAYER or OPPONENT
  - `max_health, current_health` - Tower durability
  - `is_destroyed: bool` - Destruction flag
  - `defense: int` - Damage reduction
  - `_restriction_area: Area2D` - Prevents player units from getting too close to enemy towers

- **Key Signals**:
  - `tower_destroyed(tower)` - Signal to TowerManager
  - `health_changed(current, max)` - Update UI

### 4.4 Projectile System

#### **ProjectileManager** (`scripts/battle/main/projectile_manager.gd`)
- **Role**: Spawn and manage projectiles
- **Method**: `spawn_projectile(shooter, target)` - Create projectile instance
- **Projectile Behavior**:
  - Tracks from shooter position to target
  - Applies damage on hit
  - Team-aware (only damages enemy team)

### 4.5 UI Layer

#### **SpawnUI** (`scripts/battle/ui/spawn_ui.gd`)
- **Role**: Display unit spawn cards and handle player input
- **Features**:
  - Auto-generates cards from player unit stats
  - Hotkey input (1-9 for quick spawn)
  - Toggles visibility (Tab key)
  - Filters available units based on game logic

#### **ElixirUI** (`scripts/battle/ui/elixir_ui.gd`)
- **Role**: Manage and display elixir (spawn currency)
- **Features**:
  - Track current elixir amount
  - Consume elixir on unit spawn
  - Regenerate elixir over time
  - Signal updates to UI

#### **MessageManager** & **EndingScreen**
- Display notifications and final game results

---

## 5. Combat Flow Diagram

```mermaid
flowchart TD
    Start[Battle Start] --> Config["BattleManager<br/>Load Config"]
    Config --> Init["Initialize Scene<br/>Setup Containers<br/>Connect Signals"]
    Init --> Loop["Main Loop Started"]
    
    Loop --> AI["AI Spawning<br/>Check Cooldown"]
    AI --> AIDecision{AI Spawn<br/>Chance?}
    AIDecision -->|No| AIWait["Wait Next Cooldown"]
    AIWait --> Loop
    
    AIDecision -->|Yes| CheckTowers{"Alive Enemy<br/>Towers?"}
    CheckTowers -->|No| AIWait
    CheckTowers -->|Yes| SpawnEnemy["Spawn Random Enemy<br/>at Random Lane"]
    SpawnEnemy --> Loop
    
    Loop --> PlayerAction["Player Clicks Card"]
    PlayerAction --> CanSpawn{"Enough<br/>Elixir?"}
    CanSpawn -->|No| NoElixir["Show Message<br/>Insufficient Elixir"]
    NoElixir --> Loop
    CanSpawn -->|Yes| SpawnAlly["Consume Elixir<br/>Spawn Player Unit"]
    SpawnAlly --> Loop
    
    Loop --> UnitUpdate["Each Unit<br/>Physics Update"]
    UnitUpdate --> FindTarget["Find Attack Target<br/>Using Behavior"]
    FindTarget --> GetMoveTarget["Determine Movement<br/>Target Based on<br/>Pattern/Lane"]
    GetMoveTarget --> InRange{"In Attack<br/>Range?"}
    
    InRange -->|No| MoveTo["Move Toward<br/>Movement Target"]
    MoveTo --> Animation["Update Animation<br/>Walk/Idle"]
    Animation --> UnitUpdate
    
    InRange -->|Yes| Attack["Attack Target"]
    Attack --> DamageType{Attack<br/>Type?}
    DamageType -->|Direct| TakeDamage["Target.take_damage"]
    DamageType -->|Projectile| ProjSpawn["ProjectileManager<br/>spawn_projectile"]
    
    TakeDamage --> TargetDead{"Target<br/>Destroyed?"}
    TargetDead -->|No| Animation
    TargetDead -->|Yes| Dead["Mark DYING<br/>Play Death Anim<br/>Emit died Signal"]
    Dead --> Cleanup["Remove from Scene"]
    Cleanup --> Animation
    
    ProjSpawn --> ProjTravel["Projectile Travels<br/>to Target"]
    ProjTravel --> ProjHit["Projectile Hits"]
    ProjHit --> TakeDamage
    
    Loop --> CheckEnd["Any Towers<br/>Destroyed?"]
    CheckEnd -->|Yes| TowerNotify["TowerManager<br/>Notified"]
    TowerNotify --> CheckWin{All Towers<br/>One Team<br/>Destroyed?}
    CheckWin -->|No| Loop
    CheckWin -->|Yes| GameEnd["Show Ending Screen<br/>Calculate Rewards"]
    GameEnd --> Return["Return to Main World<br/>Apply Rewards"]
    Return --> End[Battle End]
```

---

## 6. Full System Interaction Map (Chronological Flow)

This unified graph maps the game's architecture based on the player's progression through time, from the Main Menu to the Battle results.

```mermaid
graph LR
    subgraph Time0 ["0. Entry & Main Menu"]
        MM["Main Menu"]
        Start["Start Button"]
        Quit["Quit Button"]
    end

    subgraph Time1 ["1. World Exploration"]
        Player["Player"]
        Shard["Memory Shard"]
        Pause["Pause Menu"]
        TP["tp_point"]
        HUD["HUD / UI"]
        PM["ProgressManager"]
        CM["CutsceneManager"]
        GM["GuiManager"]
        AS["AudioServer"]
        DS["DisplayServer"]
        WorldScripts["World Scripts"]
        Flow["Game Flow Control"]
    end

    subgraph Time2 ["2. Battle Initialization"]
        BTM["BattleTransitionManager"]
        SS["SceneSwitcher"]
        BM_Setup["BattleManager Init"]
    end

    subgraph Time3 ["3. Active Combat"]
        BM["BattleManager"]
        TM["TowerManager"]
        AM["AlliesManager"]
        EM["EnemiesManager"]
        SUI["SpawnUI"]
        Card["Card"]
        Unit["UnitBase"]
        Tower["TowerBase"]
        HB["HealthBar UI"]
        PM_Proj["ProjectileManager"]
        Msg["MessageManager"]
    end

    subgraph Time4 ["4. Results & Persistence"]
        ES["EndingScreen"]
    end

    %% --- Entry Flow ---
    MM --> Start
    MM --> Quit
    Start -->|switch_scene| SS
    SS -->|load_world| Player

    %% --- World Flow ---
    Player -->|Explores| Shard
    Shard -->|collect_memory| PM
    PM -->|memory_collected| Shard
    PM -->|data_updated| HUD
    Pause -->|volume_changes| AS
    Pause -->|toggles_fullscreen| DS
    SS -->|scene_transition_finished| WorldScripts
    GM -->|dialog_finished| Flow
    GM -->|fullscreen_finished| Flow
    CM -->|cutscene_finished| Flow

    %% --- Transition Flow ---
    Player -->|Enters Area| TP
    TP -->|Internal: _build_config| TP
    TP -->|start_battle| BTM
    BTM -->|request_switch| SS
    SS -->|load_battle_scene| BM_Setup
    BM_Setup -->|reads_config| BTM
    
    %% --- Battle Flow ---
    BM_Setup -->|Configures| SUI
    BM_Setup -->|Configures| TM
    SUI -->|elixir_changed| SUI
    Card -->|card_pressed| BM
    BM -->|spawn_ally| AM
    BM -->|spawn_enemy| EM
    AM -->|unit_spawned| Unit
    AM -->|spawn_failed| Msg
    Unit -->|health_changed| HB
    Unit -->|dealt_damage| Unit
    Unit -->|died| Unit
    Unit -->|spawn_projectile| PM_Proj
    Tower -->|health_changed| HB
    Tower -->|tower_destroyed| TM
    
    %% --- Resolution Flow ---
    TM -->|tower_destroyed_notify| BM
    TM -->|all_towers_destroyed| BM
    BM -->|game_state_changed| BM
    BM -->|show_result_with_rewards| ES
    ES -->|end_battle| BTM
    BTM -->|Update EXP & Crystals| PM
    BTM -->|rewards_applied| HUD
```

---

## 7. Data Flow Architecture

### Configuration
```
ConfigManager
  └─> Public Variables
       ├─ enemy_multiplyer: float
       ├─ ai_cooldown_min/max: float
       ├─ starting_elixir: int
       ├─ player_tower_hp: int
       ├─ enemy_tower_hp: int
       └─ unit_stats_registry: Dictionary
```

### Unit Stats (Resources)
```
resources/unit_stats/
  ├─ ally_archer.tres → UnitStats
  │   ├─ unit_id: String
  │   ├─ health: int
  │   ├─ attack_damage: int
  │   ├─ attack_speed: float
  │   ├─ move_speed: float
  │   ├─ attack_distance: float
  │   ├─ cost: int (elixir)
  │   └─ attack_type: AttackType (DIRECT/PROJECTILE)
  └─ ...
```

### Signals Flow
```
TowerManager
  └─> tower_destroyed_notify(tower)
  └─> all_towers_destroyed(winning_team) ──> BattleManager.show_ending_screen()

UnitBase
  ├─> health_changed(current, max) ──> HealthBar UI
  ├─> died(unit) ──> Cleanup
  ├─> damage_dealt(amount, target) ──> BattleManager.on_unit_damage_dealt()
  └─> enemy_killed(target) ──> BattleManager.on_unit_enemy_killed()

ElixirUI
  └─> elixir_changed(amount) ──> Update UI Display

SpawnUI
  └─> card_pressed ──> BattleManager.spawn_ally()
```

---

## 8. Resource Management

### Resource Loading Flow

The `ProgressManager` initializes resources in this order:

1. **Load Stages**: Load all stages for current mode from `resources/stages/{mode}/`
2. **Sort Stages**: Sort by `req_exp` (ascending)
3. **Load Skills**: Load all skills from `resources/skills/`
4. **Initialize Skill Levels**: Set all skills to level 1
5. **Load Cutscenes**: Load all cutscenes from `resources/cutscenes/`
6. **Load Memories**: Load all memories from `resources/memories/`
7. **Load Memory Order**: Load mode-specific order from `resources/memories/orders/{mode}_memory_order.tres`
8. **Arrange Memories**: Order memories according to MemoryOrder resource
9. **Check Progression**: Trigger any stages that current exp qualifies for

---

## 9. Optimization Opportunities

1. **Object Pooling**: Reuse unit and projectile instances instead of instantiate/free
2. **Spatial Partitioning**: Optimize target finding with quadtrees instead of scene tree queries
3. **Update Batching**: Group unit updates instead of individual _physics_process calls
4. **Behavior Tree**: Replace pattern switching with proper behavior tree for complex AI
5. **Caching**: Cache tower lists instead of querying scene tree every frame

---

## 10. Testing Recommendations

1. **Tower Destruction Edge Cases**:
   - Rapid tower destruction (multiple towers same frame)
   - Verify no spawns on destroyed towers
   - Verify proper game end detection

2. **AI Spawning**:
   - Test with all enemy towers alive
   - Test with 1 tower alive
   - Test with tower destroyed mid-spawn
   - Verify spawn position is valid

3. **Combat Scenarios**:
   - Multi-lane unit battles
   - Projectile vs direct attacks
   - Rapid unit spawning
   - Game ending correctly for both win/loss

---

**Last Updated:** May 2, 2026  
**Status:** Complete system architecture documentation  
**Related Documentation:** [`../RESOURCES.md`](../RESOURCES.md) | [`../BUGS_ARCHIVED.md`](../BUGS_ARCHIVED.md) | [`../AGENTS.md`](../AGENTS.md)
