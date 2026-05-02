extends Node

signal game_state_changed(state: GameState)
signal rewards_applied(exp_earned: int, crystals_earned: int)

enum Team {PLAYER = 0, OPPONENT = 1}
enum GameState {IDLE = 0, READY = 1, GAME_OVER = 2}

# ============================================================================
# CONSTANTS
# ============================================================================
const SPAWN_LANES: int = 3
const AI_SPAWN_CHANCE: float = 1.0
const DEFAULT_PLAYER_POSITION: Vector2 = Vector2(2352, 3928)
const UNIT_STATS_PATH: String = "res://resources/unit_stats/"
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const DEFAULT_BACKGROUND_PATH: String = "res://scenes/battle/default_background.tscn"

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================
var game_state: GameState = GameState.IDLE

# Battle configuration
var current_config: Dictionary = {}
var enemy_multiplyer: float = 1.0

# Battle statistics
var enemy_killed: int = 0
var damage_dealt: float = 0.0
var battle_time: float = 0.0
var time: float = 0.0
var minutes: int = 0
var seconds: int = 0

# AI configuration
var ai_enabled: bool = true
var ai_cooldown_min: float = 2.0
var ai_cooldown_max: float = 5.0
var ai_cooldown: float = 0.0

# Game state
var game_ended: bool = false

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================
var _return_scene: String = "main_world"
var _battle_scene: PackedScene
var _default_background: PackedScene
var _saved_player_position: Vector2 = Vector2.ZERO
var unit_stats_registry: Dictionary = {}

# Scene references
var curr: Node
var spawn_points: Node2D
var allies_container: Node2D
var opponents_container: Node2D
var elixir: Control
var background_instance: Node

# ============================================================================
# CORE LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Preload battle scene to prevent loading delay during transition
	_battle_scene = load(BATTLE_SCENE_PATH)
	# Preload default background scene to prevent loading delay
	_default_background = load(DEFAULT_BACKGROUND_PATH)

func _process(delta: float) -> void:
	time += delta
	seconds = int(fmod(time, 60))
	minutes = int(fmod(time, 3600) / 60)
	_process_ai_spawning(delta)

# ============================================================================
# BATTLE CONTROL
# ============================================================================

func start_battle(config: Dictionary, return_scene: String = "main_world") -> void:
	# Save player position before transitioning to battle
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_saved_player_position = player.global_position
		print("[BattleManager] Saved player position: ", _saved_player_position)
	else:
		print("[BattleManager] Warning: No player found to save position")
		_saved_player_position = DEFAULT_PLAYER_POSITION
	
	# Configure battle
	current_config = config.duplicate()
	_return_scene = return_scene
	enemy_multiplyer = current_config.get("enemy_multiplyer", 1.0)
	
	# Set default background if none provided
	if not current_config.has("background_scene") or not current_config.background_scene:
		current_config.background_scene = _default_background
	
	# Load enemy stats
	unit_stats_registry.clear()
	var dir = DirAccess.open(UNIT_STATS_PATH)
	
	if not dir:
		push_error("Failed to open unit stats directory: " + UNIT_STATS_PATH)
		return
	
	var files = dir.get_files()
	for file_name in files:
		file_name = file_name.trim_suffix(".remap")
		
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		
		var resource = load(UNIT_STATS_PATH + file_name)
		if not resource or not "cost" in resource:
			continue
		
		if resource.team == Team.OPPONENT:
			var stats_id = file_name.replace(".tres", "").replace(".res", "")
			unit_stats_registry[stats_id] = resource
	
	# Connect to scene transition signal only when battle starts
	if not SceneSwitcher.scene_transition_finished.is_connected(_on_scene_transition_finished):
		SceneSwitcher.scene_transition_finished.connect(_on_scene_transition_finished)
	
	# Transition to battle scene
	if _battle_scene:
		var battle_scene_instance = _battle_scene.instantiate()
		
		# Add background immediately before scene is added to tree
		if current_config.has("background_scene") and current_config.background_scene:
			var bg_node = battle_scene_instance.get_node_or_null("Background")
			if bg_node:
				background_instance = current_config.background_scene.instantiate()
				bg_node.add_child(background_instance)
		
		SceneSwitcher.switch_to_scene_instance(battle_scene_instance, "battle_scene", "fade")
	else:
		SceneSwitcher.switch_scene("battle_scene", "fade")

