# Game Architecture and Signal Interactions

This document maps out the interactions between the different scripts and systems in the game, categorized by their main components and stages.

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

## 3. Battle Transition Flow

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

## 4. Battle Scene Internal Flow

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
    
    %% UI & Entities
    SUI["SpawnUI"]
    ES["EndingScreen"]
    Tower["TowerBase"]
    Unit["UnitBase"]
    Card["Card"]
    HB["HealthBar UI"]
    
    %% Setup & Control
    BM -->|Reads config| BTM["BattleTransitionManager"]
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

## 5. Full System Interaction Map (Chronological Flow)

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

