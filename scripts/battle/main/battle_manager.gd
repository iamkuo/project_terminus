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

# Battle configuration - managed by ConfigManager singleton
# Read directly from ConfigManager.enemy_multiplyer etc.
var enemy_multiplyer: float = 1.0
var allies_multiplyer: float = 1.0

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
var _saved_map_path: String = ""
var unit_stats_registry: Dictionary = {}
var _triggered_tp_points: Array[String] = []

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

func start_battle(player_node: Node2D = null, return_scene: String = "main_world") -> void:
	# Save player position before transitioning to battle
	var player = player_node if is_instance_valid(player_node) else _get_player()
	
	if player:
		_saved_player_position = player.global_position
		print("[BattleManager] Saved player position: ", _saved_player_position, " from node: ", player.get_path())
		
		# Also save which sub-map was active
		var world = SceneSwitcher.current_scene
		if world and world.has_node("MapContainer"):
			var map_container = world.get_node("MapContainer")
			if map_container.get_child_count() > 0:
				_saved_map_path = map_container.get_child(0).scene_file_path
				print("[BattleManager] Saved map path: ", _saved_map_path)
	else:
		print("[BattleManager] Warning: No player found to save position, using default")
		_saved_player_position = DEFAULT_PLAYER_POSITION
	
	_return_scene = return_scene
	enemy_multiplyer = ConfigManager.enemy_multiplyer
	
	# Apply player skill bonuses via SkillManager
	allies_multiplyer = SkillManager.allies_mult
	ConfigManager.allies_multiplyer = allies_multiplyer
	
	# Load enemy stats via config manager
	ConfigManager.load_unit_stats(UNIT_STATS_PATH)
	unit_stats_registry = ConfigManager.unit_stats_registry
	
	# Set default background if none provided
	if not ConfigManager.background_scene:
		ConfigManager.background_scene = _default_background
	
	# Connect to scene transition signal only when battle starts
	if not SceneSwitcher.scene_transition_finished.is_connected(_on_scene_transition_finished):
		SceneSwitcher.scene_transition_finished.connect(_on_scene_transition_finished)
	
	# Transition to battle scene
	if _battle_scene:
		var battle_scene_instance = _battle_scene.instantiate()
		
		# Add background immediately before scene is added to tree
		if ConfigManager.background_scene:
			var bg_node = battle_scene_instance.get_node_or_null("Background")
			if bg_node:
				background_instance = ConfigManager.background_scene.instantiate()
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
	
	# Apply battle configuration from manager
	# Apply AI configuration
	ai_cooldown_min = ConfigManager.ai_cooldown_min
	ai_cooldown_max = ConfigManager.ai_cooldown_max
	
	# Apply elixir configuration
	if elixir:
		elixir.current = ConfigManager.starting_elixir
		elixir.emit_signal("elixir_changed", int(floor(elixir.current)))
	
	# Update background reference
	if ConfigManager.background_scene and curr:
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
	ConfigManager.clear()

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
		return
	
	ai_cooldown = randf_range(ai_cooldown_min, ai_cooldown_max)
	
	# Simplify: Pick a random alive tower and use its lane
	var lane = alive_enemy_towers.pick_random().lane
	
	# Pick a random unit stat from the registry
	var stats_list = unit_stats_registry.values()
	if stats_list.is_empty():
		return
		
	var random_stat = stats_list.pick_random()
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
		
		# Verify tower is still valid
		if not is_instance_valid(tower):
			continue
		
		alive_towers.append(tower)
	
	return alive_towers