# ============================================================================
# BATTLE INITIALIZATION & CLEANUP
# ============================================================================

func _on_scene_transition_finished(scene_name: String) -> void:
	match scene_name:
		"battle_scene":
			_initialize_battle()
		_:
			if game_state != GameState.IDLE:
				_cleanup_battle()

func _initialize_battle() -> void:
	# Setup scene references
	curr = SceneSwitcher.current_scene
	
	if not curr:
		push_error("Failed to get current scene reference")
		return
	
	spawn_points = curr.get_node_or_null("SpawnPoints")
	allies_container = curr.get_node_or_null("AlliesContainer")
	opponents_container = curr.get_node_or_null("EnemiesContainer")
	elixir = curr.get_node_or_null("UI/ElixirUI")
	
	# Connect tower signals
	if curr:
		var tower_manager = curr.get_node_or_null("Towers")
		if tower_manager:
			if tower_manager.has_signal("all_towers_destroyed"):
				tower_manager.all_towers_destroyed.connect(_on_all_towers_destroyed)
			if tower_manager.has_signal("tower_destroyed_notify"):
				tower_manager.tower_destroyed_notify.connect(on_tower_destroyed)
	
	# Apply battle configuration
	# Apply AI configuration
	if current_config.has("ai_cooldown_min") and current_config.has("ai_cooldown_max"):
		ai_cooldown_min = current_config.ai_cooldown_min
		ai_cooldown_max = current_config.ai_cooldown_max
	
	# Apply elixir configuration
	if elixir and current_config.has("starting_elixir"):
		elixir.current = current_config.starting_elixir
		elixir.emit_signal("elixir_changed", int(floor(elixir.current)))
	
	# Update background reference
	if current_config.has("background_scene") and current_config.background_scene and curr:
		var bg_node = curr.get_node_or_null("Background")
		if bg_node and bg_node.get_child_count() > 0:
			background_instance = bg_node.get_child(0)
	
	# Reset battle state
	time = 0.0
	minutes = 0
	seconds = 0
	enemy_killed = 0
	damage_dealt = 0.0
	battle_time = 0.0
	ai_enabled = true
	ai_cooldown = randf_range(ai_cooldown_min, ai_cooldown_max)
	game_ended = false
	
	game_state = GameState.READY
	game_state_changed.emit(game_state)

func _cleanup_battle() -> void:
	game_state = GameState.IDLE
	game_state_changed.emit(game_state)
	game_ended = false
	
	# Disconnect from scene transition signal when battle ends
	if SceneSwitcher.scene_transition_finished.is_connected(_on_scene_transition_finished):
		SceneSwitcher.scene_transition_finished.disconnect(_on_scene_transition_finished)
	
	if is_instance_valid(background_instance):
		background_instance.queue_free()
		background_instance = null
	
	curr = null
	spawn_points = null
	allies_container = null
	opponents_container = null
	elixir = null
	ai_enabled = false
	current_config.clear()

# ============================================================================
# AI SPAWNING SYSTEM
# ============================================================================

func _process_ai_spawning(delta: float) -> void:
	if not (ai_enabled and not game_ended):
		return
	
	ai_cooldown -= delta
	
	if ai_cooldown > 0:
		return
	
	if randf() >= AI_SPAWN_CHANCE:
		return
	
	if unit_stats_registry.is_empty():
		return
	
	# Check if there are any alive enemy towers to spawn from
	var alive_enemy_towers = _get_alive_enemy_towers()
	
	if alive_enemy_towers.is_empty():
		print("[AI Spawn] No alive enemy towers - skipping spawn attempt")
		return
	
	ai_cooldown = randf_range(ai_cooldown_min, ai_cooldown_max)
	
	var stats_ids = unit_stats_registry.keys()
	var random_stat = unit_stats_registry[stats_ids[randi() % stats_ids.size()]]
	var lane = randi() % SPAWN_LANES
	
	print("[AI Spawn] Attempting to spawn enemy - Lane: ", lane)
	spawn_enemy(random_stat, lane)

