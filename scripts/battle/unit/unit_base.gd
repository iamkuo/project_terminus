class_name UnitBase
extends CharacterBody2D

enum Team {PLAYER = 0, OPPONENT = 1}

const unit_selection_circle = preload("res://scripts/battle/ui/unit_selection_circle.gd")

const ARRIVAL_DISTANCE: float = 5.0
const MOVING_SPEED_THRESHOLD: float = 5.0
const MAX_SEARCH_DISTANCE: float = 1e9
const CLICK_COLLISION_RADIUS: float = 20.0
const PLAYER_GOAL_X: float = 1100.0
const OPPONENT_GOAL_X: float = 200.0
const ATTACK_ANIMATION_DELAY: float = 0.3
const DEATH_ANIMATION_DELAY: float = 0.5

signal health_changed(current: int, max: int)
signal died(unit: UnitBase)
signal damage_dealt(amount: int, target: Node)
signal enemy_killed(target: Node)

enum LifecycleState {ALIVE, DYING, DEAD}

@export var stats: UnitStats

var current_health: int
var lifecycle_state: LifecycleState = LifecycleState.ALIVE
var team: Team = Team.PLAYER
var lane: int = 1
var behavior_pattern: BehaviorPattern = null
var selected: bool = false
var current_target: Node = null
var attack_cooldown: float = 0.0
var is_attacking: bool = false


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var selection_circle: Node2D = $SelectionCircle if has_node("SelectionCircle") else null
@onready var properties_ui: Control = $PropertiesUI if has_node("PropertiesUI") else null

func _ready():
	if stats:
		if team == Team.OPPONENT:
			current_health = int(stats.health * ConfigManager.enemy_multiplyer)
		else:
			current_health = int(stats.health * ConfigManager.allies_multiplyer)
	else:
		current_health = 100
		stats = UnitStats.new()
	
	# Hide sprite initially to prevent fallback animation flash
	if sprite:
		sprite.visible = false
	
	# Initialize with correct idle animation for this unit type
	call_deferred("_play_action", "idle")
	
	# Emit health changed signal to initialize UI display
	health_changed.emit(current_health, stats.health)

func _physics_process(delta: float):
	if lifecycle_state != LifecycleState.ALIVE:
		return
	
	# Check if game has ended - stop movement for non-player units
	var battle_manager = _get_battle_manager()
	if battle_manager and battle_manager.has_method("is_game_ended") and battle_manager.is_game_ended():
		# Only allow player movement when game has ended
		if team != Team.PLAYER:
			velocity = Vector2.ZERO
			_play_action("idle")
			return
	
	var was_moving = velocity.length() > MOVING_SPEED_THRESHOLD
	attack_cooldown = max(0.0, attack_cooldown - delta)
	
	# Find attack target and determine movement
	current_target = _find_target()
	var move_target = _get_movement_target(current_target)
	
	# Handle combat if we have a valid target
	if current_target and is_instance_valid(current_target):
		_handle_combat(current_target, move_target)
	else:
		_move_towards(move_target)

	# Animation sync
	var now_moving = velocity.length() > MOVING_SPEED_THRESHOLD
	if was_moving != now_moving:
		_play_action("walk" if now_moving else "idle")


func _play_action(action: String):
	if not sprite or not sprite.sprite_frames:
		return
	var base_name = stats.unit_id if stats else ""
	var anim_name = base_name + "_" + action
	
	# Try to play specific animation for this unit type
	if anim_name in sprite.sprite_frames.get_animation_names():
		sprite.play(anim_name)
		sprite.visible = true
		return
	
	# Fallback: try to find any animation with this action for any unit type
	var available_anims = sprite.sprite_frames.get_animation_names()
	for anim in available_anims:
		if anim.ends_with("_" + action):
			sprite.play(anim)
			sprite.visible = true
			return
	
	# Final fallback: try generic action name (only if it exists and is not fallback)
	if action in available_anims and action != "fallback":
		sprite.play(action)
		sprite.visible = true
		return
	
	# If we reach here, animation system failed - keep fallback animation as visual indicator
	# Don't show sprite for fallback animation

func _get_battle_manager() -> Node:
	return BattleManager

func _perform_attack(target: Node) -> void:
	if is_attacking or not target or not is_instance_valid(target):
		return

	is_attacking = true
	attack_cooldown = 1.0 / stats.attack_speed

	_play_action("attack")

	match stats.attack_type:
		UnitStats.AttackType.DIRECT:
			if target.has_method("take_damage"):
				var final_damage = stats.attack_damage
				if team == Team.PLAYER:
					final_damage = int(final_damage * ConfigManager.allies_multiplyer)
				
				target.take_damage(final_damage, self )
				damage_dealt.emit(final_damage, target)
				if team == Team.PLAYER:
					var bm = _get_battle_manager()
					if bm:
						bm.on_unit_damage_dealt(self , final_damage, target)
		UnitStats.AttackType.PROJECTILE:
			ProjectileManager.spawn_projectile(self , target)

	await get_tree().create_timer(ATTACK_ANIMATION_DELAY).timeout

	is_attacking = false


func take_damage(amount: int, attacker: Node) -> void:
	var actual_damage = max(0, amount - stats.defense)
	current_health -= actual_damage
	
	# Only emit health_changed if unit is still alive (not dying or dead)
	if lifecycle_state == LifecycleState.ALIVE:
		health_changed.emit(max(0, current_health), stats.health)
	
	if current_health <= 0 and lifecycle_state == LifecycleState.ALIVE:
		# Notify the attacker so it can emit enemy_killed and update BattleManager
		if attacker and attacker.has_method("_on_killed_target"):
			attacker._on_killed_target(self)
		lifecycle_state = LifecycleState.DYING
		_play_action("die")
		await get_tree().create_timer(DEATH_ANIMATION_DELAY).timeout
		lifecycle_state = LifecycleState.DEAD
		died.emit(self )
		queue_free()