func get_spawn_point(team: int, lane: int) -> Vector2:
	match team:
		Team.PLAYER:
			var player = _get_player()
			return player.global_position if is_instance_valid(player) else Vector2.ZERO
		Team.OPPONENT:
			# Check if there are any alive enemy towers to spawn from
			var alive_enemy_towers = _get_alive_enemy_towers()
			
			# If no alive enemy towers, don't spawn enemies
			if alive_enemy_towers.is_empty():
				return Vector2.ZERO
			
			# Use spawn points if available, but only if there are alive towers
			if not spawn_points:
				return Vector2.ZERO
			
			# Verify if the tower for this specific lane is alive
			if not alive_enemy_towers.any(func(t): return t.lane == lane):
				return Vector2.ZERO
			
			var suffixes = ["Top", "Middle", "Bottom"]
			var suffix = suffixes[lane] if lane >= 0 and lane < suffixes.size() else "Middle"
			var spawn_node = spawn_points.get_node_or_null("R_" + suffix)
			
			if not spawn_node:
				return Vector2.ZERO
				
			var result = spawn_node.global_position
			
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
	if not stats or not opponents_container:
		return
	
	var pos = get_spawn_point(Team.OPPONENT, lane)
	
	if pos == Vector2.ZERO:
		return
	
	opponents_container.spawn_unit(stats, pos, lane)

func can_spawn(team: int, cost: int) -> bool:
	if team == Team.PLAYER and elixir:
		return elixir.get_current_int() >= cost
	
	return true

# ============================================================================
# GAME ENDING
# ============================================================================

func show_ending_screen(winning_team: int) -> void:
	game_ended = true
	var root = SceneSwitcher.current_scene
	
	if not root:
		return
	
	var ending_screen = root.get_node_or_null("UI/EndingScreen")
	
	if ending_screen and ending_screen.has_method("show_result"):
		ending_screen.call("show_result", winning_team)
	else:
		get_tree().paused = true

func on_tower_destroyed(_tower: Node) -> void:
	# This function is now just for potential logic expansion or specific tower death effects
	pass

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
	print("[BattleManager] Returning to world: ", _return_scene)
	
	# Connect to scene_added to restore position while the screen is still black
	if not SceneSwitcher.scene_added.is_connected(_on_return_scene_added):
		SceneSwitcher.scene_added.connect(_on_return_scene_added)
	
	SceneSwitcher.switch_scene(_return_scene, "fade")

func _on_return_scene_added(scene_name: String) -> void:
	if scene_name == _return_scene:
		var root = SceneSwitcher.current_scene
		
		# 1. Restore the correct sub-map first
		if root and root.has_method("load_map") and not _saved_map_path.is_empty():
			root.load_map(_saved_map_path)
			print("[BattleManager] Restored active map: ", _saved_map_path)
		
		# 2. Then restore the player position
		var player = _get_player()
		if player:
			player.global_position = _saved_player_position
			print("[BattleManager] Instant restored player position to: ", _saved_player_position, " on node: ", player.get_path())
		else:
			# Fallback: if not found immediately, try again next frame
			await get_tree().process_frame
			player = _get_player()
			if player:
				player.global_position = _saved_player_position
				print("[BattleManager] Delayed restored player position to: ", _saved_player_position, " on node: ", player.get_path())
		
		# Disconnect to avoid multiple calls
		if SceneSwitcher.scene_added.is_connected(_on_return_scene_added):
			SceneSwitcher.scene_added.disconnect(_on_return_scene_added)

func _get_player() -> Node:
	# 1. Primary: Try to find player in the current active scene (most reliable)
	var root = SceneSwitcher.current_scene
	if root:
		# Use unique name if possible
		var player = root.get_node_or_null("%Player")
		if is_instance_valid(player):
			return player
			
		# Search recursively under root
		player = root.find_child("Player", true, false)
		if is_instance_valid(player):
			return player
			
	# 2. Secondary: Try group but filter for valid nodes that aren't being deleted
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			# If we have multiple, prioritize one that is not in the battle scene
			# But for now, returning the first valid one is better than returning a dying one
			return p
			
	return null

func mark_tp_point_triggered(point_id: String) -> void:
	if not point_id.is_empty() and not point_id in _triggered_tp_points:
		_triggered_tp_points.append(point_id)

func is_tp_point_triggered(point_id: String) -> bool:
	if point_id.is_empty():
		return false
	return point_id in _triggered_tp_points