# ============================================================================
# UNIT SPAWNING
# ============================================================================

func _get_alive_enemy_towers() -> Array:
	"""
	Get all alive enemy towers from the scene.
	This method safely checks for destroyed towers and queued-for-deletion nodes.
	Returns: Array of valid, alive enemy tower nodes
	"""
	var enemy_towers = get_tree().get_nodes_in_group("towers")
	var alive_towers = []
	
	for tower in enemy_towers:
		# Skip towers from other teams
		if tower.team != Team.OPPONENT:
			continue
		
		# Skip destroyed towers (multiple checks for safety)
		if tower.is_destroyed:
			print("[Alive Towers Check] Skipping destroyed tower")
			continue
		
		# Skip towers queued for deletion
		if tower.is_queued_for_deletion():
			print("[Alive Towers Check] Skipping tower queued for deletion")
			continue
		
		# Verify tower is still valid
		if not is_instance_valid(tower):
			print("[Alive Towers Check] Tower instance invalid")
			continue
		
		alive_towers.append(tower)
	
	print("[Alive Towers Check] Found ", alive_towers.size(), " alive enemy towers out of ", enemy_towers.size(), " total")
	return alive_towers

func get_spawn_point(team: int, lane: int) -> Vector2:
	match team:
		Team.PLAYER:
			var player = get_tree().get_first_node_in_group("player")
			return player.global_position if is_instance_valid(player) else Vector2.ZERO
		Team.OPPONENT:
			print("[Get Spawn Point] Getting enemy spawn point for lane: ", lane)
			
			# Check if there are any alive enemy towers to spawn from
			var alive_enemy_towers = _get_alive_enemy_towers()
			
			# If no alive enemy towers, don't spawn enemies
			if alive_enemy_towers.is_empty():
				print("[Get Spawn Point] No alive enemy towers - returning ZERO position")
				return Vector2.ZERO
			
			# Use spawn points if available, but only if there are alive towers
			if not spawn_points:
				print("[Get Spawn Point] No spawn points available - returning ZERO")
				return Vector2.ZERO
			
			var suffixes = ["Top", "Middle", "Bottom"]
			var suffix = suffixes[lane] if lane >= 0 and lane < suffixes.size() else "Middle"
			var spawn_node = spawn_points.get_node_or_null("R_" + suffix)
			
			var result = spawn_node.global_position if spawn_node else Vector2.ZERO
			print("[Get Spawn Point] Spawn node found: ", spawn_node != null, " Position: ", result)
			
			# Additional validation: ensure spawn position is reasonable
			if result == Vector2.ZERO:
				print("[Get Spawn Point] WARNING: Spawn position is ZERO - this may indicate configuration issues")
			
			return result
		_:
			return Vector2.ZERO

func spawn_ally(stats: UnitStats, lane: int) -> void:
	if not stats or not allies_container:
		return
	
	if elixir and not elixir.try_consume(stats.cost):
		MessageManager.show_message("聖水不足！")
		return
	
	var pos = get_spawn_point(Team.PLAYER, lane)
	allies_container.spawn_unit(stats, pos, lane)

func spawn_enemy(stats: UnitStats, lane: int) -> void:
	print("[Spawn Enemy] Called - Game ended: ", game_ended, " Stats valid: ", stats != null, " Container valid: ", opponents_container != null)
	
	if not stats or not opponents_container:
		print("[Spawn Enemy] Invalid stats or container - aborting spawn")
		return
	
	var pos = get_spawn_point(Team.OPPONENT, lane)
	print("[Spawn Enemy] Got spawn position: ", pos)
	
	if pos == Vector2.ZERO:
		print("[Spawn Enemy] Spawn position is ZERO - cancelling spawn (likely no alive towers)")
		return
	
	# Additional safety check: verify position is not at origin
	if pos.is_zero():
		print("[Spawn Enemy] ERROR: Spawn position is zero - this should not happen after validation")
		return
	
	print("[Spawn Enemy] Spawning enemy at position: ", pos, " in lane: ", lane)
	opponents_container.spawn_unit(stats, pos, lane)