## Called by the victim unit when it is killed by this unit.
## Allows the attacker to emit enemy_killed and update BattleManager.
func _on_killed_target(target: Node) -> void:
	enemy_killed.emit(target)
	var bm = _get_battle_manager()
	if bm:
		bm.on_unit_enemy_killed(self , target)

func set_behavior_pattern(pattern: BehaviorPattern):
	behavior_pattern = pattern

func select_unit():
	if team != Team.PLAYER:
		return
	selected = true
	if selection_circle and selection_circle is unit_selection_circle:
		selection_circle.show_for_unit(self )

func deselect_unit():
	selected = false
	if selection_circle and selection_circle is unit_selection_circle:
		selection_circle.hide_circle()

func _handle_combat(target: Node, move_target: Vector2):
	var dist = global_position.distance_to(target.global_position)
	
	if dist <= stats.attack_distance:
		# Target in range - attack and face target
		if sprite:
			sprite.flip_h = (target.global_position.x < global_position.x)
		if attack_cooldown <= 0.0:
			_perform_attack(target)
	
	# Move toward movement target (different from attack target in FOLLOW_PLAYER mode)
	_move_towards(move_target)

# Returns where the unit should move based on behavior pattern
func _get_movement_target(attack_target: Node = null) -> Vector2:
	if behavior_pattern:
		return behavior_pattern.get_movement_target(self , attack_target)
	
	# Fallback: if has attack target, move toward it, else lane goal
	if attack_target:
		return attack_target.global_position
	return _get_lane_goal_pos()

func _move_towards(target_pos: Vector2):
	var dir = target_pos - global_position
	if dir.length() < ARRIVAL_DISTANCE:
		velocity = Vector2.ZERO
	else:
		velocity = dir.normalized() * stats.move_speed
		if sprite:
			sprite.flip_h = dir.x < 0
	
	# Check for tower restriction areas before moving
	if team == Team.PLAYER and _is_path_blocked_by_restriction():
		velocity = Vector2.ZERO
	
	move_and_slide()


func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if team != Team.PLAYER or lifecycle_state != LifecycleState.ALIVE:
			return
			
		var local_mouse_pos = to_local(get_global_mouse_position())
		# Collision radius check - around 20 pixels
		if local_mouse_pos.length() <= CLICK_COLLISION_RADIUS:
			get_viewport().set_input_as_handled()
			select_unit()
			_show_control_panel()

func _show_control_panel():
	if properties_ui and properties_ui.has_method("show_for_unit"):
		properties_ui.show_for_unit(self )


func _find_target() -> Node:
	if behavior_pattern:
		return behavior_pattern.get_target_for(self )
	
	# Fallback: find any enemy in view distance, then tower
	var enemy = _find_nearest_enemy_fallback()
	if enemy:
		return enemy
	return _find_nearest_tower_fallback()

# Fallback target search when no behavior pattern is set (simple nearest enemy, then tower)
func _find_nearest_enemy_fallback() -> Node:
	var all_units = get_tree().get_nodes_in_group("units")
	var nearest: Node = null
	var nearest_dist: float = stats.view_distance
	
	for u in all_units:
		if u == self or u.team == team:
			continue
		var dist = global_position.distance_to(u.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = u
	
	return nearest

func _find_nearest_tower_fallback() -> Node:
	var towers = get_tree().get_nodes_in_group("towers")
	var nearest: Node = null
	var nearest_dist: float = 1e9
	
	for tower in towers:
		if tower.team == team:
			continue
		if tower is TowerBase and tower.is_destroyed:
			continue
		var dist = global_position.distance_to(tower.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tower
	
	return nearest

func _get_lane_goal_pos() -> Vector2:
	# For player units, use actual enemy tower positions as goal
	if team == Team.PLAYER:
		var enemy_towers = get_tree().get_nodes_in_group("towers")
		var nearest_tower: Node2D = null
		var nearest_dist: float = 1e9
		
		for tower in enemy_towers:
			if tower.team == Team.PLAYER or tower.is_destroyed:
				continue
			var dist = global_position.distance_to(tower.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_tower = tower
		
		if nearest_tower:
			# Move to a position slightly before the tower (for attack range)
			var direction = (nearest_tower.global_position - global_position).normalized()
			return nearest_tower.global_position - direction * 50.0
		else:
			# Fallback to hardcoded position if no towers found
			return Vector2(PLAYER_GOAL_X, global_position.y)
	else:
		# For enemy units, use hardcoded position or find player towers
		var player_towers = get_tree().get_nodes_in_group("towers")
		var nearest_tower: Node2D = null
		var nearest_dist: float = 1e9
		
		for tower in player_towers:
			if tower.team == Team.OPPONENT or tower.is_destroyed:
				continue
			var dist = global_position.distance_to(tower.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_tower = tower
		
		if nearest_tower:
			var direction = (nearest_tower.global_position - global_position).normalized()
			return nearest_tower.global_position - direction * 50.0
		else:
			return Vector2(OPPONENT_GOAL_X, global_position.y)

func _is_path_blocked_by_restriction() -> bool:
	# Check if unit is inside any tower restriction area
	var restrictions = get_tree().get_nodes_in_group("tower_restrictions")
	for restriction in restrictions:
		if is_instance_valid(restriction):
			# Try to find the unit's Area2D node
			var unit_area = get_node_or_null("Area2D")
			if unit_area and restriction.overlaps_area(unit_area):
				return true
	return false
	