func can_spawn(team: int, cost: int) -> bool:
	if team == Team.PLAYER and elixir:
		return elixir.get_current_int() >= cost
	
	return true

# ============================================================================
# GAME ENDING
# ============================================================================

func show_ending_screen(winning_team: int) -> void:
	print("[BattleManager] show_ending_screen called with team: ", winning_team)
	
	game_ended = true
	
	var root = SceneSwitcher.current_scene
	
	if not root:
		print("[BattleManager] No current scene found")
		return
	
	var ending_screen = root.get_node_or_null("UI/EndingScreen")
	
	if ending_screen and ending_screen.has_method("show_result"):
		print("[BattleManager] Calling show_result on ending screen")
		ending_screen.call("show_result", winning_team)
		print("min:" + str(minutes) + "sec:" + str(seconds))
	else:
		print("[BattleManager] Ending screen not found, pausing game")
		get_tree().paused = true

func on_tower_destroyed(tower: Node) -> void:
	print("[Tower Destroyed] Tower destroyed - Team: ", tower.team, " Game ended: ", game_ended)
	print("[Tower Destroyed] Tower marked as destroyed: ", tower.is_destroyed)
	
	# Don't end the game for single tower destruction
	# Only the TowerManager should handle game ending when all towers are destroyed
	# This function is now just for logging/debug purposes
	if tower.team == Team.OPPONENT:
		print("[Tower Destroyed] Enemy tower destroyed - AI spawning will check for remaining towers")
		print("[Tower Destroyed] Tower removed from 'towers' group: ", not tower.is_in_group("towers"))
	elif tower.team == Team.PLAYER:
		print("[Tower Destroyed] Player tower destroyed")

func _on_all_towers_destroyed(winning_team: int) -> void:
	print("[BattleManager] All towers destroyed! Winning team: ", winning_team)
	show_ending_screen(winning_team)

# ============================================================================
# STATISTICS TRACKING
# ============================================================================

func on_unit_damage_dealt(_source_unit: UnitBase, amount: float, _target: Node) -> void:
	if game_ended:
		return
	damage_dealt += amount

func on_unit_enemy_killed(_source_unit: UnitBase, _target: Node) -> void:
	if game_ended:
		return
	enemy_killed += 1

func is_game_ended() -> bool:
	return game_ended

# ============================================================================
# REWARDS & PROGRESSION
# ============================================================================

func end_battle(exp_earned: int, crystals_earned: int) -> void:
	ProgressManager.current_exp += exp_earned
	ProgressManager.crystal_count += crystals_earned
	rewards_applied.emit(exp_earned, crystals_earned)
	print("[BattleManager] Applied: +%d EXP, +%d Crystals" % [exp_earned, crystals_earned])
	SceneSwitcher.switch_scene(_return_scene, "fade")


# ============================================================================
# PLAYER POSITION MANAGEMENT
# ============================================================================

func _return_to_main_world() -> void:
	print("[BattleManager] Returning to main world with position restoration")
	SceneSwitcher.switch_scene(_return_scene, "fade")
	
	if not SceneSwitcher.scene_transition_finished.is_connected(_on_return_scene_finished):
		SceneSwitcher.scene_transition_finished.connect(_on_return_scene_finished)

func _on_return_scene_finished(scene_name: String) -> void:
	if scene_name == _return_scene:
		await get_tree().process_frame
		
		var player = get_tree().get_first_node_in_group("player")
		
		if player:
			player.global_position = _saved_player_position
			print("[BattleManager] Restored player position: ", _saved_player_position)
		else:
			print("[BattleManager] Warning: No player found to restore position")
		
		# Disconnect to avoid multiple calls
		if SceneSwitcher.scene_transition_finished.is_connected(_on_return_scene_finished):
			SceneSwitcher.scene_transition_finished.disconnect(_on_return_scene_finished)
